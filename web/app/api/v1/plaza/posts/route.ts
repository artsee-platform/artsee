import { NextRequest, NextResponse } from "next/server";
import { recordCreatorContent } from "@/lib/api/creator-level";
import { requireUser } from "@/lib/api/authz";
import {
  auditContent,
  auditReasonFromItems,
  collectAuditText,
  contentStatusForAudit,
} from "@/lib/api/content-safety";
import { contentSafetyErrorResponse } from "@/lib/api/content-safety-http";
import { createServiceClient } from "@/lib/api/supabase-service";
import { recordUploadAuditResults } from "@/lib/api/upload-audit";
import { attachPlazaPostState } from "@/lib/api/plaza";
import {
  createPlazaAiReplyIfEnabled,
  PlazaAiConfigError,
} from "@/lib/api/plaza-ai-reply";
export { GET } from "@/app/api/v1/plaza/feed/route";

function objectValue(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function stringList(value: unknown) {
  if (!Array.isArray(value)) return undefined;
  return value.map(String).map((item) => item.trim()).filter(Boolean);
}

function boolValue(value: unknown) {
  if (typeof value === "boolean") return value;
  return String(value ?? "").trim().toLowerCase() === "true";
}

function stringValue(value: unknown, fallback = "") {
  const text = String(value ?? "").trim();
  return text || fallback;
}

function titleFromText(text: string) {
  const firstLine = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean);
  if (!firstLine) return "";
  return firstLine.length > 32 ? `${firstLine.slice(0, 32)}...` : firstLine;
}

const RATING_TARGET_CATEGORIES = [
  "艺术家",
  "作品",
  "展览",
  "活动",
] as const;

const RATING_TARGET_CATEGORY_ALIASES: Record<string, string> = {
  名人: "艺术家",
  文化名人: "艺术家",
  艺术品: "作品",
  出版物: "作品",
  文艺书籍画册: "作品",
  艺文书籍画册: "作品",
  影像: "作品",
  文艺影像: "作品",
  数字艺术: "作品",
  "金句/语录": "作品",
  文艺金句: "作品",
  金句: "作品",
  语录: "作品",
  "金句/诗歌语录": "作品",
  "文艺金句、诗歌语录": "作品",
  美术馆: "展览",
  艺术展览: "展览",
  "美术馆/艺术展览": "展览",
  线下体验活动: "活动",
  艺术课程: "活动",
  "艺术课程、线下体验活动": "活动",
};

function normalizeRatingTargetCategory(value: unknown) {
  const raw = String(value ?? "").trim();
  if (!raw) return "";
  const normalized = RATING_TARGET_CATEGORY_ALIASES[raw] ?? raw;
  return RATING_TARGET_CATEGORIES.includes(
    normalized as (typeof RATING_TARGET_CATEGORIES)[number]
  )
    ? normalized
    : "";
}

function buildRatingTargetMetadata(options: {
  title: string;
  text: string;
  group?: string;
  tags?: string[];
  metadata: Record<string, unknown>;
}) {
  const category = normalizeRatingTargetCategory(
    options.metadata.rating_category ??
      options.metadata.category ??
      options.group ??
      options.tags?.[0]
  );
  if (!category) {
    return {
      error: `评分类型必须是：${RATING_TARGET_CATEGORIES.join("、")}`,
    };
  }
  const title = stringValue(options.title);
  if (title.length < 2) {
    return { error: "打分对象名称至少 2 个字" };
  }

  const collection = `${category}口碑`;
  const quote = stringValue(options.metadata.quote, "请给出你的判断和理由。");
  const subtitle = stringValue(
    options.metadata.subtitle ?? options.text,
    "由用户上传，等待大家打分和评论。"
  );

  return {
    metadata: {
      legacy_type: "rating_item",
      kind: "rating",
      promote_to_plaza: true,
      source: "plaza_rating",
      rating_category: category,
      category,
      target_name: title,
      collection,
      subtitle,
      quote,
      score: stringValue(options.metadata.score, "待评"),
      rating_count: stringValue(options.metadata.rating_count, "0"),
      likes_label: stringValue(options.metadata.likes_label, "0"),
      comments_label: stringValue(options.metadata.comments_label, "0"),
      source_label: stringValue(options.metadata.source_label, `${category}评分`),
      cover_seed: stringValue(options.metadata.cover_seed, `${category}-${title}`),
      time_label: stringValue(options.metadata.time_label, "刚刚"),
      replies: Array.isArray(options.metadata.replies) ? options.metadata.replies : [],
    },
    category,
  };
}

function topicIconForQuestion(text: string) {
  const value = text.toLowerCase();
  if (value.includes("ai")) return "auto_awesome";
  if (value.includes("作品集")) return "auto_fix";
  if (value.includes("留学") || value.includes("预算") || value.includes("学费")) return "wallet";
  if (value.includes("展") || value.includes("看展") || value.includes("策展")) return "visibility";
  return "forum";
}

function topicAccentForQuestion(text: string) {
  const value = text.toLowerCase();
  if (value.includes("ai")) return "#8D6AE8";
  if (value.includes("预算") || value.includes("学费")) return "#D59D2B";
  if (value.includes("展") || value.includes("看展") || value.includes("策展")) return "#0F3C8C";
  if (value.includes("机构") || value.includes("焦虑")) return "#E16F5C";
  return "#1A9B7A";
}

function buildQuestionTopicMetadata(options: {
  title: string;
  text: string;
  group?: string;
  tags?: string[];
  metadata: Record<string, unknown>;
}) {
  const category = stringValue(
    options.metadata.category ?? options.group ?? options.tags?.[0],
    "问答"
  );
  const sourceCircle = stringValue(
    options.metadata.source_circle ?? options.group ?? category,
    category
  );
  const body = options.text || "这个问题正在等更多背景和观点。";
  const searchText = `${options.title} ${body} ${category} ${sourceCircle}`;

  return {
    legacy_type: "debate_topic",
    channel: sourceCircle,
    track: category.includes("留学") || category.includes("作品集") ? "申请向" : "文化向",
    category,
    status_label: "问答精选",
    time_left: "新问题",
    lead: body,
    pro: "这个问题值得公开讨论，能帮助更多人建立判断标准",
    con: "如果背景不足，直接下结论可能会误导具体决策",
    pro_percent: 50,
    heat_label: "新",
    comments_label: "0",
    floor: "1 楼",
    hot_comment: "“先把问题问清楚，本身就是一种判断力。”",
    pro_comment: "我会先赞成公开讨论，因为相似困惑的人很多。",
    con_comment: "但也要补充目标、预算和阶段，否则答案会太泛。",
    agent_persona: "艺见锐评员",
    agent_reply: "这题可以从个人问题升格成公共讨论：先补背景，再拆正反观点。",
    ask_seed: options.title,
    icon: topicIconForQuestion(searchText),
    accent: topicAccentForQuestion(searchText),
  };
}

function warnAutoReplyFailure(error: unknown) {
  if (error instanceof PlazaAiConfigError) {
    console.warn("[plaza-ai] auto reply skipped: missing model config", error.missing);
    return;
  }
  console.warn("[plaza-ai] auto reply failed", error);
}

/** POST /api/v1/plaza/posts — 广场发帖，底层写入 community_posts */
export async function POST(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = await req.json();
    const title = String(body.title ?? "").trim();
    const text = String(body.body ?? body.content ?? "").trim();
    const imageUrls = Array.isArray(body.image_urls) ? body.image_urls.map(String) : [];
    const baseMetadata = objectValue(body.metadata);
    const kind = String(body.kind ?? baseMetadata.kind ?? "article").trim() || "article";
    const promoteToPlaza = boolValue(body.promote_to_plaza ?? baseMetadata.promote_to_plaza);
    const group = body.group !== undefined ? String(body.group).trim() : undefined;
    const tags = stringList(body.tags);
    const metadata: Record<string, unknown> = {
      ...baseMetadata,
      kind,
      promote_to_plaza: promoteToPlaza,
      source: baseMetadata.source ?? (kind === "qa" && promoteToPlaza ? "plaza_question" : "plaza_user"),
      surface: "plaza",
    };
    if (body.group !== undefined) metadata.group = group;
    if (body.quote !== undefined) metadata.quote = body.quote;
    if (body.rating !== undefined) metadata.rating = objectValue(body.rating);
    if (body.debate !== undefined) metadata.debate = objectValue(body.debate);
    if (tags) metadata.tags = tags;
    if (kind === "rating") {
      const ratingTarget = buildRatingTargetMetadata({
        title,
        text,
        group,
        tags,
        metadata,
      });
      if ("error" in ratingTarget) {
        return NextResponse.json(
          { success: false, error: ratingTarget.error },
          { status: 400 }
        );
      }
      Object.assign(metadata, ratingTarget.metadata);
      metadata.group = ratingTarget.category;
      metadata.tags = Array.from(
        new Set([ratingTarget.category, ...(tags ?? [])].filter(Boolean))
      );
    }
    if (kind === "qa" && promoteToPlaza) {
      Object.assign(
        metadata,
        buildQuestionTopicMetadata({
          title,
          text,
          group,
          tags,
          metadata,
        })
      );
    }
    const rawAutoAiReply = body.auto_ai_reply ?? baseMetadata.auto_ai_reply;
    const autoAiReply =
      rawAutoAiReply === undefined
        ? kind === "qa" && promoteToPlaza
        : boolValue(rawAutoAiReply);

    if (!title && !text && imageUrls.length === 0) {
      return NextResponse.json(
        { success: false, error: "请至少填写标题、正文或上传一张图片" },
        { status: 400 }
      );
    }

    const audit = await auditContent({
      userId: auth.user.id,
      text: collectAuditText(title, text, metadata),
      imageUrls,
      scene: "plaza_post",
    });
    const auditStatus =
      kind === "market" && audit.audit_status !== "rejected"
        ? "reviewing"
        : audit.audit_status;
    const status = contentStatusForAudit(auditStatus);
    const supabase = createServiceClient();
    await recordUploadAuditResults(
      supabase,
      auth.user.id,
      imageUrls,
      audit
    );
    const { data: row, error } = await supabase
      .from("community_posts")
      .insert({
        author_id: auth.user.id,
        title: title || titleFromText(text) || "广场动态",
        body: text || null,
        image_urls: imageUrls,
        status,
        audit_status: auditStatus,
        audit_provider: audit.provider,
        audit_reason: auditReasonFromItems(audit.items) || null,
        audit_metadata: kind === "market" ? { ...audit, manual_review_required: true } : audit,
        audited_at: new Date().toISOString(),
        metadata,
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    if (status === "published") {
      await recordCreatorContent(supabase, auth.user.id, {
        sourceType: "community_post",
        sourceId: String(row.id),
      }).catch((recordError) => {
        console.warn("[creator-level] failed to record plaza post", recordError);
      });
    }

    const [data] = await attachPlazaPostState(supabase, [row], auth.user.id);
    let aiReply = null;
    if (status === "published" && autoAiReply) {
      aiReply = await createPlazaAiReplyIfEnabled(supabase, {
        postId: String(row.id),
        post: row,
        triggeredByUserId: auth.user.id,
        trigger: "post_created",
        persona: "艺见锐评员",
        userPrompt: "这是一个刚发布到广场的新话题，请先补一条像真实用户的首条评论，帮话题开场。",
      }).catch((autoReplyError) => {
        warnAutoReplyFailure(autoReplyError);
        return null;
      });
    }

    return NextResponse.json({ success: true, data, ai_reply: aiReply }, { status: 201 });
  } catch (e: unknown) {
    const auditError = contentSafetyErrorResponse(e);
    if (auditError) return auditError;
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
