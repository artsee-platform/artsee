import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(_req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }
    const supabase = createServiceClient();
    const { data: row, error } = await supabase.from("community_posts").select("*").eq("id", id).maybeSingle();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    if (!row) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }
    const { data: prof } = await supabase
      .from("user_profiles")
      .select("nickname, avatar_url")
      .eq("id", row.author_id)
      .maybeSingle();
    const user = await getUserFromBearer(_req);
    let likedByMe = false;
    let savedByMe = false;
    if (user) {
      const { data: like } = await supabase
        .from("community_post_likes")
        .select("id")
        .eq("post_id", id)
        .eq("user_id", user.id)
        .maybeSingle();
      likedByMe = Boolean(like);
      const { data: save } = await supabase
        .from("community_post_saves")
        .select("id")
        .eq("post_id", id)
        .eq("user_id", user.id)
        .maybeSingle();
      savedByMe = Boolean(save);
    }
    return NextResponse.json({
      success: true,
      data: {
        ...row,
        user_profiles: prof ?? null,
        liked_by_me: likedByMe,
        saved_by_me: savedByMe,
      },
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export async function PATCH(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }
    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }
    const body = await req.json();
    const supabase = createServiceClient();

    const { data: row } = await supabase.from("community_posts").select("author_id").eq("id", id).single();
    if (!row || row.author_id !== user.id) {
      return NextResponse.json({ success: false, error: "无权修改" }, { status: 403 });
    }

    const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (body.title !== undefined) patch.title = body.title;
    if (body.body !== undefined) patch.body = body.body;
    if (body.image_urls !== undefined) patch.image_urls = body.image_urls;
    if (body.status !== undefined) patch.status = body.status;

    const { data, error } = await supabase.from("community_posts").update(patch).eq("id", id).select().single();
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true, data });
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
    const { data: row } = await supabase.from("community_posts").select("author_id").eq("id", id).single();
    if (!row || row.author_id !== user.id) {
      return NextResponse.json({ success: false, error: "无权删除" }, { status: 403 });
    }
    const { error } = await supabase.from("community_posts").delete().eq("id", id);
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
