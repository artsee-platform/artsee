import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function readSaveCount(supabase: ReturnType<typeof createServiceClient>, postId: string) {
  const { data } = await supabase
    .from("community_posts")
    .select("save_count")
    .eq("id", postId)
    .maybeSingle();
  return Number(data?.save_count ?? 0);
}

export async function POST(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }
    const supabase = createServiceClient();
    const { data: post } = await supabase
      .from("community_posts")
      .select("id")
      .eq("id", id)
      .eq("status", "published")
      .maybeSingle();
    if (!post) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }

    const { error } = await supabase
      .from("community_post_saves")
      .insert({ post_id: id, user_id: user.id });
    const alreadySaved = error && "code" in error && error.code === "23505";
    if (error && !alreadySaved) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    if (!alreadySaved) {
      await supabase.rpc("increment_community_post_save", { p_post_id: id });
    }
    const saveCount = await readSaveCount(supabase, id);
    return NextResponse.json({ success: true, data: { saved: true, save_count: saveCount } });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }
    const supabase = createServiceClient();
    const { data: existing } = await supabase
      .from("community_post_saves")
      .select("id")
      .eq("post_id", id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (existing) {
      const { error } = await supabase
        .from("community_post_saves")
        .delete()
        .eq("post_id", id)
        .eq("user_id", user.id);
      if (error) {
        return NextResponse.json({ success: false, error: error.message }, { status: 500 });
      }
      await supabase.rpc("decrement_community_post_save", { p_post_id: id });
    }

    const saveCount = await readSaveCount(supabase, id);
    return NextResponse.json({ success: true, data: { saved: false, save_count: saveCount } });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
