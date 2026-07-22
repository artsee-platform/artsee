import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { effectiveOrganizationSubscriptionStatus } from "@/lib/api/organization-subscription";
import { isRetiredCommercialAgencyType } from "@/lib/api/organization-visibility";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";

type OrganizationBody = {
  name?: unknown;
  type?: unknown;
  metadata?: unknown;
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectMetadata(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function objectValue(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function normalizeMembership(row: Record<string, unknown>) {
  const organization = objectValue(row.organization);
  if (!row.organization || Object.keys(organization).length === 0) return row;
  return {
    ...row,
    organization: {
      ...organization,
      stored_subscription_status:
        typeof organization.subscription_status === "string"
          ? organization.subscription_status
          : "inactive",
      subscription_status: effectiveOrganizationSubscriptionStatus(organization),
    },
  };
}

function isActiveOrganizationMembership(row: Record<string, unknown>) {
  const organization = objectValue(row.organization);
  return !isRetiredCommercialAgencyType(organization.type);
}

function isMissingOrganizationTables(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const err = error as { code?: string; message?: string };
  return (
    err.code === "42P01" ||
    err.code === "PGRST205" ||
    Boolean(err.message?.includes("organizations")) ||
    Boolean(err.message?.includes("organization_members"))
  );
}

export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("organization_members")
      .select("role,status,organization:organizations(*)", { count: "exact" })
      .eq("user_id", user.id)
      .eq("status", "active")
      .order("created_at", { ascending: false });

    if (error) {
      if (isMissingOrganizationTables(error)) {
        return NextResponse.json({
          success: true,
          data: [],
          count: 0,
          pagination: { limit, offset },
          schema_ready: false,
        });
      }
      return errorResponse(error);
    }

    const allRows = ((data ?? []) as Record<string, unknown>[])
      .filter(isActiveOrganizationMembership)
      .map(normalizeMembership);
    const rows = allRows.slice(offset, offset + limit);

    return NextResponse.json({
      success: true,
      data: rows,
      count: allRows.length,
      pagination: { limit, offset },
    });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const body = (await req.json().catch(() => ({}))) as OrganizationBody;
    const name = cleanText(body.name);
    if (!name) {
      return NextResponse.json({ success: false, error: "机构名称必填" }, { status: 400 });
    }
    const type = cleanText(body.type);
    if (isRetiredCommercialAgencyType(type)) {
      return NextResponse.json(
        { success: false, error: "该机构类型已下线" },
        { status: 400 }
      );
    }

    const supabase = createServiceClient();
    const { data: organization, error: organizationError } = await supabase
      .from("organizations")
      .insert({
        name,
        type: type || null,
        owner_user_id: user.id,
        status: "active",
        verification_status: "pending",
        metadata: objectMetadata(body.metadata),
      })
      .select("*")
      .single();

    if (organizationError) return errorResponse(organizationError);

    const { error: memberError } = await supabase
      .from("organization_members")
      .insert({
        organization_id: organization.id,
        user_id: user.id,
        role: "owner",
        status: "active",
      });

    if (memberError) return errorResponse(memberError);

    return NextResponse.json(
      {
        success: true,
        data: {
          role: "owner",
          status: "active",
          organization,
        },
      },
      { status: 201 }
    );
  } catch (e) {
    return errorResponse(e);
  }
}
