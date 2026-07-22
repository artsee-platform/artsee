import { NextRequest, NextResponse } from "next/server";
import { isPublicOfficialOrganization } from "@/lib/api/organization-visibility";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";

type Row = Record<string, unknown>;

const SORT_VALUES = new Set(["comprehensive", "distance", "rating", "match"]);
function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function boolValue(value: unknown) {
  if (typeof value === "boolean") return value;
  const text = cleanText(value).toLowerCase();
  if (["true", "1", "yes"].includes(text)) return true;
  if (["false", "0", "no"].includes(text)) return false;
  return null;
}

function stringList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanText(item))
    .filter(Boolean);
}

function objectValue(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Row;
}

function isMissingOrganizationSchema(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const err = error as { code?: string; message?: string };
  return (
    err.code === "42P01" ||
    err.code === "42703" ||
    err.code === "PGRST204" ||
    err.code === "PGRST205" ||
    Boolean(err.message?.includes("organizations")) ||
    Boolean(err.message?.includes("schema cache"))
  );
}

function distanceKm(
  originLat: number | null,
  originLon: number | null,
  targetLat: unknown,
  targetLon: unknown
) {
  const lat2 = numberValue(targetLat);
  const lon2 = numberValue(targetLon);
  if (originLat == null || originLon == null || lat2 == null || lon2 == null) {
    return null;
  }
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const radius = 6371;
  const dLat = toRad(lat2 - originLat);
  const dLon = toRad(lon2 - originLon);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(originLat)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return Math.round(radius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 10) / 10;
}

function normalizedFocusTerms(row: Row) {
  const metadata = objectValue(row.metadata);
  return [
    ...stringList(row.focus_areas),
    ...stringList(metadata.focus_areas),
    cleanText(metadata.school_id),
    cleanText(metadata.school_name),
  ]
    .filter(Boolean)
    .map((item) => item.toLowerCase());
}

function matchScore(row: Row, requestedTerms: string[]) {
  if (requestedTerms.length === 0) return 0;
  const focusTerms = normalizedFocusTerms(row);
  if (focusTerms.length === 0) return 0;
  return requestedTerms.reduce((score, term) => {
    const lower = term.toLowerCase();
    if (!lower) return score;
    const matched = focusTerms.some(
      (focus) => focus === lower || focus.includes(lower) || lower.includes(focus)
    );
    return score + (matched ? 1 : 0);
  }, 0);
}

function distanceScore(row: Row, city: string, province: string, distance: number | null) {
  if (distance != null) return Math.max(0, 100 - Math.min(distance, 100));
  if (city && cleanText(row.city) === city) return 100;
  if (province && cleanText(row.province) === province) return 70;
  return 35;
}

function normalizeOrganization(
  row: Row,
  options: {
    city: string;
    province: string;
    requestedTerms: string[];
    latitude: number | null;
    longitude: number | null;
  }
) {
  const metadata = objectValue(row.metadata);
  const distance = distanceKm(
    options.latitude,
    options.longitude,
    row.latitude,
    row.longitude
  );
  const rating = numberValue(row.rating) ?? 0;
  const reviews = numberValue(row.review_count) ?? 0;
  const matches = matchScore(row, options.requestedTerms);
  const locationScore = distanceScore(row, options.city, options.province, distance);
  const rankScore = locationScore * 0.42 + rating * 12 + Math.min(reviews, 100) * 0.08 + matches * 18;

  return {
    ...row,
    avatar_url:
      cleanText(metadata.avatar_url) ||
      cleanText(metadata.logo_url) ||
      cleanText(metadata.image_url) ||
      null,
    focus_areas: stringList(row.focus_areas),
    supports_online: boolValue(row.supports_online) ?? true,
    supports_offline: boolValue(row.supports_offline) ?? false,
    rating,
    review_count: Math.trunc(reviews),
    contract_count: Math.trunc(numberValue(row.contract_count) ?? 0),
    distance_km: distance,
    match_score: matches,
    rank_score: Math.round(rankScore * 100) / 100,
  };
}

function compareRows(sort: string) {
  return (a: Row, b: Row) => {
    if (sort === "distance") {
      const ad = numberValue(a.distance_km) ?? Number.POSITIVE_INFINITY;
      const bd = numberValue(b.distance_km) ?? Number.POSITIVE_INFINITY;
      if (ad !== bd) return ad - bd;
    }
    if (sort === "rating") {
      const ar = numberValue(a.rating) ?? 0;
      const br = numberValue(b.rating) ?? 0;
      if (ar !== br) return br - ar;
    }
    if (sort === "match") {
      const am = numberValue(a.match_score) ?? 0;
      const bm = numberValue(b.match_score) ?? 0;
      if (am !== bm) return bm - am;
    }
    const as = numberValue(a.rank_score) ?? 0;
    const bs = numberValue(b.rank_score) ?? 0;
    if (as !== bs) return bs - as;
    return (numberValue(b.rating) ?? 0) - (numberValue(a.rating) ?? 0);
  };
}

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const city = cleanText(searchParams.get("city"));
    const province = cleanText(searchParams.get("province"));
    const serviceMode = cleanText(searchParams.get("service_mode"));
    const focusArea = cleanText(searchParams.get("focus_area"));
    const schoolId = cleanText(searchParams.get("school_id"));
    const schoolName = cleanText(searchParams.get("school_name"));
    const latitude = numberValue(searchParams.get("latitude"));
    const longitude = numberValue(searchParams.get("longitude"));
    const sortParam = cleanText(searchParams.get("sort"));
    const sort = SORT_VALUES.has(sortParam) ? sortParam : "comprehensive";
    const requestedTerms = [focusArea, schoolId, schoolName].filter(Boolean);

    const supabase = createServiceClient();
    let query = supabase
      .from("organizations")
      .select(
        "id,owner_user_id,name,type,status,verification_status,metadata,city,province,latitude,longitude,focus_areas,supports_online,supports_offline,rating,review_count,contract_count,subscription_status,subscription_expires_at,created_at,updated_at",
        { count: "exact" }
      )
      .eq("status", "active");

    if (serviceMode === "online") query = query.eq("supports_online", true);
    if (serviceMode === "offline") query = query.eq("supports_offline", true);
    if (focusArea) query = query.contains("focus_areas", [focusArea]);

    const fetchLimit = Math.min(Math.max(offset + limit, 100), 500);
    const { data, error } = await query.range(0, fetchLimit - 1);

    if (error) {
      if (isMissingOrganizationSchema(error)) {
        return NextResponse.json({
          success: true,
          data: [],
          count: 0,
          pagination: { limit, offset },
          schema_ready: false,
        });
      }
      return errorResponse(error);
    }

    const normalized = (data ?? [])
      .filter((row) => isPublicOfficialOrganization(row as Row))
      .map((row) =>
        normalizeOrganization(row as Row, {
          city,
          province,
          requestedTerms,
          latitude,
          longitude,
        })
      )
      .sort(compareRows(sort));
    const page = normalized.slice(offset, offset + limit);

    return NextResponse.json({
      success: true,
      data: page,
      count: normalized.length,
      pagination: { limit, offset },
      filters: {
        city: city || null,
        province: province || null,
        focus_area: focusArea || null,
        service_mode: serviceMode || null,
        school_id: schoolId || null,
        school_name: schoolName || null,
        sort,
      },
      schema_ready: true,
    });
  } catch (e) {
    return errorResponse(e);
  }
}
