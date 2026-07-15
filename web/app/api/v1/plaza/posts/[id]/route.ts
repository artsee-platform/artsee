import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { attachPlazaPostState, PLAZA_UUID_RE } from "@/lib/api/plaza";

type Ctx = { params: Promise<{ id: string }> };

/** GET /api/v1/plaza/posts/:id — 广场帖子详情 */
export async function GET(req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!PLAZA_UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }

    const user = await getUserFromBearer(req);
    const supabase = createServiceClient();
    let query = supabase.from("community_posts").select("*").eq("id", id);
    if (user) {
      query = query.or(`status.eq.published,and(author_id.eq.${user.id},status.neq.rejected)`);
    } else {
      query = query.eq("status", "published");
    }
    query = query.eq("metadata->>surface", "plaza");

    const { data: row, error } = await query.maybeSingle();
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    if (!row) {
      return NextResponse.json({ success: false, error: "未找到" }, { status: 404 });
    }

    const [data] = await attachPlazaPostState(supabase, [row], user?.id);
    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

export { PATCH, DELETE } from "@/app/api/v1/community/posts/[id]/route";
