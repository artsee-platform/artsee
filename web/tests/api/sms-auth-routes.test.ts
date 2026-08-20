import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mocked = vi.hoisted(() => ({
  rpcResults: new Map<string, { data: unknown; error: { message: string } | null }>(),
  rpcCalls: [] as Array<{ name: string; args: Record<string, unknown> | undefined }>,
  updates: [] as Array<Record<string, unknown>>,
  issuedSessions: 0,
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    rpc: async (name: string, args?: Record<string, unknown>) => {
      mocked.rpcCalls.push({ name, args });
      return (
        mocked.rpcResults.get(name) ?? {
          data: null,
          error: { message: `Unexpected RPC: ${name}` },
        }
      );
    },
    from: () => ({
      update: (row: Record<string, unknown>) => ({
        eq: async () => {
          mocked.updates.push(row);
          return { error: null };
        },
      }),
    }),
  }),
}));

vi.mock("@/lib/api/phone-auth-session", () => ({
  PhoneAuthSessionError: class PhoneAuthSessionError extends Error {},
  issuePhoneAuthSession: async () => {
    mocked.issuedSessions += 1;
    return {
      isNewUser: false,
      user: { id: "user-1", phone: "13800138000", role: "user", profile: {} },
      session: {
        access_token: "access-token",
        refresh_token: "refresh-token",
        expires_in: 3600,
        expires_at: 123456,
        token_type: "bearer",
      },
    };
  },
}));

function request(path: string, body: Record<string, unknown>) {
  return new NextRequest(`http://localhost${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-forwarded-for": "203.0.113.10",
    },
    body: JSON.stringify(body),
  });
}

function stubSmsEnv() {
  vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "secret-id");
  vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "secret-key");
  vi.stubEnv("TENCENT_CLOUD_MAX_ATTEMPTS", "1");
  vi.stubEnv("TENCENT_SMS_SDK_APP_ID", "1400006666");
  vi.stubEnv("TENCENT_SMS_SIGN_NAME", "艺见心");
  vi.stubEnv("TENCENT_SMS_TEMPLATE_ID", "1110");
  vi.stubEnv("SMS_OTP_PEPPER", "test-only-otp-pepper-with-enough-entropy");
}

describe("SMS auth routes", () => {
  beforeEach(() => {
    mocked.rpcResults.clear();
    mocked.rpcCalls = [];
    mocked.updates = [];
    mocked.issuedSessions = 0;
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("fails closed when SMS configuration is missing", async () => {
    vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "");
    vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "");
    vi.stubEnv("TENCENT_SMS_SDK_APP_ID", "");
    vi.stubEnv("TENCENT_SMS_SIGN_NAME", "");
    vi.stubEnv("TENCENT_SMS_TEMPLATE_ID", "");
    vi.stubEnv("SMS_OTP_PEPPER", "");
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000" })
    );
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(body.success).toBe(false);
    expect(body.missing).toContain("TENCENT_SMS_SDK_APP_ID");
  });

  it("reserves a hashed code and sends it through Tencent without returning it", async () => {
    stubSmsEnv();
    mocked.rpcResults.set("reserve_sms_verification", { data: 42, error: null });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify({
            Response: {
              SendStatusSet: [{ Code: "Ok", SerialNo: "serial-1" }],
              RequestId: "request-1",
            },
          }),
          { status: 200 }
        )
      )
    );
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000", purpose: "login" })
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body).toMatchObject({ success: true, provider: "tencent_cloud_sms" });
    expect(body.code).toBeUndefined();
    expect(mocked.updates).toContainEqual(
      expect.objectContaining({ delivery_status: "sent", provider_request_id: "request-1" })
    );
  });

  it("returns 429 when the database atomic limiter rejects a phone", async () => {
    stubSmsEnv();
    mocked.rpcResults.set("reserve_sms_verification", {
      data: null,
      error: { message: "SMS_RATE_PHONE_COOLDOWN" },
    });
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000" })
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("Retry-After")).toBe("60");
  });

  it("requires a captcha before reserving a paid SMS send", async () => {
    stubSmsEnv();
    vi.stubEnv("TENCENT_CAPTCHA_REQUIRED", "1");
    vi.stubEnv("TENCENT_CAPTCHA_APP_ID", "199999164");
    vi.stubEnv("TENCENT_CAPTCHA_APP_SECRET_KEY", "captcha-app-secret");
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000" })
    );
    const body = await response.json();

    expect(response.status).toBe(428);
    expect(body).toMatchObject({
      success: false,
      code: "CAPTCHA_REQUIRED",
      captcha_required: true,
    });
    expect(mocked.rpcCalls).toHaveLength(0);
  });

  it("fails closed before opening a challenge when captcha config is missing", async () => {
    stubSmsEnv();
    vi.stubEnv("TENCENT_CAPTCHA_REQUIRED", "1");
    vi.stubEnv("TENCENT_CAPTCHA_APP_ID", "");
    vi.stubEnv("TENCENT_CAPTCHA_APP_SECRET_KEY", "");
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000" })
    );

    expect(response.status).toBe(503);
    expect(mocked.rpcCalls).toHaveLength(0);
  });

  it("verifies a captcha before reserving and sending the SMS", async () => {
    stubSmsEnv();
    vi.stubEnv("TENCENT_CAPTCHA_REQUIRED", "1");
    vi.stubEnv("TENCENT_CAPTCHA_APP_ID", "199999164");
    vi.stubEnv("TENCENT_CAPTCHA_APP_SECRET_KEY", "captcha-app-secret");
    mocked.rpcResults.set("reserve_sms_verification", { data: 43, error: null });
    const actions: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_input: URL | RequestInfo, init?: RequestInit) => {
        const action = (init?.headers as Record<string, string>)["X-TC-Action"];
        actions.push(action);
        if (action === "DescribeCaptchaResult") {
          return new Response(
            JSON.stringify({
              Response: { CaptchaCode: 1, EvilLevel: 0, RequestId: "captcha-1" },
            }),
            { status: 200 }
          );
        }
        return new Response(
          JSON.stringify({
            Response: {
              SendStatusSet: [{ Code: "Ok", SerialNo: "serial-2" }],
              RequestId: "sms-2",
            },
          }),
          { status: 200 }
        );
      })
    );
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", {
        phone: "13800138000",
        captcha_ticket: "ticket-1",
        captcha_randstr: "@rand-1",
      })
    );

    expect(response.status).toBe(200);
    expect(actions).toEqual(["DescribeCaptchaResult", "SendSms"]);
    expect(mocked.rpcCalls[0]).toMatchObject({
      name: "reserve_sms_verification",
      args: {
        p_global_hourly_limit: 100,
        p_global_daily_limit: 500,
      },
    });
  });

  it("returns 429 when the application-wide hourly circuit breaker opens", async () => {
    stubSmsEnv();
    mocked.rpcResults.set("reserve_sms_verification", {
      data: null,
      error: { message: "SMS_RATE_GLOBAL_HOURLY" },
    });
    const { POST } = await import("@/app/api/v1/auth/send-sms/route");
    const response = await POST(
      request("/api/v1/auth/send-sms", { phone: "13800138000" })
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("Retry-After")).toBe("3600");
  });

  it("rejects a wrong code without creating a session", async () => {
    stubSmsEnv();
    mocked.rpcResults.set("consume_sms_verification", {
      data: [{ status: "invalid_code", attempts: 1, verification_id: 42 }],
      error: null,
    });
    const { POST } = await import("@/app/api/v1/auth/verify-sms/route");
    const response = await POST(
      request("/api/v1/auth/verify-sms", {
        phone: "13800138000",
        code: "654321",
      })
    );

    expect(response.status).toBe(400);
    expect(mocked.issuedSessions).toBe(0);
  });

  it("returns a real Supabase session after atomic code consumption", async () => {
    stubSmsEnv();
    mocked.rpcResults.set("consume_sms_verification", {
      data: [{ status: "verified", attempts: 1, verification_id: 42 }],
      error: null,
    });
    const { POST } = await import("@/app/api/v1/auth/verify-sms/route");
    const response = await POST(
      request("/api/v1/auth/verify-sms", {
        phone: "13800138000",
        code: "654321",
      })
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.session).toMatchObject({
      access_token: "access-token",
      refresh_token: "refresh-token",
    });
    expect(mocked.issuedSessions).toBe(1);
  });
});
