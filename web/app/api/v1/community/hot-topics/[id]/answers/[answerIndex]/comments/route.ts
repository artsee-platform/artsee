import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { auditContent } from "@/lib/api/content-safety";
import {
  contentSafetyErrorResponse,
  rejectedAuditResponse,
} from "@/lib/api/content-safety-http";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string; answerIndex: string }> };

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function parseAnswerIndex(value: string) {
  const index = Number.parseInt(value, 10);
  return Number.isInteger(index) && index >= 0 ? index : -1;
}

async function ensureTopicAnswer(
  supabase: ReturnType<typeof createServiceClient>,
  topicId: string,
  answerIndex: number
) {
  const { data, error } = await supabase
    .from("community_hot_topics")
    .select("id, answers")
    .eq("id", topicId)
    .eq("status", "published")
    .maybeSingle();
  if (error) return { error: error.message };
  const answers = Array.isArray(data?.answers) ? data.answers : [];
  if (!data || answerIndex < 0 || answerIndex >= answers.length) {
    return { notFound: true };
  }
  return { data };
}

async function attachProfiles(
  supabase: ReturnType<typeof createServiceClient>,
  comments: Record<string, unknown>[]
) {
  const authorIds = [
    ...new Set(comments.map((item) => String(item.author_id)).filter(Boolean)),
  ];
  if (authorIds.length === 0) return comments;

  const { data: profiles } = await supabase
    .from("user_profiles")
    .select("id, nickname, avatar_url")
    .in("id", authorIds);
  const profileMap = Object.fromEntries(
    (profiles ?? []).map(
      (p: { id: string; nickname: string | null; avatar_url: string | null }) => [
        p.id,
        { nickname: p.nickname, avatar_url: p.avatar_url },
      ]
    )
  );

  return comments.map((comment) => ({
    ...comment,
    user_profiles: profileMap[String(comment.author_id)] ?? null,
  }));
}

async function readCommentCount(
  supabase: ReturnType<typeof createServiceClient>,
  topicId: string,
  answerIndex: number
) {
  const { count, error } = await supabase
    .from("community_hot_topic_answer_comments")
    .select("id", { count: "exact", head: true })
    .eq("topic_id", topicId)
    .eq("answer_index", answerIndex)
    .eq("status", "published");
  if (error) throw error;
  return count ?? 0;
}

export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { id, answerIndex: rawAnswerIndex } = await ctx.params;
    const answerIndex = parseAnswerIndex(rawAnswerIndex);
    if (!UUID_RE.test(id) || answerIndex < 0) {
      return NextResponse.json({ success: false, error: "无效的热议回答 ID" }, { status: 400 });
    }

    const { searchParams } = new URL(req.url);
    const limit = Math.min(parseInt(searchParams.get("limit") || "20", 10), 100);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const supabase = createServiceClient();
    const topic = await ensureTopicAnswer(supabase, id, answerIndex);
    if (topic.error) {
      return NextResponse.json({ success: false, error: topic.error }, { status: 500 });
    }
    if (topic.notFound) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }

    const { data: comments, error } = await supabase
      .from("community_hot_topic_answer_comments")
      .select("*")
      .eq("topic_id", id)
      .eq("answer_index", answerIndex)
      .eq("status", "published")
      .order("created_at", { ascending: true })
      .range(offset, offset + limit - 1);
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const data = await attachProfiles(supabase, comments ?? []);
    return NextResponse.json({ success: true, data, pagination: { limit, offset } });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export async function POST(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id, answerIndex: rawAnswerIndex } = await ctx.params;
    const answerIndex = parseAnswerIndex(rawAnswerIndex);
    if (!UUID_RE.test(id) || answerIndex < 0) {
      return NextResponse.json({ success: false, error: "无效的热议回答 ID" }, { status: 400 });
    }

    const body = await req.json();
    const text = String(body.body ?? body.content ?? "").trim();
    if (!text) {
      return NextResponse.json({ success: false, error: "评论内容不能为空" }, { status: 400 });
    }
    if (text.length > 1000) {
      return NextResponse.json({ success: false, error: "评论不能超过 1000 字" }, { status: 400 });
    }

    const supabase = createServiceClient();
    const topic = await ensureTopicAnswer(supabase, id, answerIndex);
    if (topic.error) {
      return NextResponse.json({ success: false, error: topic.error }, { status: 500 });
    }
    if (topic.notFound) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }

    const audit = await auditContent({
      userId: user.id,
      text,
      scene: "hot_topic_comment",
      dataId: `hot-${id}-${answerIndex}`,
    });
    const rejected = rejectedAuditResponse(audit, "评论");
    if (rejected) return rejected;

    const { data: comment, error } = await supabase
      .from("community_hot_topic_answer_comments")
      .insert({
        topic_id: id,
        answer_index: answerIndex,
        author_id: user.id,
        body: text,
        status: "published",
      })
      .select("*")
      .single();
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const [withProfile] = await attachProfiles(supabase, [comment]);
    const commentCount = await readCommentCount(supabase, id, answerIndex);
    return NextResponse.json(
      { success: true, data: withProfile, comment_count: commentCount },
      { status: 201 }
    );
  } catch (error: unknown) {
    const auditError = contentSafetyErrorResponse(error);
    if (auditError) return auditError;
    const msg = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
