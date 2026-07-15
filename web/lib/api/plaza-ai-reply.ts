import OpenAI from "openai";
import { isPlazaPost } from "@/lib/api/plaza";
import { createServiceClient } from "@/lib/api/supabase-service";

type Supabase = ReturnType<typeof createServiceClient>;
type Row = Record<string, unknown>;

type AiConfig = {
  apiKey: string;
  baseURL: string;
  model: string;
};

export type PlazaAiReplyTrigger = "post_created" | "user_comment" | "manual";

export class PlazaAiConfigError extends Error {
  constructor(readonly missing: string[]) {
    super("Missing plaza AI configuration");
  }
}

export class PlazaAiReplyError extends Error {
  constructor(message: string, readonly status = 500) {
    super(message);
  }
}

export function isPlazaAutoReplyEnabled() {
  return process.env.PLAZA_AI_AUTO_REPLY !== "false";
}

export function objectValue(value: unknown): Row {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Row)
    : {};
}

export function stringValue(value: unknown, fallback = "") {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text || fallback;
}

function truncate(value: unknown, max: number) {
  const text = stringValue(value);
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1)}…`;
}

function getAiConfig(): AiConfig {
  const explicitModel = process.env.PLAZA_AI_MODEL?.trim();
  const openaiKey = process.env.OPENAI_API_KEY?.trim();
  if (openaiKey) {
    return {
      apiKey: openaiKey,
      baseURL: process.env.OPENAI_BASE_URL?.trim() || "https://api.openai.com/v1",
      model: explicitModel || process.env.OPENAI_MODEL?.trim() || process.env.AI_MODEL?.trim() || "gpt-4o-mini",
    };
  }

  const moonshotKey = process.env.MOONSHOT_API_KEY?.trim();
  if (moonshotKey) {
    return {
      apiKey: moonshotKey,
      baseURL: process.env.MOONSHOT_BASE_URL?.trim() || "https://api.moonshot.cn/v1",
      model: explicitModel || process.env.MOONSHOT_MODEL?.trim() || process.env.AI_MODEL?.trim() || "moonshot-v1-8k",
    };
  }

  throw new PlazaAiConfigError(["OPENAI_API_KEY or MOONSHOT_API_KEY"]);
}

function buildRecentComments(comments: Row[]) {
  if (comments.length === 0) return "暂无评论。";
  return comments
    .slice()
    .reverse()
    .map((comment, index) => {
      const metadata = objectValue(comment.metadata);
      const stance = stringValue(metadata.stance);
      const authorType = stringValue(comment.author_type, "user");
      const prefix = stance ? `${authorType}/${stance}` : authorType;
      return `${index + 1}. [${prefix}] ${truncate(comment.body, 120)}`;
    })
    .join("\n");
}

async function generatePlazaAiReply(input: {
  post: Row;
  comments: Row[];
  persona: string;
  userPrompt: string;
}) {
  const config = getAiConfig();
  const client = new OpenAI({ apiKey: config.apiKey, baseURL: config.baseURL });
  const metadata = objectValue(input.post.metadata);
  const tags = Array.isArray(metadata.tags)
    ? metadata.tags.map(String).filter(Boolean).join("、")
    : stringValue(metadata.group ?? metadata.category);

  const completion = await client.chat.completions.create({
    model: config.model,
    temperature: 0.85,
    max_tokens: 240,
    messages: [
      {
        role: "system",
        content:
          "你是艺见心广场里的真实讨论参与者，不是客服，也不要说自己是 AI。你要像一个有观点的艺术/留学圈用户一样回复，语气自然、短、能继续引发讨论。不要编造具体院校政策、价格或个人经历。",
      },
      {
        role: "user",
        content: `话题标题：${truncate(input.post.title, 120)}
话题正文：${truncate(input.post.body, 700)}
话题标签：${tags || "无"}
你的评论身份：${input.persona}
用户希望你接的话：${input.userPrompt || "结合话题和已有评论，补一条能推动讨论的观点。"}

已有评论：
${buildRecentComments(input.comments)}

请只输出一条中文评论，80-180 字。可以有立场，可以反问，但不要写标题、不要列点、不要使用“作为AI”。`,
      },
    ],
  });

  return {
    model: config.model,
    text: stringValue(completion.choices[0]?.message?.content),
  };
}

async function loadPost(supabase: Supabase, postId: string, providedPost?: Row) {
  if (providedPost) {
    if (!isPlazaPost(providedPost)) throw new PlazaAiReplyError("未找到", 404);
    return providedPost;
  }

  const { data, error } = await supabase
    .from("community_posts")
    .select("*")
    .eq("id", postId)
    .eq("status", "published")
    .maybeSingle();

  if (error) throw new PlazaAiReplyError(error.message);
  if (!data) throw new PlazaAiReplyError("未找到", 404);
  if (!isPlazaPost(data as Row)) throw new PlazaAiReplyError("未找到", 404);
  return data as Row;
}

async function loadParentComment(supabase: Supabase, postId: string, parentId: string) {
  const { data, error } = await supabase
    .from("community_post_comments")
    .select("id, body, author_type, metadata, created_at")
    .eq("id", parentId)
    .eq("post_id", postId)
    .eq("status", "published")
    .maybeSingle();

  if (error) throw new PlazaAiReplyError(error.message);
  if (!data) throw new PlazaAiReplyError("父评论不存在", 404);
  return data as Row;
}

async function hasExistingAiReply(supabase: Supabase, options: {
  postId: string;
  parentId?: string | null;
  trigger: PlazaAiReplyTrigger;
}) {
  let query = supabase
    .from("community_post_comments")
    .select("id")
    .eq("post_id", options.postId)
    .eq("author_type", "ai")
    .eq("status", "published");

  if (options.parentId) {
    query = query.eq("parent_id", options.parentId);
  } else if (options.trigger === "post_created" || options.trigger === "manual") {
    query = query.eq("metadata->>trigger", options.trigger);
  } else {
    return false;
  }

  const { data, error } = await query.limit(1).maybeSingle();
  if (error) throw new PlazaAiReplyError(error.message);
  return Boolean(data);
}

async function loadRecentComments(supabase: Supabase, postId: string) {
  const { data, error } = await supabase
    .from("community_post_comments")
    .select("id, body, author_type, metadata, created_at")
    .eq("post_id", postId)
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(8);

  if (error) throw new PlazaAiReplyError(error.message);
  return (data ?? []) as Row[];
}

export async function createPlazaAiReply(supabase: Supabase, options: {
  postId: string;
  triggeredByUserId: string;
  trigger: PlazaAiReplyTrigger;
  post?: Row;
  parentId?: string | null;
  persona?: string;
  userPrompt?: string;
}) {
  const post = await loadPost(supabase, options.postId, options.post);
  const persona = stringValue(options.persona, "艺见锐评员");
  const parentId = options.parentId ? String(options.parentId) : null;

  if (parentId) {
    const parentComment = await loadParentComment(supabase, options.postId, parentId);
    if (parentComment.author_type === "ai") return null;
  }

  if (await hasExistingAiReply(supabase, {
    postId: options.postId,
    parentId,
    trigger: options.trigger,
  })) {
    return null;
  }

  const comments = await loadRecentComments(supabase, options.postId);
  const generated = await generatePlazaAiReply({
    post,
    comments,
    persona,
    userPrompt: truncate(options.userPrompt, 500),
  });

  if (!generated.text) {
    throw new PlazaAiReplyError("AI 暂时没有生成回复", 502);
  }

  const aiAuthorId = process.env.PLAZA_AI_USER_ID?.trim() || options.triggeredByUserId;
  const metadata = {
    persona,
    display_name: persona,
    source: "plaza_ai_reply",
    trigger: options.trigger,
    model: generated.model,
    triggered_by_user_id: options.triggeredByUserId,
    user_prompt: truncate(options.userPrompt, 500) || null,
  };

  const { data: comment, error } = await supabase
    .from("community_post_comments")
    .insert({
      post_id: options.postId,
      parent_id: parentId,
      author_id: aiAuthorId,
      author_type: "ai",
      body: generated.text,
      status: "published",
      metadata,
    })
    .select("*")
    .single();

  if (error) throw new PlazaAiReplyError(error.message);

  await supabase.rpc("increment_community_post_comment", {
    p_post_id: options.postId,
  });

  return {
    ...comment,
    user_profiles: { nickname: persona, avatar_url: null },
  };
}

export async function createPlazaAiReplyIfEnabled(supabase: Supabase, options: {
  postId: string;
  triggeredByUserId: string;
  trigger: Exclude<PlazaAiReplyTrigger, "manual">;
  post?: Row;
  parentId?: string | null;
  persona?: string;
  userPrompt?: string;
}) {
  if (!isPlazaAutoReplyEnabled()) return null;
  return createPlazaAiReply(supabase, options);
}
