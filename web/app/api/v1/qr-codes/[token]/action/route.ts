import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, notFoundResponse } from "@/lib/api/route-helpers";
import {
  buildTencentImIdentifier,
  ensureTencentImFriendship,
  TencentImConfigError,
} from "@/lib/api/tencent-im";

type Ctx = { params: Promise<{ token: string }> };

type Row = Record<string, unknown>;

type QrCodeRow = {
  id: string;
  token: string;
  type: string;
  target_id: string | null;
  owner_user_id: string | null;
  status: string;
  expires_at: string | null;
  metadata: Record<string, unknown> | null;
};

type ProfileRow = {
  id: string;
  nickname: string | null;
  avatar_url: string | null;
  user_type?: string | null;
  user_role?: string | null;
  status?: string | null;
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function profilePayload(profile: ProfileRow | null) {
  if (!profile) return null;
  return {
    id: profile.id,
    nickname: profile.nickname,
    avatar_url: profile.avatar_url,
    user_type: profile.user_type ?? null,
    user_role: profile.user_role ?? null,
    im_identifier: buildTencentImIdentifier(profile.id),
  };
}

function participantImIdentifiers(ids: string[]) {
  return Object.fromEntries(ids.map((id) => [id, buildTencentImIdentifier(id)]));
}

async function getDirectConversation(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  friendId: string
) {
  const { data: mine, error: mineError } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("user_id", userId);
  if (mineError) throw mineError;

  const ids = (mine ?? []).map((item: { conversation_id: string }) => item.conversation_id);
  if (ids.length === 0) return null;

  const { data: theirs, error: theirsError } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("user_id", friendId)
    .in("conversation_id", ids);
  if (theirsError) throw theirsError;

  const sharedIds = (theirs ?? []).map(
    (item: { conversation_id: string }) => item.conversation_id
  );
  if (sharedIds.length === 0) return null;

  const { data: conversation, error: conversationError } = await supabase
    .from("conversations")
    .select("*")
    .eq("type", "direct")
    .in("id", sharedIds)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (conversationError) throw conversationError;
  return conversation;
}

async function ensureDirectConversation(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  friendId: string
) {
  const existing = await getDirectConversation(supabase, userId, friendId);
  if (existing) return existing;

  const { data: conversation, error } = await supabase
    .from("conversations")
    .insert({
      type: "direct",
      created_by: userId,
      metadata: {
        source: "qr_code",
        friend_user_id: friendId,
      },
    })
    .select()
    .single();
  if (error) throw error;

  const { error: participantError } = await supabase
    .from("conversation_participants")
    .insert([
      {
        conversation_id: conversation.id,
        user_id: userId,
        role: "owner",
      },
      {
        conversation_id: conversation.id,
        user_id: friendId,
        role: "member",
      },
    ]);
  if (participantError) throw participantError;

  return conversation;
}

async function addFriendFromQr({
  supabase,
  userId,
  targetUserId,
  message,
}: {
  supabase: ReturnType<typeof createServiceClient>;
  userId: string;
  targetUserId: string;
  message: string | null;
}) {
  if (targetUserId === userId) {
    return NextResponse.json(
      { success: false, error: "不能添加自己为好友" },
      { status: 400 }
    );
  }

  const { data: profiles, error: profileError } = await supabase
    .from("user_profiles")
    .select("id,nickname,avatar_url,user_type,user_role,status")
    .in("id", [userId, targetUserId]);
  if (profileError) return errorResponse(profileError);

  const profileMap = Object.fromEntries(
    (profiles ?? []).map((profile: ProfileRow) => [profile.id, profile])
  ) as Record<string, ProfileRow | undefined>;
  const currentProfile = profileMap[userId] ?? null;
  const friendProfile = profileMap[targetUserId] ?? null;
  if (!friendProfile || ["banned", "disabled"].includes(friendProfile.status ?? "")) {
    return NextResponse.json(
      { success: false, error: "用户不存在或不可添加" },
      { status: 404 }
    );
  }

  const imSync = await ensureTencentImFriendship({
    fromUserId: userId,
    toUserId: targetUserId,
    fromNickname: currentProfile?.nickname,
    fromAvatarUrl: currentProfile?.avatar_url,
    toNickname: friendProfile.nickname,
    toAvatarUrl: friendProfile.avatar_url,
    addWording: message,
  });

  const now = new Date().toISOString();
  const { error: upsertError } = await supabase.from("user_friends").upsert(
    [
      {
        user_id: userId,
        friend_id: targetUserId,
        status: "active",
        source: "qr_code",
        metadata: {
          provider: "tencent_im",
          im_sync: imSync.status,
          friend_im_identifier: buildTencentImIdentifier(targetUserId),
          updated_by: userId,
        },
        updated_at: now,
      },
      {
        user_id: targetUserId,
        friend_id: userId,
        status: "active",
        source: "qr_code",
        metadata: {
          provider: "tencent_im",
          im_sync: imSync.status,
          friend_im_identifier: buildTencentImIdentifier(userId),
          updated_by: userId,
        },
        updated_at: now,
      },
    ],
    { onConflict: "user_id,friend_id" }
  );
  if (upsertError) return errorResponse(upsertError);

  const conversation = (await ensureDirectConversation(
    supabase,
    userId,
    targetUserId
  )) as Row;

  return NextResponse.json({
    success: true,
    data: {
      action: "add_friend",
      friend_id: targetUserId,
      status: "active",
      im_sync: imSync.status,
      im_identifier: buildTencentImIdentifier(targetUserId),
      profile: profilePayload(friendProfile),
      conversation: {
        ...conversation,
        peer_user_id: targetUserId,
        peer_profile: profilePayload(friendProfile),
        peer_im_identifier: buildTencentImIdentifier(targetUserId),
        current_user_im_identifier: buildTencentImIdentifier(userId),
        participant_im_identifiers: participantImIdentifiers([userId, targetUserId]),
      },
    },
  });
}

export async function POST(req: NextRequest, ctx: Ctx) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const { token } = await ctx.params;
    const body = await req.json().catch(() => ({}));
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
        { success: false, error: "二维码已失效" },
        { status: 410 }
      );
    }
    if (qrCode.expires_at && new Date(qrCode.expires_at).getTime() < Date.now()) {
      await supabase
        .from("qr_codes")
        .update({ status: "expired", updated_at: new Date().toISOString() })
        .eq("id", qrCode.id);
      return NextResponse.json(
        { success: false, error: "二维码已过期" },
        { status: 410 }
      );
    }
    if (qrCode.type !== "user" || !qrCode.target_id) {
      return NextResponse.json(
        { success: false, error: "这个二维码暂不支持当前动作" },
        { status: 400 }
      );
    }

    return await addFriendFromQr({
      supabase,
      userId: user.id,
      targetUserId: qrCode.target_id,
      message:
        cleanText(body.message) ||
        "你好，我扫了你的 Artsee 艺见心名片，想加个好友交流。",
    });
  } catch (error) {
    if (error instanceof TencentImConfigError) {
      return NextResponse.json(
        { success: false, error: error.message, missing: error.missing },
        { status: 503 }
      );
    }
    return errorResponse(error);
  }
}
