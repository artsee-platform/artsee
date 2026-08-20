import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/api/authz";
import { errorResponse } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  inspectTencentCosObject,
  isOwnedTencentCosKey,
  TencentCosValidationError,
} from "@/lib/api/tencent-cos";
import {
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

type Body = {
  upload_id?: unknown;
  key?: unknown;
};

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

export async function POST(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = (await req.json().catch(() => ({}))) as Body;
    const uploadId = cleanText(body.upload_id);
    const key = cleanText(body.key);

    if (!uploadId || !key) {
      return NextResponse.json(
        { success: false, error: "缺少上传会话或文件路径" },
        { status: 400 }
      );
    }
    if (!isOwnedTencentCosKey(key, auth.user.id)) {
      return NextResponse.json(
        { success: false, error: "无权记录该文件" },
        { status: 403 }
      );
    }

    const supabase = createServiceClient();
    const { data: session, error: readError } = await supabase
      .from("upload_files")
      .select(
        "id,user_id,file_url,file_type,scene,size,expected_size,provider,bucket,object_key,access_level,upload_status,expires_at,completed_at,object_etag,object_crc64"
      )
      .eq("id", uploadId)
      .eq("user_id", auth.user.id)
      .eq("provider", "tencent_cos")
      .maybeSingle();
    if (readError) return errorResponse(readError);
    if (!session || session.object_key !== key) {
      return NextResponse.json(
        { success: false, error: "上传会话不存在或与文件不匹配" },
        { status: 404 }
      );
    }

    if (session.upload_status === "completed") {
      return NextResponse.json({
        success: true,
        data: {
          provider: "tencent_cos",
          upload_id: session.id,
          key: session.object_key,
          url: session.file_url,
          public_url: session.access_level === "public" ? session.file_url : null,
          access_level: session.access_level,
          completed_at: session.completed_at,
        },
      });
    }

    const expiresAt = Date.parse(String(session.expires_at ?? ""));
    if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) {
      return NextResponse.json(
        { success: false, error: "上传会话已过期，请重新选择文件上传" },
        { status: 410 }
      );
    }

    const expectedSize = Number(session.expected_size ?? session.size);
    const expectedContentType = cleanText(session.file_type).toLowerCase();
    if (!Number.isFinite(expectedSize) || expectedSize <= 0 || !expectedContentType) {
      return NextResponse.json(
        { success: false, error: "上传会话元数据不完整" },
        { status: 500 }
      );
    }

    const object = await inspectTencentCosObject({
      key,
      uploadId,
      expectedSize,
      expectedContentType,
    });
    const completedAt = new Date().toISOString();
    const { data: completed, error } = await supabase
      .from("upload_files")
      .update({
        size: object.size,
        file_type: object.contentType,
        upload_status: "completed",
        completed_at: completedAt,
        object_etag: object.etag,
        object_crc64: object.crc64,
      })
      .eq("id", uploadId)
      .eq("user_id", auth.user.id)
      .eq("upload_status", "pending")
      .select("id,file_url,object_key,access_level,completed_at")
      .single();

    if (error) {
      const { data: current, error: currentError } = await supabase
        .from("upload_files")
        .select("id,file_url,object_key,access_level,upload_status,completed_at")
        .eq("id", uploadId)
        .eq("user_id", auth.user.id)
        .maybeSingle();
      if (!currentError && current?.upload_status === "completed") {
        return NextResponse.json({
          success: true,
          data: {
            provider: "tencent_cos",
            upload_id: current.id,
            key: current.object_key,
            url: current.file_url,
            public_url:
              current.access_level === "public" ? current.file_url : null,
            access_level: current.access_level,
            completed_at: current.completed_at,
          },
        });
      }
      return errorResponse(error);
    }

    return NextResponse.json({
      success: true,
      data: {
        provider: "tencent_cos",
        upload_id: completed.id,
        key: completed.object_key,
        url: completed.file_url,
        public_url: completed.access_level === "public" ? completed.file_url : null,
        access_level: completed.access_level,
        completed_at: completed.completed_at,
      },
    });
  } catch (e) {
    if (e instanceof TencentCloudConfigError) {
      return NextResponse.json(
        { success: false, error: e.message, missing: e.missing },
        { status: 503 }
      );
    }
    if (e instanceof TencentCosValidationError) {
      return NextResponse.json(
        { success: false, error: e.message },
        { status: 422 }
      );
    }
    if (e instanceof TencentCloudApiError) {
      const status = e.status === 404 ? 422 : e.message.includes("超时") ? 504 : 502;
      return NextResponse.json(
        { success: false, error: e.message },
        { status }
      );
    }
    return errorResponse(e);
  }
}
