import { createHash, createHmac } from "crypto";
import { hasSupportedFileSignature } from "@/lib/api/file-validation";
import {
  getTencentCloudCredentials,
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

export type TencentCosAccessLevel = "public" | "private";

export type TencentCosSignInput = {
  userId: string;
  uploadId: string;
  fileName: string;
  contentType: string;
  fileSize: number;
  scene?: string;
  accessLevel: TencentCosAccessLevel;
  expiresIn?: number;
};

export type TencentCosSignedUpload = {
  provider: "tencent_cos";
  method: "PUT";
  upload_id: string;
  upload_url: string;
  file_url: string;
  public_url: string | null;
  headers: Record<string, string>;
  bucket: string;
  region: string;
  key: string;
  access_level: TencentCosAccessLevel;
  expires_in: number;
};

export type TencentCosObjectMetadata = {
  size: number;
  contentType: string;
  etag: string | null;
  crc64: string | null;
  uploadId: string | null;
  encrypted: boolean;
};

export class TencentCosValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TencentCosValidationError";
  }
}

const DEFAULT_UPLOAD_EXPIRES_IN = 10 * 60;
const DEFAULT_DOWNLOAD_EXPIRES_IN = 10 * 60;
const MAX_UPLOAD_EXPIRES_IN = 15 * 60;
const MAX_DOWNLOAD_EXPIRES_IN = 10 * 60;
const INSPECTION_BYTES = 1024;

function getCosConfig() {
  const bucket = process.env.TENCENT_COS_BUCKET?.trim();
  const region =
    process.env.TENCENT_COS_REGION?.trim() ||
    process.env.TENCENT_CLOUD_REGION?.trim();
  const missing = [
    !bucket ? "TENCENT_COS_BUCKET" : null,
    !region ? "TENCENT_COS_REGION" : null,
  ].filter(Boolean) as string[];

  if (missing.length > 0) throw new TencentCloudConfigError(missing);

  return {
    bucket: bucket!,
    region: region!,
    publicBaseUrl: process.env.TENCENT_COS_PUBLIC_BASE_URL?.trim() || "",
  };
}

function sha1Hex(value: string) {
  return createHash("sha1").update(value, "utf8").digest("hex");
}

function hmacSha1Hex(key: string | Buffer, value: string) {
  return createHmac("sha1", key).update(value, "utf8").digest("hex");
}

function encodeRfc3986(value: string) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (char) =>
    `%${char.charCodeAt(0).toString(16).toUpperCase()}`
  );
}

function encodePath(key: string) {
  return `/${key.split("/").map(encodeRfc3986).join("/")}`;
}

function cleanPathPart(value: string, fallback: string) {
  const safe = value.replace(/[^a-zA-Z0-9._-]/g, "_").replace(/^_+|_+$/g, "");
  return safe || fallback;
}

function cleanScene(value: string | undefined) {
  return (value || "uploads")
    .split("/")
    .map((part) => cleanPathPart(part, "uploads"))
    .filter(Boolean)
    .join("/");
}

function clampSeconds(value: number | undefined, fallback: number, maximum: number) {
  const parsed = Number.isFinite(value) ? Math.trunc(value!) : fallback;
  return Math.max(60, Math.min(parsed, maximum));
}

function normalizedEntries(values: Record<string, string>) {
  return Object.entries(values)
    .map(([name, value]) => [name.toLowerCase(), value.trim()] as const)
    .sort(([left], [right]) => left.localeCompare(right));
}

function createCosAuthorization(input: {
  method: string;
  key: string;
  headers: Record<string, string>;
  query?: Record<string, string>;
  expiresIn: number;
}) {
  const credentials = getTencentCloudCredentials();
  const now = Math.floor(Date.now() / 1000);
  const keyTime = `${now};${now + input.expiresIn}`;
  const headerEntries = normalizedEntries(input.headers);
  const queryEntries = normalizedEntries(input.query ?? {});
  const headerList = headerEntries.map(([name]) => name).join(";");
  const queryList = queryEntries.map(([name]) => name).join(";");
  const formattedHeaders = headerEntries
    .map(([name, value]) => `${encodeRfc3986(name)}=${encodeRfc3986(value)}`)
    .join("&");
  const formattedQuery = queryEntries
    .map(([name, value]) => `${encodeRfc3986(name)}=${encodeRfc3986(value)}`)
    .join("&");
  const httpString = [
    input.method.toLowerCase(),
    encodePath(input.key),
    formattedQuery,
    formattedHeaders,
    "",
  ].join("\n");
  const stringToSign = ["sha1", keyTime, sha1Hex(httpString), ""].join("\n");
  const signingKey = hmacSha1Hex(credentials.secretKey, keyTime);
  const signature = hmacSha1Hex(signingKey, stringToSign);

  return [
    "q-sign-algorithm=sha1",
    `q-ak=${credentials.secretId}`,
    `q-sign-time=${keyTime}`,
    `q-key-time=${keyTime}`,
    `q-header-list=${headerList}`,
    `q-url-param-list=${queryList}`,
    `q-signature=${signature}`,
  ].join("&");
}

function authorizationAsQuery(authorization: string) {
  return authorization
    .split("&")
    .map((part) => {
      const separator = part.indexOf("=");
      if (separator < 0) return encodeRfc3986(part);
      return `${encodeRfc3986(part.slice(0, separator))}=${encodeRfc3986(
        part.slice(separator + 1)
      )}`;
    })
    .join("&");
}

export function buildTencentCosObjectKey(input: TencentCosSignInput) {
  const scene = cleanScene(input.scene);
  const fileName = cleanPathPart(input.fileName, "file");
  const uploadId = cleanPathPart(input.uploadId, "upload");
  return `uploads/${input.userId}/${scene}/${Date.now()}_${uploadId}_${fileName}`;
}

export function getTencentCosObjectUrl(key: string) {
  const config = getCosConfig();
  const host = `${config.bucket}.cos.${config.region}.myqcloud.com`;
  return `https://${host}${encodePath(key)}`;
}

export function createTencentCosPutSignature(
  input: TencentCosSignInput
): TencentCosSignedUpload {
  const credentials = getTencentCloudCredentials();
  const config = getCosConfig();
  const expiresIn = clampSeconds(
    input.expiresIn,
    DEFAULT_UPLOAD_EXPIRES_IN,
    MAX_UPLOAD_EXPIRES_IN
  );
  const key = buildTencentCosObjectKey(input);
  const host = `${config.bucket}.cos.${config.region}.myqcloud.com`;
  const uploadUrl = `https://${host}${encodePath(key)}`;
  const signedHeaders: Record<string, string> = {
    "content-length": String(input.fileSize),
    "content-type": input.contentType,
    host,
    "x-cos-meta-upload-id": input.uploadId,
    "x-cos-meta-expected-size": String(input.fileSize),
    "x-cos-server-side-encryption": "AES256",
  };
  signedHeaders["x-cos-acl"] =
    input.accessLevel === "public" ? "public-read" : "private";
  if (credentials.token) signedHeaders["x-cos-security-token"] = credentials.token;

  const authorization = createCosAuthorization({
    method: "PUT",
    key,
    headers: signedHeaders,
    expiresIn,
  });
  const headers: Record<string, string> = {
    Authorization: authorization,
    "Content-Type": input.contentType,
    "x-cos-meta-upload-id": input.uploadId,
    "x-cos-meta-expected-size": String(input.fileSize),
    "x-cos-server-side-encryption": "AES256",
  };
  headers["x-cos-acl"] =
    input.accessLevel === "public" ? "public-read" : "private";
  if (credentials.token) headers["x-cos-security-token"] = credentials.token;

  return {
    provider: "tencent_cos",
    method: "PUT",
    upload_id: input.uploadId,
    upload_url: uploadUrl,
    file_url: uploadUrl,
    public_url: input.accessLevel === "public" ? uploadUrl : null,
    headers,
    bucket: config.bucket,
    region: config.region,
    key,
    access_level: input.accessLevel,
    expires_in: expiresIn,
  };
}

export function createTencentCosGetUrl(key: string, expiresIn?: number) {
  const credentials = getTencentCloudCredentials();
  const config = getCosConfig();
  const host = `${config.bucket}.cos.${config.region}.myqcloud.com`;
  const query: Record<string, string> = {};
  if (credentials.token) query["x-cos-security-token"] = credentials.token;
  const authorization = createCosAuthorization({
    method: "GET",
    key,
    headers: { host },
    query,
    expiresIn: clampSeconds(
      expiresIn,
      DEFAULT_DOWNLOAD_EXPIRES_IN,
      MAX_DOWNLOAD_EXPIRES_IN
    ),
  });
  const tokenQuery = credentials.token
    ? `&x-cos-security-token=${encodeRfc3986(credentials.token)}`
    : "";
  return `${getTencentCosObjectUrl(key)}?${authorizationAsQuery(
    authorization
  )}${tokenQuery}`;
}

async function requestCosObject(
  method: "HEAD" | "GET" | "DELETE",
  key: string,
  extraHeaders: Record<string, string> = {},
  options: { allowNotFound?: boolean } = {}
) {
  const credentials = getTencentCloudCredentials();
  const config = getCosConfig();
  const host = `${config.bucket}.cos.${config.region}.myqcloud.com`;
  const signedHeaders: Record<string, string> = { host, ...extraHeaders };
  if (credentials.token) signedHeaders["x-cos-security-token"] = credentials.token;
  const headers: Record<string, string> = {
    ...extraHeaders,
    Authorization: createCosAuthorization({
      method,
      key,
      headers: signedHeaders,
      expiresIn: 5 * 60,
    }),
  };
  if (credentials.token) headers["x-cos-security-token"] = credentials.token;

  const configuredTimeout = Number.parseInt(process.env.TENCENT_COS_TIMEOUT_MS ?? "", 10);
  const timeoutMs = Math.max(
    1_000,
    Math.min(Number.isFinite(configuredTimeout) ? configuredTimeout : 10_000, 30_000)
  );
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(getTencentCosObjectUrl(key), {
      method,
      headers,
      signal: controller.signal,
      cache: "no-store",
    });
    if (!response.ok && !(options.allowNotFound && response.status === 404)) {
      const operation = method === "DELETE" ? "删除" : "检查";
      throw new TencentCloudApiError(
        response.status === 404
          ? "COS 中未找到已上传对象"
          : `COS 对象${operation}失败: ${response.status}`,
        response.status
      );
    }
    return response;
  } catch (error) {
    if (error instanceof TencentCloudApiError) throw error;
    const operation = method === "DELETE" ? "删除" : "检查";
    throw new TencentCloudApiError(
      controller.signal.aborted
        ? `COS 对象${operation}超时`
        : `COS 对象${operation}网络异常`
    );
  } finally {
    clearTimeout(timeout);
  }
}

export async function deleteTencentCosObject(input: {
  key: string;
  expectedBucket?: string | null;
}) {
  const normalizedKey = tencentCosKeyFromUrlOrKey(input.key);
  if (!normalizedKey || normalizedKey !== input.key) {
    throw new TencentCosValidationError("COS 对象路径无效");
  }

  const config = getCosConfig();
  const expectedBucket = input.expectedBucket?.trim();
  if (expectedBucket && expectedBucket !== config.bucket) {
    throw new TencentCosValidationError("COS 上传记录与当前存储桶不一致");
  }

  const response = await requestCosObject("DELETE", normalizedKey, {}, {
    allowNotFound: true,
  });
  return { alreadyMissing: response.status === 404 };
}

export async function inspectTencentCosObject(input: {
  key: string;
  uploadId: string;
  expectedSize: number;
  expectedContentType: string;
}) {
  const head = await requestCosObject("HEAD", input.key);
  const size = Number.parseInt(head.headers.get("content-length") ?? "", 10);
  const contentType = (head.headers.get("content-type") ?? "")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
  const uploadId = head.headers.get("x-cos-meta-upload-id");
  const encrypted = head.headers.get("x-cos-server-side-encryption") === "AES256";

  if (!Number.isFinite(size) || size !== input.expectedSize) {
    throw new TencentCosValidationError("COS 对象大小与上传会话不一致");
  }
  if (contentType !== input.expectedContentType.toLowerCase()) {
    throw new TencentCosValidationError("COS 对象类型与上传会话不一致");
  }
  if (uploadId !== input.uploadId) {
    throw new TencentCosValidationError("COS 对象不属于当前上传会话");
  }
  if (!encrypted) {
    throw new TencentCosValidationError("COS 对象未启用服务端加密");
  }

  const inspection = await requestCosObject("GET", input.key, {
    range: `bytes=0-${INSPECTION_BYTES - 1}`,
  });
  if (inspection.status !== 206 && size > INSPECTION_BYTES) {
    throw new TencentCosValidationError("COS 未按范围返回文件头，无法安全确认类型");
  }
  const bytes = new Uint8Array(await inspection.arrayBuffer());
  if (!hasSupportedFileSignature(bytes, contentType)) {
    throw new TencentCosValidationError("文件实际内容与声明类型不一致");
  }

  return {
    size,
    contentType,
    etag: head.headers.get("etag"),
    crc64: head.headers.get("x-cos-hash-crc64ecma"),
    uploadId,
    encrypted,
  } satisfies TencentCosObjectMetadata;
}

export function tencentCosKeyFromUrlOrKey(value: string) {
  const raw = value.trim();
  if (!raw) return null;
  let candidate = raw;

  try {
    const url = new URL(raw);
    const configuredPublicHost = (() => {
      const value = process.env.TENCENT_COS_PUBLIC_BASE_URL?.trim();
      if (!value) return null;
      try {
        return new URL(value).hostname.toLowerCase();
      } catch {
        return null;
      }
    })();
    const looksLikeCosHost = url.hostname.toLowerCase().includes(".cos.");
    if (
      !looksLikeCosHost &&
      (!configuredPublicHost || url.hostname.toLowerCase() !== configuredPublicHost)
    ) {
      return null;
    }
    const config = getCosConfig();
    const allowedHosts = new Set([
      `${config.bucket}.cos.${config.region}.myqcloud.com`.toLowerCase(),
    ]);
    if (config.publicBaseUrl) {
      try {
        allowedHosts.add(new URL(config.publicBaseUrl).hostname.toLowerCase());
      } catch {
        // Invalid optional custom domain is not trusted.
      }
    }
    if (url.protocol !== "https:" || !allowedHosts.has(url.hostname.toLowerCase())) {
      return null;
    }
    candidate = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
  } catch {
    // Treat non-URL input as an object key.
  }

  const key = candidate.split("/").filter(Boolean).join("/");
  if (!key.startsWith("uploads/") || key.includes("..")) return null;
  return key;
}

export function isOwnedTencentCosKey(key: string, userId: string) {
  return key.startsWith(`uploads/${userId}/`);
}
