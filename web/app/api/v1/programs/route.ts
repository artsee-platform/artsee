import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/api/require-admin";
import { createServiceClient } from "@/lib/api/supabase-service";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function parseIntParam(raw: string | null, defaultValue: number, min: number, max: number) {
  if (raw === null) return { value: defaultValue };
  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed) || parsed < min || parsed > max) {
    return { error: `参数必须是 ${min}-${max} 之间的整数` };
  }
  return { value: parsed };
}

// GET /api/v1/programs - 获取项目列表
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const schoolId = searchParams.get("school_id");
    const categoryId = searchParams.get("category_id");
    const degreeType = searchParams.get("degree_type");
    const requiresPortfolio = searchParams.get("requires_portfolio");
    const keyword = searchParams.get("keyword")?.trim();
    const status = searchParams.get("status");
    const includeInactive = searchParams.get("include_inactive") === "true";

    const limitCheck = parseIntParam(searchParams.get("limit"), DEFAULT_LIMIT, 1, MAX_LIMIT);
    if (limitCheck.error) {
      return NextResponse.json(
        { success: false, error: `limit ${limitCheck.error}` },
        { status: 400 }
      );
    }
    const offsetCheck = parseIntParam(searchParams.get("offset"), 0, 0, 1000000);
    if (offsetCheck.error) {
      return NextResponse.json(
        { success: false, error: `offset ${offsetCheck.error}` },
        { status: 400 }
      );
    }

    const schoolIdCheck = parseIntParam(schoolId, 0, 1, 1000000000);
    if (schoolId && schoolIdCheck.error) {
      return NextResponse.json(
        { success: false, error: `school_id ${schoolIdCheck.error}` },
        { status: 400 }
      );
    }
    const categoryIdCheck = parseIntParam(categoryId, 0, 1, 1000000000);
    if (categoryId && categoryIdCheck.error) {
      return NextResponse.json(
        { success: false, error: `category_id ${categoryIdCheck.error}` },
        { status: 400 }
      );
    }
    if (requiresPortfolio && !["true", "false"].includes(requiresPortfolio)) {
      return NextResponse.json(
        { success: false, error: "requires_portfolio 必须为 true 或 false" },
        { status: 400 }
      );
    }

    if (includeInactive || status) {
      const auth = await requireAdmin(req);
      if ("response" in auth) return auth.response;
    }

    const limit = limitCheck.value!;
    const offset = offsetCheck.value!;
    const supabase = createServiceClient();
    let query = supabase
      .from("programs")
      .select(`
        *,
        schools!school_id (
          id,
          name_zh,
          name_en,
          logo_url
        )
      `, { count: "exact" })
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq("status", status);
    } else if (!includeInactive) {
      query = query.eq("status", "active");
    }

    if (schoolId) {
      query = query.eq("school_id", schoolIdCheck.value!);
    }

    if (degreeType) {
      query = query.eq("degree_type", degreeType);
    }

    if (keyword) {
      query = query.ilike("program_name", `%${keyword}%`);
    }

    if (requiresPortfolio) {
      query = query.eq("requires_portfolio", requiresPortfolio === "true");
    }

    if (categoryId) {
      query = query.eq("program_art_categories.category_id", categoryIdCheck.value!);
    }

    const { data, error, count } = await query;

    if (error) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      data,
      count,
      pagination: {
        limit,
        offset,
      },
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return NextResponse.json(
      { success: false, error: msg },
      { status: 500 }
    );
  }
}

// POST /api/v1/programs - 创建项目（管理员 Bearer + role=admin）
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req);
  if ("response" in auth) return auth.response;
  try {
    const body = await req.json();
    const supabase = createServiceClient();

    const { data, error } = await supabase
      .from("programs")
      .insert(body)
      .select()
      .single();

    if (error) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      data,
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return NextResponse.json(
      { success: false, error: msg },
      { status: 500 }
    );
  }
}
