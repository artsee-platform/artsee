import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { DELETE as deleteCosUpload } from "@/app/api/v1/uploads/cos/[id]/route";
import { POST as cleanupCosUploads } from "@/app/api/v1/admin/maintenance/cos-uploads/route";

type Row = Record<string, unknown>;

const db = vi.hoisted(() => ({ rows: [] as Row[] }));

vi.mock("@/lib/api/authz", () => ({
  requireUser: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) {
      return {
        response: Response.json(
          { success: false, error: "未授权" },
          { status: 401 }
        ),
      };
    }
    return { user: { id: token === "other-token" ? "user-999" : "user-123" } };
  },
}));

vi.mock("@/lib/api/require-admin", () => ({
  requireAdmin: async (req: NextRequest) => {
    if (req.headers.get("authorization") === "Bearer admin-token") {
      return { user: { id: "admin-user" } };
    }
    return {
      response: Response.json(
        { success: false, error: "需要管理员权限" },
        { status: 403 }
      ),
    };
  },
}));

class QueryStub {
  private filters: Array<{ field: string; value: unknown; op: "eq" | "lt" }> = [];
  private operation: "select" | "delete" = "select";

  select() {
    return this;
  }

  delete() {
    this.operation = "delete";
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value, op: "eq" });
    return this;
  }

  lt(field: string, value: unknown) {
    this.filters.push({ field, value, op: "lt" });
    return this;
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value, op }) => {
      if (op === "lt") {
        const left = Date.parse(String(row[field] ?? ""));
        const right = Date.parse(String(value ?? ""));
        return Number.isFinite(left) && Number.isFinite(right) && left < right;
      }
      return row[field] === value;
    });
  }

  async maybeSingle() {
    const index = db.rows.findIndex((row) => this.matches(row));
    if (index < 0) return { data: null, error: null };
    if (this.operation === "delete") {
      const [deleted] = db.rows.splice(index, 1);
      return { data: { id: deleted.id }, error: null };
    }
    return { data: db.rows[index], error: null };
  }

  async limit(limit: number) {
    return {
      data: db.rows.filter((row) => this.matches(row)).slice(0, limit),
      error: null,
    };
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: () => new QueryStub(),
  }),
}));

const UPLOAD_ID = "11111111-1111-4111-8111-111111111111";
const OWNED_KEY = "uploads/user-123/community/asset.png";

function uploadRow(overrides: Row = {}): Row {
  return {
    id: UPLOAD_ID,
    user_id: "user-123",
    provider: "tencent_cos",
    bucket: "artsee-test-1250000000",
    object_key: OWNED_KEY,
    upload_status: "completed",
    expires_at: "2026-08-09T00:00:00.000Z",
    ...overrides,
  };
}

function deleteRequest(token = "valid-token") {
  return new NextRequest(`http://localhost/api/v1/uploads/cos/${UPLOAD_ID}`, {
    method: "DELETE",
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

async function invokeDelete(token = "valid-token") {
  return deleteCosUpload(deleteRequest(token), {
    params: Promise.resolve({ id: UPLOAD_ID }),
  });
}

function stubTencentEnv() {
  vi.stubEnv("TENCENT_CLOUD_SECRET_ID", "secret-id");
  vi.stubEnv("TENCENT_CLOUD_SECRET_KEY", "secret-key");
  vi.stubEnv("TENCENT_COS_BUCKET", "artsee-test-1250000000");
  vi.stubEnv("TENCENT_COS_REGION", "ap-guangzhou");
}

describe("Tencent COS deletion", () => {
  beforeEach(() => {
    db.rows = [];
    delete process.env.COS_UPLOAD_CLEANUP_CRON_SECRET;
    delete process.env.ADMIN_MAINTENANCE_CRON_SECRET;
    stubTencentEnv();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("requires login", async () => {
    const response = await invokeDelete("");
    expect(response.status).toBe(401);
  });

  it("deletes an owned COS object before removing its database record", async () => {
    db.rows.push(uploadRow());
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);

    const response = await invokeDelete();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.data).toMatchObject({
      upload_id: UPLOAD_ID,
      deleted: true,
      object_was_missing: false,
    });
    expect(db.rows).toHaveLength(0);
    expect(fetchMock).toHaveBeenCalledWith(
      `https://artsee-test-1250000000.cos.ap-guangzhou.myqcloud.com/${OWNED_KEY}`,
      expect.objectContaining({
        method: "DELETE",
        headers: expect.objectContaining({
          Authorization: expect.stringContaining("q-sign-algorithm=sha1"),
        }),
      })
    );
  });

  it("treats an already missing COS object as an idempotent success", async () => {
    db.rows.push(uploadRow());
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 404 })));

    const response = await invokeDelete();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.data.object_was_missing).toBe(true);
    expect(db.rows).toHaveLength(0);
  });

  it("does not reveal or delete another user's upload", async () => {
    db.rows.push(uploadRow());
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const response = await invokeDelete("other-token");

    expect(response.status).toBe(404);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(db.rows).toHaveLength(1);
  });

  it("rejects an inconsistent object owner without touching COS", async () => {
    db.rows.push(uploadRow({ object_key: "uploads/user-999/community/asset.png" }));
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const response = await invokeDelete();

    expect(response.status).toBe(409);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(db.rows).toHaveLength(1);
  });

  it("keeps the database record when COS deletion fails", async () => {
    db.rows.push(uploadRow());
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 403 })));

    const response = await invokeDelete();

    expect(response.status).toBe(502);
    expect(db.rows).toHaveLength(1);
  });

  it("cleans up only expired pending upload sessions", async () => {
    db.rows.push(
      uploadRow({ upload_status: "pending" }),
      uploadRow({
        id: "22222222-2222-4222-8222-222222222222",
        object_key: "uploads/user-123/community/future.png",
        upload_status: "pending",
        expires_at: "2099-08-09T00:00:00.000Z",
      }),
      uploadRow({
        id: "33333333-3333-4333-8333-333333333333",
        object_key: "uploads/user-123/community/completed.png",
        upload_status: "completed",
      })
    );
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 204 })));

    const response = await cleanupCosUploads(
      new NextRequest(
        "http://localhost/api/v1/admin/maintenance/cos-uploads?limit=10",
        {
          method: "POST",
          headers: { authorization: "Bearer admin-token" },
        }
      )
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.data).toMatchObject({
      scanned: 1,
      deleted: 1,
      skipped: 0,
      failed: 0,
    });
    expect(db.rows.map((row) => row.id)).toEqual([
      "22222222-2222-4222-8222-222222222222",
      "33333333-3333-4333-8333-333333333333",
    ]);
  });

  it("returns a retryable failure when expired object cleanup fails", async () => {
    db.rows.push(uploadRow({ upload_status: "pending" }));
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 403 })));

    const response = await cleanupCosUploads(
      new NextRequest("http://localhost/api/v1/admin/maintenance/cos-uploads", {
        method: "POST",
        headers: { authorization: "Bearer admin-token" },
      })
    );
    const body = await response.json();

    expect(response.status).toBe(502);
    expect(body.success).toBe(false);
    expect(body.data).toMatchObject({
      scanned: 1,
      deleted: 0,
      failed: 1,
      failed_upload_ids: [UPLOAD_ID],
    });
    expect(db.rows).toHaveLength(1);
  });
});
