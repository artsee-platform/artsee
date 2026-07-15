import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postPlaza } from "@/app/api/v1/plaza/posts/route";

type InsertedPost = Record<string, unknown>;

const mocks = vi.hoisted(() => ({
  insertedPosts: [] as InsertedPost[],
  auditContent: vi.fn(),
  recordCreatorContent: vi.fn(),
  createPlazaAiReplyIfEnabled: vi.fn(),
}));

vi.mock("@/lib/api/authz", () => ({
  requireUser: async (req: NextRequest) => {
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/, "");
    if (!token) {
      return {
        response: new Response(JSON.stringify({ success: false, error: "未授权" }), {
          status: 401,
        }),
      };
    }
    return { user: { id: "user-123" }, profile: { role: "user" } };
  },
}));

vi.mock("@/lib/api/content-safety", () => ({
  auditContent: mocks.auditContent,
}));

vi.mock("@/lib/api/creator-level", () => ({
  recordCreatorContent: mocks.recordCreatorContent,
}));

vi.mock("@/lib/api/plaza-ai-reply", () => ({
  PlazaAiConfigError: class PlazaAiConfigError extends Error {
    missing: string[];

    constructor(missing: string[]) {
      super("missing plaza ai config");
      this.missing = missing;
    }
  },
  createPlazaAiReplyIfEnabled: mocks.createPlazaAiReplyIfEnabled,
}));

vi.mock("@/lib/api/plaza", () => ({
  attachPlazaPostState: async (_supabase: unknown, rows: unknown[]) => rows,
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => ({
      insert: (row: InsertedPost) => ({
        select: () => ({
          single: async () => {
            if (table !== "community_posts") {
              return { data: null, error: { message: `unexpected table ${table}` } };
            }
            const inserted = {
              id: `plaza-post-${mocks.insertedPosts.length + 1}`,
              ...row,
            };
            mocks.insertedPosts.push(inserted);
            return { data: inserted, error: null };
          },
        }),
      }),
    }),
  }),
}));

function postReq(body: Record<string, unknown>, token = "valid-token") {
  return new NextRequest("http://localhost/api/v1/plaza/posts", {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function approvedAuditResult() {
  return {
    provider: "tencent_cloud",
    suggestion: "pass",
    audit_status: "approved",
    items: [
      {
        type: "text",
        suggestion: "pass",
        label: "Normal",
        sub_label: null,
        score: 0,
        request_id: "audit-request-1",
        raw: {},
      },
    ],
  };
}

describe("plaza rating target posts", () => {
  beforeEach(() => {
    mocks.insertedPosts = [];
    mocks.auditContent.mockReset();
    mocks.recordCreatorContent.mockReset();
    mocks.createPlazaAiReplyIfEnabled.mockReset();
    mocks.auditContent.mockResolvedValue(approvedAuditResult());
    mocks.recordCreatorContent.mockResolvedValue(null);
    mocks.createPlazaAiReplyIfEnabled.mockResolvedValue(null);
  });

  it("normalizes rating target metadata for allowed categories", async () => {
    const res = await postPlaza(
      postReq({
        title: "宫崎骏",
        body: "导演、动画作者，想看大家怎么评价他的创作影响力。",
        kind: "rating",
        group: "名人",
        tags: ["名人"],
        metadata: {
          quote: "动画也可以是严肃的世界观表达。",
        },
      })
    );
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(body.success).toBe(true);
    expect(mocks.insertedPosts).toHaveLength(1);
    const metadata = mocks.insertedPosts[0].metadata as Record<string, unknown>;
    expect(metadata.kind).toBe("rating");
    expect(metadata.legacy_type).toBe("rating_item");
    expect(metadata.source).toBe("plaza_rating");
    expect(metadata.promote_to_plaza).toBe(true);
    expect(metadata.rating_category).toBe("艺术家");
    expect(metadata.collection).toBe("艺术家口碑");
    expect(metadata.target_name).toBe("宫崎骏");
    expect(metadata.score).toBe("待评");
    expect(metadata.rating_count).toBe("0");
    expect(metadata.source_label).toBe("艺术家评分");
    expect(metadata.tags).toEqual(["艺术家", "名人"]);
  });

  it("rejects unsupported rating target categories", async () => {
    const res = await postPlaza(
      postReq({
        title: "水彩体验课",
        kind: "rating",
        group: "课程",
      })
    );
    const body = await res.json();

    expect(res.status).toBe(400);
    expect(body.success).toBe(false);
    expect(body.error).toContain("评分类型必须是");
    expect(mocks.insertedPosts).toHaveLength(0);
  });

  it("maps legacy category aliases to the current four categories", async () => {
    const res = await postPlaza(
      postReq({
        title: "不是丑赢了，是标准答案失效了",
        kind: "rating",
        group: "金句",
      })
    );

    expect(res.status).toBe(201);
    const metadata = mocks.insertedPosts[0].metadata as Record<string, unknown>;
    expect(metadata.rating_category).toBe("作品");
    expect(metadata.collection).toBe("作品口碑");
  });
});
