/**
 * Chat API - Streaming conversation endpoint
 * 
 * Phase 1: Unified with consult pipeline
 * Grayscale flag: USE_UNIFIED_CONSULT (default: true)
 */

import OpenAI from 'openai';
import { NextRequest } from 'next/server';
import { loadUserProfile, formatFullProfile, fireRecordFromTurn } from '@/lib/memory';
import { getUserFromBearer } from '@/lib/api/auth-user';
import {
  buildEffectiveUserProfile,
  buildGeneralContextPrompt,
  normalizeAiPersona,
  resolveAiConversation,
} from '@/lib/ai/general-context';
import { classifyIntent } from '@/lib/ai/intent';
import { logChatInteraction } from '@/lib/logging/chat-logger';
import {
  buildRoleSystemPrompt,
  runConsultStages,
  streamGenerate,
  type ConsultStages,
} from '@/lib/pipelines/consult-pipeline';
import { loadPersona } from '@/lib/knowledge/persona-loader';

// Grayscale flag
const USE_UNIFIED_CONSULT = process.env.USE_UNIFIED_CONSULT !== 'false';

// Legacy Moonshot client (for old path)
function getClient() {
  return new OpenAI({
    apiKey: process.env.MOONSHOT_API_KEY || 'dummy-key-for-build',
    baseURL: 'https://api.moonshot.cn/v1',
  });
}

// Legacy hardcoded prompt, kept only for the USE_UNIFIED_CONSULT=false fallback.
const LEGACY_SYSTEM_PROMPT = `你是「瓷言」，艺见心平台的 AI 艺术助手。

【你的范围】
- 艺术学习与申请规划
- 作品集、创作叙事和艺术家展示
- 展览活动、收藏入门和艺术鉴赏
- 机构、画廊、空间与品牌的展示和运营建议

【回答原则】
- 先识别用户身份和目标，不要默认所有问题都是艺术留学申请
- 信息不足时先问 2-4 个关键问题
- 给出具体、可执行的下一步
- 不编造数字、日期、链接或平台未提供的事实`;

export async function POST(request: NextRequest) {
  const startTime = Date.now();

  try {
    const body = await request.json();
    const { context, intent, userProfile: providedProfile } = body;
    const persona = normalizeAiPersona(body.persona ?? body.aiProfileKey ?? providedProfile?.aiProfileKey);
    const conversation = resolveAiConversation(body);

    // Get user
    const user = await getUserFromBearer(request);
    const loadedProfile = user ? await loadUserProfile(user.id) : null;
    const userProfile = buildEffectiveUserProfile({
      loadedProfile,
      providedProfile,
      context,
      persona,
    });

    if (!conversation.query) {
      return new Response(
        JSON.stringify({ error: 'Message is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Grayscale: Use unified pipeline or legacy path
    if (USE_UNIFIED_CONSULT) {
      return await handleUnifiedPath(
        user,
        userProfile,
        conversation.history,
        conversation.query,
        context,
        { persona, intent },
        startTime
      );
    } else {
      return await handleLegacyPath(user, userProfile, conversation.messages, conversation.query, context);
    }
  } catch (error) {
    console.error('Chat API error:', error);
    return new Response(
      JSON.stringify({ error: '瓷言暂时出了点问题，请稍后再试 🙏' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}

/**
 * Unified path: Use consult pipeline + streaming
 */
async function handleUnifiedPath(
  user: any,
  userProfile: any,
  history: any[],
  lastUserMessage: string,
  context: any,
  options: { persona?: string; intent?: unknown },
  startTime: number
) {
  console.log('[chat] Using unified pipeline');

  let stages: ConsultStages;
  try {
    // Run unified consult pipeline
    stages = await runConsultStages({
      query: lastUserMessage,
      userId: user?.id,
      mode: 'chat',
      history,
      userProfile,
    });
  } catch (error) {
    console.warn('[chat] Unified pipeline failed, falling back to no-retrieval chat:', error);
    stages = buildNoRetrievalStages({
      lastUserMessage,
      history,
      userProfile,
    });
  }

  // Load persona and inject into system prompt
  const basePersona = loadPersona('artsee', 'v1');
  const generalContextPrompt = buildGeneralContextPrompt({
    persona: options.persona,
    requestedIntent: options.intent,
    context,
  });
  let systemPrompt = [basePersona, generalContextPrompt, stages.systemPrompt].filter(Boolean).join('\n\n');

  // Inject tracker context if provided
  if (context?.trackerItems?.length > 0) {
    systemPrompt += `\n\n【用户当前申请清单】\n`;
    context.trackerItems.forEach((item: { school_name: string; program_name: string; tier: string; status: string }) => {
      systemPrompt += `- ${item.school_name} | ${item.program_name} | ${item.tier === 'reach' ? '冲刺' : item.tier === 'match' ? '匹配' : '保底'} | ${item.status}\n`;
    });
  }

  // Update stages with persona-enhanced prompt
  stages.systemPrompt = systemPrompt;

  // Stream generate
  let fullAssistantMessage = '';
  const encoder = new TextEncoder();

  const readableStream = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of streamGenerate(stages)) {
          if (chunk.done) {
            controller.enqueue(encoder.encode('data: [DONE]\n\n'));
            controller.close();

            const latencyMs = Date.now() - startTime;

            // Fire-and-forget: Record to memory
            if (user && lastUserMessage && fullAssistantMessage) {
              fireRecordFromTurn({
                userId: user.id,
                userMessage: lastUserMessage,
                assistantMessage: fullAssistantMessage,
                sourceRoute: 'chat',
              });
            }

            // Fire-and-forget: Log to chat_logs
            logChatInteraction({
              userId: user?.id,
              route: 'chat',
              query: lastUserMessage,
              rewrittenQuery: stages.rewrittenQuery,
              intent: stages.intent,
              retrievedChunkIds: stages.retrievedChunkIds,
              answer: fullAssistantMessage,
              lowConfidence: stages.lowConfidence,
              latencyMs,
            });
            break;
          }

          if (chunk.text) {
            fullAssistantMessage += chunk.text;
            const data = JSON.stringify({ text: chunk.text });
            controller.enqueue(encoder.encode(`data: ${data}\n\n`));
          }
        }
      } catch (err) {
        controller.error(err);
      }
    },
  });

  return new Response(readableStream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}

function buildNoRetrievalStages({
  lastUserMessage,
  history,
  userProfile,
}: {
  lastUserMessage: string;
  history: Array<{ role?: string; content?: string }>;
  userProfile: any;
}): ConsultStages {
  const recentHistory = (history || [])
    .slice(-8)
    .map((message) => {
      const role = message.role === 'assistant' ? '助手' : '用户';
      const content = String(message.content || '').trim();
      return content ? `${role}: ${content}` : '';
    })
    .filter(Boolean)
    .join('\n');

  return {
    systemPrompt: [
      buildRoleSystemPrompt(userProfile),
      '【临时降级说明】知识库检索或 embedding 服务暂时不可用。本轮请按通用艺术留学顾问能力回答：可以做思路拆解、信息补充清单、判断框架和下一步建议；不要编造具体排名、学费、截止日期、录取率、作品集页数等需要知识库或官方来源核验的硬数据。遇到硬数据问题时，请说明需要核对官方或平台知识库。',
    ].join('\n\n'),
    userMessage: [
      recentHistory ? `【最近对话】\n${recentHistory}` : '',
      `【用户当前问题】\n${lastUserMessage}`,
    ]
      .filter(Boolean)
      .join('\n\n'),
    sources: [],
    intent: classifyIntent(lastUserMessage).intent,
    lowConfidence: true,
    retrievedChunkIds: [],
  };
}

/**
 * Legacy path: Old hardcoded prompt + Moonshot
 */
async function handleLegacyPath(
  user: any,
  userProfile: any,
  messages: any[],
  lastUserMessage: string,
  context: any
) {
  console.log('[chat] Using legacy path');

  // Build system prompt with optional context
  let systemPrompt = LEGACY_SYSTEM_PROMPT;

  // Inject user profile
  if (userProfile) {
    const profileText = formatFullProfile(userProfile, {
      identity: true,
      constraints: true,
      preferences: 'full',
    });
    if (profileText) {
      systemPrompt += `\n\n${profileText}`;
    }
  }

  // Inject tracker context
  if (context?.trackerItems?.length > 0) {
    systemPrompt += `\n\n【用户当前申请清单】\n`;
    context.trackerItems.forEach((item: { school_name: string; program_name: string; tier: string; status: string }) => {
      systemPrompt += `- ${item.school_name} | ${item.program_name} | ${item.tier === 'reach' ? '冲刺' : item.tier === 'match' ? '匹配' : '保底'} | ${item.status}\n`;
    });
  }

  // Create streaming response
  const stream = await getClient().chat.completions.create({
    model: 'moonshot-v1-32k',
    max_tokens: 2048,
    stream: true,
    messages: [
      { role: 'system', content: systemPrompt },
      ...messages.map((msg: { role: string; content: string }) => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content,
      })),
    ],
  });

  // Return a ReadableStream for SSE
  let fullAssistantMessage = '';
  const encoder = new TextEncoder();

  const readableStream = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of stream) {
          const text = chunk.choices[0]?.delta?.content ?? '';
          if (text) {
            fullAssistantMessage += text;
            const data = JSON.stringify({ text });
            controller.enqueue(encoder.encode(`data: ${data}\n\n`));
          }
        }
        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();

        // Fire-and-forget: Record to memory
        if (user && lastUserMessage && fullAssistantMessage) {
          fireRecordFromTurn({
            userId: user.id,
            userMessage: lastUserMessage,
            assistantMessage: fullAssistantMessage,
            sourceRoute: 'chat',
          });
        }
      } catch (err) {
        controller.error(err);
      }
    },
  });

  return new Response(readableStream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}
