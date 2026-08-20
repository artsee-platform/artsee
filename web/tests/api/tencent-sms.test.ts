import { afterEach, describe, expect, it, vi } from "vitest";
import {
  generateSmsCode,
  hashSmsCode,
  normalizePhoneNumber,
  normalizeSmsCode,
  sendTencentVerificationSms,
  SmsDeliveryError,
  SmsInputError,
} from "@/lib/api/tencent-sms";

function stubSmsEnv() {
  vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "secret-id");
  vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "secret-key");
  vi.stubEnv("TENCENT_CLOUD_MAX_ATTEMPTS", "1");
  vi.stubEnv("TENCENT_SMS_SDK_APP_ID", "1400006666");
  vi.stubEnv("TENCENT_SMS_SIGN_NAME", "艺见心");
  vi.stubEnv("TENCENT_SMS_TEMPLATE_ID", "1110");
  vi.stubEnv("TENCENT_SMS_TEMPLATE_PARAM_ORDER", "code,ttl_minutes");
  vi.stubEnv("SMS_OTP_PEPPER", "test-only-otp-pepper-with-enough-entropy");
}

describe("Tencent SMS helpers", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("normalizes mainland phone numbers to E.164", () => {
    expect(normalizePhoneNumber("138 0013 8000", "+86")).toEqual({
      e164: "+8613800138000",
      countryCode: "+86",
      nationalNumber: "13800138000",
    });
    expect(() => normalizePhoneNumber("12345", "+86")).toThrow(SmsInputError);
    expect(() => normalizePhoneNumber("+441234567890", "+86")).toThrow(
      "手机号与国家或地区码不一致"
    );
    expect(() => normalizePhoneNumber("138abc00138000", "+86")).toThrow(
      SmsInputError
    );
    expect(() => normalizePhoneNumber("13800138000", "abc+86")).toThrow(
      "国家或地区码格式不正确"
    );
  });

  it("generates six digit codes and hashes them without storing raw values", () => {
    stubSmsEnv();
    const code = generateSmsCode();
    expect(code).toMatch(/^\d{6}$/);
    expect(normalizeSmsCode("654321")).toBe("654321");
    expect(hashSmsCode("+8613800138000", "login", "654321")).toMatch(/^[a-f0-9]{64}$/);
    expect(hashSmsCode("+8613800138000", "login", "654321")).not.toContain("654321");
  });

  it("uses Tencent SendSms 2021 API and validates Code=Ok", async () => {
    stubSmsEnv();
    const fetchMock = vi.fn(async (_input: URL | RequestInfo, init?: RequestInit) => {
      const payload = JSON.parse(String(init?.body));
      expect(payload).toMatchObject({
        PhoneNumberSet: ["+8613800138000"],
        SmsSdkAppId: "1400006666",
        SignName: "艺见心",
        TemplateId: "1110",
        TemplateParamSet: ["654321", "5"],
        SessionContext: "sms-verification:42",
      });
      const headers = init?.headers as Record<string, string>;
      expect(headers["X-TC-Action"]).toBe("SendSms");
      expect(headers["X-TC-Version"]).toBe("2021-01-11");
      return new Response(
        JSON.stringify({
          Response: {
            SendStatusSet: [{ Code: "Ok", SerialNo: "serial-1" }],
            RequestId: "request-1",
          },
        }),
        { status: 200 }
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      sendTencentVerificationSms({
        phone: "+8613800138000",
        code: "654321",
        ttlSeconds: 300,
        sessionContext: "sms-verification:42",
      })
    ).resolves.toEqual({ requestId: "request-1", serialNo: "serial-1" });
  });

  it("fails closed when Tencent reports a business error", async () => {
    stubSmsEnv();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify({
            Response: {
              SendStatusSet: [
                { Code: "FailedOperation.TemplateIncorrectOrUnapproved", Message: "failed" },
              ],
              RequestId: "request-2",
            },
          }),
          { status: 200 }
        )
      )
    );

    await expect(
      sendTencentVerificationSms({
        phone: "+8613800138000",
        code: "654321",
        ttlSeconds: 300,
        sessionContext: "sms-verification:43",
      })
    ).rejects.toBeInstanceOf(SmsDeliveryError);
  });
});
