import { NextResponse } from "next/server";
import {
  ContentSafetyInputError,
  ContentSafetyRateLimitError,
  type AuditContentResult,
} from "@/lib/api/content-safety";
import {
  TencentCloudApiError,
  TencentCloudConfigError,
} from "@/lib/api/tencent-cloud";

export function contentSafetyErrorResponse(error: unknown) {
  if (error instanceof ContentSafetyInputError) {
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 400 }
    );
  }
  if (error instanceof ContentSafetyRateLimitError) {
    return NextResponse.json(
      { success: false, error: error.message },
      {
        status: 429,
        headers: { "Retry-After": String(error.retryAfterSeconds) },
      }
    );
  }
  if (error instanceof TencentCloudConfigError) {
    return NextResponse.json(
      { success: false, error: error.message, missing: error.missing },
      { status: 503 }
    );
  }
  if (error instanceof TencentCloudApiError) {
    return NextResponse.json(
      { success: false, error: "内容安全服务暂时不可用，请稍后重试" },
      { status: 502 }
    );
  }
  return null;
}

export function rejectedAuditResponse(
  audit: AuditContentResult,
  contentName: string
) {
  if (audit.audit_status === "approved") return null;
  const error =
    audit.audit_status === "reviewing"
      ? `${contentName}需要进一步审核，请调整内容后重试`
      : `${contentName}未通过内容安全审核，请修改后重试`;
  return NextResponse.json(
    {
      success: false,
      error,
      data: { audit_status: audit.audit_status },
    },
    { status: 422 }
  );
}
