import { NextRequest, NextResponse } from "next/server";
import { requireWorkbenchUser } from "@/lib/api/workbench-access";

type Row = Record<string, unknown>;

const AMAP_GEOCODE_URL = "https://restapi.amap.com/v3/geocode/geo";
const REQUEST_TIMEOUT_MS = 8_000;

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function responseText(value: unknown) {
  if (typeof value === "string") return value.trim();
  if (Array.isArray(value)) {
    return value.map((item) => cleanText(item)).find(Boolean) ?? "";
  }
  return "";
}

function parseLocation(value: unknown) {
  const [longitudeText, latitudeText] = cleanText(value).split(",");
  const longitude = Number(longitudeText);
  const latitude = Number(latitudeText);
  if (
    !Number.isFinite(longitude) ||
    !Number.isFinite(latitude) ||
    longitude < -180 ||
    longitude > 180 ||
    latitude < -90 ||
    latitude > 90
  ) {
    return null;
  }
  return { latitude, longitude };
}

export async function POST(req: NextRequest) {
  const auth = await requireWorkbenchUser(req);
  if ("response" in auth) return auth.response;
  if (!auth.canAccessPlatformPool && auth.manageableOrganizationIds.length === 0) {
    return NextResponse.json(
      { success: false, error: "需要官方组织负责人或管理员权限" },
      { status: 403 }
    );
  }

  const body = (await req.json().catch(() => ({}))) as Row;
  const address = cleanText(body.address);
  const city = cleanText(body.city);
  if (address.length < 2 || address.length > 200) {
    return NextResponse.json(
      { success: false, error: "地址长度需为 2–200 个字符" },
      { status: 400 }
    );
  }
  if (city.length > 50) {
    return NextResponse.json(
      { success: false, error: "城市长度不能超过 50 个字符" },
      { status: 400 }
    );
  }

  const key = cleanText(process.env.AMAP_WEB_SERVICE_KEY);
  if (!key) {
    return NextResponse.json(
      { success: false, error: "高德地图服务尚未配置" },
      { status: 503 }
    );
  }

  const url = new URL(AMAP_GEOCODE_URL);
  url.searchParams.set("key", key);
  url.searchParams.set("address", address);
  url.searchParams.set("output", "JSON");
  if (city) url.searchParams.set("city", city);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const upstream = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: controller.signal,
    });
    const payload = (await upstream.json().catch(() => null)) as Row | null;
    if (!upstream.ok || !payload) {
      return NextResponse.json(
        { success: false, error: "高德地图服务暂时不可用" },
        { status: 502 }
      );
    }
    if (cleanText(payload.status) !== "1") {
      const info = responseText(payload.info) || "地址解析失败";
      return NextResponse.json(
        {
          success: false,
          error: `高德地图：${info}`,
          provider_code: responseText(payload.infocode) || null,
        },
        { status: 422 }
      );
    }

    const geocodes = Array.isArray(payload.geocodes) ? payload.geocodes : [];
    const first = geocodes[0];
    const geocode =
      first && typeof first === "object" && !Array.isArray(first)
        ? (first as Row)
        : null;
    const location = geocode ? parseLocation(geocode.location) : null;
    if (!geocode || !location) {
      return NextResponse.json(
        { success: false, error: "高德地图未找到可用坐标" },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      data: {
        provider: "amap",
        coordinate_system: "gcj02",
        latitude: location.latitude,
        longitude: location.longitude,
        formatted_address: responseText(geocode.formatted_address) || address,
        country: responseText(geocode.country) || null,
        province: responseText(geocode.province) || null,
        city: responseText(geocode.city) || null,
        district: responseText(geocode.district) || null,
        adcode: responseText(geocode.adcode) || null,
        level: responseText(geocode.level) || null,
      },
    });
  } catch (error) {
    const aborted = error instanceof Error && error.name === "AbortError";
    return NextResponse.json(
      {
        success: false,
        error: aborted ? "高德地图请求超时" : "高德地图服务请求失败",
      },
      { status: aborted ? 504 : 502 }
    );
  } finally {
    clearTimeout(timeout);
  }
}
