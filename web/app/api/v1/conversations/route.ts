import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { effectiveOrganizationSubscriptionStatus } from "@/lib/api/organization-subscription";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { auditContent } from "@/lib/api/content-safety";
import {
  contentSafetyErrorResponse,
  rejectedAuditResponse,
} from "@/lib/api/content-safety-http";

type Row = Record<string, unknown>;
type ProfileRow = {
  id: string;
  nickname: string | null;
  avatar_url: string | null;
  user_type?: string | null;
  user_role?: string | null;
};

const ALLOWED_CONVERSATION_TYPES = new Set([
  "direct",
  "organization",
  "group",
  "cooperation",
  "opportunity",
  "circle",
  "salon",
]);

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function profilePayload(profile: ProfileRow | null | undefined) {
  if (!profile) return null;
  return {
    id: profile.id,
    nickname: profile.nickname,
    avatar_url: profile.avatar_url,
    user_type: profile.user_type ?? null,
    user_role: profile.user_role ?? null,
  };
}

function organizationAvatar(row: Row) {
  const metadata = objectValue(row.metadata);
  return (
    cleanText(metadata.avatar_url) ||
    cleanText(metadata.logo_url) ||
    cleanText(metadata.image_url) ||
    null
  );
}

function realtimeTopic(conversationId: unknown) {
  return `conversation:${cleanText(conversationId)}:messages`;
}

async function findDirectConversation(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  peerId: string
) {
  const { data: mine, error: mineError } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("user_id", userId);
  if (mineError) throw mineError;

  const ids = (mine ?? []).map((item: { conversation_id: string }) => item.conversation_id);
  if (ids.length === 0) return null;

  const { data: peers, error: peerError } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("user_id", peerId)
    .in("conversation_id", ids);
  if (peerError) throw peerError;

  const sharedIds = (peers ?? []).map((item: { conversation_id: string }) => item.conversation_id);
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

async function findOrganizationConversation(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  organizationId: string
) {
  const { data: mine, error: mineError } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("user_id", userId);
  if (mineError) throw mineError;

  const ids = (mine ?? []).map((item: { conversation_id: string }) => item.conversation_id);
  if (ids.length === 0) return null;

  const { data: conversations, error } = await supabase
    .from("conversations")
    .select("*")
    .eq("type", "organization")
    .in("id", ids)
    .order("updated_at", { ascending: false })
    .limit(20);
  if (error) throw error;

  return (
    (conversations ?? []).find((conversation: Row) => {
      const metadata = objectValue(conversation.metadata);
      return (
        cleanText(metadata.organization_id) === organizationId &&
        cleanText(metadata.student_user_id) === userId
      );
    }) ?? null
  );
}

async function ensureConversationParticipants(
  supabase: ReturnType<typeof createServiceClient>,
  conversationId: string,
  participants: Array<{ user_id: string; role: "owner" | "admin" | "member" }>
) {
  const { data: existing, error } = await supabase
    .from("conversation_participants")
    .select("user_id")
    .eq("conversation_id", conversationId);
  if (error) throw error;

  const existingIds = new Set(
    (existing ?? []).map((item: { user_id: string }) => item.user_id)
  );
  const missing = participants
    .filter((item) => item.user_id && !existingIds.has(item.user_id))
    .map((item) => ({
      conversation_id: conversationId,
      user_id: item.user_id,
      role: item.role,
    }));
  if (missing.length === 0) return;

  const { error: insertError } = await supabase
    .from("conversation_participants")
    .insert(missing);
  if (insertError) throw insertError;
}

async function loadProfiles(
  supabase: ReturnType<typeof createServiceClient>,
  userIds: string[]
) {
  if (userIds.length === 0) return {} as Record<string, ProfileRow>;
  const { data, error } = await supabase
    .from("user_profiles")
    .select("id,nickname,avatar_url,user_type,user_role")
    .in("id", userIds);
  if (error) throw error;
  return Object.fromEntries(
    (data ?? []).map((profile: ProfileRow) => [profile.id, profile])
  ) as Record<string, ProfileRow>;
}

async function createOrReuseOrganizationConversation(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  organizationId: string,
  body: Row
) {
  const { data: organization, error: organizationError } = await supabase
    .from("organizations")
    .select(
      "id,owner_user_id,name,type,status,subscription_status,subscription_expires_at,metadata"
    )
    .eq("id", organizationId)
    .eq("status", "active")
    .maybeSingle();
  if (organizationError) throw organizationError;
  if (!organization) {
    return NextResponse.json(
      { success: false, error: "机构不存在或暂不可联系" },
      { status: 404 }
    );
  }
  if (effectiveOrganizationSubscriptionStatus(organization as Row) !== "active") {
    return NextResponse.json(
      { success: false, error: "该机构尚未完成入驻年费，暂不可联系" },
      { status: 402 }
    );
  }

  const { data: members, error: memberError } = await supabase
    .from("organization_members")
    .select("user_id,role,status")
    .eq("organization_id", organizationId)
    .eq("status", "active");
  if (memberError) throw memberError;

  const ownerUserId = cleanText((organization as Row).owner_user_id);
  const memberRows = (members ?? []) as Array<{
    user_id: string;
    role?: string | null;
  }>;
  const memberIds = memberRows.map((member) => member.user_id).filter(Boolean);
  const allUserIds = [
    ...new Set([userId, ownerUserId, ...memberIds].filter(Boolean)),
  ];
  if (allUserIds.length < 2) {
    return NextResponse.json(
      { success: false, error: "机构暂未配置可接待成员" },
      { status: 409 }
    );
  }

  const organizationName = cleanText((organization as Row).name) || "机构会话";
  const bodyMetadata = objectValue(body.metadata);
  const metadata = {
    ...bodyMetadata,
    source: cleanText(bodyMetadata.source) || cleanText(body.source) || "organization_message",
    group_kind: "student_organization",
    organization_id: organizationId,
    organization_name: organizationName,
    organization_type: cleanText((organization as Row).type) || null,
    organization_avatar_url: organizationAvatar(organization as Row),
    student_user_id: userId,
    transport_provider: "supabase_realtime",
  };
  const participants = allUserIds.map((participantId) => {
    const memberRole =
      participantId === ownerUserId
        ? "admin"
        : memberRows.find((member) => member.user_id === participantId)?.role;
    return {
      user_id: participantId,
      role:
        participantId === userId
          ? ("owner" as const)
          : memberRole === "owner" || memberRole === "admin"
            ? ("admin" as const)
            : ("member" as const),
    };
  });

  let conversation = await findOrganizationConversation(supabase, userId, organizationId);
  if (conversation) {
    const conversationId = cleanText((conversation as Row).id);
    const mergedMetadata = {
      ...objectValue((conversation as Row).metadata),
      ...metadata,
    };
    await ensureConversationParticipants(
      supabase,
      conversationId,
      participants
    );
    const { error: updateError } = await supabase
      .from("conversations")
      .update({
        title: cleanText((conversation as Row).title) || organizationName,
        metadata: mergedMetadata,
        updated_at: new Date().toISOString(),
      })
      .eq("id", conversationId);
    if (updateError) throw updateError;
    conversation = {
      ...(conversation as Row),
      title: cleanText((conversation as Row).title) || organizationName,
      metadata: mergedMetadata,
    };
  } else {
    const { data, error } = await supabase
      .from("conversations")
      .insert({
        type: "organization",
        title: organizationName,
        created_by: userId,
        metadata,
      })
      .select()
      .single();
    if (error) throw error;
    conversation = data;

    const { error: participantError } = await supabase
      .from("conversation_participants")
      .insert(
        participants.map((participant) => ({
          conversation_id: conversation.id,
          user_id: participant.user_id,
          role: participant.role,
        }))
      );
    if (participantError) throw participantError;
  }

  const profiles = await loadProfiles(supabase, allUserIds);
  const conversationId = cleanText((conversation as Row).id);

  return NextResponse.json({
    success: true,
    data: {
      ...(conversation as Row),
      type: "organization",
      title: cleanText((conversation as Row).title) || organizationName,
      metadata: {
        ...objectValue((conversation as Row).metadata),
        ...metadata,
      },
      organization: {
        id: organizationId,
        name: organizationName,
        type: cleanText((organization as Row).type) || null,
        avatar_url: organizationAvatar(organization as Row),
      },
      peer_user_id: null,
      peer_profile: null,
      realtime_topic: realtimeTopic(conversationId),
      participant_profiles: allUserIds.map((participantId) =>
        profilePayload(profiles[participantId])
      ),
    },
  });
}

export async function GET(req: NextRequest) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const supabase = createServiceClient();

    const { data: participants, error: participantError } = await supabase
      .from("conversation_participants")
      .select("conversation_id,last_read_at")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);
    if (participantError) return errorResponse(participantError);

    const ids = (participants ?? []).map((item: { conversation_id: string }) => item.conversation_id);
    if (ids.length === 0) {
      return NextResponse.json({ success: true, data: [], pagination: { limit, offset } });
    }

    const { data: conversations, error: conversationError } = await supabase
      .from("conversations")
      .select("*")
      .in("id", ids);
    if (conversationError) return errorResponse(conversationError);

    const { data: messages, error: messageError } = await supabase
      .from("messages")
      .select("*")
      .in("conversation_id", ids)
      .order("created_at", { ascending: false });
    if (messageError) return errorResponse(messageError);

    const { data: allParticipants } = await supabase
      .from("conversation_participants")
      .select("conversation_id,user_id")
      .in("conversation_id", ids);
    const otherUserIds = [
      ...new Set(
        (allParticipants ?? [])
          .map((item: { user_id: string }) => item.user_id)
          .filter((id: string) => id !== user.id)
      ),
    ];
    let profileMap: Record<
      string,
      {
        id: string;
        nickname: string | null;
        avatar_url: string | null;
        user_type: string | null;
        user_role: string | null;
      }
    > = {};
    if (otherUserIds.length > 0) {
      const { data: profiles } = await supabase
        .from("user_profiles")
        .select("id,nickname,avatar_url,user_type,user_role")
        .in("id", otherUserIds);
      profileMap = Object.fromEntries(
        (profiles ?? []).map((profile: ProfileRow) => [
          profile.id,
          {
            id: profile.id,
            nickname: profile.nickname,
            avatar_url: profile.avatar_url,
            user_type: profile.user_type ?? null,
            user_role: profile.user_role ?? null,
          },
        ])
      );
    }

    const data = ids
      .map((id: string) => {
        const conversation = (conversations ?? []).find((item: { id: string }) => item.id === id);
        if (!conversation) return null;
        const participant = (participants ?? []).find((item: { conversation_id: string }) => item.conversation_id === id);
        const latest = (messages ?? []).find((item: { conversation_id: string }) => item.conversation_id === id);
        const unread = (messages ?? []).filter((item: { conversation_id: string; sender_id: string | null; created_at: string }) => {
          if (item.conversation_id !== id || item.sender_id === user.id) return false;
          if (!participant?.last_read_at) return true;
          return new Date(item.created_at).getTime() > new Date(participant.last_read_at).getTime();
        }).length;
        const metadata = objectValue((conversation as Row | undefined)?.metadata);
        const isOrganizationConversation =
          conversation?.type === "organization" || Boolean(metadata.organization_id);
        const isDirectConversation = conversation?.type === "direct";
        const otherParticipant = isDirectConversation
          ? (allParticipants ?? []).find(
              (item: { conversation_id: string; user_id: string }) =>
                item.conversation_id === id && item.user_id !== user.id
            )
          : null;
        const otherProfile = otherParticipant ? profileMap[otherParticipant.user_id] : null;
        return {
          ...conversation,
          latest_message: latest ?? null,
          unread_count: unread,
          peer_profile: otherProfile,
          peer_user_id: isDirectConversation ? otherParticipant?.user_id ?? null : null,
          realtime_topic: realtimeTopic(id),
          organization: isOrganizationConversation
            ? {
                id: cleanText(metadata.organization_id) || null,
                name: cleanText(metadata.organization_name) || conversation?.title || null,
                type: cleanText(metadata.organization_type) || null,
                avatar_url: cleanText(metadata.organization_avatar_url) || null,
              }
            : null,
        };
      })
      .filter(Boolean);

    return NextResponse.json({ success: true, data, pagination: { limit, offset } });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function POST(req: NextRequest) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const body = await req.json();
    const requestedOrganizationId = cleanText(
      body.organization_id ?? objectValue(body.metadata).organization_id
    );
    const supabase = createServiceClient();
    if (requestedOrganizationId) {
      return await createOrReuseOrganizationConversation(
        supabase,
        user.id,
        requestedOrganizationId,
        body
      );
    }

    const participantIds = Array.isArray(body.participant_ids)
      ? body.participant_ids.map(String).filter(Boolean)
      : [];
    const uniqueIds = [...new Set([user.id, ...participantIds])];
    if (uniqueIds.length < 2) {
      return NextResponse.json({ success: false, error: "请至少选择一个对话对象" }, { status: 400 });
    }
    const conversationType = cleanText(body.type) || "direct";
    if (!ALLOWED_CONVERSATION_TYPES.has(conversationType)) {
      return NextResponse.json(
        { success: false, error: "会话类型无效" },
        { status: 400 }
      );
    }
    if (conversationType === "direct" && uniqueIds.length !== 2) {
      return NextResponse.json(
        { success: false, error: "一对一会话只能包含两名成员" },
        { status: 400 }
      );
    }
    if (conversationType !== "direct" && uniqueIds.length > 100) {
      return NextResponse.json(
        { success: false, error: "群聊最多包含 100 名成员" },
        { status: 400 }
      );
    }
    const conversationTitle = cleanText(body.title);
    if (Buffer.byteLength(conversationTitle, "utf8") > 100) {
      return NextResponse.json(
        { success: false, error: "会话名称不能超过 100 字节" },
        { status: 400 }
      );
    }
    if (conversationType !== "direct" && conversationTitle) {
      const audit = await auditContent({
        userId: user.id,
        text: conversationTitle,
        scene: "conversation_title",
      });
      const rejected = rejectedAuditResponse(audit, "会话名称");
      if (rejected) return rejected;
    }

    const { data: profiles } = await supabase
      .from("user_profiles")
      .select("id,nickname,avatar_url,user_type,user_role")
      .in("id", uniqueIds);
    const profileMap = Object.fromEntries(
      (profiles ?? []).map(
        (profile: {
          id: string;
          nickname: string | null;
          avatar_url: string | null;
          user_type?: string | null;
          user_role?: string | null;
        }) => [
          profile.id,
          {
            id: profile.id,
            nickname: profile.nickname,
            avatar_url: profile.avatar_url,
            user_type: profile.user_type ?? null,
            user_role: profile.user_role ?? null,
          },
        ]
      )
    );

    const peerId = conversationType === "direct" ? participantIds[0] ?? null : null;
    if (conversationType === "direct" && peerId) {
      const existing = await findDirectConversation(supabase, user.id, peerId);
      if (existing) {
        return NextResponse.json({
          success: true,
          data: {
            ...existing,
            peer_user_id: peerId,
            peer_profile: profileMap[peerId] ?? null,
            realtime_topic: realtimeTopic(existing.id),
          },
        });
      }
    }

    const { data: insertedConversation, error } = await supabase
      .from("conversations")
      .insert({
        type: conversationType,
        title: conversationTitle || null,
        created_by: user.id,
        metadata: {
          ...objectValue(body.metadata),
          transport_provider: "supabase_realtime",
        },
      })
      .select()
      .single();
    if (error) return errorResponse(error);
    const conversation = insertedConversation as Row;

    const { error: participantError } = await supabase
      .from("conversation_participants")
      .insert(
        uniqueIds.map((id) => ({
          conversation_id: cleanText(conversation.id),
          user_id: id,
          role: id === user.id ? "owner" : "member",
        }))
      );
    if (participantError) return errorResponse(participantError);

    return NextResponse.json(
      {
        success: true,
        data: {
          ...conversation,
          peer_user_id: peerId,
          peer_profile: peerId ? profileMap[peerId] ?? null : null,
          realtime_topic: realtimeTopic(conversation.id),
        },
      },
      { status: 201 }
    );
  } catch (e) {
    const auditError = contentSafetyErrorResponse(e);
    if (auditError) return auditError;
    return errorResponse(e);
  }
}
