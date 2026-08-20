import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

import { GET } from "@/app/api/v1/admin/integrations/readiness/route";

const mockState = vi.hoisted(() => ({
  serviceClientCalls: 0,
  tableFailures: new Set<string>(),
  rpcMessage: "SMS_RATE_CONFIG_INVALID",
  rpcArgs: null as Record<string, unknown> | null,
}));

vi.mock("@/lib/api/require-admin", () => ({
  requireAdmin: async (request: NextRequest) => {
    const token = request.headers
      .get("authorization")
      ?.replace(/^Bearer\s+/i, "");
    if (token === "admin-token") return { user: { id: "admin-user" } };
    return {
      response: new Response(
        JSON.stringify({ success: false, error: "需要管理员权限" }),
        { status: token ? 403 : 401 }
      ),
    };
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => {
    mockState.serviceClientCalls += 1;
    return {
      from: (table: string) => ({
        select: () => ({
          limit: async () => ({
            data: null,
            error: mockState.tableFailures.has(table)
              ? { message: `private database error for ${table}` }
              : null,
          }),
        }),
      }),
      rpc: async (_name: string, args: Record<string, unknown>) => {
        mockState.rpcArgs = args;
        return { data: null, error: { message: mockState.rpcMessage } };
      },
    };
  },
}));

function request(token = "admin-token") {
  return new NextRequest(
    "http://localhost/api/v1/admin/integrations/readiness",
    {
      headers: token ? { authorization: `Bearer ${token}` } : {},
    }
  );
}

function stubReadyEnvironment() {
  const values = {
    NEXT_PUBLIC_SUPABASE_URL: "https://project.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY: "anon-value-must-not-leak",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-value-must-not-leak",
    AMAP_WEB_SERVICE_KEY: "amap-value-must-not-leak",
    AMAP_SMOKE_TESTED: "1",
    TENCENT_CLOUD_SECRET_ID: "tencent-id-must-not-leak",
    TENCENT_CLOUD_SECRET_KEY: "tencent-key-must-not-leak",
    TENCENT_CLOUD_REGION: "ap-guangzhou",
    TENCENT_COS_BUCKET: "artsee-1234567890",
    TENCENT_COS_CORS_CONFIGURED: "1",
    TENCENT_CONTENT_SAFETY_TEXT_BIZ_TYPE: "text-biz",
    TENCENT_CONTENT_SAFETY_IMAGE_BIZ_TYPE: "image-biz",
    TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS: "assets.example.com",
    TENCENT_CONTENT_SAFETY_SMOKE_TESTED: "1",
    TENCENT_IM_SDK_APP_ID: "1400000000",
    TENCENT_IM_SECRET_KEY: "im-secret-must-not-leak",
    TENCENT_IM_CALLBACK_TOKEN:
      "callback-token-must-not-leak-1234567890",
    TENCENT_IM_REQUIRE_BFF_CALLBACK: "1",
    TENCENT_IM_CALLBACK_CONSOLE_CONFIGURED: "1",
    TENCENT_PUSH_CONSOLE_CONFIGURED: "1",
    TENCENT_PUSH_CLIENT_BUILD_CONFIGURED: "1",
    TENCENT_PUSH_SMOKE_TESTED: "1",
    TENCENT_SMS_SDK_APP_ID: "1400000001",
    TENCENT_SMS_SIGN_NAME: "艺见心",
    TENCENT_SMS_TEMPLATE_ID: "123456",
    SMS_OTP_PEPPER: "pepper-value-must-not-leak-1234567890",
    TENCENT_SMS_CONSOLE_GUARDS_CONFIGURED: "1",
    TENCENT_SMS_SMOKE_TESTED: "1",
    TENCENT_CAPTCHA_APP_ID: "123456789",
    TENCENT_CAPTCHA_APP_SECRET_KEY: "captcha-secret-must-not-leak",
    TENCENT_CAPTCHA_ALLOWED_ORIGINS: "https://artiqore.com",
    TENCENT_CAPTCHA_REQUIRED: "1",
    TENCENT_CAPTCHA_CONSOLE_CONFIGURED: "1",
    TENCENT_CAPTCHA_SMOKE_TESTED: "1",
  };
  Object.entries(values).forEach(([key, value]) => vi.stubEnv(key, value));
  return values;
}

describe("admin integration readiness", () => {
  beforeEach(() => {
    mockState.serviceClientCalls = 0;
    mockState.tableFailures.clear();
    mockState.rpcMessage = "SMS_RATE_CONFIG_INVALID";
    mockState.rpcArgs = null;
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("authenticates before creating a service-role client", async () => {
    const response = await GET(request(""));

    expect(response.status).toBe(401);
    expect(mockState.serviceClientCalls).toBe(0);
  });

  it("rejects signed-in non-admin users before running probes", async () => {
    const response = await GET(request("user-token"));

    expect(response.status).toBe(403);
    expect(mockState.serviceClientCalls).toBe(0);
  });

  it("never returns environment values or raw database errors", async () => {
    const values = stubReadyEnvironment();
    mockState.tableFailures.add("upload_files");

    const response = await GET(request());
    const body = await response.json();
    const serialized = JSON.stringify(body);

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(serialized).toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(serialized).not.toContain("private database error");
    for (const secret of [
      values.NEXT_PUBLIC_SUPABASE_ANON_KEY,
      values.SUPABASE_SERVICE_ROLE_KEY,
      values.AMAP_WEB_SERVICE_KEY,
      values.TENCENT_CLOUD_SECRET_KEY,
      values.TENCENT_IM_SECRET_KEY,
      values.TENCENT_IM_CALLBACK_TOKEN,
      values.SMS_OTP_PEPPER,
      values.TENCENT_CAPTCHA_APP_SECRET_KEY,
    ]) {
      expect(serialized).not.toContain(secret);
    }
    expect(
      body.integrations.find(
        (item: { id: string }) => item.id === "tencent_cos"
      ).status
    ).toBe("blocked");
  });

  it("reports every integration ready only after explicit attestations", async () => {
    stubReadyEnvironment();

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.summary).toEqual({ total: 8, ready: 8, attention: 0, blocked: 0 });
    expect(mockState.serviceClientCalls).toBe(1);
    expect(mockState.rpcArgs).toMatchObject({
      p_purpose: "readiness_probe",
      p_phone_cooldown_seconds: 0,
      p_global_hourly_limit: 0,
      p_global_daily_limit: 0,
    });
  });

  it("keeps paid smoke tests visible without blocking configured services", async () => {
    stubReadyEnvironment();
    vi.stubEnv("TENCENT_SMS_SMOKE_TESTED", "0");

    const response = await GET(request());
    const body = await response.json();
    const sms = body.integrations.find(
      (item: { id: string }) => item.id === "tencent_sms"
    );

    expect(sms.status).toBe("attention");
    expect(body.summary.attention).toBe(1);
    expect(body.summary.blocked).toBe(0);
  });
});
