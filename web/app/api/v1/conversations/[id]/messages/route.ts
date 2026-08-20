import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { auditContent, collectAuditText } from "@/lib/api/content-safety";
import {
  contentSafetyErrorResponse,
  rejectedAuditResponse,
} from "@/lib/api/content-safety-http";

type Row = Record<string, unknown>;

const ATTACHMENT_MESSAGE_TYPES = new Set(["image", "file"]);
const ALLOWED_MESSAGE_TYPES = new Set(["text", "image", "file"]);

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function isHttpUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === "https:";
  } catch {
    return false;
  }
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const { id } = await params;
    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const supabase = createServiceClient();

    const { data: member } = await supabase
      .from("conversation_participants")
      .select("conversation_id")
      .eq("conversation_id", id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (!member) {
      return NextResponse.json({ success: false, error: "无权查看该会话" }, { status: 403 });
    }

    const { data, error } = await supabase
      .from("messages")
      .select("*")
      .eq("conversation_id", id)
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);
    if (error) return errorResponse(error);

    await supabase
      .from("conversation_participants")
      .update({ last_read_at: new Date().toISOString() })
      .eq("conversation_id", id)
      .eq("user_id", user.id);

    return NextResponse.json({ success: true, data, pagination: { limit, offset } });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    const { id } = await params;
    const body = await req.json();
    const metadata = objectValue(body.metadata);
    const messageType = cleanText(body.message_type) || "text";
    if (!ALLOWED_MESSAGE_TYPES.has(messageType)) {
      return NextResponse.json({ success: false, error: "消息类型无效" }, { status: 400 });
    }

    const attachmentUrl = cleanText(
      body.attachment_url ??
        body.url ??
        metadata.attachment_url ??
        metadata.asset_url ??
        metadata.public_url ??
        metadata.url
    );
    const attachmentName = cleanText(
      body.attachment_name ??
        body.file_name ??
        body.filename ??
        metadata.attachment_name ??
        metadata.file_name ??
        metadata.filename
    );
    const contentType = cleanText(
      body.content_type ?? body.file_type ?? metadata.content_type ?? metadata.file_type
    );
    const size = Number(body.size ?? metadata.size);
    const hasAttachment = ATTACHMENT_MESSAGE_TYPES.has(messageType);
    const text = cleanText(body.body) || (hasAttachment
      ? messageType === "image"
        ? "[图片]"
        : `[文件]${attachmentName ? ` ${attachmentName}` : ""}`
      : "");

    if (!text) {
      return NextResponse.json({ success: false, error: "消息不能为空" }, { status: 400 });
    }
    if (hasAttachment && (!attachmentUrl || !isHttpUrl(attachmentUrl))) {
      return NextResponse.json({ success: false, error: "附件链接无效" }, { status: 400 });
    }

    const supabase = createServiceClient();
    const { data: member, error: participantError } = await supabase
      .from("conversation_participants")
      .select("conversation_id")
      .eq("conversation_id", id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (participantError) return errorResponse(participantError);
    if (!member) {
      return NextResponse.json({ success: false, error: "无权发送该会话消息" }, { status: 403 });
    }

    const auditText = collectAuditText(
      messageType === "image" ? "" : text,
      attachmentName
    );
    const audit = await auditContent({
      userId: user.id,
      text: auditText || undefined,
      imageUrls: messageType === "image" ? [attachmentUrl] : [],
      scene: "private_message",
    });
    const rejected = rejectedAuditResponse(audit, "消息");
    if (rejected) return rejected;

    const safeAudit = {
      provider: audit.provider,
      suggestion: audit.suggestion,
      audit_status: audit.audit_status,
      items: audit.items.map((item) => ({
        type: item.type,
        suggestion: item.suggestion,
        label: item.label,
        sub_label: item.sub_label,
        score: item.score,
        request_id: item.request_id,
      })),
    };
    const initialMetadata = {
      ...metadata,
      ...(hasAttachment
        ? {
            attachment_url: attachmentUrl,
            attachment_name: attachmentName || null,
            content_type: contentType || null,
            size: Number.isFinite(size) && size > 0 ? size : null,
            provider: cleanText(metadata.provider) || "tencent_cos",
          }
        : {}),
      content_audit: safeAudit,
      realtime_status: "persisted",
      transport_provider: "supabase_realtime",
    };

    const { data, error } = await supabase
      .from("messages")
      .insert({
        conversation_id: id,
        sender_id: user.id,
        body: text,
        message_type: messageType,
        metadata: initialMetadata,
      })
      .select()
      .single();
    if (error) return errorResponse(error);

    await supabase
      .from("conversations")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", id);

    return NextResponse.json({ success: true, data }, { status: 201 });
  } catch (e) {
    const auditError = contentSafetyErrorResponse(e);
    if (auditError) return auditError;
    return errorResponse(e);
  }
}
