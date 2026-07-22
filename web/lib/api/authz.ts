import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import type { User } from "@supabase/supabase-js";
import { isAdminRole } from "./admin-roles";
import { getUserFromBearer } from "./auth-user";
import { isRetiredCommercialAgencyType } from "./organization-visibility";
import { createServiceClient } from "./supabase-service";

export type AuthzProfile = {
  role?: string | null;
  user_role?: string | null;
  user_type?: string | null;
  status?: string | null;
};

export type AuthzContext = {
  user: User;
  profile: AuthzProfile | null;
};

export type AuthzResult =
  | AuthzContext
  | {
      response: NextResponse;
    };

const BUSINESS_USER_ROLES = new Set([
  "official_association",
  "official_partner",
  "school_official",
  "gallery_exhibition",
  "event_organizer",
  "hotel_culture_space",
  "brand_partner",
  "art_media_community",
  "other_service",
  "institution",
  "institution_user",
]);

function unauthorized() {
  return {
    response: NextResponse.json(
      { success: false, error: "未授权" },
      { status: 401 }
    ),
  };
}

function forbidden(message = "权限不足") {
  return {
    response: NextResponse.json(
      { success: false, error: message },
      { status: 403 }
    ),
  };
}

function serverError(message: string) {
  return {
    response: NextResponse.json(
      { success: false, error: message },
      { status: 500 }
    ),
  };
}

export function isAuthzResponse(
  value: AuthzResult
): value is { response: NextResponse } {
  return "response" in value;
}

export function isAdminProfile(profile: AuthzProfile | null | undefined) {
  return isAdminRole(profile?.role);
}

export async function requireUser(req: NextRequest): Promise<AuthzResult> {
  const user = await getUserFromBearer(req);
  if (!user) return unauthorized();

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("user_profiles")
    .select("role,user_role,user_type,status")
    .eq("id", user.id)
    .maybeSingle();

  if (error) return serverError(error.message);
  if (["banned", "disabled"].includes(data?.status ?? "")) {
    return forbidden("账号已被限制使用");
  }
  return { user, profile: data ?? null };
}

export async function requireAdmin(req: NextRequest): Promise<AuthzResult> {
  const auth = await requireUser(req);
  if (isAuthzResponse(auth)) return auth;
  if (!isAdminProfile(auth.profile)) return forbidden("需要管理员权限");
  return auth;
}

export async function requireRole(
  req: NextRequest,
  roles: string[]
): Promise<AuthzResult> {
  const auth = await requireUser(req);
  if (isAuthzResponse(auth)) return auth;
  const allowed = new Set(roles);
  const profile = auth.profile;
  if (
    allowed.has(profile?.role ?? "") ||
    allowed.has(profile?.user_role ?? "") ||
    allowed.has(profile?.user_type ?? "")
  ) {
    return auth;
  }
  return forbidden();
}

export async function requireOrgMember(
  req: NextRequest,
  organizationId: string,
  roles: string[] = []
): Promise<AuthzResult> {
  const auth = await requireUser(req);
  if (isAuthzResponse(auth)) return auth;
  if (isAdminProfile(auth.profile)) return auth;

  const supabase = createServiceClient();
  let query = supabase
    .from("organization_members")
    .select("role")
    .eq("organization_id", organizationId)
    .eq("user_id", auth.user.id)
    .eq("status", "active");
  if (roles.length > 0) query = query.in("role", roles);
  const { data, error } = await query.maybeSingle();

  if (error) return serverError(error.message);
  if (!data) return forbidden("需要机构成员权限");

  const { data: organization, error: organizationError } = await supabase
    .from("organizations")
    .select("id,type")
    .eq("id", organizationId)
    .maybeSingle();
  if (organizationError) return serverError(organizationError.message);
  if (isRetiredCommercialAgencyType(organization?.type)) {
    return forbidden("该机构类型已下线");
  }
  return auth;
}

export async function requireBusinessPublisher(
  req: NextRequest
): Promise<AuthzResult> {
  const auth = await requireUser(req);
  if (isAuthzResponse(auth)) return auth;
  if (isAdminProfile(auth.profile)) return auth;

  const profile = auth.profile;
  const hasRetiredProfileRole =
    isRetiredCommercialAgencyType(profile?.user_role) ||
    isRetiredCommercialAgencyType(profile?.role);
  if (
    !hasRetiredProfileRole &&
    (BUSINESS_USER_ROLES.has(profile?.user_role ?? "") ||
      BUSINESS_USER_ROLES.has(profile?.role ?? ""))
  ) {
    return auth;
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("organization_members")
    .select("id,organization_id")
    .eq("user_id", auth.user.id)
    .eq("status", "active")
    .limit(20);
  if (error) return serverError(error.message);
  const organizationIds = uniqueStrings(
    ((data ?? []) as Record<string, unknown>[]).map((row) =>
      typeof row.organization_id === "string" ? row.organization_id : null
    )
  );
  if (organizationIds.length > 0) {
    const { data: organizations, error: organizationError } = await supabase
      .from("organizations")
      .select("id,type")
      .in("id", organizationIds)
      .limit(organizationIds.length);
    if (organizationError) return serverError(organizationError.message);
    if (
      ((organizations ?? []) as Record<string, unknown>[]).some(
        (row) => !isRetiredCommercialAgencyType(row.type)
      )
    ) {
      return auth;
    }
  }
  return forbidden("需要机构或商家权限");
}

function uniqueStrings(values: Array<string | null | undefined>) {
  return Array.from(
    new Set(values.filter((value): value is string => typeof value === "string" && value.length > 0))
  );
}
