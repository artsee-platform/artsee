import {
  requestTencentCloudApi,
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

export type AuditSuggestion = "pass" | "review" | "block";

export type AuditItemResult = {
  type: "text" | "image";
  suggestion: AuditSuggestion;
  label: string | null;
  sub_label: string | null;
  score: number | null;
  request_id: string | null;
  raw: unknown;
};

export type AuditContentInput = {
  userId: string;
  text?: string;
  imageUrls?: string[];
  scene?: string;
  dataId?: string;
};

export type AuditContentResult = {
  provider: "tencent_cloud";
  suggestion: AuditSuggestion;
  audit_status: "approved" | "reviewing" | "rejected";
  items: AuditItemResult[];
};

export class ContentSafetyInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ContentSafetyInputError";
  }
}

export class ContentSafetyRateLimitError extends Error {
  constructor(public readonly retryAfterSeconds: number) {
    super("内容审核请求过于频繁，请稍后重试");
    this.name = "ContentSafetyRateLimitError";
  }
}

type TencentModerationEnvelope = {
  Response?: {
    Error?: {
      Code?: string;
      Message?: string;
    };
    Suggestion?: string;
    Label?: string;
    SubLabel?: string;
    Score?: number;
    RequestId?: string;
    [key: string]: unknown;
  };
};

const TEXT_ENDPOINT =
  process.env.TENCENT_CONTENT_SAFETY_TEXT_ENDPOINT || "tms.tencentcloudapi.com";
const IMAGE_ENDPOINT =
  process.env.TENCENT_CONTENT_SAFETY_IMAGE_ENDPOINT || "ims.tencentcloudapi.com";
const TEXT_ACTION = process.env.TENCENT_CONTENT_SAFETY_TEXT_ACTION || "TextModeration";
const IMAGE_ACTION =
  process.env.TENCENT_CONTENT_SAFETY_IMAGE_ACTION || "ImageModeration";
const API_VERSION = process.env.TENCENT_CONTENT_SAFETY_VERSION || "2020-12-29";
export const MAX_AUDIT_TEXT_CHARACTERS = 10_000;
export const MAX_AUDIT_IMAGE_URLS = 9;
const MAX_AUDIT_DATA_ID_CHARACTERS = 64;
const DATA_ID_RE = /^[A-Za-z0-9_@#-]+$/;
const RATE_LIMIT_WINDOW_MS = 60_000;
const DEFAULT_RATE_LIMIT_UNITS = 60;
const MAX_AUDIT_VALUE_NODES = 2_000;

const auditWindows = new Map<
  string,
  { startedAt: number; consumedUnits: number }
>();

function toBase64(value: string) {
  return Buffer.from(value, "utf8").toString("base64");
}

function cleanText(value: string | undefined) {
  return value?.trim() ?? "";
}

function normalizeSuggestion(value: unknown): AuditSuggestion {
  const suggestion = String(value ?? "").toLowerCase();
  if (suggestion === "pass") return "pass";
  if (suggestion === "review") return "review";
  if (suggestion === "block") return "block";
  throw new TencentCloudApiError("腾讯云内容安全返回了未知审核建议");
}

function auditStatusForSuggestion(suggestion: AuditSuggestion) {
  if (suggestion === "block") return "rejected";
  if (suggestion === "review") return "reviewing";
  return "approved";
}

export function contentStatusForAudit(
  auditStatus: AuditContentResult["audit_status"]
) {
  if (auditStatus === "approved") return "published";
  if (auditStatus === "rejected") return "rejected";
  return "reviewing";
}

export function auditReasonFromItems(
  items: Array<{ label: string | null; sub_label: string | null }>
) {
  return items
    .map((item) => [item.label, item.sub_label].filter(Boolean).join("/"))
    .filter(Boolean)
    .join(", ");
}

export function collectAuditText(...values: unknown[]) {
  const stack = [...values];
  const strings: string[] = [];
  const seen = new Set<object>();
  let visitedNodes = 0;

  while (stack.length > 0) {
    const value = stack.pop();
    visitedNodes += 1;
    if (visitedNodes > MAX_AUDIT_VALUE_NODES) {
      throw new ContentSafetyInputError("待审核内容结构过于复杂");
    }
    if (typeof value === "string") {
      const text = value.trim();
      if (text) strings.push(text);
      continue;
    }
    if (!value || typeof value !== "object" || seen.has(value)) continue;
    seen.add(value);
    if (Array.isArray(value)) {
      stack.push(...value);
    } else {
      stack.push(...Object.values(value as Record<string, unknown>));
    }
  }

  return [...new Set(strings)].reverse().join("\n\n");
}

function unicodeLength(value: string) {
  return Array.from(value).length;
}

function positiveInteger(value: string | undefined, fallback: number) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function consumeAuditQuota(userId: string, units: number) {
  const now = Date.now();
  if (auditWindows.size > 1_000) {
    for (const [key, value] of auditWindows) {
      if (now - value.startedAt >= RATE_LIMIT_WINDOW_MS) auditWindows.delete(key);
    }
  }
  const limit = positiveInteger(
    process.env.TENCENT_CONTENT_SAFETY_MAX_UNITS_PER_MINUTE,
    DEFAULT_RATE_LIMIT_UNITS
  );
  const current = auditWindows.get(userId);
  if (!current || now - current.startedAt >= RATE_LIMIT_WINDOW_MS) {
    auditWindows.set(userId, { startedAt: now, consumedUnits: units });
    return;
  }
  if (current.consumedUnits + units > limit) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((RATE_LIMIT_WINDOW_MS - (now - current.startedAt)) / 1_000)
    );
    throw new ContentSafetyRateLimitError(retryAfterSeconds);
  }
  current.consumedUnits += units;
}

function addAllowedHost(hosts: Set<string>, value: string | undefined) {
  const raw = value?.trim();
  if (!raw) return;
  try {
    const url = new URL(raw.includes("://") ? raw : `https://${raw}`);
    hosts.add(url.hostname.toLowerCase());
  } catch {
    // Invalid server configuration is ignored; a missing final allowlist fails closed below.
  }
}

function allowedImageHosts() {
  const hosts = new Set<string>();
  for (const value of (
    process.env.TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS ?? ""
  ).split(",")) {
    addAllowedHost(hosts, value);
  }
  addAllowedHost(hosts, process.env.TENCENT_COS_PUBLIC_BASE_URL);
  addAllowedHost(
    hosts,
    process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL
  );

  const bucket = process.env.TENCENT_COS_BUCKET?.trim();
  const region =
    process.env.TENCENT_COS_REGION?.trim() ||
    process.env.TENCENT_CLOUD_REGION?.trim();
  if (bucket && region) {
    hosts.add(`${bucket}.cos.${region}.myqcloud.com`.toLowerCase());
  }
  return hosts;
}

function normalizeImageUrls(values: string[]) {
  if (values.length > MAX_AUDIT_IMAGE_URLS) {
    throw new ContentSafetyInputError(
      `每次最多审核 ${MAX_AUDIT_IMAGE_URLS} 张图片`
    );
  }
  const hosts = allowedImageHosts();
  if (values.length > 0 && hosts.size === 0) {
    throw new TencentCloudConfigError([
      "TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS",
    ]);
  }

  const urls = values.map((value) => value.trim()).filter(Boolean);
  for (const value of urls) {
    let url: URL;
    try {
      url = new URL(value);
    } catch {
      throw new ContentSafetyInputError("图片链接格式不正确");
    }
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      !hosts.has(url.hostname.toLowerCase())
    ) {
      throw new ContentSafetyInputError("图片必须来自平台允许的 HTTPS 存储域名");
    }
  }
  return [...new Set(urls)];
}

function validateDataId(value: string | undefined) {
  if (!value) return;
  if (
    unicodeLength(value) > MAX_AUDIT_DATA_ID_CHARACTERS ||
    !DATA_ID_RE.test(value)
  ) {
    throw new ContentSafetyInputError("data_id 格式不正确");
  }
}

function itemDataId(base: string | undefined, fallback: string, suffix = "") {
  const source = base || fallback;
  return `${source.slice(0, MAX_AUDIT_DATA_ID_CHARACTERS - suffix.length)}${suffix}`;
}

function mergeSuggestions(items: AuditItemResult[]): AuditSuggestion {
  if (items.some((item) => item.suggestion === "block")) return "block";
  if (items.some((item) => item.suggestion === "review")) return "review";
  return "pass";
}

function parseModerationResponse(
  type: AuditItemResult["type"],
  payload: TencentModerationEnvelope
): AuditItemResult {
  if (!payload || typeof payload !== "object" || !payload.Response) {
    throw new TencentCloudApiError("腾讯云内容安全返回结构不完整");
  }
  const response = payload.Response;
  if (response.Error) {
    throw new TencentCloudApiError(
      `腾讯云内容安全失败: ${response.Error.Code ?? "Unknown"} ${response.Error.Message ?? ""}`.trim()
    );
  }
  return {
    type,
    suggestion: normalizeSuggestion(response.Suggestion),
    label: typeof response.Label === "string" ? response.Label : null,
    sub_label: typeof response.SubLabel === "string" ? response.SubLabel : null,
    score: typeof response.Score === "number" ? response.Score : null,
    request_id: typeof response.RequestId === "string" ? response.RequestId : null,
    raw: response,
  };
}

async function auditText(input: AuditContentInput) {
  const text = cleanText(input.text);
  if (!text) return null;

  const payload: Record<string, unknown> = {
    Content: toBase64(text),
    DataId: itemDataId(input.dataId, `text-${Date.now()}`),
    User: { UserId: input.userId },
  };
  const bizType = process.env.TENCENT_CONTENT_SAFETY_TEXT_BIZ_TYPE?.trim();
  if (bizType) payload.BizType = bizType;

  const response = await requestTencentCloudApi<TencentModerationEnvelope>({
    service: "tms",
    endpoint: TEXT_ENDPOINT,
    action: TEXT_ACTION,
    version: API_VERSION,
    region: process.env.TENCENT_CLOUD_REGION?.trim(),
    payload,
  });
  return parseModerationResponse("text", response);
}

async function auditImage(input: AuditContentInput, url: string, index: number) {
  const payload: Record<string, unknown> = {
    FileUrl: url,
    DataId: itemDataId(
      input.dataId,
      `image-${Date.now()}`,
      `-image-${index}`
    ),
    User: { UserId: input.userId },
  };
  const bizType = process.env.TENCENT_CONTENT_SAFETY_IMAGE_BIZ_TYPE?.trim();
  if (bizType) payload.BizType = bizType;

  const response = await requestTencentCloudApi<TencentModerationEnvelope>({
    service: "ims",
    endpoint: IMAGE_ENDPOINT,
    action: IMAGE_ACTION,
    version: API_VERSION,
    region: process.env.TENCENT_CLOUD_REGION?.trim(),
    payload,
  });
  return parseModerationResponse("image", response);
}

export async function auditContent(
  input: AuditContentInput
): Promise<AuditContentResult> {
  const text = cleanText(input.text);
  if (unicodeLength(text) > MAX_AUDIT_TEXT_CHARACTERS) {
    throw new ContentSafetyInputError(
      `待审核文本不能超过 ${MAX_AUDIT_TEXT_CHARACTERS} 个字符`
    );
  }
  validateDataId(input.dataId);
  const imageUrls = normalizeImageUrls(input.imageUrls ?? []);
  if (!text && imageUrls.length === 0) {
    throw new ContentSafetyInputError("请提供待审核文本或图片");
  }
  consumeAuditQuota(input.userId, Math.max(1, (text ? 1 : 0) + imageUrls.length));

  const normalizedInput = { ...input, text, imageUrls };
  const textResult = await auditText(normalizedInput);
  const imageResults = await Promise.all(
    imageUrls.map((url, index) => auditImage(normalizedInput, url, index))
  );
  const items = [textResult, ...imageResults].filter(Boolean) as AuditItemResult[];
  const suggestion = mergeSuggestions(items);

  return {
    provider: "tencent_cloud",
    suggestion,
    audit_status: auditStatusForSuggestion(suggestion),
    items,
  };
}
