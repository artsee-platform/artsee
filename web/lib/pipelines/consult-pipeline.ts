/**
 * Unified Consult Pipeline
 * 
 * Phase 1: Unify chat and consult routes
 * 
 * Architecture:
 * - runConsultStages: Shared non-streaming logic (rewrite → retrieve → rerank → intent → prompt)
 * - generate: Non-streaming generation (for consult API)
 * - streamGenerate: Streaming generation (for chat API)
 */

import { searchKnowledgeWithSchoolInfo } from '@/lib/knowledge/retriever';
import { hybridSearchKnowledge } from '@/lib/knowledge/hybrid-retriever';
import { getRetrievalPolicy } from '@/lib/knowledge/retrieval-policy';
import { createClient } from '@/lib/supabase/server';
import { classifyIntent, IntentType } from '@/lib/ai/intent';
import { buildSystemPrompt, buildUserMessage } from '@/lib/knowledge/prompt-builder';
import { runSchoolFitAnalysis } from './school-fit-pipeline';
import fs from 'fs';
import path from 'path';
import {
  loadUserProfile,
  rewriteQueryWithProfile,
  rerankChunksWithProfile,
  searchUserMemories,
  formatMemoriesForPrompt,
  rewriteQueryWithHistory,
  formatHistoryForPrompt,
} from '@/lib/memory';

const CHAT_API_KEY =
  process.env.OPENAI_API_KEY ||
  process.env.MOONSHOT_API_KEY ||
  process.env.GLM_API_KEY;
const CHAT_BASE_URL =
  process.env.OPENAI_BASE_URL ||
  process.env.AI_BASE_URL ||
  process.env.GLM_BASE_URL ||
  'https://api.openai.com/v1';
const CHAT_MODEL = process.env.AI_MODEL || process.env.CHAT_MODEL || 'deepseek-chat';

function chatCompletionsUrl(): string {
  return `${CHAT_BASE_URL.replace(/\/$/, '')}/chat/completions`;
}

// Cache for Evidence Guard prompt
let evidenceGuardPrompt: string | null = null;

/**
 * Load Evidence Guard prompt
 */
function loadEvidenceGuard(): string {
  if (!evidenceGuardPrompt) {
    const promptPath = path.join(process.cwd(), 'lib', 'knowledge', 'prompts', 'guard.no-evidence.v1.md');
    evidenceGuardPrompt = fs.readFileSync(promptPath, 'utf-8');
  }
  return evidenceGuardPrompt;
}

// School name mappings for extraction
const SCHOOL_MAPPINGS: Record<string, string> = {
  '皇艺': 'royal-college-art',
  'rca': 'royal-college-art',
  'csm': 'central-saint-martins',
  '中央圣马丁': 'central-saint-martins',
  'ual': 'university-arts-london',
  '伦艺': 'university-arts-london',
  'parsons': 'parsons-school-design',
  '帕森斯': 'parsons-school-design',
  'pratt': 'pratt-institute',
  'risd': 'risd',
  'scad': 'scad',
  'sva': 'school-visual-arts',
  'goldsmiths': 'goldsmiths-university-london',
  '金匠': 'goldsmiths-university-london',
  'edinburgh': 'edinburgh-college-art',
  '爱丁堡': 'edinburgh-college-art',
  'falmouth': 'falmouth-university',
  'bournemouth': 'bournemouth-university',
};

/**
 * Extract school slug from query text
 */
function extractSchoolSlug(question: string): string | null {
  const lowerQ = question.toLowerCase();
  
  for (const [keyword, slug] of Object.entries(SCHOOL_MAPPINGS)) {
    if (lowerQ.includes(keyword.toLowerCase())) {
      return slug;
    }
  }
  
  return null;
}

/**
 * Extract school ID from query by matching school names
 */
async function extractSchoolFromQuery(question: string, supabase: any): Promise<string | null> {
  const schoolSlug = extractSchoolSlug(question);
  if (!schoolSlug) {
    return null;
  }

  const { data, error } = await supabase
    .from('schools')
    .select('id')
    .eq('slug', schoolSlug)
    .single();

  if (error || !data) {
    return null;
  }

  return data.id;
}

export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface ConsultInput {
  query: string;
  userId?: string;
  schoolId?: string;
  mode: 'short' | 'report' | 'chat';
  history?: Message[];
  userProfile?: any; // Provided profile (optional)
}

export interface Source {
  schoolId?: string;
  schoolName?: string;
  heading: string;
  similarity: number;
  chunkId: string;
}

export interface ConsultStages {
  systemPrompt: string;
  userMessage: string;
  sources: Source[];
  intent: IntentType;
  lowConfidence: boolean;
  retrievedChunkIds: string[];
  rewrittenQuery?: string;
  schoolData?: any;
}

/**
 * Run all non-streaming stages of the consult pipeline
 * 
 * This is the shared core logic used by both chat and consult routes.
 */
export async function runConsultStages(input: ConsultInput): Promise<ConsultStages> {
  const { query, userId, schoolId, mode, history, userProfile: providedProfile } = input;

  const supabase = await createClient();

  // Load user profile if authenticated
  let userProfile = providedProfile;
  if (userId && !providedProfile) {
    userProfile = await loadUserProfile(userId);
  }

  // Step 1: Rewrite query with conversation history (Phase 1.5)
  const historyRewriteResult = await rewriteQueryWithHistory(query, history || []);
  let searchQuery = historyRewriteResult.rewrittenQuery;

  if (historyRewriteResult.rewritten) {
    console.log(`[pipeline] History rewrite: "${query}" → "${searchQuery}"`);
  }

  // Step 2: Rewrite query with user profile
  const profileRewriteResult = rewriteQueryWithProfile(searchQuery, userProfile);
  searchQuery = profileRewriteResult.rewrittenQuery;

  if (profileRewriteResult.rewritten) {
    console.log(`[pipeline] Profile rewrite: added context`);
  }

  // Extract school from query if not explicitly provided
  let effectiveSchoolId = schoolId;
  if (!effectiveSchoolId) {
    const extractedSchoolId = await extractSchoolFromQuery(query, supabase);
    if (extractedSchoolId) {
      effectiveSchoolId = extractedSchoolId;
      console.log(`[pipeline] Extracted school from query: ${extractedSchoolId}`);
    }
  }

  // Retrieve school data if specified
  let schoolData = null;
  if (effectiveSchoolId) {
    const { data } = await supabase
      .from('schools')
      .select('id, slug, name_en, name_zh, country, city, website')
      .eq('id', effectiveSchoolId)
      .single();
    schoolData = data;
  }

  // Intent classification (before retrieval to decide parameters)
  const intentResult = classifyIntent(query);

  // Phase 3.1: Get retrieval policy based on intent
  const policy = getRetrievalPolicy(intentResult.intent);
  const matchCount = mode === 'report' ? policy.matchCount * 2 : policy.matchCount;

  console.log(`[pipeline] Intent: ${intentResult.intent}, threshold: ${policy.matchThreshold}, count: ${matchCount}, hybrid: ${policy.useHybrid}`);

  // Retrieve knowledge chunks
  // Phase 3.1: Use intent-specific retrieval parameters
  // Phase 4.2: Use multi-hop retrieval for school_fit_analysis
  let knowledgeChunks;

  if (intentResult.intent === 'school_fit_analysis') {
    console.log('[pipeline] Using multi-hop retrieval for school_fit_analysis');
    const fitResult = await runSchoolFitAnalysis(
      searchQuery,
      effectiveSchoolId || undefined,
      userProfile,
      {
        matchThreshold: policy.matchThreshold,
        topK: matchCount,
      }
    );
    knowledgeChunks = fitResult.chunks;
    console.log(`[pipeline] Multi-hop retrieved ${fitResult.totalRetrieved} chunks, merged to ${knowledgeChunks.length}`);
  } else if (policy.useHybrid) {
    console.log('[pipeline] Using hybrid retrieval');
    knowledgeChunks = await hybridSearchKnowledge(searchQuery, {
      schoolId: effectiveSchoolId || undefined,
      matchThreshold: policy.matchThreshold,
      matchCount,
      useHybrid: true,
    });
  } else {
    knowledgeChunks = await searchKnowledgeWithSchoolInfo(searchQuery, {
      schoolId: effectiveSchoolId || undefined,
      matchThreshold: policy.matchThreshold,
      matchCount,
    });
  }

  // Rerank with profile
  const rerankResult = rerankChunksWithProfile(knowledgeChunks, userProfile);
  knowledgeChunks = rerankResult.items;

  // Search user memories
  let userMemories: any[] = [];
  if (userId) {
    userMemories = await searchUserMemories(userId, query, {
      matchThreshold: 0.6,
      matchCount: 3,
    });
  }

  // Build system prompt
  // Phase 3.2: Pass intent to load intent-specific skill prompt
  let systemPrompt = buildSystemPrompt({
    userProfile,
    profileSlots: intentResult.slots,
    schoolData: schoolData || undefined,
    knowledgeChunks: knowledgeChunks.map((c) => ({
      chunk_text: c.chunkText,
      heading_path: c.headingPath,
      similarity: c.similarity,
    })),
    mode: mode as 'short' | 'report',
    intent: intentResult.intent,
  });

  // Inject user memories into system prompt
  if (userMemories.length > 0) {
    const memoriesText = formatMemoriesForPrompt(userMemories);
    systemPrompt += `\n\n${memoriesText}`;
  }

  // Determine low confidence
  const avgSimilarity =
    knowledgeChunks.length > 0
      ? knowledgeChunks.reduce((sum, c) => sum + c.similarity, 0) / knowledgeChunks.length
      : 0;
  const lowConfidence = knowledgeChunks.length === 0 || avgSimilarity < 0.5;

  // Evidence Guard: Add safety constraint for hard_data queries with low confidence
  if (lowConfidence && intentResult.intent === 'hard_data') {
    const guardPrompt = loadEvidenceGuard();
    systemPrompt += `\n\n${guardPrompt}`;
    console.log('[pipeline] Evidence Guard activated: low confidence on hard_data query');
  }

  // Build user message
  const userMessage = buildUserMessage(query);

  return {
    systemPrompt,
    userMessage,
    sources: knowledgeChunks.map((c) => ({
      schoolId: c.schoolId,
      schoolName: c.schoolName,
      heading: c.headingPath,
      similarity: c.similarity,
      chunkId: c.chunkId,
    })),
    intent: intentResult.intent,
    lowConfidence,
    retrievedChunkIds: knowledgeChunks.map((c) => c.chunkId),
    rewrittenQuery: historyRewriteResult.rewritten ? historyRewriteResult.rewrittenQuery : undefined,
    schoolData: schoolData || undefined,
  };
}

/**
 * Non-streaming generation (for consult API)
 */
export async function generate(
  stages: ConsultStages,
  options: {
    model?: string;
    temperature?: number;
    maxTokens?: number;
  } = {}
): Promise<{ answer: string }> {
  const { model = CHAT_MODEL, temperature = 0.7, maxTokens = 800 } = options;

  if (!CHAT_API_KEY) {
    throw new Error('Missing chat API key. Set OPENAI_API_KEY, MOONSHOT_API_KEY, or GLM_API_KEY.');
  }

  const response = await fetch(chatCompletionsUrl(), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${CHAT_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: stages.systemPrompt },
        { role: 'user', content: stages.userMessage },
      ],
      temperature,
      max_tokens: maxTokens,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Chat API error: ${errorText}`);
  }

  const data = await response.json();
  const answer = data.choices?.[0]?.message?.content || 'No response generated';

  return { answer };
}

/**
 * Streaming generation (for chat API)
 * 
 * Returns an async generator that yields text chunks
 */
export async function* streamGenerate(
  stages: ConsultStages,
  options: {
    model?: string;
    temperature?: number;
    maxTokens?: number;
  } = {}
): AsyncGenerator<{ text: string; done: boolean }> {
  const { model = CHAT_MODEL, temperature = 0.7, maxTokens = 800 } = options;

  if (!CHAT_API_KEY) {
    throw new Error('Missing chat API key. Set OPENAI_API_KEY, MOONSHOT_API_KEY, or GLM_API_KEY.');
  }

  const response = await fetch(chatCompletionsUrl(), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${CHAT_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: stages.systemPrompt },
        { role: 'user', content: stages.userMessage },
      ],
      temperature,
      max_tokens: maxTokens,
      stream: true,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Chat API error: ${errorText}`);
  }

  const reader = response.body?.getReader();
  if (!reader) {
    throw new Error('No response body');
  }

  const decoder = new TextDecoder();
  let buffer = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') {
            yield { text: '', done: true };
            return;
          }

          try {
            const parsed = JSON.parse(data);
            const content = parsed.choices?.[0]?.delta?.content;
            if (content) {
              yield { text: content, done: false };
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }

  yield { text: '', done: true };
}
