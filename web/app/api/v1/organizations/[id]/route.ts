import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { getUserMembership } from "@/lib/api/membership";
import { isPublicOfficialOrganization } from "@/lib/api/organization-visibility";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  errorResponse,
  invalidIdResponse,
  notFoundResponse,
} from "@/lib/api/route-helpers";

type Ctx = { params: Promise<{ id: string }> };
type Row = Record<string, unknown>;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function stringList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => cleanText(item)).filter(Boolean);
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function isMissingOrganizationSchema(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const err = error as { code?: string; message?: string };
  return (
    err.code === "42P01" ||
    err.code === "42703" ||
    err.code === "PGRST204" ||
    err.code === "PGRST205" ||
    Boolean(err.message?.includes("organizations")) ||
    Boolean(err.message?.includes("schema cache"))
  );
}

function isMissingReviewSchema(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const err = error as { code?: string; message?: string };
  return (
    err.code === "42P01" ||
    err.code === "42703" ||
    err.code === "PGRST200" ||
    err.code === "PGRST204" ||
    err.code === "PGRST205" ||
    Boolean(err.message?.includes("consultation_reviews")) ||
    Boolean(err.message?.includes("schema cache"))
  );
}

function publicReview(row: Row) {
  const consultation = objectValue(row.consultation);
  return {
    id: cleanText(row.id),
    rating: Number(row.rating) || 0,
    body: cleanText(row.body) || null,
    target_name: cleanText(consultation.target_name) || null,
    created_at: cleanText(row.created_at) || null,
  };
}

function publicOrganization(row: Row, includeContact: boolean, reviews: Row[]) {
  const metadata = objectValue(row.metadata);
  const contact = includeContact
    ? {
        address: cleanText(metadata.address) || null,
        phone: cleanText(metadata.phone) || null,
        wechat_qr_url: cleanText(metadata.wechat_qr_url) || null,
        contact_note: cleanText(metadata.contact_note) || null,
      }
    : {
        address: null,
        phone: null,
        wechat_qr_url: null,
        contact_note: null,
      };

  return {
    ...row,
    avatar_url:
      cleanText(metadata.avatar_url) ||
      cleanText(metadata.logo_url) ||
      cleanText(metadata.image_url) ||
      null,
    summary: cleanText(metadata.summary) || cleanText(metadata.description) || null,
    focus_areas: stringList(row.focus_areas),
    contact_locked: !includeContact,
    reviews: reviews.map(publicReview),
    ...contact,
  };
}

export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) return invalidIdResponse();

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("organizations")
      .select(
        "id,owner_user_id,name,type,status,verification_status,metadata,city,province,latitude,longitude,focus_areas,supports_online,supports_offline,rating,review_count,contract_count,subscription_status,subscription_expires_at,created_at,updated_at"
      )
      .eq("id", id)
      .eq("status", "active")
      .maybeSingle();

    if (error) {
      if (isMissingOrganizationSchema(error)) return notFoundResponse();
      return errorResponse(error);
    }
    if (!data) return notFoundResponse();
    if (!isPublicOfficialOrganization(data as Row)) return notFoundResponse();

    const { data: reviewsData, error: reviewsError } = await supabase
      .from("consultation_reviews")
      .select("id,rating,body,created_at,consultation:consultations(target_name)")
      .eq("organization_id", id)
      .order("created_at", { ascending: false })
      .limit(5);

    if (reviewsError && !isMissingReviewSchema(reviewsError)) {
      return errorResponse(reviewsError);
    }

    const user = await getUserFromBearer(req);
    let includeContact = false;
    if (user) {
      const membership = await getUserMembership(supabase, user.id);
      if (membership.error) return errorResponse(membership.error);
      includeContact = membership.data?.is_member === true;
    }

    return NextResponse.json({
      success: true,
      data: publicOrganization(
        data as Row,
        includeContact,
        (reviewsData ?? []) as Row[]
      ),
    });
  } catch (e) {
    return errorResponse(e);
  }
}
