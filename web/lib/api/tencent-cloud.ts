import { createHash, createHmac } from "crypto";

export class TencentCloudConfigError extends Error {
  constructor(public readonly missing: string[]) {
    super(`缺少腾讯云配置: ${missing.join(", ")}`);
    this.name = "TencentCloudConfigError";
  }
}

export class TencentCloudApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number
  ) {
    super(message);
    this.name = "TencentCloudApiError";
  }
}

export type TencentCloudCredentials = {
  secretId: string;
  secretKey: string;
  token?: string;
};

export type TencentCloudRequestOptions = {
  service: string;
  endpoint: string;
  action: string;
  version: string;
  region?: string;
  payload: Record<string, unknown>;
};

export function getTencentCloudCredentials(): TencentCloudCredentials {
  const secretId = process.env.TENCENT_CLOUD_SECRET_ID?.trim();
  const secretKey = process.env.TENCENT_CLOUD_SECRET_KEY?.trim();
  const missing = [
    !secretId ? "TENCENT_CLOUD_SECRET_ID" : null,
    !secretKey ? "TENCENT_CLOUD_SECRET_KEY" : null,
  ].filter(Boolean) as string[];

  if (missing.length > 0) throw new TencentCloudConfigError(missing);

  return {
    secretId: secretId!,
    secretKey: secretKey!,
    token: process.env.TENCENT_CLOUD_SECURITY_TOKEN?.trim() || undefined,
  };
}

function sha256Hex(value: string) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function hmacSha256(key: string | Buffer, value: string) {
  return createHmac("sha256", key).update(value, "utf8").digest();
}

function hmacSha256Hex(key: string | Buffer, value: string) {
  return createHmac("sha256", key).update(value, "utf8").digest("hex");
}

function normalizeEndpoint(endpoint: string) {
  return endpoint.replace(/^https?:\/\//, "").replace(/\/+$/, "");
}

function positiveInteger(value: string | undefined, fallback: number) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function shouldRetry(status: number) {
  return status === 429 || status >= 500;
}

function wait(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function requestTencentCloudApi<T>(
  options: TencentCloudRequestOptions
): Promise<T> {
  const credentials = getTencentCloudCredentials();
  const host = normalizeEndpoint(options.endpoint);
  const timestamp = Math.floor(Date.now() / 1000);
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10);
  const payload = JSON.stringify(options.payload);
  const hashedPayload = sha256Hex(payload);
  const canonicalHeaders = `content-type:application/json; charset=utf-8\nhost:${host}\n`;
  const signedHeaders = "content-type;host";
  const canonicalRequest = [
    "POST",
    "/",
    "",
    canonicalHeaders,
    signedHeaders,
    hashedPayload,
  ].join("\n");
  const credentialScope = `${date}/${options.service}/tc3_request`;
  const stringToSign = [
    "TC3-HMAC-SHA256",
    String(timestamp),
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join("\n");

  const secretDate = hmacSha256(`TC3${credentials.secretKey}`, date);
  const secretService = hmacSha256(secretDate, options.service);
  const secretSigning = hmacSha256(secretService, "tc3_request");
  const signature = hmacSha256Hex(secretSigning, stringToSign);
  const authorization = [
    `TC3-HMAC-SHA256 Credential=${credentials.secretId}/${credentialScope}`,
    `SignedHeaders=${signedHeaders}`,
    `Signature=${signature}`,
  ].join(", ");

  const headers: Record<string, string> = {
    Authorization: authorization,
    "Content-Type": "application/json; charset=utf-8",
    "X-TC-Action": options.action,
    "X-TC-Timestamp": String(timestamp),
    "X-TC-Version": options.version,
  };
  if (options.region) headers["X-TC-Region"] = options.region;
  if (credentials.token) headers["X-TC-Token"] = credentials.token;

  const timeoutMs = Math.min(
    positiveInteger(process.env.TENCENT_CLOUD_TIMEOUT_MS, 10_000),
    30_000
  );
  const maxAttempts = Math.min(
    positiveInteger(process.env.TENCENT_CLOUD_MAX_ATTEMPTS, 2),
    3
  );

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`https://${host}`, {
        method: "POST",
        headers,
        body: payload,
        signal: controller.signal,
      });
      const json = (await response.json().catch(() => null)) as T | null;

      if (!response.ok) {
        if (attempt < maxAttempts && shouldRetry(response.status)) {
          await wait(150 * attempt);
          continue;
        }
        throw new TencentCloudApiError(
          `腾讯云接口请求失败: ${response.status} ${response.statusText}`,
          response.status
        );
      }
      if (json == null) {
        throw new TencentCloudApiError("腾讯云接口返回了无效 JSON");
      }

      return json;
    } catch (error) {
      if (error instanceof TencentCloudApiError) throw error;
      if (attempt < maxAttempts) {
        await wait(150 * attempt);
        continue;
      }
      const timedOut = controller.signal.aborted;
      throw new TencentCloudApiError(
        timedOut ? "腾讯云接口请求超时" : "腾讯云接口网络异常"
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  throw new TencentCloudApiError("腾讯云接口请求失败");
}
