import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { SUBMISSION_MATERIALS_BUCKET } from "@/lib/api/submission-materials";
import { hasSupportedFileSignature } from "@/lib/api/file-validation";

const DEFAULT_MAX_SIZE = 5 * 1024 * 1024; // 5MB
const MATERIAL_MAX_SIZE = 10 * 1024 * 1024; // 10MB
const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];
const MATERIAL_TYPES = [...IMAGE_TYPES, "application/pdf"];

/**
 * POST /api/v1/upload
 * 通用文件上传（头像、社区图片等）
 * Body: multipart/form-data
 *   - file: 文件（必填，默认图片类型，≤5MB；submission-materials 支持图片/PDF，≤10MB）
 *   - folder: 存储文件夹（可选，默认 "avatars"）
 * 返回: { success: true, url: string }
 */
export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json(
        { success: false, error: "未授权" },
        { status: 401 }
      );
    }

    const form = await req.formData();
    const file = form.get("file") as File | null;
    const folder = (form.get("folder") as string) || "avatars";

    if (!file) {
      return NextResponse.json(
        { success: false, error: "缺少文件" },
        { status: 400 }
      );
    }

    const isDocumentUpload =
      folder.startsWith("submission-materials") || folder.startsWith("contracts");
    const allowedTypes = isDocumentUpload ? MATERIAL_TYPES : IMAGE_TYPES;
    const maxSize = isDocumentUpload ? MATERIAL_MAX_SIZE : DEFAULT_MAX_SIZE;
    const bucket = isDocumentUpload ? SUBMISSION_MATERIALS_BUCKET : "avatars";

    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json(
        { success: false, error: "不支持的文件类型" },
        { status: 400 }
      );
    }

    if (file.size > maxSize) {
      return NextResponse.json(
        { success: false, error: `文件大小超过 ${Math.floor(maxSize / 1024 / 1024)}MB 限制` },
        { status: 400 }
      );
    }

    const bytes = new Uint8Array(await file.arrayBuffer());
    if (!hasSupportedFileSignature(bytes.slice(0, 1024), file.type)) {
      return NextResponse.json(
        { success: false, error: "文件实际内容与声明类型不一致" },
        { status: 400 }
      );
    }
    const timestamp = Date.now();
    const safeFolder = folder
      .split("/")
      .map((part) => part.replace(/[^a-zA-Z0-9_-]/g, "_"))
      .filter(Boolean)
      .join("/");
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const path = `${user.id}/${safeFolder || "uploads"}/${timestamp}_${safeName}`;

    const supabase = createServiceClient();
    const { error } = await supabase.storage.from(bucket).upload(path, bytes, {
      contentType: file.type,
      upsert: true,
    });

    if (error) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 500 }
      );
    }

    const { data: publicUrlData } = supabase.storage
      .from(bucket)
      .getPublicUrl(path);

    await supabase.from("upload_files").insert({
      user_id: user.id,
      file_url: publicUrlData.publicUrl,
      file_type: file.type,
      scene: folder,
      size: file.size,
      expected_size: file.size,
      provider: "supabase",
      bucket,
      object_key: path,
      access_level: isDocumentUpload ? "private" : "public",
      upload_status: "completed",
      completed_at: new Date().toISOString(),
      audit_status: file.type.startsWith("image/") ? "pending" : null,
    });

    return NextResponse.json({
      success: true,
      url: publicUrlData.publicUrl,
      bucket,
      path,
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json(
      { success: false, error: msg },
      { status: 500 }
    );
  }
}
