import { randomBytes } from "crypto";
import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse } from "@/lib/api/route-helpers";

type QrCodeRow = {
  id: string;
  token: string;
  type: string;
  target_id: string | null;
  owner_user_id: string | null;
  status: string;
  expires_at: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
};

type ProfileRow = {
  id: string;
  nickname: string | null;
  avatar_url: string | null;
  user_type?: string | null;
  user_role?: string | null;
  status?: string | null;
  is_verified?: boolean | null;
  handle?: string | null;
  username?: string | null;
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function publicBase(req: NextRequest) {
  return (
    process.env.NEXT_PUBLIC_SITE_URL ||
    process.env.NEXT_PUBLIC_APP_URL ||
    process.env.APP_URL ||
    req.nextUrl.origin
  ).replace(/\/$/, "");
}

function qrUrl(req: NextRequest, token: string) {
  return `${publicBase(req)}/api/v1/qr-codes/${encodeURIComponent(token)}`;
}

function randomToken() {
  return `u_${randomBytes(12).toString("base64url")}`;
}

function profilePayload(profile: ProfileRow | null) {
  if (!profile) return null;
  return {
    id: profile.id,
    nickname: profile.nickname,
    avatar_url: profile.avatar_url,
    user_type: profile.user_type ?? null,
    user_role: profile.user_role ?? null,
    status: profile.status ?? null,
    is_verified: profile.is_verified === true,
    handle: profile.handle ?? profile.username ?? null,
  };
}

function qrPayload(req: NextRequest, row: QrCodeRow, profile: ProfileRow | null) {
  return {
    ...row,
    qr_url: qrUrl(req, row.token),
    target_profile: profilePayload(profile),
  };
}

async function createUniqueToken(supabase: ReturnType<typeof createServiceClient>) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const token = randomToken();
    const { data, error } = await supabase
      .from("qr_codes")
      .select("id")
      .eq("token", token)
      .maybeSingle();
    if (error) throw error;
    if (!data) return token;
  }
  throw new Error("二维码 token 生成失败，请重试");
}

export async function POST(req: NextRequest) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const type = cleanText(body.type) || "user";
    if (type !== "user") {
      return NextResponse.json(
        { success: false, error: "当前仅支持生成个人名片码" },
        { status: 400 }
      );
    }

    const supabase = createServiceClient();
    const now = new Date().toISOString();
    const { data: existing, error: existingError } = await supabase
      .from("qr_codes")
      .select("*")
      .eq("type", "user")
      .eq("owner_user_id", user.id)
      .eq("target_id", user.id)
      .eq("status", "active")
      .or(`expires_at.is.null,expires_at.gt.${now}`)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (existingError) return errorResponse(existingError);

    let qrCode = existing as QrCodeRow | null;
    if (!qrCode) {
      const token = await createUniqueToken(supabase);
      const { data, error } = await supabase
        .from("qr_codes")
        .insert({
          token,
          type: "user",
          target_id: user.id,
          owner_user_id: user.id,
          status: "active",
          metadata:
            body.metadata && typeof body.metadata === "object" && !Array.isArray(body.metadata)
              ? body.metadata
              : {},
        })
        .select("*")
        .single();
      if (error) return errorResponse(error);
      qrCode = data as QrCodeRow;
    }

    const { data: profile, error: profileError } = await supabase
      .from("user_profiles")
      .select("id,nickname,avatar_url,user_type,user_role,status,is_verified,handle,username")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) return errorResponse(profileError);

    return NextResponse.json({
      success: true,
      data: qrPayload(req, qrCode, (profile as ProfileRow | null) ?? null),
    });
  } catch (error) {
    return errorResponse(error);
  }
}
