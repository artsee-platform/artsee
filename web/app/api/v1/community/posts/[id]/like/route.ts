import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };

/** POST /api/v1/community/posts/[id]/like — 点赞图文（需登录） */
export async function POST(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    const supabase = createServiceClient();

    // 尝试插入点赞记录（利用 UNIQUE 约束防重复）
    const { error: insertError } = await supabase
      .from("community_post_likes")
      .insert({
        post_id: id,
        user_id: user.id,
      });

    // 如果已存在（UNIQUE 冲突），直接返回当前状态
    if (insertError && insertError.code === "23505") {
      const { data: post } = await supabase
        .from("community_posts")
        .select("like_count")
        .eq("id", id)
        .single();
      return NextResponse.json({
        success: true,
        data: { liked: true, like_count: post?.like_count ?? 0 },
      });
    }

    if (insertError) {
      return NextResponse.json({ success: false, error: insertError.message }, { status: 500 });
    }

    // 增加点赞计数并获取最新值
    await supabase.rpc("increment_community_post_like", { p_post_id: id });
    const { data: updatedPost } = await supabase
      .from("community_posts")
      .select("like_count")
      .eq("id", id)
      .single();

    return NextResponse.json({
      success: true,
      data: { liked: true, like_count: updatedPost?.like_count ?? 1 },
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

/** DELETE /api/v1/community/posts/[id]/like — 取消点赞（需登录） */
export async function DELETE(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    const supabase = createServiceClient();

    // 删除点赞记录
    const { error: deleteError } = await supabase
      .from("community_post_likes")
      .delete()
      .eq("post_id", id)
      .eq("user_id", user.id);

    if (deleteError) {
      return NextResponse.json({ success: false, error: deleteError.message }, { status: 500 });
    }

    // 减少点赞计数并获取最新值
    await supabase.rpc("decrement_community_post_like", { p_post_id: id });
    const { data: updatedPost } = await supabase
      .from("community_posts")
      .select("like_count")
      .eq("id", id)
      .single();

    return NextResponse.json({
      success: true,
      data: { liked: false, like_count: updatedPost?.like_count ?? 0 },
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
