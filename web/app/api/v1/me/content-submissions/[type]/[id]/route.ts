import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/api/authz";
import { errorResponse, notFoundResponse } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  isOwnedSubmissionMaterialPath,
  materialPathFromUrlOrPath,
  SUBMISSION_MATERIALS_BUCKET,
} from "@/lib/api/submission-materials";

type Ctx = { params: Promise<{ type: string; id: string }> };
type ContentType = "events" | "opportunities" | "artworks" | "artists" | "marketplace";
type FieldType = "text" | "number" | "datetime";
type Row = Record<string, unknown>;

const TYPE_CONFIG: Record<
  ContentType,
  {
    table: string;
    ownerField: string;
    kind?: string;
    fields: Record<string, { type: FieldType; required?: boolean }>;
  }
> = {
  events: {
    table: "events",
    ownerField: "created_by",
    fields: {
      title: { type: "text", required: true },
      summary: { type: "text" },
      description: { type: "text" },
      city: { type: "text" },
      venue: { type: "text" },
      type: { type: "text" },
      start_time: { type: "datetime" },
      end_time: { type: "datetime" },
      quota: { type: "number" },
      fee_amount: { type: "number" },
    },
  },
  opportunities: {
    table: "opportunities",
    ownerField: "created_by",
    fields: {
      title: { type: "text", required: true },
      requirements: { type: "text" },
      city: { type: "text" },
      type: { type: "text" },
      budget_min: { type: "number" },
      budget_max: { type: "number" },
      deadline: { type: "datetime" },
    },
  },
  artworks: {
    table: "artworks",
    ownerField: "user_id",
    fields: {
      title: { type: "text", required: true },
      description: { type: "text" },
      category: { type: "text" },
      copyright_status: { type: "text" },
      visibility: { type: "text" },
    },
  },
  artists: {
    table: "artist_profiles",
    ownerField: "user_id",
    fields: {
      display_name: { type: "text", required: true },
      experience: { type: "text" },
      cooperation_intent: { type: "text" },
    },
  },
  marketplace: {
    table: "community_posts",
    ownerField: "author_id",
    kind: "market",
    fields: {
      title: { type: "text", required: true },
      body: { type: "text" },
    },
  },
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function arrayValue(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function textArrayValue(value: unknown) {
  if (Array.isArray(value)) {
    return value
      .map((item) => cleanText(item))
      .filter((item) => item.length > 0);
  }
  if (typeof value === "string") {
    return value
      .split(/\r?\n/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function parseNumber(value: unknown) {
  if (value == null || value === "") return null;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : undefined;
}

function parseDatetime(value: unknown) {
  const text = cleanText(value);
  if (!text) return null;
  const timestamp = Date.parse(text);
  if (!Number.isFinite(timestamp)) return undefined;
  return new Date(timestamp).toISOString();
}

function normalizeFieldValue(type: FieldType, value: unknown) {
  if (type === "number") return parseNumber(value);
  if (type === "datetime") return parseDatetime(value);
  const text = cleanText(value);
  return text || null;
}

function canEdit(status: string, previousDecision: string) {
  return (
    status === "draft" ||
    status === "rejected" ||
    previousDecision === "rejected" ||
    (status === "archived" && previousDecision === "rejected")
  );
}

export async function PATCH(req: NextRequest, ctx: Ctx) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const { type: rawType, id } = await ctx.params;
    const type = rawType as ContentType;
    const config = TYPE_CONFIG[type];
    if (!config) {
      return NextResponse.json({ success: false, error: "无效内容类型" }, { status: 400 });
    }

    const body = (await req.json().catch(() => ({}))) as Row;
    const submittedFields = objectValue(body.fields);
    const submitForReview = body.submit !== false;
    const supabase = createServiceClient();
    let readQuery = supabase
      .from(config.table)
      .select("*")
      .eq("id", id)
      .eq(config.ownerField, auth.user.id);
    if (config.kind) readQuery = readQuery.eq("metadata->>kind", config.kind);
    const { data: current, error: readError } = await readQuery.maybeSingle();

    if (readError) return errorResponse(readError);
    if (!current) return notFoundResponse();

    const row = current as Row;
    const metadata = objectValue(row.metadata);
    const previousReview = objectValue(metadata.review);
    const previousDecision = cleanText(previousReview.decision);
    const status = cleanText(row.status);
    if (!canEdit(status, previousDecision)) {
      return NextResponse.json(
        { success: false, error: "当前内容状态不支持编辑后提交" },
        { status: 400 }
      );
    }

    const patch: Row = {};
    for (const [key, field] of Object.entries(config.fields)) {
      if (!(key in submittedFields)) continue;
      const value = normalizeFieldValue(field.type, submittedFields[key]);
      if (value === undefined) {
        return NextResponse.json(
          { success: false, error: `${key} 格式不正确` },
          { status: 400 }
        );
      }
      if (field.required && (value == null || value === "")) {
        return NextResponse.json(
          { success: false, error: `${key} 不能为空` },
          { status: 400 }
        );
      }
      patch[key] = value;
    }

    if (Object.keys(patch).length === 0) {
      return NextResponse.json(
        { success: false, error: "没有可更新字段" },
        { status: 400 }
      );
    }

    const now = new Date().toISOString();
    const reviewHistory = previousDecision
      ? [...arrayValue(metadata.review_history), previousReview]
      : arrayValue(metadata.review_history);
    const reviewNote = cleanText(body.note);
    const nextStatus = submitForReview ? "reviewing" : "draft";
    const hasSupplementalMaterials = "supplemental_materials" in body;
    const previousSupplementalMaterials = textArrayValue(
      metadata.supplemental_materials ?? previousReview.supplemental_materials
    );
    const supplementalMaterials = hasSupplementalMaterials
      ? textArrayValue(body.supplemental_materials)
      : previousSupplementalMaterials;

    const updatePatch: Row = {
      ...patch,
      status: nextStatus,
      updated_at: now,
      metadata: {
        ...metadata,
        supplemental_materials: supplementalMaterials,
        review_history: reviewHistory,
        review: {
          decision: submitForReview ? "edited_resubmitted" : "edited_draft",
          edited_by_user_id: auth.user.id,
          edited_at: now,
          resubmission_note: reviewNote || null,
          supplemental_materials: supplementalMaterials,
        },
      },
    };
    if (type === "marketplace") {
      updatePatch.audit_status = submitForReview ? "reviewing" : "pending";
      updatePatch.audit_provider = "admin";
      updatePatch.audit_reason = null;
      updatePatch.audit_metadata = {
        source: "user_content_edit",
        edited_by_user_id: auth.user.id,
        submit_for_review: submitForReview,
      };
      updatePatch.audited_at = now;
    }

    let updateQuery = supabase
      .from(config.table)
      .update(updatePatch)
      .eq("id", id)
      .eq(config.ownerField, auth.user.id);
    if (config.kind) updateQuery = updateQuery.eq("metadata->>kind", config.kind);
    const { data, error } = await updateQuery.select("*").single();
    if (error) return errorResponse(error);

    if (hasSupplementalMaterials) {
      const removedPaths = previousSupplementalMaterials
        .filter((material) => !supplementalMaterials.includes(material))
        .map((material) => materialPathFromUrlOrPath(material))
        .filter((path): path is string => Boolean(path))
        .filter((path) => isOwnedSubmissionMaterialPath(path, auth.user.id, type, id));
      if (removedPaths.length > 0) {
        const { error: removeError } = await supabase.storage
          .from(SUBMISSION_MATERIALS_BUCKET)
          .remove(removedPaths);
        if (removeError) {
          console.warn("[content-submissions] failed to remove materials", removeError);
        }
      }
    }

    return NextResponse.json({ success: true, data });
  } catch (e) {
    return errorResponse(e);
  }
}
