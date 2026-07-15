import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { parsePagination } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";
import { attachPlazaPostState } from "@/lib/api/plaza";

/** GET /api/v1/plaza/feed — 广场聚合流，底层复用 community_posts */
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const pagination = parsePagination(searchParams);
    const limit = Math.min(pagination.limit, 50);
    const offset = pagination.offset;
    const kind = searchParams.get("kind")?.trim();
    const group = searchParams.get("group")?.trim();
    const source = searchParams.get("source")?.trim();
    const sort = searchParams.get("sort")?.trim() || "latest";

    const user = await getUserFromBearer(req);
    const supabase = createServiceClient();
    let query = supabase.from("community_posts").select("*");

    if (user) {
      query = query.or(`status.eq.published,and(author_id.eq.${user.id},status.neq.rejected)`);
    } else {
      query = query.eq("status", "published");
    }

    query = query.eq("metadata->>surface", "plaza");
    if (kind) query = query.eq("metadata->>kind", kind);
    if (source) query = query.eq("metadata->>source", source);
    if (group) {
      query = query.or(
        [
          `metadata->>group.eq.${group}`,
          `metadata->>category.eq.${group}`,
          `metadata->>circle.eq.${group}`,
          `metadata->>circle_title.eq.${group}`,
        ].join(",")
      );
    }

    if (sort === "hot") {
      query = query
        .order("like_count", { ascending: false })
        .order("comment_count", { ascending: false })
        .order("created_at", { ascending: false });
    } else {
      query = query.order("created_at", { ascending: false });
    }

    const { data: rows, error } = await query.range(offset, offset + limit - 1);
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const data = await attachPlazaPostState(supabase, rows ?? [], user?.id);
    return NextResponse.json({
      success: true,
      data,
      pagination: { limit, offset, sort },
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
