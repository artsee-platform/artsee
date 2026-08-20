import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { POST as tencentImCallback } from "@/app/api/v1/im/callback/route";
import {
  createTencentImCallbackSign,
  hashTencentImMsgBody,
} from "@/lib/api/tencent-im-callback";

const database = vi.hoisted(() => ({
  rpc: vi.fn(),
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({ rpc: database.rpc }),
}));

const sdkAppId = "1600000000";
const callbackToken = "callback-token-with-at-least-32-characters";
const requestTime = "1786320000";
const permit = "a".repeat(43);

function callbackBody(command = "C2C.CallbackBeforeSendMsg") {
  return {
    CallbackCommand: command,
    From_Account: "sender-im-id",
    ...(command === "C2C.CallbackBeforeSendMsg"
      ? { To_Account: "peer-im-id" }
      : { GroupId: "group-im-id" }),
    MsgBody: [
      { MsgContent: { Text: "你好" }, MsgType: "TIMTextElem" },
    ],
    CloudCustomData: JSON.stringify({
      conversation_id: "conversation-1",
      message_id: "message-1",
      artsee_bff_authorization: { version: 1, permit },
    }),
  };
}

function request(input?: {
  body?: Record<string, unknown>;
  command?: string;
  sdkAppId?: string;
  platform?: string;
  requestTime?: string;
  sign?: string;
}) {
  const command = input?.command ?? "C2C.CallbackBeforeSendMsg";
  const time = input?.requestTime ?? requestTime;
  const sign =
    input?.sign ?? createTencentImCallbackSign(callbackToken, time);
  const url = new URL("https://artiqore.com/api/v1/im/callback");
  url.searchParams.set("SdkAppid", input?.sdkAppId ?? sdkAppId);
  url.searchParams.set("CallbackCommand", command);
  url.searchParams.set("contenttype", "json");
  url.searchParams.set("OptPlatform", input?.platform ?? "RESTAPI");
  url.searchParams.set("RequestTime", time);
  url.searchParams.set("Sign", sign);
  return new NextRequest(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input?.body ?? callbackBody(command)),
  });
}

describe("Tencent IM BFF-only before-send callback", () => {
  beforeEach(() => {
    vi.stubEnv("TENCENT_IM_SDK_APP_ID", sdkAppId);
    vi.stubEnv("TENCENT_IM_CALLBACK_TOKEN", callbackToken);
    vi.stubEnv("TENCENT_IM_REQUIRE_BFF_CALLBACK", "1");
    vi.useFakeTimers({ now: new Date("2026-08-10T00:00:00.000Z") });
    database.rpc.mockReset();
    database.rpc.mockResolvedValue({ data: true, error: null });
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  it("accepts an authenticated C2C REST send and strips the permit", async () => {
    const body = callbackBody();
    const response = await tencentImCallback(request({ body }));
    const result = await response.json();

    expect(response.status).toBe(200);
    expect(result).toMatchObject({ ActionStatus: "OK", ErrorCode: 0 });
    expect(JSON.parse(result.CloudCustomData)).toEqual({
      conversation_id: "conversation-1",
      message_id: "message-1",
    });
    expect(database.rpc).toHaveBeenCalledWith(
      "consume_tencent_im_send_permit",
      expect.objectContaining({
        p_from_identifier: "sender-im-id",
        p_target_kind: "c2c",
        p_target_identifier: "peer-im-id",
        p_msg_body_sha256: hashTencentImMsgBody(body.MsgBody),
      })
    );
  });

  it("accepts a permitted group REST send", async () => {
    const command = "Group.CallbackBeforeSendMsg";
    const response = await tencentImCallback(
      request({ command, body: callbackBody(command) })
    );

    expect((await response.json()).ErrorCode).toBe(0);
    expect(database.rpc).toHaveBeenCalledWith(
      "consume_tencent_im_send_permit",
      expect.objectContaining({
        p_target_kind: "group",
        p_target_identifier: "group-im-id",
      })
    );
  });

  it.each([
    ["invalid signature", { sign: "0".repeat(64) }],
    ["stale timestamp", { requestTime: "1786319800" }],
    ["wrong SDKAppID", { sdkAppId: "1600000001" }],
    ["direct iOS SDK send", { platform: "iOS" }],
  ])("rejects %s before reading a permit", async (_label, overrides) => {
    const response = await tencentImCallback(request(overrides));

    expect((await response.json()).ErrorCode).toBe(1);
    expect(database.rpc).not.toHaveBeenCalled();
  });

  it("rejects a missing or replayed permit", async () => {
    database.rpc.mockResolvedValueOnce({ data: false, error: null });
    const response = await tencentImCallback(request());

    expect((await response.json()).ErrorCode).toBe(1);
  });

  it("fails closed when strict mode is not configured", async () => {
    vi.stubEnv("TENCENT_IM_REQUIRE_BFF_CALLBACK", "0");
    const response = await tencentImCallback(request());

    expect((await response.json()).ErrorCode).toBe(1);
    expect(database.rpc).not.toHaveBeenCalled();
  });
});

describe("Tencent IM callback permit migration", () => {
  const migrationsDirectory = path.resolve(
    process.cwd(),
    "../supabase/migrations"
  );
  const migrationName = readdirSync(migrationsDirectory)
    .filter((name) => name.endsWith("_tencent_im_bff_callback_permits.sql"))
    .sort()
    .at(-1);

  if (!migrationName) throw new Error("Missing Tencent IM permit migration");
  const migration = readFileSync(
    path.join(migrationsDirectory, migrationName),
    "utf8"
  );

  it("keeps permit rows private and grants only service_role", () => {
    expect(migration).toMatch(
      /ALTER TABLE public\.tencent_im_send_permits ENABLE ROW LEVEL SECURITY/i
    );
    expect(migration).toMatch(
      /REVOKE ALL ON TABLE public\.tencent_im_send_permits\s+FROM PUBLIC, anon, authenticated/i
    );
    expect(migration).toMatch(
      /GRANT SELECT, INSERT, DELETE ON TABLE public\.tencent_im_send_permits\s+TO service_role/i
    );
  });

  it("atomically deletes a matching unexpired permit", () => {
    expect(migration).toMatch(
      /DELETE FROM public\.tencent_im_send_permits[\s\S]*expires_at >= NOW\(\)[\s\S]*RETURNING token_hash/i
    );
    expect(migration).toMatch(/SECURITY INVOKER/i);
    expect(migration).toMatch(
      /REVOKE ALL ON FUNCTION public\.consume_tencent_im_send_permit[\s\S]*FROM PUBLIC, anon, authenticated/i
    );
  });

  it("uses the documented SHA-256 callback signature construction", () => {
    expect(createTencentImCallbackSign("xxxxyyyy", "1669872112")).toBe(
      createHash("sha256").update("xxxxyyyy1669872112").digest("hex")
    );
  });
});
