import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/api/require-admin";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!id || typeof id !== "string") {
      return NextResponse.json({ success: false, error: "无效 id" }, { status: 400 });
    }
    const supabase = createServiceClient();
    
    // 1. 获取院校基础信息
    const { data: school, error: schoolError } = await supabase
      .from("schools")
      .select("*")
      .eq("id", id)
      .maybeSingle();
    
    if (schoolError) {
      return NextResponse.json({ success: false, error: schoolError.message }, { status: 500 });
    }
    if (!school) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }
    
    // 2. 获取专业列表（含分类）
    const { data: programs } = await supabase
      .from("programs")
      .select(`
        id,
        program_name,
        degree_type,
        duration_months,
        requires_portfolio,
        tuition_fee,
        application_deadline,
        status
      `)
      .eq("school_id", id)
      .eq("status", "active")
      .order("created_at", { ascending: false });
    
    // 3. 获取申请文档（如果表存在）
    const { data: documents } = await supabase
      .from("school_documents")
      .select("id, title, content, document_type, created_at")
      .eq("school_id", id)
      .order("created_at", { ascending: false })
      .limit(20);
    
    // 4. 获取媒体资源状态（如果表存在）
    const { data: mediaStatus } = await supabase
      .from("school_media_status")
      .select("*")
      .eq("school_id", id)
      .maybeSingle();
    
    // 5. 获取资源统计（如果表存在）
    const { data: metrics } = await supabase
      .from("school_resource_metrics")
      .select("*")
      .eq("school_id", id)
      .maybeSingle();
    
    // 6. 构建完整响应
    const enrichedData = {
      ...school,
      programs: programs || [],
      documents: documents || [],
      media: mediaStatus || {
        has_logo: !!school.logo_url,
        has_banner: false,
        has_gallery: false,
      },
      metrics: metrics || {
        total_programs: programs?.length || 0,
        total_documents: documents?.length || 0,
        total_media: 0,
      },
    };
    
    return NextResponse.json({ success: true, data: enrichedData });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export async function PATCH(req: NextRequest, ctx: Ctx) {
  const admin = await requireAdmin(req);
  if ("response" in admin) return admin.response;
  try {
    const { id } = await ctx.params;
    if (!id || typeof id !== "string") {
      return NextResponse.json({ success: false, error: "无效 id" }, { status: 400 });
    }
    const body = await req.json();
    const supabase = createServiceClient();
    const { data, error } = await supabase.from("schools").update(body).eq("id", id).select().single();
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, ctx: Ctx) {
  const admin = await requireAdmin(_req);
  if ("response" in admin) return admin.response;
  try {
    const { id } = await ctx.params;
    if (!id || typeof id !== "string") {
      return NextResponse.json({ success: false, error: "无效 id" }, { status: 400 });
    }
    const supabase = createServiceClient();
    const { error } = await supabase.from("schools").delete().eq("id", id);
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
