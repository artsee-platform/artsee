import { NextRequest, NextResponse } from "next/server";
import { writeAdminAuditLog } from "@/lib/api/admin-audit";
import { requireAdmin } from "@/lib/api/require-admin";
import { createServiceClient } from "@/lib/api/supabase-service";
import { createNotification } from "@/lib/api/notifications";
import { errorResponse } from "@/lib/api/route-helpers";

type Ctx = { params: Promise<{ id: string }> };
type SupabaseServiceClient = ReturnType<typeof createServiceClient>;

const BUSINESS_ROLES = new Set([
  "official_association",
  "official_partner",
  "school_official",
  "gallery_exhibition",
  "event_organizer",
  "hotel_culture_space",
  "brand_partner",
  "art_media_community",
  "other_service",
]);

function objectValue(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function businessRoleForVerification(row: Record<string, unknown>) {
  const materials = objectValue(row.materials);
  const requestedRole = String(materials.requested_role || materials.user_role || "");
  return BUSINESS_ROLES.has(requestedRole) ? requestedRole : "other_service";
}

function profilePatchForVerification(row: Record<string, unknown>) {
  const type = String(row.type || "");

  if (type === "business") {
    return {
      user_type: "business",
      user_role: businessRoleForVerification(row),
      is_verified: true,
    };
  }

  if (["student", "artist", "collector"].includes(type)) {
    return {
      user_type: "personal",
      user_role: type,
      is_verified: true,
    };
  }

  return null;
}

function roleCodeForVerification(type: unknown) {
  switch (String(type || "")) {
    case "student":
      return "student_verified";
    case "artist":
      return "artist_verified";
    case "collector":
      return "collector_verified";
    case "business":
      return "business_verified";
    default:
      return null;
  }
}

function verificationTypeLabel(type: unknown) {
  switch (String(type || "")) {
    case "student":
      return "学生身份";
    case "artist":
      return "艺术家身份";
    case "collector":
      return "收藏者身份";
    case "business":
      return "机构入驻";
    default:
      return "身份认证";
  }
}

function verificationNotification(status: string, row: Record<string, unknown>, note: unknown) {
  const typeLabel = verificationTypeLabel(row.type);
  const reviewNote = String(note || "").trim();
  if (status === "approved") {
    return {
      title: `${typeLabel}认证已通过`,
      content:
        String(row.type || "") === "business"
          ? "你的机构身份已开通，可前往工作台管理机构档案、发布内容和处理咨询。"
          : "你的身份认证已通过，可继续完善主页并使用对应功能。",
    };
  }
  return {
    title: `${typeLabel}认证未通过`,
    content: reviewNote || "认证材料未通过审核，请补充资料后重新提交。",
  };
}

function organizationNameForVerification(row: Record<string, unknown>, userId: string) {
  const materials = objectValue(row.materials);
  const candidates = [
    materials.company_name,
    materials.organization_name,
    materials.display_name,
    materials.legal_name,
  ];
  for (const candidate of candidates) {
    const name = String(candidate || "").trim();
    if (name) return name;
  }
  return `机构-${userId.slice(0, 8)}`;
}

async function ensureBusinessOrganization(
  supabase: SupabaseServiceClient,
  row: Record<string, unknown>
) {
  if (String(row.type || "") !== "business") return;

  const userId = String(row.user_id || "");
  if (!userId) return;

  const role = businessRoleForVerification(row);
  const materials = objectValue(row.materials);
  const metadata = {
    ...materials,
    source: "verification",
    verification_id: row.id,
    verified_at: new Date().toISOString(),
  };

  const { data: existing, error: existingError } = await supabase
    .from("organizations")
    .select("id")
    .eq("owner_user_id", userId)
    .eq("type", role)
    .maybeSingle();
  if (existingError) throw existingError;

  let organizationId = String((existing as { id?: unknown } | null)?.id || "");
  if (organizationId) {
    const { error: updateError } = await supabase
      .from("organizations")
      .update({
        name: organizationNameForVerification(row, userId),
        status: "active",
        verification_status: "verified",
        metadata,
      })
      .eq("id", organizationId);
    if (updateError) throw updateError;
  } else {
    const { data: created, error: createError } = await supabase
      .from("organizations")
      .insert({
        owner_user_id: userId,
        name: organizationNameForVerification(row, userId),
        type: role,
        status: "active",
        verification_status: "verified",
        metadata,
      })
      .select("id")
      .single();
    if (createError) throw createError;
    organizationId = String((created as { id?: unknown } | null)?.id || "");
  }

  if (!organizationId) return;
  const { error: memberError } = await supabase
    .from("organization_members")
    .upsert(
      {
        organization_id: organizationId,
        user_id: userId,
        role: "owner",
        status: "active",
      },
      { onConflict: "organization_id,user_id" }
    );
  if (memberError) throw memberError;
}

export async function POST(req: NextRequest, ctx: Ctx) {
  const admin = await requireAdmin(req);
  if ("response" in admin) return admin.response;
  try {
    const { id } = await ctx.params;
    const body = await req.json();
    const status = String(body.status || "");
    if (!["approved", "rejected"].includes(status)) {
      return NextResponse.json({ success: false, error: "status 必须是 approved 或 rejected" }, { status: 400 });
    }
    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("verifications")
      .update({
        status,
        review_note: body.review_note ?? null,
        reviewer_id: admin.user.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq("id", id)
      .select()
      .single();
    if (error) return errorResponse(error);
    if (status === "approved") {
      const profilePatch = profilePatchForVerification(data as Record<string, unknown>);
      const userId = String((data as { user_id?: unknown }).user_id || "");
      if (profilePatch && userId) {
        const { error: profileError } = await supabase
          .from("user_profiles")
          .update(profilePatch)
          .eq("id", userId);
        if (profileError) return errorResponse(profileError);
      }

      const roleCode = roleCodeForVerification((data as { type?: unknown }).type);
      if (roleCode && userId) {
        const { error: roleError } = await supabase
          .from("user_roles")
          .upsert(
            { user_id: userId, role_code: roleCode },
            { onConflict: "user_id,role_code", ignoreDuplicates: true }
          );
        if (roleError) return errorResponse(roleError);
      }

      try {
        await ensureBusinessOrganization(supabase, data as Record<string, unknown>);
      } catch (organizationError) {
        return errorResponse(organizationError);
      }
    }
    const userId = String((data as { user_id?: unknown }).user_id || "");
    const notification = verificationNotification(
      status,
      data as Record<string, unknown>,
      body.review_note
    );
    await createNotification(supabase, userId, {
      ...notification,
      type: "verification",
      metadata: {
        verification_id: id,
        verification_type: (data as { type?: unknown }).type,
        status,
      },
    });
    await writeAdminAuditLog(supabase, req, {
      actorUserId: admin.user.id,
      action: "verification.review",
      targetType: "verification",
      targetId: id,
      targetLabel: verificationTypeLabel((data as { type?: unknown }).type),
      metadata: {
        status,
        user_id: userId,
        verification_type: (data as { type?: unknown }).type,
        has_review_note: Boolean(String(body.review_note || "").trim()),
      },
    });
    return NextResponse.json({ success: true, data });
  } catch (e) {
    return errorResponse(e);
  }
}
