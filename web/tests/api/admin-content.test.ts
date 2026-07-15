import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getAdminContent } from "@/app/api/v1/admin/content/route";
import { POST as reviewAdminContent } from "@/app/api/v1/admin/content/[type]/[id]/review/route";

type Row = Record<string, unknown>;

const ADMIN_ID = "admin-user";
const STUDENT_ID = "student-user";
const BUSINESS_ID = "business-user";

const tokenUsers: Record<string, string> = {
  admin: ADMIN_ID,
  student: STUDENT_ID,
  business: BUSINESS_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  events: [],
  opportunities: [],
  artworks: [],
  artist_profiles: [],
  community_posts: [],
  notifications: [],
};

function resetDb() {
  db.user_profiles = [
    { id: ADMIN_ID, role: "admin" },
    { id: STUDENT_ID, role: "user" },
    { id: BUSINESS_ID, role: "user" },
  ];
  db.events = [
    {
      id: "event-1",
      title: "青年艺术展",
      status: "reviewing",
      created_by: BUSINESS_ID,
      summary: "线下展览",
      metadata: {
        review: {
          supplemental_materials: [
            "https://example.supabase.co/storage/v1/object/public/submission-materials/business-user/submission-materials/events/event-1/proof.pdf",
          ],
        },
      },
      created_at: "2026-06-12T09:00:00.000Z",
      updated_at: "2026-06-12T10:00:00.000Z",
    },
  ];
  db.opportunities = [
    {
      id: "opp-1",
      title: "品牌合作",
      status: "reviewing",
      created_by: BUSINESS_ID,
      requirements: "作品集",
      metadata: {},
      created_at: "2026-06-12T08:00:00.000Z",
      updated_at: "2026-06-12T08:30:00.000Z",
    },
  ];
  db.artworks = [
    {
      id: "artwork-1",
      title: "装置作品",
      status: "reviewing",
      user_id: STUDENT_ID,
      description: "毕业作品",
      metadata: {},
      created_at: "2026-06-12T11:00:00.000Z",
      updated_at: "2026-06-12T11:30:00.000Z",
    },
  ];
  db.artist_profiles = [];
  db.community_posts = [
    {
      id: "market-1",
      title: "作品集诊断名额",
      status: "reviewing",
      audit_status: "reviewing",
      author_id: BUSINESS_ID,
      body: "一对一作品集服务",
      metadata: { kind: "market" },
      created_at: "2026-06-12T12:00:00.000Z",
      updated_at: "2026-06-12T12:30:00.000Z",
    },
    {
      id: "post-1",
      title: "普通广场帖",
      status: "reviewing",
      author_id: BUSINESS_ID,
      body: "不应该出现在市集审核中",
      metadata: { kind: "article" },
      created_at: "2026-06-12T12:10:00.000Z",
      updated_at: "2026-06-12T12:40:00.000Z",
    },
  ];
  db.notifications = [];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private patch: Row | null = null;
  private inserted: Row | null = null;
  private rangeStart = 0;
  private rangeEnd: number | null = null;

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  order() {
    return this;
  }

  range(start: number, end: number) {
    this.rangeStart = start;
    this.rangeEnd = end;
    return this;
  }

  insert(row: Row) {
    this.inserted = {
      id: typeof row.id === "string" ? row.id : `${this.table}-${db[this.table].length + 1}`,
      ...row,
    };
    db[this.table].push(this.inserted);
    return this;
  }

  update(patch: Row) {
    this.patch = patch;
    return this;
  }

  async maybeSingle() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  async single() {
    if (this.inserted) return { data: this.inserted, error: null };
    if (this.patch) {
      const rows = db[this.table];
      const index = rows.findIndex((row) => this.matches(row));
      if (index < 0) return { data: null, error: { message: "not found" } };
      rows[index] = { ...rows[index], ...this.patch };
      return { data: rows[index], error: null };
    }
    const row = this.findRows()[0] ?? null;
    return { data: row, error: row ? null : { message: "not found" } };
  }

  then<TResult1 = unknown, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: Row[]; count: number; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
  ) {
    const rows = this.findRows();
    const sliced =
      this.rangeEnd == null
        ? rows
        : rows.slice(this.rangeStart, this.rangeEnd + 1);
    return Promise.resolve({ data: sliced, count: rows.length, error: null }).then(
      onfulfilled,
      onrejected
    );
  }

  private findRows() {
    return (db[this.table] ?? []).filter((row) => this.matches(row));
  }

  private matches(row: Row) {
    return this.filters.every(({ field, value }) => fieldValue(row, field) === value);
  }
}

function fieldValue(row: Row, field: string) {
  const [base, jsonKey] = field.split("->>");
  if (!jsonKey) return row[field];
  const value = row[base];
  if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
  return (value as Row)[jsonKey];
}

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    const id = token ? tokenUsers[token] : null;
    return id ? ({ id } as { id: string }) : null;
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function req(path: string, token: keyof typeof tokenUsers | null, method = "GET", body?: Row) {
  return new NextRequest(`http://localhost${path}`, {
    method,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
}

function ctx(type: string, id: string) {
  return { params: Promise.resolve({ type, id }) };
}

describe("admin content moderation", () => {
  beforeEach(resetDb);

  it("requires admin access to list review content", async () => {
    const denied = await getAdminContent(req("/api/v1/admin/content", "student"));
    expect(denied.status).toBe(403);

    const listed = await getAdminContent(
      req("/api/v1/admin/content?status=reviewing", "admin")
    );
    const body = await listed.json();
    expect(listed.status).toBe(200);
    expect(body.data.map((item: Row) => item.type).sort()).toEqual([
      "artworks",
      "events",
      "marketplace",
      "opportunities",
    ]);
    expect(body.count).toBe(4);
    const event = body.data.find((item: Row) => item.id === "event-1");
    expect(event.supplemental_materials).toEqual([
      "https://example.supabase.co/storage/v1/object/public/submission-materials/business-user/submission-materials/events/event-1/proof.pdf",
    ]);
    expect(body.data.some((item: Row) => item.id === "post-1")).toBe(false);
  });

  it("approves artwork content and notifies the owner", async () => {
    const approved = await reviewAdminContent(
      req("/api/v1/admin/content/artworks/artwork-1/review", "admin", "POST", {
        status: "approved",
        review_note: "可以公开",
      }),
      ctx("artworks", "artwork-1")
    );
    const body = await approved.json();
    expect(approved.status).toBe(200);
    expect(body.data.status).toBe("published");
    expect(body.data.metadata.review.decision).toBe("approved");
    expect(db.notifications.at(-1)?.user_id).toBe(STUDENT_ID);
  });

  it("approves marketplace listings and keeps audit fields aligned", async () => {
    const approved = await reviewAdminContent(
      req("/api/v1/admin/content/marketplace/market-1/review", "admin", "POST", {
        status: "approved",
        review_note: "商品信息完整",
      }),
      ctx("marketplace", "market-1")
    );
    const body = await approved.json();
    expect(approved.status).toBe(200);
    expect(body.data.status).toBe("published");
    expect(body.data.audit_status).toBe("approved");
    expect(body.data.audit_provider).toBe("admin");
    expect(body.data.metadata.review.decision).toBe("approved");
    expect(db.notifications.at(-1)?.user_id).toBe(BUSINESS_ID);
  });

  it("rejects content with table-specific status semantics", async () => {
    const rejectedEvent = await reviewAdminContent(
      req("/api/v1/admin/content/events/event-1/review", "admin", "POST", {
        status: "rejected",
      }),
      ctx("events", "event-1")
    );
    const rejectedEventBody = await rejectedEvent.json();
    expect(rejectedEvent.status).toBe(200);
    expect(rejectedEventBody.data.status).toBe("archived");
    expect(rejectedEventBody.data.metadata.review.decision).toBe("rejected");

    const rejectedArtwork = await reviewAdminContent(
      req("/api/v1/admin/content/artworks/artwork-1/review", "admin", "POST", {
        status: "rejected",
      }),
      ctx("artworks", "artwork-1")
    );
    const rejectedArtworkBody = await rejectedArtwork.json();
    expect(rejectedArtwork.status).toBe(200);
    expect(rejectedArtworkBody.data.status).toBe("rejected");
  });
});
