import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, notFoundResponse } from "@/lib/api/route-helpers";

type Ctx = { params: Promise<{ token: string }> };

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

function actionFor(qrCode: QrCodeRow) {
  if (qrCode.type === "user") {
    return {
      kind: "add_friend",
      label: "添加好友",
      method: "POST",
      path: `/api/v1/qr-codes/${encodeURIComponent(qrCode.token)}/action`,
    };
  }
  if (qrCode.type === "group") {
    return { kind: "join_group", label: "加入群聊" };
  }
  if (qrCode.type === "event") {
    return { kind: "event_checkin", label: "活动签到" };
  }
  return null;
}

export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { token } = await ctx.params;
    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("qr_codes")
      .select("*")
      .eq("token", token)
      .maybeSingle();
    if (error) return errorResponse(error);
    if (!data) return notFoundResponse();

    const qrCode = data as QrCodeRow;
    if (qrCode.status !== "active") {
      return NextResponse.json(
        { success: false, error: "二维码已失效", data: { status: qrCode.status } },
        { status: 410 }
      );
    }
    if (qrCode.expires_at && new Date(qrCode.expires_at).getTime() < Date.now()) {
      await supabase
        .from("qr_codes")
        .update({ status: "expired", updated_at: new Date().toISOString() })
        .eq("id", qrCode.id);
      return NextResponse.json(
        { success: false, error: "二维码已过期", data: { status: "expired" } },
        { status: 410 }
      );
    }

    let targetProfile: ProfileRow | null = null;
    if (qrCode.type === "user" && qrCode.target_id) {
      const { data: profile, error: profileError } = await supabase
        .from("user_profiles")
        .select("id,nickname,avatar_url,user_type,user_role,status,is_verified,handle,username")
        .eq("id", qrCode.target_id)
        .maybeSingle();
      if (profileError) return errorResponse(profileError);
      targetProfile = (profile as ProfileRow | null) ?? null;
      if (!targetProfile || ["banned", "disabled"].includes(targetProfile.status ?? "")) {
        return NextResponse.json(
          { success: false, error: "用户不存在或不可添加" },
          { status: 404 }
        );
      }
    }

    const user = await getUserFromBearer(req);
    let viewerState: Record<string, unknown> = { logged_in: Boolean(user) };
    if (user && qrCode.type === "user" && qrCode.target_id) {
      if (user.id === qrCode.target_id) {
        viewerState = { logged_in: true, is_self: true, friendship_status: "self" };
      } else {
        const { data: friend } = await supabase
          .from("user_friends")
          .select("status")
          .eq("user_id", user.id)
          .eq("friend_id", qrCode.target_id)
          .maybeSingle();
        viewerState = {
          logged_in: true,
          is_self: false,
          friendship_status: friend?.status ?? "none",
        };
      }
    }

    return NextResponse.json({
      success: true,
      data: {
        qr_code: {
          id: qrCode.id,
          token: qrCode.token,
          type: qrCode.type,
          status: qrCode.status,
          expires_at: qrCode.expires_at,
          qr_url: qrUrl(req, qrCode.token),
          metadata: qrCode.metadata ?? {},
        },
        target: profilePayload(targetProfile),
        action: actionFor(qrCode),
        viewer: viewerState,
      },
    });
  } catch (error) {
    return errorResponse(error);
  }
}
