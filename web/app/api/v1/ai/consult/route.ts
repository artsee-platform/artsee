import { NextRequest, NextResponse } from 'next/server';
import { getUserFromBearer } from '@/lib/api/auth-user';
import { getIntentDescription } from '@/lib/ai/intent';
import { fireRecordFromTurn } from '@/lib/memory';
import { logChatInteraction } from '@/lib/logging/chat-logger';
import { runConsultStages, generate } from '@/lib/pipelines/consult-pipeline';

export async function POST(request: NextRequest) {
  const startTime = Date.now();
  
  try {
    const body = await request.json();
    const { 
      query, 
      schoolId, 
      userProfile: providedProfile,
      mode = 'short'
    } = body;

    if (!query || typeof query !== 'string') {
      return NextResponse.json(
        { error: 'Query is required' },
        { status: 400 }
      );
    }

    // Get user from Bearer token
    const user = await getUserFromBearer(request);

    // Run unified consult pipeline
    const stages = await runConsultStages({
      query,
      userId: user?.id,
      schoolId,
      mode: mode as 'short' | 'report' | 'chat',
      userProfile: providedProfile,
    });

    console.log(`[consult] Intent: ${getIntentDescription(stages.intent)}, chunks: ${stages.sources.length}, lowConfidence: ${stages.lowConfidence}`);

    // Generate answer (non-streaming)
    const { answer } = await generate(stages, {
      maxTokens: mode === 'report' ? 2000 : 800,
    });

    const latencyMs = Date.now() - startTime;

    // Fire-and-forget: Record to memory system
    if (user) {
      fireRecordFromTurn({
        userId: user.id,
        userMessage: query,
        assistantMessage: answer,
        sourceRoute: 'consult',
      });
    }

    // Fire-and-forget: Log to chat_logs
    logChatInteraction({
      userId: user?.id,
      route: 'consult',
      query,
      rewrittenQuery: stages.rewrittenQuery,
      intent: stages.intent,
      retrievedChunkIds: stages.retrievedChunkIds,
      answer,
      lowConfidence: stages.lowConfidence,
      latencyMs,
    });

    return NextResponse.json({
      query,
      answer,
      sources: stages.sources.map((s) => ({
        schoolId: s.schoolId,
        schoolName: s.schoolName,
        heading: s.heading,
        similarity: s.similarity,
      })),
      schoolData: stages.schoolData,
      mode,
      ...(stages.rewrittenQuery && {
        rewrittenQuery: stages.rewrittenQuery,
      }),
    });
  } catch (error: any) {
    console.error('Consult API error:', error);
    return NextResponse.json(
      { error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}
