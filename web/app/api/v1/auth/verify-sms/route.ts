import { NextRequest, NextResponse } from "next/server";
import { issuePhoneAuthSession, PhoneAuthSessionError } from "@/lib/api/phone-auth-session";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  assertSmsConfigured,
  getSmsMaxAttempts,
  hashSmsCode,
  normalizePhoneNumber,
  normalizeSmsCode,
  normalizeSmsPurpose,
  SmsConfigError,
  SmsInputError,
} from "@/lib/api/tencent-sms";

export const runtime = "nodejs";

type ConsumeResult = {
  status?: string;
  attempts?: number;
  verification_id?: number | string | null;
};

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json()) as Record<string, unknown>;
    const phone = normalizePhoneNumber(body.phone, body.country_code ?? body.countryCode);
    const purpose = normalizeSmsPurpose(body.purpose);
    const code = normalizeSmsCode(body.code);
    assertSmsConfigured();

    const service = createServiceClient();
    const { data, error } = await service.rpc("consume_sms_verification", {
      p_phone: phone.e164,
      p_purpose: purpose,
      p_code_hash: hashSmsCode(phone.e164, purpose, code),
      p_max_attempts: getSmsMaxAttempts(),
    });
    if (error) {
      if (/consume_sms_verification|schema cache/i.test(error.message || "")) {
        throw new SmsConfigError(["supabase/migrations/*_harden_sms_auth.sql"]);
      }
      throw new Error("验证码消费失败");
    }

    const result = (Array.isArray(data) ? data[0] : data) as ConsumeResult | null;
    if (result?.status !== "verified") {
      const locked = result?.status === "locked";
      const expired = result?.status === "expired" || result?.status === "not_found";
      return NextResponse.json(
        {
          success: false,
          error: locked
            ? "验证码错误次数过多，请重新获取"
            : expired
              ? "验证码无效或已过期"
              : "验证码错误",
          attempts: result?.attempts ?? 0,
        },
        { status: locked ? 429 : 400, headers: { "Cache-Control": "no-store" } }
      );
    }

    const auth = await issuePhoneAuthSession(phone);
    return NextResponse.json(
      {
        success: true,
        isNewUser: auth.isNewUser,
        user: auth.user,
        session: auth.session,
        message: auth.isNewUser ? "注册成功" : "登录成功",
      },
      { headers: { "Cache-Control": "no-store" } }
    );
  } catch (error) {
    if (error instanceof SmsInputError) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 400, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof SmsConfigError) {
      return NextResponse.json(
        { success: false, error: "短信服务暂不可用", missing: error.missing },
        { status: 503, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof PhoneAuthSessionError) {
      console.error("Phone auth session issue failed", { message: error.message });
      return NextResponse.json(
        { success: false, error: "验证码已通过，但登录会话创建失败，请重新获取验证码" },
        { status: 500, headers: { "Cache-Control": "no-store" } }
      );
    }

    console.error("SMS verification failed", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return NextResponse.json(
      { success: false, error: "验证验证码失败" },
      { status: 500, headers: { "Cache-Control": "no-store" } }
    );
  }
}
