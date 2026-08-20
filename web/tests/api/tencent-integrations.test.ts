import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as signCosUpload } from "@/app/api/v1/uploads/cos/sign/route";
import { POST as completeCosUpload } from "@/app/api/v1/uploads/cos/complete/route";
import { POST as auditContent } from "@/app/api/v1/content/audit/route";

const mockDb = vi.hoisted(() => ({
  inserts: [] as Array<{ table: string; row: Record<string, unknown> }>,
  rows: [] as Array<Record<string, unknown>>,
}));

vi.mock("@/lib/api/authz", () => ({
  requireUser: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) {
      return {
        response: new Response(
          JSON.stringify({ success: false, error: "未授权" }),
          { status: 401 }
        ),
      };
    }
    return { user: { id: "user-123" }, profile: { role: "user" } };
  },
  requireAdmin: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) {
      return {
        response: new Response(
          JSON.stringify({ success: false, error: "未授权" }),
          { status: 401 }
        ),
      };
    }
    if (token === "non-admin-token") {
      return {
        response: new Response(
          JSON.stringify({ success: false, error: "需要管理员权限" }),
          { status: 403 }
        ),
      };
    }
    return { user: { id: "user-123" }, profile: { role: "admin" } };
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => {
    class QueryStub {
      private filters: Array<{ field: string; value: unknown }> = [];
      private patch: Record<string, unknown> | null = null;

      constructor(private readonly table: string) {}

      select() {
        return this;
      }

      eq(field: string, value: unknown) {
        this.filters.push({ field, value });
        return this;
      }

      update(patch: Record<string, unknown>) {
        this.patch = patch;
        return this;
      }

      async insert(row: Record<string, unknown>) {
        mockDb.inserts.push({ table: this.table, row });
        mockDb.rows.push({ ...row, created_at: new Date().toISOString() });
        return { error: null };
      }

      private matchingRow() {
        if (this.table !== "upload_files") return null;
        return (
          mockDb.rows.find((row) =>
            this.filters.every(({ field, value }) => row[field] === value)
          ) ?? null
        );
      }

      async maybeSingle() {
        return { data: this.matchingRow(), error: null };
      }

      async single() {
        const row = this.matchingRow();
        if (!row) return { data: null, error: { message: "not found" } };
        if (this.patch) Object.assign(row, this.patch);
        return { data: row, error: null };
      }
    }

    return { from: (table: string) => new QueryStub(table) };
  },
}));

function postReq(path: string, body?: Record<string, unknown>, token = "valid-token") {
  return new NextRequest(`http://localhost${path}`, {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
}

function stubTencentEnv() {
  vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "secret-id");
  vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "secret-key");
  vi.stubEnv("TENCENT_CLOUD_REGION", "ap-guangzhou");
  vi.stubEnv("TENCENT_COS_BUCKET", "artsee-test-1250000000");
  vi.stubEnv("TENCENT_COS_REGION", "ap-guangzhou");
  vi.stubEnv("TENCENT_COS_PUBLIC_BASE_URL", "https://assets.example.com");
}

describe("Tencent COS upload signing", () => {
  beforeEach(() => {
    mockDb.inserts = [];
    mockDb.rows = [];
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it("requires login", async () => {
    const res = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "art.png",
        content_type: "image/png",
        size: 12,
      }, "")
    );
    expect(res.status).toBe(401);
  });

  it("returns 503 when Tencent COS env is missing", async () => {
    vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "");
    vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "");
    const res = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "art.png",
        content_type: "image/png",
        size: 12,
      })
    );
    const body = await res.json();
    expect(res.status).toBe(503);
    expect(body.missing).toContain("TENCENT_CLOUD_SECRET_ID");
  });

  it("returns a scoped signed PUT upload for the current user", async () => {
    stubTencentEnv();
    vi.useFakeTimers({ now: new Date("2026-06-18T12:00:00.000Z") });

    const res = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "作品 1.png",
        content_type: "image/png",
        scene: "community",
        size: 1024,
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.provider).toBe("tencent_cos");
    expect(body.data.method).toBe("PUT");
    expect(body.data.key).toMatch(/^uploads\/user-123\/community\//);
    expect(body.data.file_url).toContain(
      "https://artsee-test-1250000000.cos.ap-guangzhou.myqcloud.com/uploads/user-123/community/"
    );
    expect(body.data.public_url).toBe(body.data.file_url);
    expect(body.data.headers.Authorization).toContain("q-sign-algorithm=sha1");
    expect(body.data.headers.Authorization).toContain("content-length");
    expect(body.data.headers["Content-Type"]).toBe("image/png");
    expect(body.data.headers["x-cos-acl"]).toBe("public-read");
    expect(body.data.headers["x-cos-server-side-encryption"]).toBe("AES256");
    expect(body.data.upload_id).toBeTruthy();
    expect(mockDb.inserts[0].row).toMatchObject({
      id: body.data.upload_id,
      user_id: "user-123",
      object_key: body.data.key,
      access_level: "public",
      upload_status: "pending",
      expected_size: 1024,
    });
  });

  it("keeps contract uploads private", async () => {
    stubTencentEnv();
    vi.stubEnv("TENCENT_COS_PRIVATE_DIRECT_UPLOAD_ENABLED", "true");
    const res = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "contract.pdf",
        content_type: "application/pdf",
        scene: "contracts/org-1",
        size: 128,
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.access_level).toBe("private");
    expect(body.data.public_url).toBeNull();
    expect(body.data.headers["x-cos-acl"]).toBe("private");
  });

  it("falls back to protected Supabase storage for private files by default", async () => {
    stubTencentEnv();
    const res = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "contract.pdf",
        content_type: "application/pdf",
        scene: "contracts/org-1",
        size: 128,
      })
    );
    const body = await res.json();

    expect(res.status).toBe(503);
    expect(body.fallback).toBe("supabase_private");
    expect(mockDb.inserts).toHaveLength(0);
  });

  it("verifies COS metadata and file bytes before completing the session", async () => {
    stubTencentEnv();
    const signedResponse = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "art.png",
        content_type: "image/png",
        scene: "community",
        size: 12,
      })
    );
    const signed = (await signedResponse.json()).data;
    const pngHeader = new Uint8Array([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0,
    ]);
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(null, {
          status: 200,
          headers: {
            "Content-Length": "12",
            "Content-Type": "image/png",
            ETag: '"object-etag"',
            "x-cos-hash-crc64ecma": "12345",
            "x-cos-meta-upload-id": signed.upload_id,
            "x-cos-server-side-encryption": "AES256",
          },
        })
      )
      .mockResolvedValueOnce(new Response(pngHeader, { status: 206 }));
    vi.stubGlobal("fetch", fetchMock);

    const res = await completeCosUpload(
      postReq("/api/v1/uploads/cos/complete", {
        upload_id: signed.upload_id,
        key: signed.key,
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data).toMatchObject({
      upload_id: signed.upload_id,
      key: signed.key,
      access_level: "public",
    });
    expect(mockDb.rows[0]).toMatchObject({
      upload_status: "completed",
      size: 12,
      object_etag: '"object-etag"',
      object_crc64: "12345",
    });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("rejects completion when COS reports a different file size", async () => {
    stubTencentEnv();
    const signedResponse = await signCosUpload(
      postReq("/api/v1/uploads/cos/sign", {
        file_name: "art.png",
        content_type: "image/png",
        scene: "community",
        size: 12,
      })
    );
    const signed = (await signedResponse.json()).data;
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(null, {
          status: 200,
          headers: {
            "Content-Length": "999",
            "Content-Type": "image/png",
            "x-cos-meta-upload-id": signed.upload_id,
            "x-cos-server-side-encryption": "AES256",
          },
        })
      )
    );

    const res = await completeCosUpload(
      postReq("/api/v1/uploads/cos/complete", {
        upload_id: signed.upload_id,
        key: signed.key,
      })
    );
    expect(res.status).toBe(422);
    expect(mockDb.rows[0].upload_status).toBe("pending");
  });

  it("rejects completion records for another user's key", async () => {
    const res = await completeCosUpload(
      postReq("/api/v1/uploads/cos/complete", {
        upload_id: "upload-1",
        key: "uploads/other-user/community/1_art.png",
      })
    );
    expect(res.status).toBe(403);
  });
});

describe("Tencent content audit", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("requires text or images", async () => {
    const res = await auditContent(
      postReq("/api/v1/content/audit", {
        text: "",
        image_urls: [],
      })
    );
    expect(res.status).toBe(400);
  });

  it("requires an administrator", async () => {
    const res = await auditContent(
      postReq(
        "/api/v1/content/audit",
        { text: "测试内容" },
        "non-admin-token"
      )
    );
    expect(res.status).toBe(403);
  });

  it("returns 503 when Tencent credentials are missing", async () => {
    vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "");
    vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "");
    const res = await auditContent(
      postReq("/api/v1/content/audit", {
        text: "测试内容",
      })
    );
    expect(res.status).toBe(503);
  });

  it("merges text and image moderation into the strictest audit status", async () => {
    stubTencentEnv();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            Response: {
              Suggestion: "Pass",
              Label: "Normal",
              Score: 0,
              RequestId: "text-request",
            },
          }),
          { status: 200 }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            Response: {
              Suggestion: "Block",
              Label: "Illegal",
              SubLabel: "Sensitive",
              Score: 98,
              RequestId: "image-request",
            },
          }),
          { status: 200 }
        )
      );
    vi.stubGlobal("fetch", fetchMock);

    const res = await auditContent(
      postReq("/api/v1/content/audit", {
        text: "一段正常文字",
        image_urls: ["https://assets.example.com/uploads/user-123/community/1.png"],
        scene: "community_post",
        data_id: "post-draft-1",
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(body.data.suggestion).toBe("block");
    expect(body.data.audit_status).toBe("rejected");
    expect(body.data.items).toHaveLength(2);
    expect(body.data.items[1]).toMatchObject({
      type: "image",
      label: "Illegal",
      sub_label: "Sensitive",
      score: 98,
      request_id: "image-request",
    });
  });

  it("accepts images from the configured Supabase Storage project", async () => {
    stubTencentEnv();
    vi.stubEnv("TENCENT_COS_BUCKET", "");
    vi.stubEnv("TENCENT_COS_REGION", "");
    vi.stubEnv("TENCENT_COS_PUBLIC_BASE_URL", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://project.supabase.co");
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          Response: {
            Suggestion: "Pass",
            Label: "Normal",
            Score: 0,
            RequestId: "supabase-image-request",
          },
        }),
        { status: 200 }
      )
    );
    vi.stubGlobal("fetch", fetchMock);

    const res = await auditContent(
      postReq("/api/v1/content/audit", {
        image_urls: [
          "https://project.supabase.co/storage/v1/object/public/community/image.png",
        ],
      })
    );

    expect(res.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it("fails closed when Tencent omits Suggestion", async () => {
    stubTencentEnv();
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({ Response: { Label: "Normal", RequestId: "bad-response" } }),
          { status: 200 }
        )
      )
    );

    const res = await auditContent(
      postReq("/api/v1/content/audit", { text: "测试内容" })
    );
    expect(res.status).toBe(502);
  });

  it("retries a transient Tencent server error once", async () => {
    stubTencentEnv();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ message: "temporary" }), { status: 500 })
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            Response: {
              Suggestion: "Pass",
              Label: "Normal",
              RequestId: "retry-success",
            },
          }),
          { status: 200 }
        )
      );
    vi.stubGlobal("fetch", fetchMock);

    const res = await auditContent(
      postReq("/api/v1/content/audit", { text: "重试测试" })
    );
    expect(res.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("rejects oversized text before calling Tencent", async () => {
    stubTencentEnv();
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const res = await auditContent(
      postReq("/api/v1/content/audit", { text: "字".repeat(10_001) })
    );
    expect(res.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects image URLs outside the storage allowlist", async () => {
    stubTencentEnv();
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const res = await auditContent(
      postReq("/api/v1/content/audit", {
        image_urls: ["https://untrusted.example.net/image.png"],
      })
    );
    expect(res.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
