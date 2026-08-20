import { createCipheriv, randomBytes } from "crypto";

import {
  getTencentCloudCredentials,
  requestTencentCloudApi,
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

type TencentCaptchaEnvelope = {
  Response?: {
    CaptchaCode?: number;
    CaptchaMsg?: string;
    EvilLevel?: number;
    EvilBitmap?: number;
    RequestId?: string;
    Error?: { Code?: string; Message?: string };
  };
};

export type TencentCaptchaProof = {
  ticket: string;
  randstr: string;
};

export class TencentCaptchaConfigError extends Error {
  constructor(public readonly missing: string[]) {
    super(`缺少或无效的腾讯验证码配置: ${missing.join(", ")}`);
    this.name = "TencentCaptchaConfigError";
  }
}

export class TencentCaptchaRequiredError extends Error {
  constructor() {
    super("请先完成安全验证");
    this.name = "TencentCaptchaRequiredError";
  }
}

export class TencentCaptchaRejectedError extends Error {
  constructor(public readonly providerCode: number | null = null) {
    super("安全验证无效或已过期，请重试");
    this.name = "TencentCaptchaRejectedError";
  }
}

export class TencentCaptchaUnavailableError extends Error {
  constructor(public readonly providerCode?: string) {
    super("安全验证服务暂不可用");
    this.name = "TencentCaptchaUnavailableError";
  }
}

function enabled(value: string | undefined) {
  return ["1", "true", "yes", "on"].includes(
    value?.trim().toLowerCase() ?? ""
  );
}

function captchaConfig(requireSecret: boolean) {
  const appIdRaw = process.env.TENCENT_CAPTCHA_APP_ID?.trim() ?? "";
  const appSecretKey =
    process.env.TENCENT_CAPTCHA_APP_SECRET_KEY?.trim() ?? "";
  const appId = Number.parseInt(appIdRaw, 10);
  const missing = [
    !/^\d+$/.test(appIdRaw) ||
    !Number.isSafeInteger(appId) ||
    appId <= 0
      ? "TENCENT_CAPTCHA_APP_ID"
      : null,
    requireSecret && !appSecretKey
      ? "TENCENT_CAPTCHA_APP_SECRET_KEY"
      : null,
  ].filter(Boolean) as string[];
  if (missing.length > 0) throw new TencentCaptchaConfigError(missing);
  return { appId, appSecretKey };
}

export function isTencentCaptchaRequired() {
  return enabled(process.env.TENCENT_CAPTCHA_REQUIRED);
}

export function assertTencentCaptchaConfigured() {
  captchaConfig(true);
  try {
    getTencentCloudCredentials();
  } catch (error) {
    if (error instanceof TencentCloudConfigError) {
      throw new TencentCaptchaConfigError(error.missing);
    }
    throw error;
  }
}

function captchaEncryptionKey(appSecretKey: string) {
  const source = Buffer.from(appSecretKey, "utf8");
  if (source.length === 0 || source.length > 32) {
    throw new TencentCaptchaConfigError([
      "TENCENT_CAPTCHA_APP_SECRET_KEY (must be at most 32 bytes)",
    ]);
  }
  const key = Buffer.alloc(32);
  for (let index = 0; index < key.length; index += 1) {
    key[index] = source[index % source.length];
  }
  return key;
}

export function getTencentCaptchaChallengeConfig(
  nowSeconds = Math.floor(Date.now() / 1_000)
) {
  const config = captchaConfig(true);
  const iv = randomBytes(12);
  const plaintext = `${config.appId}&${nowSeconds}&300`;
  const cipher = createCipheriv(
    "aes-256-gcm",
    captchaEncryptionKey(config.appSecretKey),
    iv
  );
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return {
    appId: String(config.appId),
    aidEncrypted: Buffer.concat([iv, encrypted, tag]).toString("base64"),
    aidEncryptedType: "gcm" as const,
  };
}

export function normalizeTencentCaptchaProof(
  ticketValue: unknown,
  randstrValue: unknown
): TencentCaptchaProof {
  if (ticketValue == null && randstrValue == null) {
    throw new TencentCaptchaRequiredError();
  }
  const ticket = typeof ticketValue === "string" ? ticketValue.trim() : "";
  const randstr =
    typeof randstrValue === "string" ? randstrValue.trim() : "";
  if (
    !ticket ||
    ticket.length > 2_048 ||
    !randstr ||
    randstr.length > 256 ||
    ticket.startsWith("trerror_")
  ) {
    throw new TencentCaptchaRejectedError();
  }
  return { ticket, randstr };
}

function maxAllowedEvilLevel() {
  const parsed = Number.parseInt(
    process.env.TENCENT_CAPTCHA_MAX_EVIL_LEVEL ?? "",
    10
  );
  if (!Number.isSafeInteger(parsed) || parsed < 0 || parsed > 99) return 0;
  return parsed;
}

export async function verifyTencentCaptchaProof(input: {
  proof: TencentCaptchaProof;
  userIp: string;
}) {
  const config = captchaConfig(true);
  let envelope: TencentCaptchaEnvelope;
  try {
    envelope = await requestTencentCloudApi<TencentCaptchaEnvelope>({
      service: "captcha",
      endpoint: "captcha.tencentcloudapi.com",
      action: "DescribeCaptchaResult",
      version: "2019-07-22",
      payload: {
        CaptchaType: 9,
        Ticket: input.proof.ticket,
        UserIp: input.userIp,
        Randstr: input.proof.randstr,
        CaptchaAppId: config.appId,
        AppSecretKey: config.appSecretKey,
        NeedGetCaptchaTime: 1,
      },
    });
  } catch (error) {
    if (error instanceof TencentCloudConfigError) {
      throw new TencentCaptchaConfigError(error.missing);
    }
    if (error instanceof TencentCloudApiError) {
      throw new TencentCaptchaUnavailableError();
    }
    throw error;
  }

  const response = envelope.Response;
  if (response?.Error) {
    throw new TencentCaptchaUnavailableError(response.Error.Code);
  }
  const captchaCode = response?.CaptchaCode;
  const evilLevel = response?.EvilLevel ?? 0;
  if (captchaCode !== 1 || evilLevel > maxAllowedEvilLevel()) {
    throw new TencentCaptchaRejectedError(captchaCode ?? null);
  }
  return {
    requestId: response?.RequestId ?? "",
    evilLevel,
    evilBitmap: response?.EvilBitmap ?? 0,
  };
}
