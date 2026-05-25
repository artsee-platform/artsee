import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };

/** GET /api/v1/community/posts/[id]/comments — 获取图文评论列表 */
export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    const { searchParams } = new URL(req.url);
    const limit = Math.min(parseInt(searchParams.get("limit") || "30", 10), 100);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const supabase = createServiceClient();
    const { data: rows, error } = await supabase
      .from("community_post_comments")
      .select("*")
      .eq("post_id", id)
      .eq("status", "published")
      .order("created_at", { ascending: true })
      .range(offset, offset + limit - 1);

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const comments = rows ?? [];
    const authorIds = [...new Set(comments.map((c: { author_id: string }) => c.author_id))];
    let profileMap: Record<string, { nickname: string | null; avatar_url: string | null }> = {};
    if (authorIds.length > 0) {
      const { data: profiles } = await supabase
        .from("user_profiles")
        .select("id, nickname, avatar_url")
        .in("id", authorIds);
      profileMap = Object.fromEntries(
        (profiles ?? []).map((p: { id: string; nickname: string | null; avatar_url: string | null }) => [
          p.id,
          { nickname: p.nickname, avatar_url: p.avatar_url },
        ])
      );
    }

    const data = comments.map((c: Record<string, unknown>) => ({
      ...c,
      user_profiles: profileMap[String(c.author_id)] ?? null,
    }));

    return NextResponse.json({ success: true, data, pagination: { limit, offset } });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

/** POST /api/v1/community/posts/[id]/comments — 发表评论（需登录） */
export async function POST(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    const body = await req.json();
    const commentBody = (body.body as string)?.trim() ?? "";

    if (!commentBody || commentBody.length === 0) {
      return NextResponse.json({ success: false, error: "评论内容不能为空" }, { status: 400 });
    }
    if (commentBody.length > 1000) {
      return NextResponse.json({ success: false, error: "评论内容不能超过 1000 字" }, { status: 400 });
    }

    const supabase = createServiceClient();

    // 检查图文是否存在
    const { data: post } = await supabase
      .from("community_posts")
      .select("id")
      .eq("id", id)
      .maybeSingle();
    if (!post) {
      return NextResponse.json({ success: false, error: "图文不存在" }, { status: 404 });
    }

    // 创建评论
    const { data: comment, error } = await supabase
      .from("community_post_comments")
      .insert({
        post_id: id,
        author_id: user.id,
        body: commentBody,
        status: "published",
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    // 增加评论计数
    await supabase.rpc("increment_community_post_comment", { p_post_id: id });

    // 获取作者信息
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("nickname, avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    return NextResponse.json({
      success: true,
      data: { ...comment, user_profiles: profile ?? null },
    }, { status: 201 });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
