import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/api/require-admin";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";

type ContentType = "events" | "opportunities" | "artworks" | "artists" | "marketplace";
type ContentRow = Record<string, unknown>;

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
    orderField: string;
    summaryFields: string[];
    kind?: string;
  }
> = {
  events: {
    table: "events",
    titleField: "title",
    ownerField: "created_by",
    orderField: "updated_at",
    summaryFields: ["summary", "city", "venue", "type"],
  },
  opportunities: {
    table: "opportunities",
    titleField: "title",
    ownerField: "created_by",
    orderField: "updated_at",
    summaryFields: ["requirements", "city", "type"],
  },
  artworks: {
    table: "artworks",
    titleField: "title",
    ownerField: "user_id",
    orderField: "updated_at",
    summaryFields: ["description", "category", "copyright_status"],
  },
  artists: {
    table: "artist_profiles",
    titleField: "display_name",
    ownerField: "user_id",
    orderField: "updated_at",
    summaryFields: ["experience", "cooperation_intent"],
  },
  marketplace: {
    table: "community_posts",
    titleField: "title",
    ownerField: "author_id",
    orderField: "updated_at",
    summaryFields: ["body", "audit_reason"],
    kind: "market",
  },
};

function cleanText(value: string | null) {
  return value?.trim() ?? "";
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function stringArrayValue(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item).trim())
    .filter(Boolean);
}

function toReviewItem(type: ContentType, row: ContentRow) {
  const config = TYPE_CONFIG[type];
  const metadata = objectValue(row.metadata);
  const review = objectValue(metadata.review);
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
    owner_user_id: stringValue(row[config.ownerField]) || null,
    summary,
    supplemental_materials: supplementalMaterials,
    created_at: stringValue(row.created_at) || null,
    updated_at: stringValue(row.updated_at) || null,
    raw: row,
  };
}

async function listByType(
  type: ContentType,
  status: string,
  limit: number,
  offset: number,
  rangeForMergedList = false
) {
  const config = TYPE_CONFIG[type];
  let query = createServiceClient()
    .from(config.table)
    .select("*", { count: "exact" })
    .order(config.orderField, { ascending: false })
    .range(rangeForMergedList ? 0 : offset, rangeForMergedList ? offset + limit - 1 : offset + limit - 1);
  if (status && status !== "all") query = query.eq("status", status);
  if (config.kind) query = query.eq("metadata->>kind", config.kind);
  const { data, error, count } = await query;
  if (error) throw new Error(error.message ?? JSON.stringify(error));
  return {
    rows: (data ?? []).map((row: ContentRow) => toReviewItem(type, row)),
    count: count ?? data?.length ?? 0,
  };
}

export async function GET(req: NextRequest) {
  try {
    const admin = await requireAdmin(req);
    if ("response" in admin) return admin.response;

    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const rawType = cleanText(searchParams.get("type")) || "all";
    const status = cleanText(searchParams.get("status")) || "reviewing";

    if (rawType !== "all" && !CONTENT_TYPES.has(rawType as ContentType)) {
      return NextResponse.json({ success: false, error: "无效内容类型" }, { status: 400 });
    }

    const types =
      rawType === "all"
        ? (Array.from(CONTENT_TYPES) as ContentType[])
        : [rawType as ContentType];

    const results = await Promise.all(
      types.map((type) => listByType(type, status, limit, offset, rawType === "all"))
    );
    const allRows = results
      .flatMap((result) => result.rows)
      .sort((a, b) => {
        const left = new Date(a.updated_at ?? a.created_at ?? 0).getTime();
        const right = new Date(b.updated_at ?? b.created_at ?? 0).getTime();
        return right - left;
      });
    const rows = rawType === "all" ? allRows.slice(offset, offset + limit) : allRows;

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
