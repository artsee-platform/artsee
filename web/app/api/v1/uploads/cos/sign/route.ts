import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { requireUser } from "@/lib/api/authz";
import { errorResponse } from "@/lib/api/route-helpers";
import {
  createTencentCosPutSignature,
  type TencentCosAccessLevel,
} from "@/lib/api/tencent-cos";
import { TencentCloudConfigError } from "@/lib/api/tencent-cloud";
import { createServiceClient } from "@/lib/api/supabase-service";

const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const DOCUMENT_TYPES = new Set([...IMAGE_TYPES, "application/pdf"]);
const DEFAULT_MAX_SIZE = 5 * 1024 * 1024;
const DOCUMENT_MAX_SIZE = 10 * 1024 * 1024;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const DEFAULT_MAX_UPLOADS_PER_WINDOW = 30;
const uploadWindows = new Map<string, { startedAt: number; count: number }>();

type Body = {
  file_name?: unknown;
  content_type?: unknown;
  size?: unknown;
  scene?: unknown;
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function isDocumentScene(scene: string) {
  const root = scene.split("/", 1)[0];
  return root === "submission-materials" || root === "contracts";
}

function accessLevelForScene(scene: string): TencentCosAccessLevel {
  return isDocumentScene(scene) ? "private" : "public";
}

function privateCosDirectUploadEnabled() {
  return process.env.TENCENT_COS_PRIVATE_DIRECT_UPLOAD_ENABLED === "true";
}

function positiveInteger(value: string | undefined, fallback: number) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function consumeUploadQuota(userId: string) {
  const now = Date.now();
  if (uploadWindows.size > 1_000) {
    for (const [key, value] of uploadWindows) {
      if (now - value.startedAt >= RATE_LIMIT_WINDOW_MS) uploadWindows.delete(key);
    }
  }
  const limit = Math.min(
    positiveInteger(
      process.env.TENCENT_COS_MAX_UPLOADS_PER_10_MINUTES,
      DEFAULT_MAX_UPLOADS_PER_WINDOW
    ),
    300
  );
  const current = uploadWindows.get(userId);
  if (!current || now - current.startedAt >= RATE_LIMIT_WINDOW_MS) {
    uploadWindows.set(userId, { startedAt: now, count: 1 });
    return null;
  }
  if (current.count >= limit) {
    return Math.max(
      1,
      Math.ceil((RATE_LIMIT_WINDOW_MS - (now - current.startedAt)) / 1_000)
    );
  }
  current.count += 1;
  return null;
}

export async function POST(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = (await req.json().catch(() => ({}))) as Body;
    const fileName = cleanText(body.file_name);
    const contentType = cleanText(body.content_type).toLowerCase();
    const scene = cleanText(body.scene) || "uploads";
    const size = Number(body.size);
    const allowedTypes = isDocumentScene(scene) ? DOCUMENT_TYPES : IMAGE_TYPES;
    const maxSize = isDocumentScene(scene) ? DOCUMENT_MAX_SIZE : DEFAULT_MAX_SIZE;

    if (!fileName) {
      return NextResponse.json(
        { success: false, error: "缺少文件名" },
        { status: 400 }
      );
    }
    if (!allowedTypes.has(contentType)) {
      return NextResponse.json(
        { success: false, error: "不支持的文件类型" },
        { status: 400 }
      );
    }
    if (!Number.isFinite(size) || size <= 0) {
      return NextResponse.json(
        { success: false, error: "无效文件大小" },
        { status: 400 }
      );
    }
    if (size > maxSize) {
      return NextResponse.json(
        { success: false, error: `文件大小超过 ${Math.floor(maxSize / 1024 / 1024)}MB 限制` },
        { status: 400 }
      );
    }

    const accessLevel = accessLevelForScene(scene);
    if (accessLevel === "private" && !privateCosDirectUploadEnabled()) {
      return NextResponse.json(
        {
          success: false,
          error: "私有资料使用受保护存储上传",
          fallback: "supabase_private",
        },
        { status: 503 }
      );
    }

    const retryAfter = consumeUploadQuota(auth.user.id);
    if (retryAfter != null) {
      return NextResponse.json(
        { success: false, error: "上传请求过于频繁，请稍后再试" },
        { status: 429, headers: { "Retry-After": String(retryAfter) } }
      );
    }

    const uploadId = randomUUID();
    const upload = createTencentCosPutSignature({
      userId: auth.user.id,
      uploadId,
      fileName,
      contentType,
      fileSize: size,
      scene,
      accessLevel,
      expiresIn: Number(process.env.TENCENT_COS_SIGN_EXPIRES_SECONDS) || undefined,
    });

    const expiresAt = new Date(Date.now() + upload.expires_in * 1_000).toISOString();
    const supabase = createServiceClient();
    const { error } = await supabase.from("upload_files").insert({
      id: uploadId,
      user_id: auth.user.id,
      file_url: upload.file_url,
      file_type: contentType,
      scene,
      size,
      expected_size: size,
      provider: "tencent_cos",
      bucket: upload.bucket,
      object_key: upload.key,
      access_level: accessLevel,
      upload_status: "pending",
      expires_at: expiresAt,
      audit_status: contentType.startsWith("image/") ? "pending" : null,
    });
    if (error) return errorResponse(error);

    return NextResponse.json({ success: true, data: upload });
  } catch (e) {
    if (e instanceof TencentCloudConfigError) {
      return NextResponse.json(
        { success: false, error: e.message, missing: e.missing },
        { status: 503 }
      );
    }
    return errorResponse(e);
  }
}
