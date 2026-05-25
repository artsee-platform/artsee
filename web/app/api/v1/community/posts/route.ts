import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

/** GET /api/v1/community/posts — 图文社区列表（数据库 community_posts） */
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const limit = Math.min(parseInt(searchParams.get("limit") || "20", 10), 50);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const supabase = createServiceClient();
    const { data: rows, error } = await supabase
      .from("community_posts")
      .select("*")
      .eq("status", "published")
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const posts = rows ?? [];
    const authorIds = [...new Set(posts.map((p: { author_id: string }) => p.author_id))];
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

    // 查询当前用户的点赞状态
    const user = await getUserFromBearer(req);
    let likedPostIds = new Set<string>();
    if (user && posts.length > 0) {
      const postIds = posts.map((p: { id: string }) => p.id);
      const { data: likes } = await supabase
        .from("community_post_likes")
        .select("post_id")
        .eq("user_id", user.id)
        .in("post_id", postIds);
      likedPostIds = new Set((likes ?? []).map((l: { post_id: string }) => l.post_id));
    }

    const data = posts.map((p: Record<string, unknown>) => ({
      ...p,
      user_profiles: profileMap[String(p.author_id)] ?? null,
      liked_by_me: likedPostIds.has(String(p.id)),
    }));

    return NextResponse.json({ success: true, data, pagination: { limit, offset } });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

/** POST /api/v1/community/posts — 发布图文（需登录） */
export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const body = await req.json();
    const title = (body.title as string)?.trim() ?? "";
    const text = (body.body as string)?.trim() ?? "";
    const imageUrls = Array.isArray(body.image_urls) ? body.image_urls.map(String) : [];

    if (!title && !text && imageUrls.length === 0) {
      return NextResponse.json({ success: false, error: "请至少填写标题、正文或上传一张图片" }, { status: 400 });
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("community_posts")
      .insert({
        author_id: user.id,
        title: title || "作品分享",
        body: text || null,
        image_urls: imageUrls,
        status: "published",
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
