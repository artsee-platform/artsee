import { describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST as postCommunity } from "@/app/api/v1/community/posts/route";
import { GET as getCommunityHotTopics } from "@/app/api/v1/community/hot-topics/route";
import { GET as getPlazaFeed } from "@/app/api/v1/plaza/feed/route";
import { GET as getPlazaPost } from "@/app/api/v1/plaza/posts/[id]/route";
import { POST as postPlazaAiReply } from "@/app/api/v1/plaza/posts/[id]/ai-reply/route";
import { GET as getPaymentProviders } from "@/app/api/v1/payments/providers/route";
import { POST as postAiSearch } from "@/app/api/v1/ai/schools/search/route";
import { POST as postSchoolCompare } from "@/app/api/v1/schools/compare/route";

type MockQuery = {
  select: () => MockQuery;
  eq: () => MockQuery;
  or: () => MockQuery;
  order: () => MockQuery;
  range: () => Promise<{ data: unknown[]; error: null; count?: number }>;
  maybeSingle: () => Promise<{ data: unknown; error: null }>;
  insert: () => {
    select: () => {
      single: () => Promise<{ data: { id: string }; error: null }>;
    };
  };
};

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => {
      if (table === "programs") {
        return {
          select: () => ({
            eq: () => ({
              limit: async () => ({ data: [], error: null }),
            }),
          }),
        };
      }
      if (table === "community_posts") {
        const rows = [
          {
            id: "11111111-1111-4111-8111-111111111111",
            author_id: "22222222-2222-4222-8222-222222222222",
            title: "花 60 万读艺术留学，真的买到未来了吗？",
            body: "预算、城市、作品集和家庭期待被放在同一张桌上。",
            image_urls: ["https://example.com/a.jpg"],
            status: "published",
            like_count: 18,
            comment_count: 7,
            save_count: 3,
            view_count: 120,
            metadata: {
              surface: "plaza",
              source: "plaza_legacy",
              kind: "article",
              group: "留学账本",
              tags: ["预算", "回报"],
            },
            created_at: "2026-07-06T00:00:00Z",
            updated_at: "2026-07-06T00:00:00Z",
          },
        ];
        const query = {} as MockQuery;
        query.select = () => query;
        query.eq = () => query;
        query.or = () => query;
        query.order = () => query;
        query.range = async () => ({ data: rows, error: null });
        query.maybeSingle = async () => ({ data: rows[0], error: null });
        query.insert = () => ({
          select: () => ({
            single: async () => ({ data: { id: "x" }, error: null }),
          }),
        });
        return query;
      }
      if (table === "user_profiles") {
        return {
          select: () => ({
            in: async () => ({
              data: [
                {
                  id: "22222222-2222-4222-8222-222222222222",
                  nickname: "Artsee开发者",
                  avatar_url: null,
                },
              ],
              error: null,
            }),
          }),
        };
      }
      if (table === "community_hot_topics") {
        const query = {} as MockQuery;
        query.select = () => query;
        query.eq = () => query;
        query.or = () => query;
        query.order = () => query;
        query.range = async () => ({
          data: [
            {
              id: "topic-1",
              slug: "ai-art-award-progress-or-cheating",
              tag: "🔥 争议",
              title: "AI绘画拿大奖，这是艺术的进步还是作弊？",
              category: "行业就业",
              participant_count: 156,
              sort_order: 1,
              is_pinned: true,
              answers: [],
              metadata: { theme: "AI科技" },
              created_at: "2026-06-10T00:00:00Z",
            },
          ],
          count: 1,
          error: null,
        });
        query.maybeSingle = async () => ({ data: null, error: null });
        query.insert = () => ({
          select: () => ({
            single: async () => ({ data: { id: "x" }, error: null }),
          }),
        });
        return query;
      }
      if (table === "schools") {
        return {
          select: () => ({
            in: async (_field: string, ids: string[]) => ({
              data: [
                {
                  id: ids[2],
                  name_zh: "中央圣马丁学院",
                  name_en: "Central Saint Martins",
                  city: "伦敦",
                  country: "英国",
                  qs_art_design_rank: 3,
                  program_count: 18,
                  portfolio_difficulty: 5,
                  acceptance_rate: 8,
                  career_resources_rating: 5,
                  tuition_usd_per_year: 36000,
                  city_cost_index: 5,
                },
                {
                  id: ids[0],
                  name_zh: "皇家艺术学院",
                  name_en: "Royal College of Art",
                  city: "伦敦",
                  country: "英国",
                  qs_art_design_rank: 1,
                  program_count: 26,
                  portfolio_difficulty: 5,
                  acceptance_rate: 7,
                  career_resources_rating: 5,
                  tuition_usd_per_year: 42000,
                  city_cost_index: 5,
                },
                {
                  id: ids[1],
                  name_zh: "罗德岛设计学院",
                  name_en: "RISD",
                  city: "普罗维登斯",
                  country: "美国",
                  qs_art_design_rank: 4,
                  program_count: 20,
                  portfolio_difficulty: 5,
                  acceptance_rate: 15,
                  career_resources_rating: 4,
                  tuition_usd_per_year: 58000,
                  city_cost_index: 4,
                },
              ],
              error: null,
            }),
          }),
        };
      }
      if (table === "school_comparisons") {
        return {
          insert: () => ({
            select: () => ({
              single: async () => ({
                data: { id: "comparison-1" },
                error: null,
              }),
            }),
          }),
        };
      }
      return { select: () => ({ eq: () => ({}) }) };
    },
  }),
}));

describe("community POST", () => {
  it("未带 Bearer 返回 401", async () => {
    const req = new NextRequest("http://localhost/api/v1/community/posts", {
      method: "POST",
      body: JSON.stringify({ title: "t", body: "b", image_urls: [] }),
    });
    const res = await postCommunity(req);
    expect(res.status).toBe(401);
  });
});

describe("community hot topics", () => {
  it("返回已发布热议话题列表", async () => {
    const req = new NextRequest("http://localhost/api/v1/community/hot-topics?limit=3");
    const res = await getCommunityHotTopics(req);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.count).toBe(1);
    expect(body.data[0].slug).toBe("ai-art-award-progress-or-cheating");
  });
});

describe("plaza feed", () => {
  it("返回统一的广场 feed item", async () => {
    const req = new NextRequest("http://localhost/api/v1/plaza/feed?limit=5");
    const res = await getPlazaFeed(req);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data[0].surface).toBe("plaza");
    expect(body.data[0].kind).toBe("article");
    expect(body.data[0].group).toBe("留学账本");
    expect(body.data[0].tags).toEqual(["预算", "回报"]);
    expect(body.data[0].user_profiles.nickname).toBe("Artsee开发者");
  });

  it("正常 UUID 可以读取广场帖子详情", async () => {
    const id = "11111111-1111-4111-8111-111111111111";
    const req = new NextRequest(`http://localhost/api/v1/plaza/posts/${id}`);
    const res = await getPlazaPost(req, {
      params: Promise.resolve({ id }),
    });
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.id).toBe(id);
    expect(body.data.surface).toBe("plaza");
  });
});

describe("plaza AI reply", () => {
  it("未登录不能触发 AI 回复", async () => {
    const req = new NextRequest(
      "http://localhost/api/v1/plaza/posts/11111111-1111-4111-8111-111111111111/ai-reply",
      {
        method: "POST",
        body: JSON.stringify({ prompt: "从反方接一句" }),
      }
    );
    const res = await postPlazaAiReply(req, {
      params: Promise.resolve({ id: "11111111-1111-4111-8111-111111111111" }),
    });

    expect(res.status).toBe(401);
  });
});

describe("payment providers", () => {
  it("返回支付渠道能力，不暴露密钥", async () => {
    const prevProvider = process.env.PAYMENT_PROVIDER;
    const prevEndpoint = process.env.PAYMENT_CHECKOUT_ENDPOINT;
    try {
      process.env.PAYMENT_PROVIDER = "wechat_pay";
      process.env.PAYMENT_CHECKOUT_ENDPOINT =
        "https://pay.example.test/checkout";

      const res = await getPaymentProviders();
      const body = await res.json();

      expect(res.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data.configured_provider).toBe("wechat_pay");
      expect(body.data.providers).toContainEqual(
        expect.objectContaining({
          id: "wechat_pay",
          label: "微信支付",
          enabled: true,
        })
      );
      expect(JSON.stringify(body)).not.toContain("SECRET");
    } finally {
      if (prevProvider === undefined) {
        delete process.env.PAYMENT_PROVIDER;
      } else {
        process.env.PAYMENT_PROVIDER = prevProvider;
      }
      if (prevEndpoint === undefined) {
        delete process.env.PAYMENT_CHECKOUT_ENDPOINT;
      } else {
        process.env.PAYMENT_CHECKOUT_ENDPOINT = prevEndpoint;
      }
    }
  });
});

describe("AI schools search", () => {
  it("无 query 返回 400", async () => {
    const req = new NextRequest("http://localhost/api/v1/ai/schools/search", {
      method: "POST",
      body: JSON.stringify({}),
    });
    const res = await postAiSearch(req);
    expect(res.status).toBe(400);
  });

  it("未配置 API Key 返回 503", async () => {
    const prevKey = process.env.OPENAI_API_KEY;
    const prevMoon = process.env.MOONSHOT_API_KEY;
    delete process.env.OPENAI_API_KEY;
    delete process.env.MOONSHOT_API_KEY;

    const req = new NextRequest("http://localhost/api/v1/ai/schools/search", {
      method: "POST",
      body: JSON.stringify({ query: "英国插画硕士" }),
    });
    const res = await postAiSearch(req);
    expect(res.status).toBe(503);

    if (prevKey !== undefined) process.env.OPENAI_API_KEY = prevKey;
    if (prevMoon !== undefined) process.env.MOONSHOT_API_KEY = prevMoon;
  });
});

describe("schools compare", () => {
  it("支持 3 所院校一起生成对比", async () => {
    const ids = [
      "11111111-1111-4111-8111-111111111111",
      "22222222-2222-4222-8222-222222222222",
      "33333333-3333-4333-8333-333333333333",
    ];
    const req = new NextRequest("http://localhost/api/v1/schools/compare", {
      method: "POST",
      body: JSON.stringify({ school_ids: ids }),
    });
    const res = await postSchoolCompare(req);
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.schools).toHaveLength(3);
    expect((body.data.schools as Array<{ id: string }>).map((school) => school.id)).toEqual(ids);
    expect(body.data.scores).toHaveLength(3);
    expect((body.data.rows as Array<{ values: unknown[] }>).every((row) => row.values.length === 3)).toBe(true);
  });
});
