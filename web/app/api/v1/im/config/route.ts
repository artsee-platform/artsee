import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { errorResponse } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  consumeTencentImLoginConfigQuota,
  createTencentImLoginConfig,
  TencentImConfigError,
  TencentImRateLimitError,
} from "@/lib/api/tencent-im";

export async function GET(req: NextRequest) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  try {
    consumeTencentImLoginConfigQuota(user.id);
    const supabase = createServiceClient();
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("nickname,avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    const config = await createTencentImLoginConfig({
      userId: user.id,
      nickname:
        typeof profile?.nickname === "string" ? profile.nickname : undefined,
      avatarUrl:
        typeof profile?.avatar_url === "string"
          ? profile.avatar_url
          : undefined,
    });

    return NextResponse.json(
      { success: true, data: config },
      { headers: { "Cache-Control": "private, no-store" } }
    );
  } catch (error) {
    if (error instanceof TencentImRateLimitError) {
      return NextResponse.json(
        { success: false, error: error.message },
        {
          status: 429,
          headers: { "Retry-After": String(error.retryAfterSeconds) },
        }
      );
    }
    if (error instanceof TencentImConfigError) {
      return NextResponse.json(
        { success: false, error: error.message, missing: error.missing },
        { status: 503 }
      );
    }
    return errorResponse(error);
  }
}
