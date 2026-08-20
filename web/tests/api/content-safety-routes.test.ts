import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import {
  GET as getCommunityPost,
  PATCH as patchCommunityPost,
} from "@/app/api/v1/community/posts/[id]/route";
import { POST as postCommunityComment } from "@/app/api/v1/community/posts/[id]/comments/route";
import { POST as postCommunityCircle } from "@/app/api/v1/community/circles/route";

type Row = Record<string, unknown>;
type Mode = "select" | "insert" | "update" | "upsert";

const USER_ID = "10000000-0000-4000-8000-000000000001";
const POST_ID = "20000000-0000-4000-8000-000000000001";
const auditMock = vi.hoisted(() => vi.fn());

let posts: Row[] = [];
let comments: Row[] = [];
let circles: Row[] = [];
let circleMembers: Row[] = [];

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) =>
    req.headers.get("authorization") === "Bearer author-token"
      ? ({ id: USER_ID } as { id: string })
      : null,
}));

vi.mock("@/lib/api/authz", () => ({
  requireUser: async (req: NextRequest) =>
    req.headers.get("authorization") === "Bearer author-token"
      ? { user: { id: USER_ID }, profile: { role: "user" } }
      : {
          response: new Response(
            JSON.stringify({ success: false, error: "未授权" }),
            { status: 401 }
          ),
        },
}));

vi.mock("@/lib/api/content-safety", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/api/content-safety")>()),
  auditContent: auditMock,
}));

vi.mock("@/lib/api/plaza-ai-reply", () => ({
  PlazaAiConfigError: class PlazaAiConfigError extends Error {},
  createPlazaAiReplyIfEnabled: vi.fn().mockResolvedValue(null),
}));

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private inFilter: { field: string; values: unknown[] } | null = null;
  private ownerOr: string | null = null;
  private mode: Mode = "select";
  private payload: Row = {};

  constructor(private readonly table: string) {}

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  in(field: string, values: unknown[]) {
    this.inFilter = { field, values };
    return this;
  }

  or(expression: string) {
    const match = expression.match(/author_id\.eq\.([0-9a-f-]+)/i);
    this.ownerOr = match?.[1] ?? null;
    return this;
  }

  order() {
    return this;
  }

  range() {
    return this;
  }

  insert(payload: Row) {
    this.mode = "insert";
    this.payload = payload;
    return this;
  }

  update(payload: Row) {
    this.mode = "update";
    this.payload = payload;
    return this;
  }

  upsert(payload: Row) {
    this.mode = "upsert";
    this.payload = payload;
    return this;
  }

  async maybeSingle() {
    const rows = this.rows().filter((row) => this.matches(row));
    return { data: rows[0] ?? null, error: null };
  }

  async single() {
    if (this.mode === "update") {
      const row = this.rows().find((candidate) => this.matches(candidate));
      if (!row) return { data: null, error: { message: "not found" } };
      Object.assign(row, this.payload);
      return { data: row, error: null };
    }
    if (this.mode === "insert") {
      const collection = this.rows();
      const row = {
        id: `${this.table}-${collection.length + 1}`,
        ...this.payload,
      };
      collection.push(row);
      return { data: row, error: null };
    }
    const row = this.rows().find((candidate) => this.matches(candidate));
    return { data: row ?? null, error: row ? null : { message: "not found" } };
  }

  then(resolve: (value: unknown) => void, reject: (reason?: unknown) => void) {
    return this.execute().then(resolve, reject);
  }

  private async execute() {
    if (this.mode === "upsert") {
      this.rows().push({ id: `${this.table}-${this.rows().length + 1}`, ...this.payload });
      return { data: null, error: null };
    }
    if (this.mode === "update") {
      const row = this.rows().find((candidate) => this.matches(candidate));
      if (row) Object.assign(row, this.payload);
      return { data: row ?? null, error: null };
    }
    return {
      data: this.rows().filter((row) => this.matches(row)),
      error: null,
    };
  }

  private rows(): Row[] {
    if (this.table === "community_posts") return posts;
    if (this.table === "community_post_comments") return comments;
    if (this.table === "community_circles") return circles;
    if (this.table === "community_circle_members") return circleMembers;
    if (this.table === "user_profiles") {
      return [{ id: USER_ID, nickname: "审核测试用户", avatar_url: null }];
    }
    return [];
  }

  private matches(row: Row) {
    const direct = this.filters.every(({ field, value }) => row[field] === value);
    const listed =
      !this.inFilter || this.inFilter.values.includes(row[this.inFilter.field]);
    const visible =
      !this.ownerOr || row.status === "published" || row.author_id === this.ownerOr;
    return direct && listed && visible;
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
    rpc: vi.fn().mockResolvedValue({ error: null }),
  }),
}));

function request(
  path: string,
  options: { method?: string; body?: Row; token?: string } = {}
) {
  const token = options.token;
  return new NextRequest(`http://localhost${path}`, {
    method: options.method ?? "GET",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
}

function postContext() {
  return { params: Promise.resolve({ id: POST_ID }) };
}

function approvedAudit() {
  return {
    provider: "tencent_cloud",
    suggestion: "pass",
    audit_status: "approved",
    items: [],
  };
}

describe("content safety route enforcement", () => {
  beforeEach(() => {
    posts = [
      {
        id: POST_ID,
        author_id: USER_ID,
        title: "原始标题",
        body: "原始正文",
        image_urls: [],
        status: "rejected",
        metadata: {},
      },
    ];
    comments = [];
    circles = [];
    circleMembers = [];
    auditMock.mockReset();
    auditMock.mockResolvedValue(approvedAudit());
  });

  it("does not expose a rejected post to the public", async () => {
    const res = await getCommunityPost(
      request(`/api/v1/community/posts/${POST_ID}`),
      postContext()
    );
    expect(res.status).toBe(404);
  });

  it("still lets the author read their non-public post", async () => {
    const res = await getCommunityPost(
      request(`/api/v1/community/posts/${POST_ID}`, { token: "author-token" }),
      postContext()
    );
    expect(res.status).toBe(200);
  });

  it("re-audits edited post content and derives status server-side", async () => {
    const res = await patchCommunityPost(
      request(`/api/v1/community/posts/${POST_ID}`, {
        method: "PATCH",
        token: "author-token",
        body: { title: "修改后的安全标题" },
      }),
      postContext()
    );
    expect(res.status).toBe(200);
    expect(auditMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: USER_ID,
        text: "修改后的安全标题\n\n原始正文",
        dataId: POST_ID,
      })
    );
    expect(posts[0]).toMatchObject({
      title: "修改后的安全标题",
      status: "published",
      audit_status: "approved",
    });
  });

  it("rejects client-controlled post status", async () => {
    const res = await patchCommunityPost(
      request(`/api/v1/community/posts/${POST_ID}`, {
        method: "PATCH",
        token: "author-token",
        body: { status: "published" },
      }),
      postContext()
    );
    expect(res.status).toBe(400);
    expect(auditMock).not.toHaveBeenCalled();
  });

  it("publishes only comments explicitly approved by moderation", async () => {
    posts[0].status = "published";
    const res = await postCommunityComment(
      request(`/api/v1/community/posts/${POST_ID}/comments`, {
        method: "POST",
        token: "author-token",
        body: { body: "这是一条安全评论" },
      }),
      postContext()
    );
    expect(res.status).toBe(201);
    expect(comments).toHaveLength(1);
    expect(comments[0].status).toBe("published");
  });

  it("does not insert comments that need review", async () => {
    posts[0].status = "published";
    auditMock.mockResolvedValueOnce({
      provider: "tencent_cloud",
      suggestion: "review",
      audit_status: "reviewing",
      items: [],
    });
    const res = await postCommunityComment(
      request(`/api/v1/community/posts/${POST_ID}/comments`, {
        method: "POST",
        token: "author-token",
        body: { body: "需要复审" },
      }),
      postContext()
    );
    expect(res.status).toBe(422);
    expect(comments).toHaveLength(0);
  });

  it("ignores client publication state when creating a circle", async () => {
    const res = await postCommunityCircle(
      request("/api/v1/community/circles", {
        method: "POST",
        token: "author-token",
        body: { title: "安全圈子", status: "published" },
      })
    );
    expect(res.status).toBe(400);
    expect(circles).toHaveLength(0);
  });

  it("creates an approved circle with server-controlled published status", async () => {
    const res = await postCommunityCircle(
      request("/api/v1/community/circles", {
        method: "POST",
        token: "author-token",
        body: {
          title: "安全圈子",
          subtitle: "讨论作品集与院校申请",
          category: "作品集",
        },
      })
    );
    expect(res.status).toBe(201);
    expect(circles[0]).toMatchObject({
      creator_id: USER_ID,
      status: "published",
    });
    expect(circleMembers).toHaveLength(1);
  });
});
