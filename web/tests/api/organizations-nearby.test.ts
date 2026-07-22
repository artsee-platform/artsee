import { describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET as getNearbyOrganizations } from "@/app/api/v1/organizations/nearby/route";

type Row = Record<string, unknown>;

const organizations: Row[] = [
  {
    id: "org-1",
    name: "国际艺术教育协会",
    type: "official_association",
    status: "active",
    verification_status: "verified",
    city: "上海",
    province: "上海",
    latitude: 31.2304,
    longitude: 121.4737,
    focus_areas: ["uk", "portfolio", "rca"],
    supports_online: true,
    supports_offline: true,
    rating: 4.8,
    review_count: 32,
    contract_count: 6,
    subscription_status: "active",
    subscription_expires_at: "2099-01-01T00:00:00.000Z",
    metadata: { address: "上海市静安区", phone: "021-0000", is_official: true },
  },
  {
    id: "org-2",
    name: "北美院校官方联络处",
    type: "school_official",
    status: "active",
    verification_status: "verified",
    city: "北京",
    province: "北京",
    latitude: 39.9042,
    longitude: 116.4074,
    focus_areas: ["us", "portfolio"],
    supports_online: true,
    supports_offline: false,
    rating: 4.9,
    review_count: 18,
    contract_count: 3,
    subscription_status: "inactive",
    metadata: {},
  },
  {
    id: "org-3",
    name: "暂停机构",
    status: "inactive",
    city: "上海",
    focus_areas: ["uk"],
    supports_online: true,
    supports_offline: true,
    rating: 5,
    review_count: 99,
    subscription_status: "active",
    subscription_expires_at: "2099-01-01T00:00:00.000Z",
    metadata: {},
  },
  {
    id: "org-4",
    name: "过期机构",
    type: "study_abroad_agency",
    status: "active",
    city: "上海",
    focus_areas: ["uk"],
    supports_online: true,
    supports_offline: true,
    rating: 5,
    review_count: 12,
    subscription_status: "active",
    subscription_expires_at: "2020-01-01T00:00:00.000Z",
    metadata: {},
  },
  {
    id: "org-5",
    name: "未续费机构",
    type: "portfolio_training",
    status: "active",
    city: "上海",
    focus_areas: ["uk"],
    supports_online: true,
    supports_offline: true,
    rating: 5,
    review_count: 9,
    subscription_status: "inactive",
    metadata: {},
  },
  {
    id: "org-6",
    name: "商业留学中心",
    type: "study_abroad_agency",
    status: "active",
    city: "上海",
    focus_areas: ["uk"],
    supports_online: true,
    supports_offline: true,
    rating: 5,
    review_count: 24,
    subscription_status: "active",
    subscription_expires_at: "2099-01-01T00:00:00.000Z",
    metadata: {},
  },
  {
    id: "org-7",
    name: "待认证官方协会",
    type: "official_association",
    status: "active",
    verification_status: "pending",
    city: "上海",
    focus_areas: ["uk"],
    supports_online: true,
    supports_offline: true,
    rating: 5,
    review_count: 8,
    subscription_status: "inactive",
    metadata: { is_official: true },
  },
];

class QueryStub {
  private filters: Array<{ field: string; value: unknown }> = [];
  private focusAreas: string[] = [];

  select() {
    return this;
  }

  eq(field: string, value: unknown) {
    this.filters.push({ field, value });
    return this;
  }

  contains(field: string, value: unknown) {
    if (field === "focus_areas" && Array.isArray(value)) {
      this.focusAreas = value.map((item) => item.toString());
    }
    return this;
  }

  async range(start: number, end: number) {
    const rows = organizations.filter((row) => this.matches(row));
    return {
      data: rows.slice(start, end + 1),
      count: rows.length,
      error: null,
    };
  }

  private matches(row: Row) {
    const filtersMatch = this.filters.every(({ field, value }) => row[field] === value);
    if (!filtersMatch) return false;
    if (this.focusAreas.length === 0) return true;
    const focus = Array.isArray(row.focus_areas) ? row.focus_areas : [];
    return this.focusAreas.every((item) => focus.includes(item));
  }
}

vi.mock("@/lib/api/supabase-service", () => ({
  createServiceClient: () => ({
    from: () => new QueryStub(),
  }),
}));

describe("GET /api/v1/organizations/nearby", () => {
  it("公开只返回官方组织列表", async () => {
    const req = new NextRequest("http://localhost/api/v1/organizations/nearby");
    const res = await getNearbyOrganizations(req);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.success).toBe(true);
    expect(body.data).toHaveLength(2);
    expect(body.data[0].status).toBe("active");
    expect(body.data.map((item: Row) => item.id)).not.toContain("org-4");
    expect(body.data.map((item: Row) => item.id)).not.toContain("org-5");
    expect(body.data.map((item: Row) => item.id)).not.toContain("org-6");
    expect(body.data.map((item: Row) => item.id)).not.toContain("org-7");
  });

  it("支持城市、领域、服务方式筛选", async () => {
    const req = new NextRequest(
      "http://localhost/api/v1/organizations/nearby?city=上海&focus_area=uk&service_mode=offline"
    );
    const res = await getNearbyOrganizations(req);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].id).toBe("org-1");
    expect(body.data[0].address).toBeUndefined();
    expect(body.data[0].phone).toBeUndefined();
  });

  it("城市用于优先排序，不会隐藏外地机构", async () => {
    const req = new NextRequest(
      "http://localhost/api/v1/organizations/nearby?city=上海"
    );
    const res = await getNearbyOrganizations(req);
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data).toHaveLength(2);
    expect(body.data[0].id).toBe("org-1");
    expect(body.data[1].id).toBe("org-2");
  });
});
