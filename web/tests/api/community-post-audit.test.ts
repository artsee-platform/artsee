import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postCommunity } from "@/app/api/v1/community/posts/route";
import { TencentCloudConfigError } from "@/lib/api/tencent-cloud";

type InsertedPost = Record<string, unknown>;
type AuditResult = {
  provider: "tencent_cloud";
  suggestion: "pass" | "review" | "block";
  audit_status: "approved" | "reviewing" | "rejected";
  items: Array<{
    type: "text" | "image";
    suggestion: "pass" | "review" | "block";
    label: string | null;
    sub_label: string | null;
    score: number | null;
    request_id: string | null;
    raw: unknown;
  }>;
};

const mocks = vi.hoisted(() => ({
  auditContent: vi.fn(),
  recordCreatorContent: vi.fn(),
  insertedPosts: [] as InsertedPost[],
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
}));

vi.mock("@/lib/api/content-safety", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/api/content-safety")>()),
  auditContent: mocks.auditContent,
}));

vi.mock("@/lib/api/creator-level", () => ({
  recordCreatorContent: mocks.recordCreatorContent,
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
              id: `post-${mocks.insertedPosts.length + 1}`,
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
  return new NextRequest("http://localhost/api/v1/community/posts", {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}

function auditResult(
  auditStatus: AuditResult["audit_status"],
  item: Partial<AuditResult["items"][number]> = {}
): AuditResult {
  const suggestion =
    auditStatus === "approved"
      ? "pass"
      : auditStatus === "rejected"
        ? "block"
        : "review";

  return {
    provider: "tencent_cloud",
    suggestion,
    audit_status: auditStatus,
    items: [
      {
        type: "text",
        suggestion,
        label: item.label ?? "Normal",
        sub_label: item.sub_label ?? null,
        score: item.score ?? 0,
        request_id: item.request_id ?? "audit-request-1",
        raw: item.raw ?? {},
      },
    ],
  };
}

describe("community post content audit", () => {
  beforeEach(() => {
    mocks.auditContent.mockReset();
    mocks.recordCreatorContent.mockReset();
    mocks.recordCreatorContent.mockResolvedValue(null);
    mocks.insertedPosts = [];
  });

  it("publishes approved posts and records creator content", async () => {
    mocks.auditContent.mockResolvedValueOnce(auditResult("approved"));

    const res = await postCommunity(
      postReq({
        title: "作品集进度",
        body: "今天完成了第一版装置草图",
        image_urls: ["https://assets.example.com/uploads/user-123/community/1.png"],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.status).toBe("published");
    expect(body.data.audit_status).toBe("approved");
    expect(body.data.audit_provider).toBe("tencent_cloud");
    expect(mocks.auditContent).toHaveBeenCalledWith({
      userId: "user-123",
      text: "作品集进度\n\n今天完成了第一版装置草图",
      imageUrls: ["https://assets.example.com/uploads/user-123/community/1.png"],
      scene: "community_post",
    });
    expect(mocks.recordCreatorContent).toHaveBeenCalledWith(
      expect.anything(),
      "user-123",
      { sourceType: "community_post", sourceId: "post-1" }
    );
  });

  it("uses the body preview as title when a text-only post has no title", async () => {
    mocks.auditContent.mockResolvedValueOnce(auditResult("approved"));

    const res = await postCommunity(
      postReq({
        title: "",
        body: "a",
        image_urls: [],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.title).toBe("a");
    expect(mocks.insertedPosts[0].title).toBe("a");
  });

  it("keeps review posts out of the public feed and skips creator credit", async () => {
    mocks.auditContent.mockResolvedValueOnce(
      auditResult("reviewing", { label: "Ad", sub_label: "Suspected" })
    );

    const res = await postCommunity(
      postReq({
        title: "求建议",
        body: "帮我看看这张图",
        image_urls: [],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.status).toBe("reviewing");
    expect(body.data.audit_status).toBe("reviewing");
    expect(body.data.audit_reason).toBe("Ad/Suspected");
    expect(mocks.recordCreatorContent).not.toHaveBeenCalled();
  });

  it("stores rejected audit results without publishing", async () => {
    mocks.auditContent.mockResolvedValueOnce(
      auditResult("rejected", { label: "Illegal", sub_label: "Sensitive", score: 98 })
    );

    const res = await postCommunity(
      postReq({
        title: "作品分享",
        body: "文本",
        image_urls: [],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.data.status).toBe("rejected");
    expect(body.data.audit_status).toBe("rejected");
    expect(body.data.audit_reason).toBe("Illegal/Sensitive");
    expect(body.data.audit_metadata.suggestion).toBe("block");
    expect(mocks.recordCreatorContent).not.toHaveBeenCalled();
  });

  it("fails closed when Tencent Cloud credentials are missing", async () => {
    mocks.auditContent.mockRejectedValueOnce(
      new TencentCloudConfigError(["TENCENT_CLOUD_SECRET_ID"])
    );

    const res = await postCommunity(
      postReq({
        title: "作品分享",
        body: "文本",
        image_urls: [],
      })
    );
    const body = await res.json();

    expect(res.status).toBe(503);
    expect(body.missing).toEqual(["TENCENT_CLOUD_SECRET_ID"]);
    expect(mocks.insertedPosts).toHaveLength(0);
  });
});
