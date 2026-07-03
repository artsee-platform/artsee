import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse, parsePagination } from "@/lib/api/route-helpers";

function asPost(row: Record<string, unknown>) {
  const rawPost = row.community_posts;
  const post = Array.isArray(rawPost) ? rawPost[0] : rawPost;
  if (!post || typeof post !== "object") return null;
  return post as Record<string, unknown>;
}

export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const { limit, offset } = parsePagination(searchParams);
    const supabase = createServiceClient();
    const { data: rows, error, count } = await supabase
      .from("community_post_saves")
      .select("id, post_id, created_at, community_posts(*)", { count: "exact" })
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) return errorResponse(error);

    const savedRows = (rows ?? []) as Record<string, unknown>[];
    const posts: Record<string, unknown>[] = [];
    for (const row of savedRows) {
      const post = asPost(row);
      if (!post || post.status !== "published") continue;
      posts.push({ ...post, saved_at: row.created_at });
    }

    const authorIds = [...new Set(posts.map((post) => String(post.author_id)).filter(Boolean))];
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

    const postIds = posts.map((post) => String(post.id));
    let likedIds = new Set<string>();
    if (postIds.length > 0) {
      const { data: likes } = await supabase
        .from("community_post_likes")
        .select("post_id")
        .eq("user_id", user.id)
        .in("post_id", postIds);
      likedIds = new Set((likes ?? []).map((item: { post_id: string }) => item.post_id));
    }

    return NextResponse.json({
      success: true,
      data: posts.map((post) => ({
        ...post,
        user_profiles: profileMap[String(post.author_id)] ?? null,
        liked_by_me: likedIds.has(String(post.id)),
        saved_by_me: true,
      })),
      count,
      pagination: { limit, offset },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
