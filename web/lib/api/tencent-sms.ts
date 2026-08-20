import { createHmac, randomInt } from "crypto";
import {
  requestTencentCloudApi,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

const DEFAULT_CODE_TTL_SECONDS = 300;
const DEFAULT_MAX_ATTEMPTS = 5;

export type SmsPurpose = "login";

export type NormalizedPhone = {
  e164: string;
  countryCode: string;
  nationalNumber: string;
};

type TencentSmsSendStatus = {
  SerialNo?: string;
  PhoneNumber?: string;
  Fee?: number;
  SessionContext?: string;
  Code?: string;
  Message?: string;
  IsoCode?: string;
};

type TencentSmsResponse = {
  Response?: {
    SendStatusSet?: TencentSmsSendStatus[];
    RequestId?: string;
    Error?: { Code?: string; Message?: string };
  };
};

export class SmsConfigError extends Error {
  constructor(public readonly missing: string[]) {
    super(`缺少短信配置: ${missing.join(", ")}`);
    this.name = "SmsConfigError";
  }
}

export class SmsInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SmsInputError";
  }
}

export class SmsDeliveryError extends Error {
  constructor(
    message: string,
    public readonly providerCode?: string,
    public readonly requestId?: string
  ) {
    super(message);
    this.name = "SmsDeliveryError";
  }
}

export class SmsRateLimitError extends Error {
  constructor(
    message: string,
    public readonly retryAfterSeconds: number,
    public readonly limitType: string
  ) {
    super(message);
    this.name = "SmsRateLimitError";
  }
}

function positiveInteger(
  value: string | undefined,
  fallback: number,
  maximum: number
) {
  const parsed = Number.parseInt(value ?? "", 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, maximum);
}

function enabled(value: string | undefined) {
  return ["1", "true", "yes", "on"].includes(value?.trim().toLowerCase() ?? "");
}

function requireSmsSecrets() {
  const values = {
    secretId: process.env.TENCENT_CLOUD_SECRET_ID?.trim(),
    secretKey: process.env.TENCENT_CLOUD_SECRET_KEY?.trim(),
    sdkAppId: process.env.TENCENT_SMS_SDK_APP_ID?.trim(),
    signName: process.env.TENCENT_SMS_SIGN_NAME?.trim(),
    templateId: process.env.TENCENT_SMS_TEMPLATE_ID?.trim(),
    otpPepper: process.env.SMS_OTP_PEPPER?.trim(),
  };
  const missing = [
    !values.secretId ? "TENCENT_CLOUD_SECRET_ID" : null,
    !values.secretKey ? "TENCENT_CLOUD_SECRET_KEY" : null,
    !values.sdkAppId ? "TENCENT_SMS_SDK_APP_ID" : null,
    !values.signName ? "TENCENT_SMS_SIGN_NAME" : null,
    !values.templateId ? "TENCENT_SMS_TEMPLATE_ID" : null,
    !values.otpPepper ? "SMS_OTP_PEPPER" : null,
    values.sdkAppId && !/^\d+$/.test(values.sdkAppId)
      ? "TENCENT_SMS_SDK_APP_ID (must be numeric)"
      : null,
    values.templateId && !/^\d+$/.test(values.templateId)
      ? "TENCENT_SMS_TEMPLATE_ID (must be numeric)"
      : null,
    values.otpPepper && Buffer.byteLength(values.otpPepper, "utf8") < 32
      ? "SMS_OTP_PEPPER (minimum 32 bytes)"
      : null,
  ].filter(Boolean) as string[];
  if (missing.length > 0) throw new SmsConfigError(missing);
  return {
    secretId: values.secretId!,
    secretKey: values.secretKey!,
    sdkAppId: values.sdkAppId!,
    signName: values.signName!,
    templateId: values.templateId!,
    otpPepper: values.otpPepper!,
  };
}

export function assertSmsConfigured() {
  requireSmsSecrets();
}

export function getSmsCodeTtlSeconds() {
  return positiveInteger(
    process.env.TENCENT_SMS_CODE_TTL_SECONDS,
    DEFAULT_CODE_TTL_SECONDS,
    600
  );
}

export function getSmsMaxAttempts() {
  return positiveInteger(
    process.env.SMS_OTP_MAX_ATTEMPTS,
    DEFAULT_MAX_ATTEMPTS,
    10
  );
}

export function getSmsRateLimits() {
  return {
    phoneCooldownSeconds: positiveInteger(
      process.env.SMS_PHONE_COOLDOWN_SECONDS,
      60,
      600
    ),
    phoneHourlyLimit: positiveInteger(
      process.env.SMS_PHONE_HOURLY_LIMIT,
      5,
      20
    ),
    phoneDailyLimit: positiveInteger(
      process.env.SMS_PHONE_DAILY_LIMIT,
      10,
      50
    ),
    ipHourlyLimit: positiveInteger(process.env.SMS_IP_HOURLY_LIMIT, 20, 200),
    ipDailyLimit: positiveInteger(process.env.SMS_IP_DAILY_LIMIT, 100, 1000),
    globalHourlyLimit: positiveInteger(
      process.env.SMS_GLOBAL_HOURLY_LIMIT,
      100,
      10_000
    ),
    globalDailyLimit: positiveInteger(
      process.env.SMS_GLOBAL_DAILY_LIMIT,
      500,
      100_000
    ),
  };
}

export function normalizeSmsPurpose(value: unknown): SmsPurpose {
  const purpose = typeof value === "string" ? value.trim().toLowerCase() : "login";
  if (!purpose || purpose === "login") return "login";
  throw new SmsInputError("不支持的验证码用途");
}

export function normalizePhoneNumber(
  value: unknown,
  countryCodeValue: unknown = "+86"
): NormalizedPhone {
  if (typeof value !== "string" || !value.trim()) {
    throw new SmsInputError("手机号不能为空");
  }

  const phoneInput = value.trim();
  if (!/^[+0-9\s()-]+$/.test(phoneInput)) {
    throw new SmsInputError("手机号格式不正确");
  }
  const rawPhone = phoneInput.replace(/[\s()-]/g, "");
  if (!/^(?:\+\d+|00\d+|\d+)$/.test(rawPhone)) {
    throw new SmsInputError("手机号格式不正确");
  }
  const rawCountry =
    typeof countryCodeValue === "string" && countryCodeValue.trim()
      ? countryCodeValue.trim()
      : "+86";
  if (!/^\+?[1-9]\d{0,2}$/.test(rawCountry)) {
    throw new SmsInputError("国家或地区码格式不正确");
  }
  const countryDigits = rawCountry.replace(/^\+/, "");
  const requestedCountryCode = `+${countryDigits}`;

  let e164: string;
  if (rawPhone.startsWith("+")) {
    e164 = rawPhone;
  } else if (rawPhone.startsWith("00")) {
    e164 = `+${rawPhone.slice(2)}`;
  } else {
    e164 = `${requestedCountryCode}${rawPhone}`;
  }

  if (!/^\+[1-9]\d{7,14}$/.test(e164)) {
    throw new SmsInputError("手机号格式不正确");
  }

  const suppliedWithCountryCode = rawPhone.startsWith("+") || rawPhone.startsWith("00");
  if (suppliedWithCountryCode && !e164.startsWith(requestedCountryCode)) {
    throw new SmsInputError("手机号与国家或地区码不一致");
  }

  const isMainlandChina = e164.startsWith("+86");
  if (isMainlandChina && !/^\+861[3-9]\d{9}$/.test(e164)) {
    throw new SmsInputError("中国大陆手机号格式不正确");
  }
  if (!isMainlandChina && !enabled(process.env.TENCENT_SMS_ALLOW_INTERNATIONAL)) {
    throw new SmsInputError("当前仅支持中国大陆手机号");
  }

  const countryCode = isMainlandChina ? "+86" : requestedCountryCode;
  const nationalNumber = e164.startsWith(countryCode)
    ? e164.slice(countryCode.length)
    : e164.slice(1);
  return { e164, countryCode, nationalNumber };
}

export function normalizeSmsCode(value: unknown) {
  const code = typeof value === "string" ? value.trim() : String(value ?? "").trim();
  if (!/^\d{6}$/.test(code)) throw new SmsInputError("验证码必须为6位数字");
  return code;
}

export function generateSmsCode() {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export function hashSmsCode(phone: string, purpose: SmsPurpose, code: string) {
  const { otpPepper } = requireSmsSecrets();
  return createHmac("sha256", otpPepper)
    .update(`v1\n${phone}\n${purpose}\n${code}`, "utf8")
    .digest("hex");
}

export function hashSmsRequestIp(ip: string) {
  const { otpPepper } = requireSmsSecrets();
  return createHmac("sha256", otpPepper)
    .update(`sms-ip-v1\n${ip || "unknown"}`, "utf8")
    .digest("hex");
}

export function getRequestIp(request: Request) {
  return (
    request.headers.get("x-real-ip")?.trim() ||
    request.headers.get("cf-connecting-ip")?.trim() ||
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown"
  );
}

function templateParameters(code: string, ttlSeconds: number) {
  const order = (process.env.TENCENT_SMS_TEMPLATE_PARAM_ORDER || "code")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  if (order.length === 0 || order.some((value) => !["code", "ttl_minutes"].includes(value))) {
    throw new SmsConfigError(["TENCENT_SMS_TEMPLATE_PARAM_ORDER"]);
  }
  const ttlMinutes = String(Math.max(1, Math.ceil(ttlSeconds / 60)));
  return order.map((value) => (value === "code" ? code : ttlMinutes));
}

export async function sendTencentVerificationSms(input: {
  phone: string;
  code: string;
  ttlSeconds: number;
  sessionContext: string;
}) {
  const config = requireSmsSecrets();
  let response: TencentSmsResponse;
  try {
    response = await requestTencentCloudApi<TencentSmsResponse>({
      service: "sms",
      endpoint: "sms.tencentcloudapi.com",
      action: "SendSms",
      version: "2021-01-11",
      region:
        process.env.TENCENT_SMS_REGION?.trim() ||
        process.env.TENCENT_CLOUD_REGION?.trim() ||
        "ap-guangzhou",
      payload: {
        PhoneNumberSet: [input.phone],
        SmsSdkAppId: config.sdkAppId,
        SignName: config.signName,
        TemplateId: config.templateId,
        TemplateParamSet: templateParameters(input.code, input.ttlSeconds),
        SessionContext: input.sessionContext.slice(0, 511),
      },
    });
  } catch (error) {
    if (error instanceof TencentCloudConfigError) {
      throw new SmsConfigError(error.missing);
    }
    throw error;
  }

  const cloudResponse = response.Response;
  if (cloudResponse?.Error) {
    throw new SmsDeliveryError(
      "腾讯云短信接口拒绝了请求",
      cloudResponse.Error.Code,
      cloudResponse.RequestId
    );
  }
  const status = cloudResponse?.SendStatusSet?.[0];
  if (!status || status.Code !== "Ok") {
    throw new SmsDeliveryError(
      "腾讯云短信发送失败",
      status?.Code || "MissingSendStatus",
      cloudResponse?.RequestId
    );
  }

  return {
    requestId: cloudResponse?.RequestId || "",
    serialNo: status.SerialNo || "",
  };
}

export function mapSmsRateLimitError(message: string) {
  if (message.includes("SMS_RATE_PHONE_COOLDOWN")) {
    return new SmsRateLimitError(
      "验证码发送过于频繁，请稍后再试",
      60,
      "phone_cooldown"
    );
  }
  if (message.includes("SMS_RATE_PHONE_HOURLY")) {
    return new SmsRateLimitError(
      "该手机号本小时发送次数已达上限",
      3600,
      "phone_hourly"
    );
  }
  if (message.includes("SMS_RATE_PHONE_DAILY")) {
    return new SmsRateLimitError(
      "该手机号今日发送次数已达上限",
      86400,
      "phone_daily"
    );
  }
  if (message.includes("SMS_RATE_IP_HOURLY")) {
    return new SmsRateLimitError(
      "当前网络请求次数过多，请稍后再试",
      3600,
      "ip_hourly"
    );
  }
  if (message.includes("SMS_RATE_IP_DAILY")) {
    return new SmsRateLimitError(
      "当前网络今日请求次数已达上限",
      86400,
      "ip_daily"
    );
  }
  if (message.includes("SMS_RATE_GLOBAL_HOURLY")) {
    return new SmsRateLimitError(
      "短信服务本小时发送量已达安全上限",
      3600,
      "global_hourly"
    );
  }
  if (message.includes("SMS_RATE_GLOBAL_DAILY")) {
    return new SmsRateLimitError(
      "短信服务今日发送量已达安全上限",
      86400,
      "global_daily"
    );
  }
  return null;
}
