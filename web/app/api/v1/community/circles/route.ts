import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { requireUser } from "@/lib/api/authz";
import { auditContent, collectAuditText } from "@/lib/api/content-safety";
import {
  contentSafetyErrorResponse,
  rejectedAuditResponse,
} from "@/lib/api/content-safety-http";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";
import { recordUploadAuditResults } from "@/lib/api/upload-audit";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const supabase = createServiceClient();
    let query = supabase
      .from("community_circles")
      .select("*", { count: "exact" })
      .eq("status", "published")
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    const category = searchParams.get("category")?.trim();
    const keyword = searchParams.get("keyword")?.trim();
    if (category) query = query.eq("category", category);
    if (keyword) query = query.ilike("title", `%${keyword}%`);

    const { data, error, count } = await query;
    if (error) return errorResponse(error);
    const circles = data ?? [];
    const user = await getUserFromBearer(req);
    let membershipMap: Record<string, string> = {};
    if (user && circles.length > 0) {
      const ids = circles.map((circle: { id: string }) => circle.id);
      const { data: memberships } = await supabase
        .from("community_circle_members")
        .select("circle_id, status")
        .eq("user_id", user.id)
        .in("circle_id", ids);
      membershipMap = Object.fromEntries(
        (memberships ?? []).map((item: { circle_id: string; status: string }) => [
          item.circle_id,
          item.status,
        ])
      );
    }
    return NextResponse.json({
      success: true,
      data: circles.map((circle: Record<string, unknown>) => ({
        ...circle,
        join_status:
          membershipMap[String(circle.id)] ??
          (user && circle.creator_id === user.id ? "joined" : null),
      })),
      count,
      pagination: { limit, offset },
    });
  } catch (e) {
    return errorResponse(e);
  }
}

export async function POST(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = await req.json();
    const title = String(body.title ?? "").trim();
    if (!title) {
      return NextResponse.json({ success: false, error: "请填写圈子名称" }, { status: 400 });
    }
    if (body.status !== undefined) {
      return NextResponse.json(
        { success: false, error: "圈子状态不能由客户端直接修改" },
        { status: 400 }
      );
    }

    const subtitle = String(body.subtitle ?? "").trim();
    const category = String(body.category ?? "art").trim() || "art";
    const city = String(body.city ?? "").trim();
    const coverUrl = String(body.cover_url ?? "").trim();
    const metadata =
      body.metadata && typeof body.metadata === "object" && !Array.isArray(body.metadata)
        ? body.metadata
        : {};
    const audit = await auditContent({
      userId: auth.user.id,
      text: collectAuditText(title, subtitle, category, city, metadata),
      imageUrls: coverUrl ? [coverUrl] : [],
      scene: "community_circle",
    });
    const rejected = rejectedAuditResponse(audit, "圈子内容");
    if (rejected) return rejected;

    const supabase = createServiceClient();
    await recordUploadAuditResults(
      supabase,
      auth.user.id,
      coverUrl ? [coverUrl] : [],
      audit
    );
    const { data, error } = await supabase
      .from("community_circles")
      .insert({
        creator_id: auth.user.id,
        title,
        subtitle: subtitle || null,
        category,
        city: city || null,
        cover_url: coverUrl || null,
        status: "published",
        metadata,
      })
      .select()
      .single();

    if (error) return errorResponse(error);
    if (data?.id) {
      await supabase.from("community_circle_members").upsert(
        {
          circle_id: data.id,
          user_id: auth.user.id,
          status: "joined",
          updated_at: new Date().toISOString(),
        },
        { onConflict: "circle_id,user_id" }
      );
    }
    return NextResponse.json(
      { success: true, data: { ...data, join_status: "joined" } },
      { status: 201 }
    );
  } catch (e) {
    const auditError = contentSafetyErrorResponse(e);
    if (auditError) return auditError;
    return errorResponse(e);
  }
}
