import {
  createHash,
  randomBytes,
  timingSafeEqual,
} from "crypto";

import { createServiceClient } from "@/lib/api/supabase-service";

const CALLBACK_MAX_SKEW_SECONDS = 60;
const DEFAULT_PERMIT_TTL_SECONDS = 45;
const MAX_PERMIT_TTL_SECONDS = 120;
const PERMIT_TABLE = "tencent_im_send_permits";

type TargetKind = "c2c" | "group";

type PermitInput = {
  fromIdentifier: string;
  targetKind: TargetKind;
  targetIdentifier: string;
  msgBody: unknown;
};

export class TencentImCallbackConfigError extends Error {
  constructor(public readonly missing: string[]) {
    super(`缺少或无效的腾讯 IM 回调配置: ${missing.join(", ")}`);
    this.name = "TencentImCallbackConfigError";
  }
}

export class TencentImPermitError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TencentImPermitError";
  }
}

function positiveInt(value: string | undefined, fallback: number, max: number) {
  const parsed = Number.parseInt(value ?? "", 10);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, max);
}

function callbackConfig() {
  const sdkAppIdRaw = process.env.TENCENT_IM_SDK_APP_ID?.trim() ?? "";
  const callbackToken = process.env.TENCENT_IM_CALLBACK_TOKEN?.trim() ?? "";
  const sdkAppId = Number.parseInt(sdkAppIdRaw, 10);
  const missing = [
    !/^\d+$/.test(sdkAppIdRaw) || !Number.isSafeInteger(sdkAppId) || sdkAppId <= 0
      ? "TENCENT_IM_SDK_APP_ID"
      : null,
    callbackToken.length < 32 ? "TENCENT_IM_CALLBACK_TOKEN" : null,
  ].filter(Boolean) as string[];
  if (missing.length > 0) throw new TencentImCallbackConfigError(missing);
  return { sdkAppId, callbackToken };
}

export function isTencentImBffCallbackRequired() {
  return process.env.TENCENT_IM_REQUIRE_BFF_CALLBACK === "1";
}

export function createTencentImCallbackSign(
  callbackToken: string,
  requestTime: string
) {
  return createHash("sha256")
    .update(`${callbackToken}${requestTime}`, "utf8")
    .digest("hex");
}

function constantTimeHexEqual(left: string, right: string) {
  if (!/^[0-9a-f]{64}$/i.test(left) || !/^[0-9a-f]{64}$/i.test(right)) {
    return false;
  }
  return timingSafeEqual(
    Buffer.from(left.toLowerCase(), "hex"),
    Buffer.from(right.toLowerCase(), "hex")
  );
}

export function verifyTencentImCallbackUrl(
  url: URL,
  nowSeconds = Math.floor(Date.now() / 1_000)
) {
  if (!isTencentImBffCallbackRequired()) {
    return { ok: false as const, reason: "callback_not_enabled" };
  }

  let config: ReturnType<typeof callbackConfig>;
  try {
    config = callbackConfig();
  } catch {
    return { ok: false as const, reason: "callback_config_invalid" };
  }

  const sdkAppId = url.searchParams.get("SdkAppid") ?? "";
  const command = url.searchParams.get("CallbackCommand") ?? "";
  const requestTime = url.searchParams.get("RequestTime") ?? "";
  const sign = url.searchParams.get("Sign") ?? "";
  const platform = url.searchParams.get("OptPlatform") ?? "";
  const parsedRequestTime = Number.parseInt(requestTime, 10);
  const commandAllowed =
    command === "C2C.CallbackBeforeSendMsg" ||
    command === "Group.CallbackBeforeSendMsg";

  if (sdkAppId !== String(config.sdkAppId)) {
    return { ok: false as const, reason: "sdk_app_id_mismatch" };
  }
  if (!commandAllowed) {
    return { ok: false as const, reason: "command_not_allowed" };
  }
  if (platform !== "RESTAPI") {
    return { ok: false as const, reason: "client_sdk_send_denied" };
  }
  if (
    !/^\d{9,11}$/.test(requestTime) ||
    !Number.isSafeInteger(parsedRequestTime) ||
    Math.abs(nowSeconds - parsedRequestTime) > CALLBACK_MAX_SKEW_SECONDS
  ) {
    return { ok: false as const, reason: "request_time_invalid" };
  }
  const expected = createTencentImCallbackSign(
    config.callbackToken,
    requestTime
  );
  if (!constantTimeHexEqual(sign, expected)) {
    return { ok: false as const, reason: "signature_invalid" };
  }
  return { ok: true as const, command };
}

function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) ?? "null";
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(object[key])}`)
    .join(",")}}`;
}

export function hashTencentImMsgBody(msgBody: unknown) {
  return createHash("sha256")
    .update(canonicalJson(msgBody), "utf8")
    .digest("hex");
}

function hashPermitToken(token: string) {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

export async function issueTencentImSendPermit(input: PermitInput) {
  callbackConfig();
  const token = randomBytes(32).toString("base64url");
  const ttlSeconds = positiveInt(
    process.env.TENCENT_IM_CALLBACK_PERMIT_TTL_SECONDS,
    DEFAULT_PERMIT_TTL_SECONDS,
    MAX_PERMIT_TTL_SECONDS
  );
  const { error } = await createServiceClient().from(PERMIT_TABLE).insert({
    token_hash: hashPermitToken(token),
    from_identifier: input.fromIdentifier,
    target_kind: input.targetKind,
    target_identifier: input.targetIdentifier,
    msg_body_sha256: hashTencentImMsgBody(input.msgBody),
    expires_at: new Date(Date.now() + ttlSeconds * 1_000).toISOString(),
  });
  if (error) {
    throw new TencentImPermitError("无法创建腾讯 IM 消息放行票据");
  }
  return token;
}

export async function consumeTencentImSendPermit(
  token: string,
  input: PermitInput
) {
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) return false;
  const { data, error } = await createServiceClient().rpc(
    "consume_tencent_im_send_permit",
    {
      p_token_hash: hashPermitToken(token),
      p_from_identifier: input.fromIdentifier,
      p_target_kind: input.targetKind,
      p_target_identifier: input.targetIdentifier,
      p_msg_body_sha256: hashTencentImMsgBody(input.msgBody),
    }
  );
  if (error) {
    throw new TencentImPermitError("无法消费腾讯 IM 消息放行票据");
  }
  return data === true;
}

export async function discardTencentImSendPermit(token: string) {
  const { error } = await createServiceClient()
    .from(PERMIT_TABLE)
    .delete()
    .eq("token_hash", hashPermitToken(token));
  if (error) {
    console.warn("[tencent-im] failed to discard send permit", {
      code: error.code ?? null,
    });
  }
}

export function attachTencentImSendPermit(
  cloudCustomData: Record<string, unknown>,
  token: string
) {
  return JSON.stringify({
    ...cloudCustomData,
    artsee_bff_authorization: { version: 1, permit: token },
  });
}

export function extractTencentImSendPermit(cloudCustomData: unknown) {
  if (typeof cloudCustomData !== "string") return null;
  try {
    const decoded = JSON.parse(cloudCustomData) as Record<string, unknown>;
    const authorization = decoded.artsee_bff_authorization;
    if (!authorization || typeof authorization !== "object") return null;
    const token = (authorization as Record<string, unknown>).permit;
    return typeof token === "string" ? token : null;
  } catch {
    return null;
  }
}

export function stripTencentImSendPermit(cloudCustomData: string) {
  try {
    const decoded = JSON.parse(cloudCustomData) as Record<string, unknown>;
    delete decoded.artsee_bff_authorization;
    return JSON.stringify(decoded);
  } catch {
    return cloudCustomData;
  }
}
