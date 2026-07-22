import type { User } from "@supabase/supabase-js";
import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { isAdminRole } from "./admin-roles";
import { getUserFromBearer } from "./auth-user";
import { isRetiredCommercialAgencyType } from "./organization-visibility";
import { createServiceClient } from "./supabase-service";

export type WorkbenchAuth =
  | {
      user: User;
      canAccessPlatformPool: boolean;
      organizationIds: string[];
      memberships: WorkbenchMembership[];
      memberIds: string[];
      manageableOrganizationIds: string[];
    }
  | {
      response: NextResponse;
    };

export type WorkbenchMembership = {
  id: string;
  organization_id: string;
  user_id: string;
  role: string;
  status?: string | null;
  metadata?: Record<string, unknown> | null;
};

const MANAGER_ROLES = new Set(["owner", "admin"]);

function isMissingOrganizationMembersTable(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const err = error as { code?: string; message?: string };
  return (
    err.code === "42P01" ||
    err.code === "PGRST205" ||
    Boolean(err.message?.includes("organization_members"))
  );
}

export async function requireWorkbenchUser(req: NextRequest): Promise<WorkbenchAuth> {
  const user = await getUserFromBearer(req);
  if (!user) {
    return {
      response: NextResponse.json({ success: false, error: "未授权" }, { status: 401 }),
    };
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("user_profiles")
    .select("role,user_role,user_type")
    .eq("id", user.id)
    .maybeSingle();

  if (error) {
    return {
      response: NextResponse.json({ success: false, error: error.message }, { status: 500 }),
    };
  }

  const role = data?.role?.toString();
  const userRole = data?.user_role?.toString();
  const userType = data?.user_type?.toString();
  const canAccessPlatformPool =
    isAdminRole(role) ||
    role === "advisor" ||
    userRole === "advisor" ||
    userType === "advisor";

  const {
    data: memberships,
    error: membershipError,
  } = await supabase
    .from("organization_members")
    .select("id,organization_id,user_id,role,status,metadata")
    .eq("user_id", user.id)
    .eq("status", "active");

  if (membershipError && !isMissingOrganizationMembersTable(membershipError)) {
    return {
      response: NextResponse.json(
        { success: false, error: membershipError.message },
        { status: 500 }
      ),
    };
  }

  const normalizedMemberships =
    memberships
      ?.filter(isWorkbenchMembership)
      .map((membership) => ({
        ...membership,
        metadata:
          membership.metadata &&
          typeof membership.metadata === "object" &&
          !Array.isArray(membership.metadata)
            ? (membership.metadata as Record<string, unknown>)
            : null,
      })) ?? [];
  const { memberships: activeMemberships, error: organizationError } =
    await filterRetiredAgencyMemberships(supabase, normalizedMemberships);

  if (organizationError) {
    return {
      response: NextResponse.json(
        { success: false, error: organizationError.message },
        { status: 500 }
      ),
    };
  }

  const organizationIds = uniqueStrings(
    activeMemberships.map((membership) => membership.organization_id)
  );
  const memberIds = uniqueStrings(activeMemberships.map((membership) => membership.id));
  const manageableOrganizationIds = uniqueStrings(
    activeMemberships
      .filter((membership) => MANAGER_ROLES.has(membership.role))
      .map((membership) => membership.organization_id)
  );

  return {
    user,
    canAccessPlatformPool,
    organizationIds,
    memberships: activeMemberships,
    memberIds,
    manageableOrganizationIds,
  };
}

async function filterRetiredAgencyMemberships(
  supabase: ReturnType<typeof createServiceClient>,
  memberships: WorkbenchMembership[]
) {
  const organizationIds = uniqueStrings(
    memberships.map((membership) => membership.organization_id)
  );
  if (organizationIds.length === 0) return { memberships, error: null };

  const { data, error } = await supabase
    .from("organizations")
    .select("id,type")
    .in("id", organizationIds);

  if (error) return { memberships: [] as WorkbenchMembership[], error };

  const typeByOrganizationId = new Map(
    ((data ?? []) as Record<string, unknown>[])
      .filter((row) => typeof row.id === "string")
      .map((row) => [row.id as string, row.type])
  );

  return {
    memberships: memberships.filter(
      (membership) =>
        !isRetiredCommercialAgencyType(
          typeByOrganizationId.get(membership.organization_id)
        )
    ),
    error: null,
  };
}

export function canAccessWorkbenchConsultation(
  consultation: Record<string, unknown>,
  userId: string,
  canAccessPlatformPool: boolean,
  organizationIds: string[] = [],
  memberships: WorkbenchMembership[] = []
) {
  return canAccessWorkbenchAssignment(
    consultation,
    userId,
    canAccessPlatformPool,
    organizationIds,
    memberships
  );
}

export function canAccessWorkbenchAssignment(
  row: Record<string, unknown>,
  userId: string,
  canAccessPlatformPool: boolean,
  organizationIds: string[] = [],
  memberships: WorkbenchMembership[] = []
) {
  if (row.assigned_to_user_id === userId) return true;
  if (row.primary_advisor_id === userId) return true;

  const memberIds = uniqueStrings(memberships.map((membership) => membership.id));
  if (
    typeof row.assigned_to_member_id === "string" &&
    memberIds.includes(row.assigned_to_member_id)
  ) {
    return true;
  }

  if (jsonIdArrayIncludes(row.collaborator_ids, [userId, ...memberIds])) return true;
  if (jsonAdvisorArrayIncludes(row.assigned_advisors, userId, memberIds)) return true;

  const assignedOrgId =
    typeof row.assigned_to_org_id === "string" ? row.assigned_to_org_id : null;
  if (assignedOrgId && canManageWorkbenchOrganization(memberships, assignedOrgId)) {
    return true;
  }

  if (memberships.length === 0 && assignedOrgId && organizationIds.includes(assignedOrgId)) {
    return true;
  }

  const unassigned =
    row.assigned_to_user_id == null && row.assigned_to_org_id == null;
  return canAccessPlatformPool && unassigned;
}

export function canManageWorkbenchOrganization(
  memberships: WorkbenchMembership[],
  organizationId: string
) {
  return memberships.some(
    (membership) =>
      membership.organization_id === organizationId &&
      MANAGER_ROLES.has(membership.role)
  );
}

export function findWorkbenchMembership(
  memberships: WorkbenchMembership[],
  organizationId: string
) {
  return memberships.find((membership) => membership.organization_id === organizationId) ?? null;
}

function isWorkbenchMembership(value: unknown): value is WorkbenchMembership {
  if (!value || typeof value !== "object") return false;
  const row = value as Record<string, unknown>;
  return (
    typeof row.id === "string" &&
    typeof row.organization_id === "string" &&
    typeof row.user_id === "string" &&
    typeof row.role === "string"
  );
}

function uniqueStrings(values: Array<string | null | undefined>) {
  return Array.from(
    new Set(values.filter((value): value is string => typeof value === "string" && value.length > 0))
  );
}

function jsonIdArrayIncludes(value: unknown, ids: string[]) {
  if (!Array.isArray(value)) return false;
  return value.some((item) => {
    if (typeof item === "string") return ids.includes(item);
    if (!item || typeof item !== "object") return false;
    const row = item as Record<string, unknown>;
    return (
      (typeof row.user_id === "string" && ids.includes(row.user_id)) ||
      (typeof row.member_id === "string" && ids.includes(row.member_id))
    );
  });
}

function jsonAdvisorArrayIncludes(value: unknown, userId: string, memberIds: string[]) {
  if (!Array.isArray(value)) return false;
  return value.some((item) => {
    if (typeof item === "string") return item === userId || memberIds.includes(item);
    if (!item || typeof item !== "object") return false;
    const row = item as Record<string, unknown>;
    return (
      row.user_id === userId ||
      (typeof row.member_id === "string" && memberIds.includes(row.member_id))
    );
  });
}
