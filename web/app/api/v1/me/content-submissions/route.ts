import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/api/authz";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";

type ContentType = "events" | "opportunities" | "artworks" | "artists" | "marketplace";
type Row = Record<string, unknown>;

const CONTENT_TYPES = new Set<ContentType>([
  "events",
  "opportunities",
  "artworks",
  "artists",
  "marketplace",
]);
const TYPE_CONFIG: Record<
  ContentType,
  {
    table: string;
    titleField: string;
    ownerField: string;
    summaryFields: string[];
    kind?: string;
    editableFields: Array<{
      key: string;
      label: string;
      type?: "text" | "multiline" | "number" | "datetime";
      required?: boolean;
    }>;
  }
> = {
  events: {
    table: "events",
    titleField: "title",
    ownerField: "created_by",
    summaryFields: ["summary", "city", "venue", "type"],
    editableFields: [
      { key: "title", label: "活动标题", required: true },
      { key: "summary", label: "活动摘要", type: "multiline" },
      { key: "description", label: "活动详情", type: "multiline" },
      { key: "city", label: "城市" },
      { key: "venue", label: "地点" },
      { key: "type", label: "活动类型" },
      { key: "start_time", label: "开始时间", type: "datetime" },
      { key: "end_time", label: "结束时间", type: "datetime" },
      { key: "quota", label: "名额", type: "number" },
      { key: "fee_amount", label: "费用", type: "number" },
    ],
  },
  opportunities: {
    table: "opportunities",
    titleField: "title",
    ownerField: "created_by",
    summaryFields: ["requirements", "city", "type"],
    editableFields: [
      { key: "title", label: "机会标题", required: true },
      { key: "requirements", label: "合作要求", type: "multiline" },
      { key: "city", label: "城市" },
      { key: "type", label: "机会类型" },
      { key: "budget_min", label: "最低预算", type: "number" },
      { key: "budget_max", label: "最高预算", type: "number" },
      { key: "deadline", label: "截止时间", type: "datetime" },
    ],
  },
  artworks: {
    table: "artworks",
    titleField: "title",
    ownerField: "user_id",
    summaryFields: ["description", "category", "copyright_status"],
    editableFields: [
      { key: "title", label: "作品标题", required: true },
      { key: "description", label: "作品说明", type: "multiline" },
      { key: "category", label: "作品类别" },
      { key: "copyright_status", label: "版权状态" },
      { key: "visibility", label: "可见范围" },
    ],
  },
  artists: {
    table: "artist_profiles",
    titleField: "display_name",
    ownerField: "user_id",
    summaryFields: ["experience", "cooperation_intent"],
    editableFields: [
      { key: "display_name", label: "展示名称", required: true },
      { key: "experience", label: "经历介绍", type: "multiline" },
      { key: "cooperation_intent", label: "合作意向", type: "multiline" },
    ],
  },
  marketplace: {
    table: "community_posts",
    titleField: "title",
    ownerField: "author_id",
    summaryFields: ["body", "audit_reason"],
    kind: "market",
    editableFields: [
      { key: "title", label: "商品标题", required: true },
      { key: "body", label: "商品说明", type: "multiline" },
    ],
  },
};

function cleanText(value: string | null) {
  return value?.trim() ?? "";
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : "";
}

function metadataValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function stringArrayValue(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item).trim())
    .filter(Boolean);
}

function reviewMetadata(row: Row) {
  const metadata = metadataValue(row.metadata);
  return metadataValue(metadata.review);
}

function toSubmissionItem(type: ContentType, row: Row) {
  const config = TYPE_CONFIG[type];
  const metadata = metadataValue(row.metadata);
  const review = reviewMetadata(row);
  const supplementalMaterials = stringArrayValue(
    review.supplemental_materials ?? metadata.supplemental_materials
  );
  const summary = config.summaryFields
    .map((field) => stringValue(row[field]))
    .filter(Boolean)
    .slice(0, 3)
    .join(" / ");

  return {
    type,
    id: String(row.id ?? ""),
    title: stringValue(row[config.titleField]) || "未命名内容",
    status: stringValue(row.status) || "draft",
    summary,
    review_decision: stringValue(review.decision) || null,
    review_note: stringValue(review.review_note) || null,
    reviewed_at: stringValue(review.reviewed_at) || null,
    supplemental_materials: supplementalMaterials,
    created_at: stringValue(row.created_at) || null,
    updated_at: stringValue(row.updated_at) || null,
    editable_fields: config.editableFields.map((field) => ({
      ...field,
      value: row[field.key] ?? null,
    })),
  };
}

async function listByType(
  type: ContentType,
  userId: string,
  status: string,
  limit: number,
  offset: number,
  merged: boolean
) {
  const config = TYPE_CONFIG[type];
  let query = createServiceClient()
    .from(config.table)
    .select("*", { count: "exact" })
    .eq(config.ownerField, userId)
    .order("updated_at", { ascending: false })
    .range(merged ? 0 : offset, merged ? offset + limit - 1 : offset + limit - 1);
  if (status && status !== "all") query = query.eq("status", status);
  if (config.kind) query = query.eq("metadata->>kind", config.kind);
  const { data, error, count } = await query;
  if (error) throw new Error(error.message ?? JSON.stringify(error));
  const rows = (data ?? []) as unknown as Row[];
  return {
    rows: rows.map((row) => toSubmissionItem(type, row)),
    count: count ?? rows.length,
  };
}

export async function GET(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const rawType = cleanText(searchParams.get("type")) || "all";
    const status = cleanText(searchParams.get("status")) || "all";

    if (rawType !== "all" && !CONTENT_TYPES.has(rawType as ContentType)) {
      return NextResponse.json({ success: false, error: "无效内容类型" }, { status: 400 });
    }

    const types =
      rawType === "all"
        ? (Array.from(CONTENT_TYPES) as ContentType[])
        : [rawType as ContentType];
    const merged = rawType === "all";
    const results = await Promise.all(
      types.map((type) => listByType(type, auth.user.id, status, limit, offset, merged))
    );
    const allRows = results
      .flatMap((result) => result.rows)
      .sort((a, b) => {
        const left = new Date(a.updated_at ?? a.created_at ?? 0).getTime();
        const right = new Date(b.updated_at ?? b.created_at ?? 0).getTime();
        return right - left;
      });
    const rows = merged ? allRows.slice(offset, offset + limit) : allRows;

    return NextResponse.json({
      success: true,
      data: rows,
      count: results.reduce((sum, result) => sum + result.count, 0),
      pagination: { limit, offset },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
