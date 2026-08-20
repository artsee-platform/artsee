import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST } from "@/app/api/v1/maps/geocode/route";

const fetchMock = vi.fn();

vi.mock("@/lib/api/workbench-access", () => ({
  requireWorkbenchUser: async (req: NextRequest) => {
    const token = req.headers.get("authorization");
    if (token === "Bearer owner-token") {
      return {
        user: { id: "owner-user" },
        canAccessPlatformPool: false,
        organizationIds: ["org-1"],
        manageableOrganizationIds: ["org-1"],
        memberIds: ["member-1"],
        memberships: [],
      };
    }
    if (token === "Bearer advisor-token") {
      return {
        user: { id: "advisor-user" },
        canAccessPlatformPool: false,
        organizationIds: ["org-1"],
        manageableOrganizationIds: [],
        memberIds: ["member-2"],
        memberships: [],
      };
    }
    return {
      response: Response.json(
        { success: false, error: "未授权" },
        { status: 401 }
      ),
    };
  },
}));

function request(body: Record<string, unknown>, token = "owner-token") {
  return new NextRequest("http://localhost/api/v1/maps/geocode", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

describe("POST /api/v1/maps/geocode", () => {
  beforeEach(() => {
    vi.stubEnv("AMAP_WEB_SERVICE_KEY", "test-amap-key");
    vi.stubGlobal("fetch", fetchMock);
    fetchMock.mockReset();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("未登录返回 401", async () => {
    const res = await POST(request({ address: "上海市静安区南京西路" }, "bad"));
    expect(res.status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("非负责人或管理员返回 403", async () => {
    const res = await POST(
      request({ address: "上海市静安区南京西路" }, "advisor-token")
    );
    expect(res.status).toBe(403);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("通过高德解析地址并返回标准化坐标", async () => {
    fetchMock.mockResolvedValue(
      Response.json({
        status: "1",
        info: "OK",
        infocode: "10000",
        count: "1",
        geocodes: [
          {
            formatted_address: "上海市静安区南京西路",
            country: "中国",
            province: "上海市",
            city: "上海市",
            district: "静安区",
            adcode: "310106",
            location: "121.459384,31.229251",
            level: "道路",
          },
        ],
      })
    );

    const res = await POST(
      request({ address: "静安区南京西路", city: "上海" })
    );
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data).toMatchObject({
      provider: "amap",
      coordinate_system: "gcj02",
      latitude: 31.229251,
      longitude: 121.459384,
      city: "上海市",
      district: "静安区",
    });

    const [calledUrl, options] = fetchMock.mock.calls[0];
    const url = new URL(calledUrl.toString());
    expect(url.origin + url.pathname).toBe(
      "https://restapi.amap.com/v3/geocode/geo"
    );
    expect(url.searchParams.get("address")).toBe("静安区南京西路");
    expect(url.searchParams.get("city")).toBe("上海");
    expect(url.searchParams.get("key")).toBe("test-amap-key");
    expect(options).toMatchObject({ method: "GET", cache: "no-store" });
  });

  it("未配置高德 Key 返回 503", async () => {
    vi.stubEnv("AMAP_WEB_SERVICE_KEY", "");
    const res = await POST(request({ address: "上海市静安区南京西路" }));
    expect(res.status).toBe(503);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("拒绝无效地址且不会消耗高德配额", async () => {
    const res = await POST(request({ address: " " }));
    expect(res.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("高德返回失败时输出可读错误", async () => {
    fetchMock.mockResolvedValue(
      Response.json({
        status: "0",
        info: "INVALID_USER_KEY",
        infocode: "10001",
        geocodes: [],
      })
    );
    const res = await POST(request({ address: "上海市静安区南京西路" }));
    const body = await res.json();
    expect(res.status).toBe(422);
    expect(body.error).toBe("高德地图：INVALID_USER_KEY");
    expect(body.provider_code).toBe("10001");
  });
});
