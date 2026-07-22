import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  errorResponse,
  invalidIdResponse,
  notFoundResponse,
} from "@/lib/api/route-helpers";
import { requireWorkbenchUser } from "@/lib/api/workbench-access";
import { isRetiredCommercialAgencyType } from "@/lib/api/organization-visibility";

type Ctx = { params: Promise<{ id: string }> };
type Row = Record<string, unknown>;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const METADATA_KEYS = [
  "summary",
  "description",
  "address",
  "phone",
  "wechat_qr_url",
  "contact_note",
  "avatar_url",
  "logo_url",
] as const;

function hasOwn(row: Row, key: string) {
  return Object.prototype.hasOwnProperty.call(row, key);
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown): Row {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function numberValue(value: unknown) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function boolValue(value: unknown) {
  if (typeof value === "boolean") return value;
  if (value === "true") return true;
  if (value === "false") return false;
  return undefined;
}

function stringList(value: unknown) {
  if (typeof value === "string") {
    return value
      .split(/[,，\s]+/u)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  if (!Array.isArray(value)) return undefined;
  return value.map((item) => cleanText(item)).filter(Boolean);
}

function metadataPatch(body: Row) {
  const patch: Row = {};
  const explicit = objectValue(body.metadata);
  for (const key of METADATA_KEYS) {
    if (hasOwn(explicit, key)) patch[key] = cleanText(explicit[key]);
    if (hasOwn(body, key)) patch[key] = cleanText(body[key]);
  }
  return Object.keys(patch).length > 0 ? patch : null;
}

export async function PATCH(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) return invalidIdResponse();

    const auth = await requireWorkbenchUser(req);
    if ("response" in auth) return auth.response;
    if (!auth.manageableOrganizationIds.includes(id)) {
      return NextResponse.json(
        { success: false, error: "需要机构负责人或管理员权限" },
        { status: 403 }
      );
    }

    const body = (await req.json().catch(() => ({}))) as Row;
    const update: Row = {};

    if (hasOwn(body, "name")) {
      const name = cleanText(body.name);
      if (!name) {
        return NextResponse.json(
          { success: false, error: "机构名称必填" },
          { status: 400 }
        );
      }
      update.name = name;
    }
    if (hasOwn(body, "type")) {
      const type = cleanText(body.type);
      if (isRetiredCommercialAgencyType(type)) {
        return NextResponse.json(
          { success: false, error: "该机构类型已下线" },
          { status: 400 }
        );
      }
      update.type = type || null;
    }
    if (hasOwn(body, "city")) update.city = cleanText(body.city) || null;
    if (hasOwn(body, "province")) update.province = cleanText(body.province) || null;

    if (hasOwn(body, "latitude")) {
      const latitude = numberValue(body.latitude);
      if (latitude === undefined) {
        return NextResponse.json({ success: false, error: "纬度格式无效" }, { status: 400 });
      }
      update.latitude = latitude;
    }
    if (hasOwn(body, "longitude")) {
      const longitude = numberValue(body.longitude);
      if (longitude === undefined) {
        return NextResponse.json({ success: false, error: "经度格式无效" }, { status: 400 });
      }
      update.longitude = longitude;
    }

    if (hasOwn(body, "focus_areas")) update.focus_areas = stringList(body.focus_areas) ?? [];
    if (hasOwn(body, "supports_online")) {
      const value = boolValue(body.supports_online);
      if (value === undefined) {
        return NextResponse.json(
          { success: false, error: "线上服务字段格式无效" },
          { status: 400 }
        );
      }
      update.supports_online = value;
    }
    if (hasOwn(body, "supports_offline")) {
      const value = boolValue(body.supports_offline);
      if (value === undefined) {
        return NextResponse.json(
          { success: false, error: "线下服务字段格式无效" },
          { status: 400 }
        );
      }
      update.supports_offline = value;
    }

    const metadata = metadataPatch(body);
    const supabase = createServiceClient();
    if (metadata) {
      const { data: current, error: currentError } = await supabase
        .from("organizations")
        .select("id,metadata")
        .eq("id", id)
        .maybeSingle();

      if (currentError) return errorResponse(currentError);
      if (!current) return notFoundResponse();
      update.metadata = {
        ...objectValue((current as Row).metadata),
        ...metadata,
      };
    }

    if (Object.keys(update).length === 0) {
      return NextResponse.json(
        { success: false, error: "没有可更新的机构字段" },
        { status: 400 }
      );
    }

    const { data, error } = await supabase
      .from("organizations")
      .update(update)
      .eq("id", id)
      .select("*")
      .single();

    if (error) return errorResponse(error);

    const membership = auth.memberships.find(
      (item) => item.organization_id === id
    );
    return NextResponse.json({
      success: true,
      data: {
        role: membership?.role ?? "admin",
        status: membership?.status ?? "active",
        organization: data,
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
