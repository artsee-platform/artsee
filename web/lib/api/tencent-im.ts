import { createHash, createHmac } from "crypto";
import { deflateSync } from "zlib";

import {
  attachTencentImSendPermit,
  discardTencentImSendPermit,
  isTencentImBffCallbackRequired,
  issueTencentImSendPermit,
} from "@/lib/api/tencent-im-callback";

export class TencentImConfigError extends Error {
  constructor(public readonly missing: string[]) {
    super(`缺少或无效的腾讯云 IM 配置: ${missing.join(", ")}`);
    this.name = "TencentImConfigError";
  }
}

export class TencentImApiError extends Error {
  constructor(
    public readonly code: number | null,
    message: string,
    public readonly httpStatus: number | null = null
  ) {
    super(message);
    this.name = "TencentImApiError";
  }
}

export class TencentImRateLimitError extends Error {
  constructor(public readonly retryAfterSeconds: number) {
    super("腾讯云 IM 登录配置请求过于频繁，请稍后重试");
    this.name = "TencentImRateLimitError";
  }
}

export type TencentImConfig = {
  sdkAppId: number;
  secretKey: string;
  adminUserId: string;
  expireSeconds: number;
  restHost: string;
  restTimeoutMs: number;
  restMaxAttempts: number;
};

export type TencentImLoginConfig = {
  sdk_app_id: number;
  identifier: string;
  user_sig: string;
  expires_in: number;
  expires_at: string;
  account_sync: "synced" | "skipped" | "failed";
};

type TencentImRestEnvelope = {
  ActionStatus?: string;
  ErrorInfo?: string;
  ErrorCode?: number;
};

type TencentImGroupEnvelope = TencentImRestEnvelope & {
  GroupId?: string;
};

type TencentImSendEnvelope = TencentImRestEnvelope & {
  MsgKey?: string;
  MsgTime?: number;
  MsgSeq?: number;
};

type TencentImFriendAddEnvelope = TencentImRestEnvelope & {
  ResultItem?: Array<{
    To_Account?: string;
    ResultCode?: number;
    ResultInfo?: string;
  }>;
  Fail_Account?: string[];
};

const DEFAULT_ADMIN_USER_ID = "administrator";
const DEFAULT_EXPIRE_SECONDS = 7 * 24 * 60 * 60;
const DEFAULT_REST_TIMEOUT_MS = 5_000;
const DEFAULT_REST_MAX_ATTEMPTS = 2;
const LOGIN_RATE_LIMIT_WINDOW_MS = 60_000;
const DEFAULT_LOGIN_RATE_LIMIT = 12;
const ACCOUNT_CACHE_TTL_MS = 6 * 60 * 60 * 1_000;

const loginRateWindows = new Map<
  string,
  { startedAt: number; requestCount: number }
>();
const accountSyncCache = new Map<string, number>();
const accountSyncInFlight = new Map<string, Promise<void>>();

function parsePositiveInt(value: string | undefined, fallback: number) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function boundedPositiveInt(
  value: string | undefined,
  fallback: number,
  max: number
) {
  return Math.min(parsePositiveInt(value, fallback), max);
}

export function getTencentImConfig(): TencentImConfig {
  const sdkAppIdRaw = process.env.TENCENT_IM_SDK_APP_ID?.trim();
  const secretKey = process.env.TENCENT_IM_SECRET_KEY?.trim();
  const sdkAppId = Number.parseInt(sdkAppIdRaw ?? "", 10);
  const validSdkAppId =
    Boolean(sdkAppIdRaw) &&
    /^\d+$/.test(sdkAppIdRaw!) &&
    Number.isSafeInteger(sdkAppId) &&
    sdkAppId > 0;
  const validSecretKey =
    Boolean(secretKey) &&
    secretKey!.length >= 20 &&
    !/^\d+$/.test(secretKey!);
  const missing = [
    !validSdkAppId ? "TENCENT_IM_SDK_APP_ID" : null,
    !validSecretKey ? "TENCENT_IM_SECRET_KEY" : null,
  ].filter(Boolean) as string[];

  if (missing.length > 0) throw new TencentImConfigError(missing);

  return {
    sdkAppId,
    secretKey: secretKey!,
    adminUserId:
      process.env.TENCENT_IM_ADMIN_USER_ID?.trim() || DEFAULT_ADMIN_USER_ID,
    expireSeconds: parsePositiveInt(
      process.env.TENCENT_IM_USER_SIG_EXPIRES_SECONDS,
      DEFAULT_EXPIRE_SECONDS
    ),
    restHost:
      process.env.TENCENT_IM_REST_HOST?.trim().replace(/^https?:\/\//, "") ||
      "console.tim.qq.com",
    restTimeoutMs: boundedPositiveInt(
      process.env.TENCENT_IM_REST_TIMEOUT_MS,
      DEFAULT_REST_TIMEOUT_MS,
      30_000
    ),
    restMaxAttempts: boundedPositiveInt(
      process.env.TENCENT_IM_REST_MAX_ATTEMPTS,
      DEFAULT_REST_MAX_ATTEMPTS,
      3
    ),
  };
}

function base64UrlEncode(value: Buffer | string) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/\+/g, "*")
    .replace(/\//g, "-")
    .replace(/=/g, "_");
}

export function buildTencentImIdentifier(userId: string) {
  const normalized = userId.trim();
  if (!normalized) throw new Error("腾讯云 IM 用户 ID 不能为空");
  // Tencent IM UserID is limited to 32 bytes. Supabase Auth IDs are UUIDs
  // (36 bytes), so prefixing or using them directly is invalid. A versioned,
  // fixed-width hash is stable, contains only supported characters, and does
  // not expose the underlying Auth UUID.
  return `u${createHash("sha256").update(normalized, "utf8").digest("hex").slice(0, 31)}`;
}

export function buildTencentImGroupId(conversationId: string) {
  const normalized = conversationId.trim();
  if (!normalized) throw new Error("腾讯云 IM 会话 ID 不能为空");
  return `artsee_g_${createHash("sha256")
    .update(normalized, "utf8")
    .digest("hex")
    .slice(0, 32)}`;
}

export function consumeTencentImLoginConfigQuota(userId: string) {
  const now = Date.now();
  if (loginRateWindows.size > 1_000) {
    for (const [key, value] of loginRateWindows) {
      if (now - value.startedAt >= LOGIN_RATE_LIMIT_WINDOW_MS) {
        loginRateWindows.delete(key);
      }
    }
  }
  const limit = boundedPositiveInt(
    process.env.TENCENT_IM_LOGIN_CONFIG_REQUESTS_PER_MINUTE,
    DEFAULT_LOGIN_RATE_LIMIT,
    120
  );
  const current = loginRateWindows.get(userId);
  if (!current || now - current.startedAt >= LOGIN_RATE_LIMIT_WINDOW_MS) {
    loginRateWindows.set(userId, { startedAt: now, requestCount: 1 });
    return;
  }
  if (current.requestCount >= limit) {
    throw new TencentImRateLimitError(
      Math.max(
        1,
        Math.ceil(
          (LOGIN_RATE_LIMIT_WINDOW_MS - (now - current.startedAt)) / 1_000
        )
      )
    );
  }
  current.requestCount += 1;
}

export function generateTencentImUserSig(input: {
  sdkAppId: number;
  secretKey: string;
  identifier: string;
  expireSeconds: number;
  nowSeconds?: number;
}) {
  const now = input.nowSeconds ?? Math.floor(Date.now() / 1000);
  const signContent = [
    `TLS.identifier:${input.identifier}`,
    `TLS.sdkappid:${input.sdkAppId}`,
    `TLS.time:${now}`,
    `TLS.expire:${input.expireSeconds}`,
    "",
  ].join("\n");
  const sig = createHmac("sha256", input.secretKey)
    .update(signContent, "utf8")
    .digest("base64");
  const payload = {
    "TLS.ver": "2.0",
    "TLS.identifier": input.identifier,
    "TLS.sdkappid": input.sdkAppId,
    "TLS.expire": input.expireSeconds,
    "TLS.time": now,
    "TLS.sig": sig,
  };
  return base64UrlEncode(deflateSync(JSON.stringify(payload)));
}

async function callTencentImRest<T extends TencentImRestEnvelope>(
  command: string,
  body: Record<string, unknown>,
  options?: { maxAttempts?: number }
): Promise<T> {
  const config = getTencentImConfig();
  const maxAttempts = Math.max(
    1,
    Math.min(options?.maxAttempts ?? config.restMaxAttempts, 3)
  );
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const random = Math.floor(Math.random() * 4294967295);
    const userSig = generateTencentImUserSig({
      sdkAppId: config.sdkAppId,
      secretKey: config.secretKey,
      identifier: config.adminUserId,
      expireSeconds: config.expireSeconds,
    });
    const url = new URL(`https://${config.restHost}/v4/${command}`);
    url.searchParams.set("sdkappid", String(config.sdkAppId));
    url.searchParams.set("identifier", config.adminUserId);
    url.searchParams.set("usersig", userSig);
    url.searchParams.set("random", String(random));
    url.searchParams.set("contenttype", "json");

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(config.restTimeoutMs),
      });
      const json = (await response.json().catch(() => null)) as T | null;
      if (!response.ok || !json) {
        const error = new TencentImApiError(
          null,
          `腾讯云 IM 请求失败: ${response.status} ${response.statusText}`,
          response.status
        );
        if (
          attempt < maxAttempts &&
          (response.status === 429 || response.status >= 500)
        ) {
          lastError = error;
          await new Promise((resolve) => setTimeout(resolve, attempt * 150));
          continue;
        }
        throw error;
      }
      const errorCode = json.ErrorCode ?? 0;
      if (json.ActionStatus === "FAIL" || errorCode !== 0) {
        throw new TencentImApiError(
          errorCode,
          `腾讯云 IM 请求失败: ${errorCode || "Unknown"} ${json.ErrorInfo ?? ""}`.trim(),
          response.status
        );
      }
      return json;
    } catch (error) {
      if (error instanceof TencentImApiError) throw error;
      lastError = error;
      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, attempt * 150));
        continue;
      }
    }
  }

  throw new TencentImApiError(
    null,
    `腾讯云 IM 网络请求失败: ${lastError instanceof Error ? lastError.message : "Unknown"}`
  );
}

export async function ensureTencentImAccount(input: {
  identifier: string;
  nickname?: string | null;
  avatarUrl?: string | null;
}) {
  const cachedAt = accountSyncCache.get(input.identifier);
  if (cachedAt && Date.now() - cachedAt < ACCOUNT_CACHE_TTL_MS) return;
  const existing = accountSyncInFlight.get(input.identifier);
  if (existing) return existing;

  const sync = callTencentImRest("im_open_login_svc/account_import", {
    UserID: input.identifier,
    Nick: input.nickname || input.identifier,
    FaceUrl: input.avatarUrl || undefined,
  }).then(() => {
    accountSyncCache.set(input.identifier, Date.now());
  });
  accountSyncInFlight.set(input.identifier, sync);
  try {
    await sync;
  } finally {
    accountSyncInFlight.delete(input.identifier);
  }
}

export async function ensureTencentImAccounts(
  users: Array<{
    userId: string;
    nickname?: string | null;
    avatarUrl?: string | null;
  }>
) {
  if (process.env.TENCENT_IM_SKIP_ACCOUNT_IMPORT === "1") return;
  const uniqueUsers = [
    ...new Map(users.map((user) => [user.userId, user])).values(),
  ];
  for (let index = 0; index < uniqueUsers.length; index += 10) {
    await Promise.all(
      uniqueUsers.slice(index, index + 10).map((user) =>
        ensureTencentImAccount({
          identifier: buildTencentImIdentifier(user.userId),
          nickname: user.nickname,
          avatarUrl: user.avatarUrl,
        })
      )
    );
  }
}

function truncateUtf8(value: string, maxBytes: number) {
  let result = "";
  for (const character of value) {
    if (Buffer.byteLength(result + character, "utf8") > maxBytes) break;
    result += character;
  }
  return result;
}

export async function ensureTencentImGroup(input: {
  conversationId: string;
  title?: string | null;
  ownerUserId: string;
  users: Array<{
    userId: string;
    nickname?: string | null;
    avatarUrl?: string | null;
  }>;
}) {
  const users = [
    ...new Map(input.users.map((user) => [user.userId, user])).values(),
  ];
  if (!users.some((user) => user.userId === input.ownerUserId)) {
    users.unshift({ userId: input.ownerUserId });
  }
  if (users.length > 100) {
    throw new TencentImApiError(10005, "腾讯云 IM 群成员不能超过 100 人");
  }
  await ensureTencentImAccounts(users);

  const groupId = buildTencentImGroupId(input.conversationId);
  const ownerIdentifier = buildTencentImIdentifier(input.ownerUserId);
  const memberIdentifiers = users
    .map((user) => buildTencentImIdentifier(user.userId))
    .filter((identifier) => identifier !== ownerIdentifier);
  let created = true;
  try {
    await callTencentImRest<TencentImGroupEnvelope>(
      "group_open_http_svc/create_group",
      {
        Owner_Account: ownerIdentifier,
        Type: "Private",
        GroupId: groupId,
        Name: truncateUtf8(input.title?.trim() || "艺见心群聊", 100),
        MemberList: memberIdentifiers.slice(0, 20).map((identifier) => ({
          Member_Account: identifier,
        })),
      }
    );
  } catch (error) {
    if (!(error instanceof TencentImApiError) || error.code !== 10025) {
      throw error;
    }
    created = false;
  }

  if (!created || memberIdentifiers.length > 20) {
    for (let index = 0; index < memberIdentifiers.length; index += 20) {
      await callTencentImRest("group_open_http_svc/add_group_member", {
        GroupId: groupId,
        Silence: 1,
        MemberList: memberIdentifiers
          .slice(index, index + 20)
          .map((identifier) => ({ Member_Account: identifier })),
      });
    }
  }
  return groupId;
}

function offlinePushInfo(conversationId: string, messageType: string) {
  const description =
    messageType === "image"
      ? "你收到一张图片"
      : messageType === "file"
        ? "你收到一个文件"
        : "你收到一条新消息";
  return {
    PushFlag: 0,
    Title: process.env.TENCENT_IM_OFFLINE_PUSH_TITLE?.trim() || "艺见心新消息",
    Desc: description,
    Ext: JSON.stringify({ action: "open_chat", conversation_id: conversationId }),
  };
}

export async function sendTencentImConversationMessage(input: {
  conversationId: string;
  messageId: string;
  messageType: string;
  text: string;
  fromUserId: string;
  toUserId?: string | null;
  groupId?: string | null;
}) {
  const fromIdentifier = buildTencentImIdentifier(input.fromUserId);
  const cloudCustomData = {
    conversation_id: input.conversationId,
    message_id: input.messageId,
    message_type: input.messageType,
  };
  const msgBody = [
    {
      MsgType: "TIMTextElem",
      MsgContent: { Text: input.text },
    },
  ];
  const random = Math.floor(Math.random() * 4294967295);

  if (input.groupId) {
    const permit = isTencentImBffCallbackRequired()
      ? await issueTencentImSendPermit({
          fromIdentifier,
          targetKind: "group",
          targetIdentifier: input.groupId,
          msgBody,
        })
      : null;
    try {
      const response = await callTencentImRest<TencentImSendEnvelope>(
        "group_open_http_svc/send_group_msg",
        {
          GroupId: input.groupId,
          From_Account: fromIdentifier,
          Random: random,
          MsgBody: msgBody,
          CloudCustomData: permit
            ? attachTencentImSendPermit(cloudCustomData, permit)
            : JSON.stringify(cloudCustomData),
          OfflinePushInfo: offlinePushInfo(
            input.conversationId,
            input.messageType
          ),
        },
        // A permit is one-time. Retrying the same payload after a lost REST
        // response could only be rejected by the second callback invocation.
        permit ? { maxAttempts: 1 } : undefined
      );
      return {
        provider: "tencent_im" as const,
        mode: "group" as const,
        group_id: input.groupId,
        im_msg_seq: response.MsgSeq ?? null,
      };
    } finally {
      if (permit) await discardTencentImSendPermit(permit);
    }
  }

  if (!input.toUserId) {
    throw new TencentImApiError(null, "腾讯云 IM 单聊缺少接收用户");
  }
  const toIdentifier = buildTencentImIdentifier(input.toUserId);
  await ensureTencentImAccounts([
    { userId: input.fromUserId },
    { userId: input.toUserId },
  ]);
  const permit = isTencentImBffCallbackRequired()
    ? await issueTencentImSendPermit({
        fromIdentifier,
        targetKind: "c2c",
        targetIdentifier: toIdentifier,
        msgBody,
      })
    : null;
  try {
    const response = await callTencentImRest<TencentImSendEnvelope>(
      "openim/sendmsg",
      {
        SyncOtherMachine: 1,
        From_Account: fromIdentifier,
        To_Account: toIdentifier,
        MsgRandom: random,
        MsgBody: msgBody,
        CloudCustomData: permit
          ? attachTencentImSendPermit(cloudCustomData, permit)
          : JSON.stringify(cloudCustomData),
        OfflinePushInfo: offlinePushInfo(
          input.conversationId,
          input.messageType
        ),
      },
      permit ? { maxAttempts: 1 } : undefined
    );
    return {
      provider: "tencent_im" as const,
      mode: "c2c" as const,
      peer_im_identifier: toIdentifier,
      im_msg_key: response.MsgKey ?? null,
      im_msg_time: response.MsgTime ?? null,
    };
  } finally {
    if (permit) await discardTencentImSendPermit(permit);
  }
}

export async function ensureTencentImFriendship(input: {
  fromUserId: string;
  toUserId: string;
  fromNickname?: string | null;
  fromAvatarUrl?: string | null;
  toNickname?: string | null;
  toAvatarUrl?: string | null;
  addWording?: string | null;
}) {
  if (process.env.TENCENT_IM_SKIP_FRIENDSHIP_SYNC === "1") {
    return { status: "skipped" as const };
  }

  const fromIdentifier = buildTencentImIdentifier(input.fromUserId);
  const toIdentifier = buildTencentImIdentifier(input.toUserId);
  await ensureTencentImAccounts([
    {
      userId: input.fromUserId,
      nickname: input.fromNickname,
      avatarUrl: input.fromAvatarUrl,
    },
    {
      userId: input.toUserId,
      nickname: input.toNickname,
      avatarUrl: input.toAvatarUrl,
    },
  ]);

  const response = await callTencentImRest<TencentImFriendAddEnvelope>(
    "sns/friend_add",
    {
      From_Account: fromIdentifier,
      AddFriendItem: [
        {
          To_Account: toIdentifier,
          Remark: input.toNickname || undefined,
          AddSource: "AddSource_Type_Artsee",
          AddWording: input.addWording || "来自 Artsee 艺见心",
        },
      ],
      AddType: "Add_Type_Both",
      ForceAddFlags: 1,
    }
  );
  const item = response.ResultItem?.[0];
  const resultCode = item?.ResultCode ?? response.ErrorCode ?? 0;
  if (resultCode !== 0 && resultCode !== 30015) {
    throw new Error(
      `腾讯云 IM 添加好友失败: ${resultCode} ${item?.ResultInfo || response.ErrorInfo || ""}`.trim()
    );
  }

  return {
    status: resultCode === 30015 ? ("exists" as const) : ("synced" as const),
    code: resultCode,
  };
}

export async function createTencentImLoginConfig(input: {
  userId: string;
  nickname?: string | null;
  avatarUrl?: string | null;
}): Promise<TencentImLoginConfig> {
  const config = getTencentImConfig();
  const identifier = buildTencentImIdentifier(input.userId);
  let accountSync: TencentImLoginConfig["account_sync"] = "synced";
  if (process.env.TENCENT_IM_SKIP_ACCOUNT_IMPORT === "1") {
    accountSync = "skipped";
  } else {
    try {
      await ensureTencentImAccount({
        identifier,
        nickname: input.nickname,
        avatarUrl: input.avatarUrl,
      });
    } catch (error) {
      accountSync = "failed";
      throw error;
    }
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const expiresAt = new Date(
    (nowSeconds + config.expireSeconds) * 1000
  ).toISOString();

  return {
    sdk_app_id: config.sdkAppId,
    identifier,
    user_sig: generateTencentImUserSig({
      sdkAppId: config.sdkAppId,
      secretKey: config.secretKey,
      identifier,
      expireSeconds: config.expireSeconds,
      nowSeconds,
    }),
    expires_in: config.expireSeconds,
    expires_at: expiresAt,
    account_sync: accountSync,
  };
}
