import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import {
  POST as likeAnswer,
} from "@/app/api/v1/community/hot-topics/[id]/answers/[answerIndex]/like/route";
import {
  POST as commentAnswer,
} from "@/app/api/v1/community/hot-topics/[id]/answers/[answerIndex]/comments/route";

type Row = Record<string, unknown>;
type Ctx = { params: Promise<{ id: string; answerIndex: string }> };

const USER_ID = "10000000-0000-4000-8000-000000000001";
const TOPIC_ID = "20000000-0000-4000-8000-000000000001";
const auditMock = vi.hoisted(() => vi.fn());

let likes: Row[] = [];
let comments: Row[] = [];

const topics: Row[] = [
  {
    id: TOPIC_ID,
    status: "published",
    answers: [
      { stance: "正方", content: "AI 是工具" },
      { stance: "反方", content: "需要边界" },
    ],
  },
];

const profiles: Row[] = [
  { id: USER_ID, nickname: "测试用户", avatar_url: "https://example.test/a.png" },
];

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const h = req.headers.get("authorization");
    if (h === "Bearer valid-token") return { id: USER_ID } as { id: string };
    return null;
  },
}));

vi.mock("@/lib/api/content-safety", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/api/content-safety")>()),
  auditContent: auditMock,
}));

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private inFilter: { field: string; values: unknown[] } | null = null;
  private mode: "select" | "delete" = "select";
  private payload: Row | null = null;
  private head = false;

  constructor(private readonly table: string) {}

  select(_columns?: string, options?: { count?: string; head?: boolean }) {
    this.head = options?.head === true;
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

  order() {
    return this;
  }

  range() {
    return this;
  }

  upsert(payload: Row) {
    if (this.table === "community_hot_topic_answer_likes") {
      const exists = likes.some(
        (row) =>
          row.topic_id === payload.topic_id &&
          row.answer_index === payload.answer_index &&
          row.user_id === payload.user_id
      );
      if (!exists) likes.push({ id: `like-${likes.length + 1}`, ...payload });
    }
    return Promise.resolve({ error: null });
  }

  insert(payload: Row) {
    this.payload = payload;
    return this;
  }

  delete() {
    this.mode = "delete";
    return this;
  }

  async maybeSingle() {
    const rows = this.rows().filter((row) => this.matches(row));
    return { data: rows[0] ?? null, error: null };
  }

  async single() {
    if (this.table === "community_hot_topic_answer_comments" && this.payload) {
      const row = { id: `comment-${comments.length + 1}`, ...this.payload };
      comments.push(row);
      return { data: row, error: null };
    }
    return { data: null, error: null };
  }

  then(resolve: (value: unknown) => void, reject: (reason?: unknown) => void) {
    return this.execute().then(resolve, reject);
  }

  private async execute() {
    if (this.mode === "delete" && this.table === "community_hot_topic_answer_likes") {
      likes = likes.filter((row) => !this.matches(row));
      return { data: null, error: null };
    }
    const rows = this.rows().filter((row) => this.matches(row));
    if (this.head) return { data: null, count: rows.length, error: null };
    return { data: rows, count: rows.length, error: null };
  }

  private rows() {
    return {
      community_hot_topics: topics,
      community_hot_topic_answer_likes: likes,
      community_hot_topic_answer_comments: comments,
      user_profiles: profiles,
    }[this.table] ?? [];
  }

  private matches(row: Row) {
    const eqMatches = this.filters.every(({ field, value }) => row[field] === value);
    const inMatches =
      !this.inFilter || this.inFilter.values.includes(row[this.inFilter.field]);
    return eqMatches && inMatches;
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => new QueryStub(table),
  }),
}));

function req(body?: Row) {
  return new NextRequest("http://localhost/api/v1/community/hot-topics/x", {
    method: "POST",
    headers: { authorization: "Bearer valid-token" },
    body: body ? JSON.stringify(body) : undefined,
  });
}

function ctx(answerIndex: string) {
  return { params: Promise.resolve({ id: TOPIC_ID, answerIndex }) } satisfies Ctx;
}

describe("hot topic answer interactions", () => {
  beforeEach(() => {
    likes = [];
    comments = [];
    auditMock.mockReset();
    auditMock.mockResolvedValue({
      provider: "tencent_cloud",
      suggestion: "pass",
      audit_status: "approved",
      items: [],
    });
  });

  it("likes a published hot topic answer", async () => {
    const res = await likeAnswer(req(), ctx("0"));
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data).toMatchObject({ liked: true, like_count: 1 });
    expect(likes).toHaveLength(1);
  });

  it("creates a comment with attached author profile", async () => {
    const res = await commentAnswer(req({ body: "说得很清楚" }), ctx("1"));
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(body.data.body).toBe("说得很清楚");
    expect(body.data.user_profiles.nickname).toBe("测试用户");
    expect(body.comment_count).toBe(1);
    expect(auditMock).toHaveBeenCalledWith({
      userId: USER_ID,
      text: "说得很清楚",
      scene: "hot_topic_comment",
      dataId: `hot-${TOPIC_ID}-1`,
    });
  });

  it("does not publish a comment that needs review", async () => {
    auditMock.mockResolvedValueOnce({
      provider: "tencent_cloud",
      suggestion: "review",
      audit_status: "reviewing",
      items: [],
    });

    const res = await commentAnswer(req({ body: "待复审内容" }), ctx("1"));
    expect(res.status).toBe(422);
    expect(comments).toHaveLength(0);
  });

  it("rejects unknown answer indexes", async () => {
    const res = await likeAnswer(req(), ctx("9"));
    const body = await res.json();

    expect(res.status).toBe(404);
    expect(body.error).toBe("未找到");
  });
});
