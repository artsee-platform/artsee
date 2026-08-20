import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import { GET as captchaChallenge } from "@/app/api/v1/auth/captcha/challenge/route";
import {
  getTencentCaptchaChallengeConfig,
  normalizeTencentCaptchaProof,
  TencentCaptchaRejectedError,
  verifyTencentCaptchaProof,
} from "@/lib/api/tencent-captcha";

function stubCaptchaEnv() {
  vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "secret-id");
  vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "secret-key");
  vi.stubEnv("TENCENT_CLOUD_MAX_ATTEMPTS", "1");
  vi.stubEnv("TENCENT_CAPTCHA_APP_ID", "199999164");
  vi.stubEnv("TENCENT_CAPTCHA_APP_SECRET_KEY", "captcha-app-secret");
  vi.stubEnv("TENCENT_CAPTCHA_MAX_EVIL_LEVEL", "0");
}

describe("Tencent Captcha", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("serves the official dynamically loaded challenge without exposing the secret", async () => {
    stubCaptchaEnv();
    vi.stubEnv("TENCENT_CAPTCHA_ALLOWED_ORIGINS", "https://artiqore.com");
    const response = await captchaChallenge(
      new NextRequest(
        "https://artiqore.com/api/v1/auth/captcha/challenge?return_origin=https%3A%2F%2Fartiqore.com"
      )
    );
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("no-store");
    expect(response.headers.get("content-security-policy")).toContain(
      "frame-ancestors https://artiqore.com"
    );
    expect(html).toContain("https://turing.captcha.qcloud.com/TJCaptcha.js");
    expect(html).toContain("199999164");
    expect(html).toContain("aidEncryptedType: 'gcm'");
    expect(html).not.toContain("captcha-app-secret");
  });

  it("generates a different short-lived encrypted AppId proof per challenge", () => {
    stubCaptchaEnv();
    const first = getTencentCaptchaChallengeConfig(1_786_320_000);
    const second = getTencentCaptchaChallengeConfig(1_786_320_000);

    expect(first).toMatchObject({
      appId: "199999164",
      aidEncryptedType: "gcm",
    });
    expect(Buffer.from(first.aidEncrypted, "base64").length).toBeGreaterThan(28);
    expect(first.aidEncrypted).not.toBe(second.aidEncrypted);
    expect(first.aidEncrypted).not.toContain("captcha-app-secret");
  });

  it("verifies ticket and randstr with DescribeCaptchaResult", async () => {
    stubCaptchaEnv();
    const fetchMock = vi.fn(async (_input: URL | RequestInfo, init?: RequestInit) => {
      const payload = JSON.parse(String(init?.body));
      expect(payload).toMatchObject({
        CaptchaType: 9,
        Ticket: "ticket-1",
        Randstr: "@rand-1",
        UserIp: "203.0.113.10",
        CaptchaAppId: 199999164,
        AppSecretKey: "captcha-app-secret",
      });
      expect((init?.headers as Record<string, string>)["X-TC-Action"]).toBe(
        "DescribeCaptchaResult"
      );
      return new Response(
        JSON.stringify({
          Response: {
            CaptchaCode: 1,
            CaptchaMsg: "OK",
            EvilLevel: 0,
            EvilBitmap: 0,
            RequestId: "captcha-request-1",
          },
        }),
        { status: 200 }
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      verifyTencentCaptchaProof({
        proof: { ticket: "ticket-1", randstr: "@rand-1" },
        userIp: "203.0.113.10",
      })
    ).resolves.toMatchObject({ requestId: "captcha-request-1", evilLevel: 0 });
  });

  it("fails closed for disaster-recovery tickets and risky provider results", async () => {
    expect(() =>
      normalizeTencentCaptchaProof(
        "trerror_1001_199999164_1786320000",
        "@fallback"
      )
    ).toThrow(TencentCaptchaRejectedError);

    stubCaptchaEnv();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify({
            Response: { CaptchaCode: 1, EvilLevel: 100, RequestId: "risk-1" },
          }),
          { status: 200 }
        )
      )
    );
    await expect(
      verifyTencentCaptchaProof({
        proof: { ticket: "ticket-2", randstr: "@rand-2" },
        userIp: "203.0.113.10",
      })
    ).rejects.toBeInstanceOf(TencentCaptchaRejectedError);
  });
});

describe("SMS global circuit breaker migration", () => {
  const migrationsDirectory = path.resolve(
    process.cwd(),
    "../supabase/migrations"
  );
  const migrationName = readdirSync(migrationsDirectory)
    .filter((name) => name.endsWith("_harden_sms_global_limits.sql"))
    .sort()
    .at(-1);

  if (!migrationName) throw new Error("Missing SMS global limits migration");
  const migration = readFileSync(
    path.join(migrationsDirectory, migrationName),
    "utf8"
  );

  it("serializes the global count and enforces hourly and daily limits", () => {
    expect(migration).toMatch(/pg_advisory_xact_lock[\s\S]*sms-global/i);
    expect(migration).toMatch(/SMS_RATE_GLOBAL_HOURLY/i);
    expect(migration).toMatch(/SMS_RATE_GLOBAL_DAILY/i);
    expect(migration).toMatch(/sms_verifications_created_idx/i);
  });

  it("keeps the RPC invoker-only and unavailable to public clients", () => {
    expect(migration).toMatch(/SECURITY INVOKER/i);
    expect(migration).toMatch(/SET search_path = ''/i);
    expect(migration).toMatch(
      /REVOKE ALL ON FUNCTION public\.reserve_sms_verification[\s\S]*FROM PUBLIC, anon, authenticated/i
    );
    expect(migration).toMatch(
      /GRANT EXECUTE ON FUNCTION public\.reserve_sms_verification[\s\S]*TO service_role/i
    );
  });
});
