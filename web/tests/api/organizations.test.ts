import { describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET, POST } from "@/app/api/v1/me/organizations/route";
import { PATCH } from "@/app/api/v1/me/organizations/[id]/route";

const ORG_ID = "50000000-0000-4000-8000-000000000001";
let lastOrganizationUpdate: Record<string, unknown> | null = null;
let lastOrganizationInsert: Record<string, unknown> | null = null;

vi.mock("@/lib/api/auth-user", () => ({
  getUserFromBearer: async (req: NextRequest) => {
    const h = req.headers.get("authorization");
    if (h === "Bearer valid-token") return { id: "user-123" } as any;
    return null;
  },
}));

vi.mock("@/lib/api/workbench-access", () => ({
  requireWorkbenchUser: async (req: NextRequest) => {
    const h = req.headers.get("authorization");
    if (h === "Bearer owner-token") {
      return {
        user: { id: "owner-user" },
        canAccessPlatformPool: false,
        organizationIds: [ORG_ID],
        manageableOrganizationIds: [ORG_ID],
        memberIds: ["member-owner"],
        memberships: [
          {
            id: "member-owner",
            organization_id: ORG_ID,
            user_id: "owner-user",
            role: "owner",
            status: "active",
          },
        ],
      };
    }
    if (h === "Bearer advisor-token") {
      return {
        user: { id: "advisor-user" },
        canAccessPlatformPool: false,
        organizationIds: [ORG_ID],
        manageableOrganizationIds: [],
        memberIds: ["member-advisor"],
        memberships: [
          {
            id: "member-advisor",
            organization_id: ORG_ID,
            user_id: "advisor-user",
            role: "advisor",
            status: "active",
          },
        ],
      };
    }
    return {
      response: Response.json({ success: false, error: "未授权" }, { status: 401 }),
    };
  },
}));

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: (table: string) => {
      if (table === "organization_members") {
        const query: any = {};
        query.select = () => query;
        query.eq = () => query;
        query.order = () => query;
        const result = {
          data: [
            {
              role: "owner",
              status: "active",
              organization: {
                id: ORG_ID,
                name: "艺见美术馆",
                type: "gallery_exhibition",
                subscription_status: "active",
                subscription_expires_at: "2020-01-01T00:00:00.000Z",
              },
            },
          ],
          count: 1,
          error: null,
        };
        query.range = async () => result;
        query.then = (
          onfulfilled?: (value: typeof result) => unknown,
          onrejected?: (reason: unknown) => unknown
        ) => Promise.resolve(result).then(onfulfilled, onrejected);
        query.insert = () => ({ error: null });
        return query;
      }
      if (table === "organizations") {
        const current = {
          id: ORG_ID,
          name: "艺见美术馆",
          type: "gallery_exhibition",
          metadata: {
            logo_url: "https://cdn.example.test/logo.png",
            summary: "旧简介",
          },
        };
        const query: any = {};
        query.insert = (payload: Record<string, unknown>) => {
          lastOrganizationInsert = payload;
          return {
            select: () => ({
              single: async () => ({
                data: { id: "org-123", name: "艺见美术馆", ...payload },
                error: null,
              }),
            }),
          };
        };
        query.select = () => query;
        query.eq = () => query;
        query.maybeSingle = async () => ({ data: current, error: null });
        query.update = (payload: Record<string, unknown>) => {
          lastOrganizationUpdate = payload;
          return {
            eq: () => ({
              select: () => ({
                single: async () => ({
                  data: {
                    ...current,
                    ...payload,
                  },
                  error: null,
                }),
              }),
            }),
          };
        };
        return query;
      }
      return {};
    },
  }),
}));

function ctx(id = ORG_ID) {
  return { params: Promise.resolve({ id }) };
}

describe("GET /api/v1/me/organizations", () => {
  it("未带 Bearer Token 返回 401", async () => {
    const req = new NextRequest("http://localhost/api/v1/me/organizations");
    const res = await GET(req);
    expect(res.status).toBe(401);
  });

  it("返回当前用户组织列表", async () => {
    const req = new NextRequest("http://localhost/api/v1/me/organizations", {
      headers: { authorization: "Bearer valid-token" },
    });
    const res = await GET(req);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.count).toBe(1);
    expect(body.data[0].organization.stored_subscription_status).toBe("active");
    expect(body.data[0].organization.subscription_status).toBe("expired");
  });
});

describe("POST /api/v1/me/organizations", () => {
  it("缺少机构名称返回 400", async () => {
    const req = new NextRequest("http://localhost/api/v1/me/organizations", {
      method: "POST",
      headers: { authorization: "Bearer valid-token" },
      body: JSON.stringify({}),
    });
    const res = await POST(req);
    expect(res.status).toBe(400);
  });

  it("创建机构后返回 owner membership", async () => {
    lastOrganizationInsert = null;
    const req = new NextRequest("http://localhost/api/v1/me/organizations", {
      method: "POST",
      headers: { authorization: "Bearer valid-token" },
      body: JSON.stringify({ name: "艺见美术馆", type: "gallery_exhibition" }),
    });
    const res = await POST(req);
    const body = await res.json();
    expect(res.status).toBe(201);
    expect(body.success).toBe(true);
    expect(body.data.role).toBe("owner");
    expect(body.data.organization.id).toBe("org-123");
    expect(lastOrganizationInsert).toMatchObject({
      type: "gallery_exhibition",
    });
  });

  it("不再允许创建旧留学机构类型", async () => {
    const req = new NextRequest("http://localhost/api/v1/me/organizations", {
      method: "POST",
      headers: { authorization: "Bearer valid-token" },
      body: JSON.stringify({ name: "旧留学机构", type: "study_abroad_agency" }),
    });
    const res = await POST(req);
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.error).toBe("该机构类型已下线");
  });
});

describe("PATCH /api/v1/me/organizations/:id", () => {
  it("未登录返回 401", async () => {
    const req = new NextRequest(`http://localhost/api/v1/me/organizations/${ORG_ID}`, {
      method: "PATCH",
      body: JSON.stringify({ name: "新机构" }),
    });
    const res = await PATCH(req, ctx());
    expect(res.status).toBe(401);
  });

  it("非 owner/admin 成员不能更新机构资料", async () => {
    const req = new NextRequest(`http://localhost/api/v1/me/organizations/${ORG_ID}`, {
      method: "PATCH",
      headers: { authorization: "Bearer advisor-token" },
      body: JSON.stringify({ name: "新机构" }),
    });
    const res = await PATCH(req, ctx());
    expect(res.status).toBe(403);
  });

  it("owner 可更新公开资料、筛选字段并合并 metadata", async () => {
    lastOrganizationUpdate = null;
    const req = new NextRequest(`http://localhost/api/v1/me/organizations/${ORG_ID}`, {
      method: "PATCH",
      headers: { authorization: "Bearer owner-token" },
      body: JSON.stringify({
        name: " 艺见伦敦申请中心 ",
        city: "上海",
        province: "上海",
        focus_areas: ["uk", "portfolio", ""],
        supports_online: true,
        supports_offline: true,
        metadata: {
          summary: "专注英国艺术院校申请",
          address: "上海市静安区 88 号",
          phone: "021-0000",
        },
      }),
    });
    const res = await PATCH(req, ctx());
    const body = await res.json();

    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data.role).toBe("owner");
    expect(body.data.organization.name).toBe("艺见伦敦申请中心");
    expect(body.data.organization.focus_areas).toEqual(["uk", "portfolio"]);
    expect(lastOrganizationUpdate).not.toBeNull();
    const update: Record<string, unknown> = lastOrganizationUpdate ?? {};
    expect(update.metadata).toMatchObject({
      logo_url: "https://cdn.example.test/logo.png",
      summary: "专注英国艺术院校申请",
      address: "上海市静安区 88 号",
      phone: "021-0000",
    });
  });

  it("不再允许把机构改成旧留学机构类型", async () => {
    const req = new NextRequest(`http://localhost/api/v1/me/organizations/${ORG_ID}`, {
      method: "PATCH",
      headers: { authorization: "Bearer owner-token" },
      body: JSON.stringify({ type: "portfolio_training" }),
    });
    const res = await PATCH(req, ctx());
    const body = await res.json();
    expect(res.status).toBe(400);
    expect(body.error).toBe("该机构类型已下线");
  });
});
