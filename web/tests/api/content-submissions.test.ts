import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getMyContentSubmissions } from "@/app/api/v1/me/content-submissions/route";
import { PATCH as updateContentSubmission } from "@/app/api/v1/me/content-submissions/[type]/[id]/route";
import { POST as resubmitContentSubmission } from "@/app/api/v1/me/content-submissions/[type]/[id]/resubmit/route";

type Row = Record<string, unknown>;

const USER_ID = "user-1";
const OTHER_ID = "user-2";

const tokenUsers: Record<string, string> = {
  user: USER_ID,
  other: OTHER_ID,
};

const db: Record<string, Row[]> = {
  user_profiles: [],
  events: [],
  opportunities: [],
  artworks: [],
  artist_profiles: [],
  community_posts: [],
};
const removedStoragePaths: string[][] = [];

function resetDb() {
  removedStoragePaths.length = 0;
  db.user_profiles = [
    { id: USER_ID, role: "user", status: "active" },
    { id: OTHER_ID, role: "user", status: "active" },
  ];
  db.events = [
    {
      id: "event-1",
      title: "我的展览",
      status: "reviewing",
      created_by: USER_ID,
      summary: "上海线下",
      created_at: "2026-06-12T10:00:00.000Z",
      updated_at: "2026-06-12T10:00:00.000Z",
      metadata: {},
    },
    {
      id: "event-2",
      title: "别人的展览",
      status: "reviewing",
      created_by: OTHER_ID,
      created_at: "2026-06-12T11:00:00.000Z",
      updated_at: "2026-06-12T11:00:00.000Z",
      metadata: {},
    },
  ];
  db.opportunities = [
    {
      id: "opportunity-1",
      title: "我的机会",
      status: "archived",
      created_by: USER_ID,
      requirements: "作品集",
      created_at: "2026-06-12T09:00:00.000Z",
      updated_at: "2026-06-12T12:00:00.000Z",
      metadata: {
        review: {
          decision: "rejected",
          review_note: "资料不完整",
          reviewed_at: "2026-06-12T12:00:00.000Z",
        },
      },
    },
  ];
  db.artworks = [
    {
      id: "artwork-1",
      title: "我的作品",
      status: "published",
      user_id: USER_ID,
      description: "毕业作品",
      created_at: "2026-06-12T08:00:00.000Z",
      updated_at: "2026-06-12T08:00:00.000Z",
      metadata: {},
    },
  ];
  db.artist_profiles = [];
  db.community_posts = [
    {
      id: "market-1",
      title: "作品集诊断名额",
      status: "reviewing",
      audit_status: "reviewing",
      author_id: USER_ID,
      body: "一对一作品集服务",
      created_at: "2026-06-12T12:30:00.000Z",
      updated_at: "2026-06-12T13:00:00.000Z",
      metadata: { kind: "market" },
    },
    {
      id: "post-1",
      title: "普通广场帖",
      status: "reviewing",
      author_id: USER_ID,
      body: "不是市集商品",
      created_at: "2026-06-12T12:20:00.000Z",
      updated_at: "2026-06-12T13:10:00.000Z",
      metadata: { kind: "article" },
    },
    {
      id: "market-other",
      title: "别人的商品",
      status: "reviewing",
      author_id: OTHER_ID,
      body: "不属于当前用户",
      created_at: "2026-06-12T12:40:00.000Z",
      updated_at: "2026-06-12T13:20:00.000Z",
      metadata: { kind: "market" },
    },
  ];
}

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private rangeStart = 0;
  private rangeEnd: number | null = null;
  private patch: Row | null = null;

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

  update(patch: Row) {
    this.patch = patch;
    return this;
  }

  async maybeSingle() {
    return { data: this.findRows()[0] ?? null, error: null };
  }

  async single() {
    if (!this.patch) {
      const row = this.findRows()[0] ?? null;
      return { data: row, error: row ? null : { message: "not found" } };
    }
    const rows = db[this.table] ?? [];
    const index = rows.findIndex((row) => {
      return this.filters.every(({ field, value }) => fieldValue(row, field) === value);
    });
    if (index < 0) return { data: null, error: { message: "not found" } };
    rows[index] = { ...rows[index], ...this.patch };
    return { data: rows[index], error: null };
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
    return (db[this.table] ?? []).filter((row) => {
      return this.filters.every(({ field, value }) => fieldValue(row, field) === value);
    });
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
    storage: {
      from: () => ({
        remove: vi.fn(async (paths: string[]) => {
          removedStoragePaths.push(paths);
          return { data: [], error: null };
        }),
      }),
    },
  }),
}));

function req(path: string, token: keyof typeof tokenUsers | null) {
  return new NextRequest(`http://localhost${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

function postReq(path: string, token: keyof typeof tokenUsers | null, body: Row = {}) {
  return new NextRequest(`http://localhost${path}`, {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function patchReq(path: string, token: keyof typeof tokenUsers | null, body: Row = {}) {
  return new NextRequest(`http://localhost${path}`, {
    method: "PATCH",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function resubmitCtx(type: string, id: string) {
  return { params: Promise.resolve({ type, id }) };
}

describe("my content submissions", () => {
  beforeEach(resetDb);

  it("requires login", async () => {
    const res = await getMyContentSubmissions(req("/api/v1/me/content-submissions", null));
    expect(res.status).toBe(401);
  });

  it("lists only current user's submissions across content tables", async () => {
    const res = await getMyContentSubmissions(req("/api/v1/me/content-submissions", "user"));
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.map((item: Row) => item.id)).toEqual([
      "market-1",
      "opportunity-1",
      "event-1",
      "artwork-1",
    ]);
    expect(body.count).toBe(4);
    expect(body.data.some((item: Row) => item.id === "post-1")).toBe(false);
    expect(body.data[1].review_decision).toBe("rejected");
    expect(body.data[1].review_note).toBe("资料不完整");
    expect(body.data[0].type).toBe("marketplace");
    expect(body.data[0].editable_fields.some((field: Row) => field.key === "title")).toBe(true);
  });

  it("supports type and status filtering", async () => {
    const res = await getMyContentSubmissions(
      req("/api/v1/me/content-submissions?type=events&status=reviewing", "user")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].type).toBe("events");
    expect(body.data[0].title).toBe("我的展览");

    const marketRes = await getMyContentSubmissions(
      req("/api/v1/me/content-submissions?type=marketplace&status=reviewing", "user")
    );
    const marketBody = await marketRes.json();
    expect(marketRes.status).toBe(200);
    expect(marketBody.data).toHaveLength(1);
    expect(marketBody.data[0].type).toBe("marketplace");
    expect(marketBody.data[0].title).toBe("作品集诊断名额");
  });

  it("lets users resubmit their rejected content", async () => {
    const res = await resubmitContentSubmission(
      postReq("/api/v1/me/content-submissions/opportunities/opportunity-1/resubmit", "user", {
        note: "已补充资料",
      }),
      resubmitCtx("opportunities", "opportunity-1")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.metadata.review.decision).toBe("resubmitted");
    expect(body.data.metadata.review.resubmission_note).toBe("已补充资料");
    expect(body.data.metadata.review_history[0].decision).toBe("rejected");
  });

  it("lets users edit rejected content and submit it for review", async () => {
    const res = await updateContentSubmission(
      patchReq("/api/v1/me/content-submissions/opportunities/opportunity-1", "user", {
        fields: {
          title: "补充后的机会",
          requirements: "已补充完整作品集要求",
          budget_min: "1000",
        },
        note: "已按备注修改",
        supplemental_materials: ["https://example.com/portfolio.pdf"],
      }),
      resubmitCtx("opportunities", "opportunity-1")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.title).toBe("补充后的机会");
    expect(body.data.requirements).toBe("已补充完整作品集要求");
    expect(body.data.budget_min).toBe(1000);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.metadata.review.decision).toBe("edited_resubmitted");
    expect(body.data.metadata.review.resubmission_note).toBe("已按备注修改");
    expect(body.data.metadata.review.supplemental_materials).toEqual([
      "https://example.com/portfolio.pdf",
    ]);
    expect(body.data.metadata.supplemental_materials).toEqual([
      "https://example.com/portfolio.pdf",
    ]);
    expect(body.data.metadata.review_history[0].decision).toBe("rejected");
  });

  it("lets users edit rejected marketplace listings and submit them for manual review", async () => {
    db.community_posts[0] = {
      ...db.community_posts[0],
      status: "rejected",
      audit_status: "rejected",
      metadata: {
        kind: "market",
        review: {
          decision: "rejected",
          review_note: "请补充商品说明",
          reviewed_at: "2026-06-12T14:00:00.000Z",
        },
      },
    };

    const res = await updateContentSubmission(
      patchReq("/api/v1/me/content-submissions/marketplace/market-1", "user", {
        fields: {
          title: "补充后的作品集诊断",
          body: "补充服务内容与交付说明",
        },
        note: "已补充商品说明",
      }),
      resubmitCtx("marketplace", "market-1")
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.title).toBe("补充后的作品集诊断");
    expect(body.data.body).toBe("补充服务内容与交付说明");
    expect(body.data.status).toBe("reviewing");
    expect(body.data.audit_status).toBe("reviewing");
    expect(body.data.metadata.kind).toBe("market");
    expect(body.data.metadata.review.decision).toBe("edited_resubmitted");
  });

  it("removes old owned material objects when users remove material links", async () => {
    const metadata =
      db.opportunities[0].metadata &&
      typeof db.opportunities[0].metadata === "object" &&
      !Array.isArray(db.opportunities[0].metadata)
        ? (db.opportunities[0].metadata as Row)
        : {};
    db.opportunities[0].metadata = {
      ...metadata,
      supplemental_materials: [
        `https://example.supabase.co/storage/v1/object/public/submission-materials/${USER_ID}/submission-materials/opportunities/opportunity-1/old.pdf`,
      ],
    };
    const res = await updateContentSubmission(
      patchReq("/api/v1/me/content-submissions/opportunities/opportunity-1", "user", {
        fields: {
          title: "补充后的机会",
        },
        supplemental_materials: [],
      }),
      resubmitCtx("opportunities", "opportunity-1")
    );
    expect(res.status).toBe(200);
    expect(removedStoragePaths).toEqual([
      [`${USER_ID}/submission-materials/opportunities/opportunity-1/old.pdf`],
    ]);
  });

  it("does not let users resubmit another user's content", async () => {
    const res = await resubmitContentSubmission(
      postReq("/api/v1/me/content-submissions/events/event-2/resubmit", "user"),
      resubmitCtx("events", "event-2")
    );
    expect(res.status).toBe(404);
  });

  it("rejects resubmitting published content", async () => {
    const res = await resubmitContentSubmission(
      postReq("/api/v1/me/content-submissions/artworks/artwork-1/resubmit", "user"),
      resubmitCtx("artworks", "artwork-1")
    );
    expect(res.status).toBe(400);
  });
});
