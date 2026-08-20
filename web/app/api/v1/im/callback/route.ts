import { NextRequest, NextResponse } from "next/server";

import {
  consumeTencentImSendPermit,
  extractTencentImSendPermit,
  stripTencentImSendPermit,
  verifyTencentImCallbackUrl,
} from "@/lib/api/tencent-im-callback";

export const runtime = "nodejs";

const MAX_CALLBACK_BODY_BYTES = 128 * 1_024;

type CallbackBody = Record<string, unknown> & {
  CallbackCommand?: unknown;
  From_Account?: unknown;
  To_Account?: unknown;
  GroupId?: unknown;
  MsgBody?: unknown;
  CloudCustomData?: unknown;
};

function callbackResponse(errorCode: 0 | 1, errorInfo: string, body?: CallbackBody) {
  return NextResponse.json({
    ActionStatus: "OK",
    ErrorCode: errorCode,
    ErrorInfo: errorInfo,
    ...(errorCode === 0 && Array.isArray(body?.MsgBody)
      ? {
          MsgBody: body.MsgBody,
          CloudCustomData: stripTencentImSendPermit(
            String(body.CloudCustomData ?? "")
          ),
        }
      : {}),
  });
}

function rejectCallback(reason: string) {
  console.warn("[tencent-im-callback] rejected", { reason });
  return callbackResponse(1, "BFF authorization required");
}

export async function POST(req: NextRequest) {
  const verified = verifyTencentImCallbackUrl(new URL(req.url));
  if (!verified.ok) return rejectCallback(verified.reason);

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > MAX_CALLBACK_BODY_BYTES) {
    return rejectCallback("body_too_large");
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return rejectCallback("body_read_failed");
  }
  if (Buffer.byteLength(rawBody, "utf8") > MAX_CALLBACK_BODY_BYTES) {
    return rejectCallback("body_too_large");
  }

  let body: CallbackBody;
  try {
    const decoded = JSON.parse(rawBody);
    if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
      return rejectCallback("body_invalid");
    }
    body = decoded as CallbackBody;
  } catch {
    return rejectCallback("body_invalid");
  }

  if (body.CallbackCommand !== verified.command || !Array.isArray(body.MsgBody)) {
    return rejectCallback("command_or_message_mismatch");
  }
  const fromIdentifier = String(body.From_Account ?? "").trim();
  const targetKind =
    verified.command === "C2C.CallbackBeforeSendMsg" ? "c2c" : "group";
  const targetIdentifier = String(
    targetKind === "c2c" ? body.To_Account ?? "" : body.GroupId ?? ""
  ).trim();
  const permit = extractTencentImSendPermit(body.CloudCustomData);
  if (!fromIdentifier || !targetIdentifier || !permit) {
    return rejectCallback("permit_missing");
  }

  try {
    const allowed = await consumeTencentImSendPermit(permit, {
      fromIdentifier,
      targetKind,
      targetIdentifier,
      msgBody: body.MsgBody,
    });
    if (!allowed) return rejectCallback("permit_invalid_or_replayed");
    return callbackResponse(0, "", body);
  } catch (error) {
    console.error("[tencent-im-callback] permit verification failed", {
      error: error instanceof Error ? error.name : "UnknownError",
    });
    return rejectCallback("permit_store_unavailable");
  }
}
