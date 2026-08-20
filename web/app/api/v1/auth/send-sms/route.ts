import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/api/supabase-service";
import { TencentCloudApiError } from "@/lib/api/tencent-cloud";
import {
  assertTencentCaptchaConfigured,
  isTencentCaptchaRequired,
  normalizeTencentCaptchaProof,
  TencentCaptchaConfigError,
  TencentCaptchaRejectedError,
  TencentCaptchaRequiredError,
  TencentCaptchaUnavailableError,
  verifyTencentCaptchaProof,
} from "@/lib/api/tencent-captcha";
import {
  assertSmsConfigured,
  generateSmsCode,
  getRequestIp,
  getSmsCodeTtlSeconds,
  getSmsRateLimits,
  hashSmsCode,
  hashSmsRequestIp,
  mapSmsRateLimitError,
  normalizePhoneNumber,
  normalizeSmsPurpose,
  sendTencentVerificationSms,
  SmsConfigError,
  SmsDeliveryError,
  SmsInputError,
  SmsRateLimitError,
} from "@/lib/api/tencent-sms";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let verificationId: number | string | null = null;

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const phone = normalizePhoneNumber(body.phone, body.country_code ?? body.countryCode);
    const purpose = normalizeSmsPurpose(body.purpose);
    assertSmsConfigured();
    const requestIp = getRequestIp(request);
    if (isTencentCaptchaRequired()) {
      assertTencentCaptchaConfigured();
      const proof = normalizeTencentCaptchaProof(
        body.captcha_ticket ?? body.captchaTicket,
        body.captcha_randstr ?? body.captchaRandstr
      );
      await verifyTencentCaptchaProof({ proof, userIp: requestIp });
    }
    const service = createServiceClient();

    const code = generateSmsCode();
    const codeHash = hashSmsCode(phone.e164, purpose, code);
    const requestIpHash = hashSmsRequestIp(requestIp);
    const ttlSeconds = getSmsCodeTtlSeconds();
    const limits = getSmsRateLimits();
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();

    const { data: reservedId, error: reserveError } = await service.rpc(
      "reserve_sms_verification",
      {
        p_phone: phone.e164,
        p_country_code: phone.countryCode,
        p_purpose: purpose,
        p_code_hash: codeHash,
        p_expires_at: expiresAt,
        p_ip_hash: requestIpHash,
        p_phone_cooldown_seconds: limits.phoneCooldownSeconds,
        p_phone_hourly_limit: limits.phoneHourlyLimit,
        p_phone_daily_limit: limits.phoneDailyLimit,
        p_ip_hourly_limit: limits.ipHourlyLimit,
        p_ip_daily_limit: limits.ipDailyLimit,
        p_global_hourly_limit: limits.globalHourlyLimit,
        p_global_daily_limit: limits.globalDailyLimit,
      }
    );
    if (reserveError) {
      const rateError = mapSmsRateLimitError(reserveError.message || "");
      if (rateError) throw rateError;
      if (/reserve_sms_verification|schema cache/i.test(reserveError.message || "")) {
        throw new SmsConfigError(["supabase/migrations/*_harden_sms_auth.sql"]);
      }
      throw new Error("无法保存短信验证码请求");
    }
    verificationId = reservedId as number | string | null;
    if (verificationId == null) throw new Error("验证码请求未返回记录 ID");

    try {
      const delivery = await sendTencentVerificationSms({
        phone: phone.e164,
        code,
        ttlSeconds,
        sessionContext: `sms-verification:${verificationId}`,
      });
      const { error: deliveryUpdateError } = await service
        .from("sms_verifications")
        .update({
          delivery_status: "sent",
          provider_request_id: delivery.requestId || null,
          provider_serial_no: delivery.serialNo || null,
        })
        .eq("id", verificationId);
      if (deliveryUpdateError) throw new Error("无法确认短信发送状态");
    } catch (error) {
      await service
        .from("sms_verifications")
        .update({
          delivery_status: "failed",
          invalidated_at: new Date().toISOString(),
        })
        .eq("id", verificationId);
      throw error;
    }

    return NextResponse.json(
      {
        success: true,
        message: "验证码已发送",
        provider: "tencent_cloud_sms",
        expires_in: ttlSeconds,
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
    if (error instanceof SmsRateLimitError) {
      if (error.limitType.startsWith("global_")) {
        console.warn("[sms-security] application circuit breaker opened", {
          limitType: error.limitType,
        });
      }
      return NextResponse.json(
        {
          success: false,
          error: error.message,
          code: "SMS_RATE_LIMITED",
        },
        {
          status: 429,
          headers: {
            "Cache-Control": "no-store",
            "Retry-After": String(error.retryAfterSeconds),
          },
        }
      );
    }
    if (error instanceof TencentCaptchaRequiredError) {
      return NextResponse.json(
        {
          success: false,
          error: error.message,
          code: "CAPTCHA_REQUIRED",
          captcha_required: true,
        },
        { status: 428, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof TencentCaptchaRejectedError) {
      return NextResponse.json(
        {
          success: false,
          error: error.message,
          code: "CAPTCHA_INVALID",
          captcha_required: true,
        },
        { status: 400, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof TencentCaptchaConfigError) {
      return NextResponse.json(
        {
          success: false,
          error: "安全验证服务暂不可用",
          missing: error.missing,
        },
        { status: 503, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof TencentCaptchaUnavailableError) {
      console.error("Tencent Captcha verification unavailable", {
        providerCode: error.providerCode,
      });
      return NextResponse.json(
        { success: false, error: "安全验证服务暂不可用" },
        { status: 502, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof SmsConfigError) {
      return NextResponse.json(
        { success: false, error: "短信服务暂不可用", missing: error.missing },
        { status: 503, headers: { "Cache-Control": "no-store" } }
      );
    }
    if (error instanceof SmsDeliveryError || error instanceof TencentCloudApiError) {
      console.error("Tencent SMS delivery failed", {
        providerCode: error instanceof SmsDeliveryError ? error.providerCode : undefined,
        requestId: error instanceof SmsDeliveryError ? error.requestId : undefined,
      });
      return NextResponse.json(
        { success: false, error: "短信发送失败，请稍后重试" },
        { status: 502, headers: { "Cache-Control": "no-store" } }
      );
    }

    console.error("SMS verification request failed", {
      message: error instanceof Error ? error.message : "unknown",
      verificationId,
    });
    return NextResponse.json(
      { success: false, error: "发送验证码失败" },
      { status: 500, headers: { "Cache-Control": "no-store" } }
    );
  }
}
