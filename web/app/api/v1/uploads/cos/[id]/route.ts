import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/api/authz";
import { deleteTencentCosUpload } from "@/lib/api/cos-upload-deletion";
import {
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";
import { TencentCosValidationError } from "@/lib/api/tencent-cos";
import { errorResponse, invalidIdResponse } from "@/lib/api/route-helpers";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const { id } = await params;
    if (!UUID_RE.test(id)) return invalidIdResponse();

    const result = await deleteTencentCosUpload({
      uploadId: id,
      userId: auth.user.id,
    });
    if (result.status === "not_found") {
      return NextResponse.json(
        { success: false, error: "上传记录不存在或无权删除" },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      data: {
        upload_id: result.uploadId,
        deleted: true,
        object_was_missing: result.objectWasMissing,
      },
    });
  } catch (error) {
    if (error instanceof TencentCloudConfigError) {
      return NextResponse.json(
        { success: false, error: error.message, missing: error.missing },
        { status: 503 }
      );
    }
    if (error instanceof TencentCosValidationError) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 409 }
      );
    }
    if (error instanceof TencentCloudApiError) {
      const status = error.message.includes("超时") ? 504 : 502;
      return NextResponse.json(
        { success: false, error: error.message },
        { status }
      );
    }
    return errorResponse(error);
  }
}
