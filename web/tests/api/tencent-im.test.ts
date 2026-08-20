import { afterEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getImConfig } from "@/app/api/v1/im/config/route";
import {
  buildTencentImIdentifier,
  generateTencentImUserSig,
  sendTencentImConversationMessage,
} from "@/lib/api/tencent-im";

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) return null;
    return { id: "user-123" };
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) =>
      table === "tencent_im_send_permits"
        ? {
            insert: async () => ({ error: null }),
            delete: () => ({ eq: async () => ({ error: null }) }),
          }
        : {
            select: () => ({
              eq: () => ({
                maybeSingle: async () => ({
                  data: {
                    nickname: "Artsee开发者",
                    avatar_url: "https://example.com/a.png",
                  },
                  error: null,
                }),
              }),
            }),
          },
  }),
}));

function getReq(token = "valid-token") {
  return new NextRequest("http://localhost/api/v1/im/config", {
    method: "GET",
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

describe("Tencent IM config", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  it("requires login", async () => {
    const res = await getImConfig(getReq(""));
    expect(res.status).toBe(401);
  });

  it("returns missing config as 503", async () => {
    vi.stubEnv("TENCENT_IM_SDK_APP_ID", "");
    vi.stubEnv("TENCENT_IM_SECRET_KEY", "");

    const res = await getImConfig(getReq());
    const body = await res.json();

    expect(res.status).toBe(503);
    expect(body.missing).toContain("TENCENT_IM_SDK_APP_ID");
    expect(body.missing).toContain("TENCENT_IM_SECRET_KEY");
  });

  it("generates a UserSig payload for the current user", async () => {
    vi.stubEnv("TENCENT_IM_SDK_APP_ID", "1600000000");
    vi.stubEnv("TENCENT_IM_SECRET_KEY", "test-secret-with-enough-length");
    vi.stubEnv("TENCENT_IM_SKIP_ACCOUNT_IMPORT", "1");
    vi.stubEnv("TENCENT_IM_USER_SIG_EXPIRES_SECONDS", "3600");
    vi.useFakeTimers({ now: new Date("2026-06-24T12:00:00.000Z") });

    const res = await getImConfig(getReq());
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.sdk_app_id).toBe(1600000000);
    expect(body.data.identifier).toMatch(/^u[a-f0-9]{31}$/);
    expect(Buffer.byteLength(body.data.identifier, "utf8")).toBe(32);
    expect(body.data.user_sig).toEqual(expect.any(String));
    expect(body.data.user_sig.length).toBeGreaterThan(100);
    expect(body.data.expires_in).toBe(3600);
    expect(body.data.account_sync).toBe("skipped");
  });

  it("sanitizes identifiers and generates deterministic sigs", () => {
    const identifier = buildTencentImIdentifier("user/a b:c");
    const sig = generateTencentImUserSig({
      sdkAppId: 1600000000,
      secretKey: "test-secret-with-enough-length",
      identifier,
      expireSeconds: 3600,
      nowSeconds: 1782302400,
    });

    expect(identifier).toMatch(/^u[a-f0-9]{31}$/);
    expect(identifier).toBe(buildTencentImIdentifier("user/a b:c"));
    expect(identifier).not.toBe(buildTencentImIdentifier("user/a b:d"));
    expect(sig).toEqual(expect.any(String));
    expect(sig).not.toContain("+");
    expect(sig).not.toContain("/");
    expect(sig).not.toContain("=");
  });

  it("sends canonical C2C messages through the Tencent REST API", async () => {
    vi.stubEnv("TENCENT_IM_SDK_APP_ID", "1600000000");
    vi.stubEnv("TENCENT_IM_SECRET_KEY", "test-secret-with-enough-length");
    vi.stubEnv("TENCENT_IM_REST_MAX_ATTEMPTS", "1");
    const fetchMock = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = input.toString();
      if (url.includes("/openim/sendmsg")) {
        const payload = JSON.parse(String(init?.body));
        expect(payload.From_Account).toBe(buildTencentImIdentifier("sender-unique"));
        expect(payload.To_Account).toBe(buildTencentImIdentifier("peer-unique"));
        expect(payload.CloudCustomData).toContain('"message_id":"msg-1"');
        expect(payload.OfflinePushInfo.Desc).toBe("你收到一条新消息");
        return new Response(
          JSON.stringify({ ActionStatus: "OK", ErrorCode: 0, MsgKey: "key-1" }),
          { status: 200 }
        );
      }
      return new Response(JSON.stringify({ ActionStatus: "OK", ErrorCode: 0 }), {
        status: 200,
      });
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await sendTencentImConversationMessage({
      conversationId: "conv-1",
      messageId: "msg-1",
      messageType: "text",
      text: "你好",
      fromUserId: "sender-unique",
      toUserId: "peer-unique",
    });

    expect(result).toMatchObject({ mode: "c2c", im_msg_key: "key-1" });
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it("attaches a one-time BFF permit in strict callback mode", async () => {
    vi.stubEnv("TENCENT_IM_SDK_APP_ID", "1600000000");
    vi.stubEnv("TENCENT_IM_SECRET_KEY", "test-secret-with-enough-length");
    vi.stubEnv(
      "TENCENT_IM_CALLBACK_TOKEN",
      "callback-token-with-at-least-32-characters"
    );
    vi.stubEnv("TENCENT_IM_REQUIRE_BFF_CALLBACK", "1");
    vi.stubEnv("TENCENT_IM_REST_MAX_ATTEMPTS", "3");

    let sendPayload: Record<string, unknown> | null = null;
    const fetchMock = vi.fn(
      async (input: URL | RequestInfo, init?: RequestInit) => {
        if (input.toString().includes("/openim/sendmsg")) {
          sendPayload = JSON.parse(String(init?.body));
          return new Response(
            JSON.stringify({
              ActionStatus: "OK",
              ErrorCode: 0,
              MsgKey: "strict-key",
            }),
            { status: 200 }
          );
        }
        return new Response(
          JSON.stringify({ ActionStatus: "OK", ErrorCode: 0 }),
          { status: 200 }
        );
      }
    );
    vi.stubGlobal("fetch", fetchMock);

    await sendTencentImConversationMessage({
      conversationId: "conv-strict",
      messageId: "msg-strict",
      messageType: "text",
      text: "只允许 BFF 发送",
      fromUserId: "sender-strict",
      toUserId: "peer-strict",
    });

    expect(sendPayload).not.toBeNull();
    const capturedPayload = sendPayload as unknown as Record<string, unknown>;
    const cloudCustomData = JSON.parse(
      String(capturedPayload.CloudCustomData)
    );
    expect(cloudCustomData).toMatchObject({
      conversation_id: "conv-strict",
      message_id: "msg-strict",
      artsee_bff_authorization: { version: 1 },
    });
    expect(cloudCustomData.artsee_bff_authorization.permit).toMatch(
      /^[A-Za-z0-9_-]{43}$/
    );
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });
});
