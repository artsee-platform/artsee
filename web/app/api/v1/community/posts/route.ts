import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { recordCreatorContent } from "@/lib/api/creator-level";
import { requireUser } from "@/lib/api/authz";
import { createServiceClient } from "@/lib/api/supabase-service";
import { auditContent } from "@/lib/api/content-safety";
import { TencentCloudConfigError } from "@/lib/api/tencent-cloud";

function postStatusForAudit(auditStatus: string) {
  if (auditStatus === "approved") return "published";
  if (auditStatus === "rejected") return "rejected";
  return "reviewing";
}

function auditReasonFromItems(
  items: Array<{ label: string | null; sub_label: string | null }>
) {
  return items
    .map((item) => [item.label, item.sub_label].filter(Boolean).join("/"))
    .filter(Boolean)
    .join(", ");
}

/** GET /api/v1/community/posts — 图文社区列表（数据库 community_posts） */
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const limit = Math.min(parseInt(searchParams.get("limit") || "20", 10), 50);
    const offset = parseInt(searchParams.get("offset") || "0", 10);

    const user = await getUserFromBearer(req);
    const supabase = createServiceClient();
    let query = supabase
      .from("community_posts")
      .select("*")
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (user) {
      query = query.or(`status.eq.published,and(author_id.eq.${user.id},status.neq.rejected)`);
    } else {
      query = query.eq("status", "published");
    }

    const kind = searchParams.get("kind")?.trim();
    if (kind) query = query.eq("metadata->>kind", kind);

    const { data: rows, error } = await query;

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
    const postIds = posts.map((p: { id: string }) => p.id);
    let likedIds = new Set<string>();
    let savedIds = new Set<string>();
    if (user && postIds.length > 0) {
      const { data: likes } = await supabase
        .from("community_post_likes")
        .select("post_id")
        .eq("user_id", user.id)
        .in("post_id", postIds);
      likedIds = new Set((likes ?? []).map((item: { post_id: string }) => item.post_id));
      const { data: saves } = await supabase
        .from("community_post_saves")
        .select("post_id")
        .eq("user_id", user.id)
        .in("post_id", postIds);
      savedIds = new Set((saves ?? []).map((item: { post_id: string }) => item.post_id));
    }

    const data = posts.map((p: Record<string, unknown>) => ({
      ...p,
      user_profiles: profileMap[String(p.author_id)] ?? null,
      liked_by_me: likedIds.has(String(p.id)),
      saved_by_me: savedIds.has(String(p.id)),
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
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = await req.json();
    const title = (body.title as string)?.trim() ?? "";
    const text = (body.body as string)?.trim() ?? "";
    const imageUrls = Array.isArray(body.image_urls) ? body.image_urls.map(String) : [];
    const metadata =
      body.metadata && typeof body.metadata === "object" && !Array.isArray(body.metadata)
        ? body.metadata
        : {};

    if (!title && !text && imageUrls.length === 0) {
      return NextResponse.json({ success: false, error: "请至少填写标题、正文或上传一张图片" }, { status: 400 });
    }

    const audit = await auditContent({
      userId: auth.user.id,
      text: [title, text].filter(Boolean).join("\n\n"),
      imageUrls,
      scene: "community_post",
    });
    const status = postStatusForAudit(audit.audit_status);
    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("community_posts")
      .insert({
        author_id: auth.user.id,
        title: title || "作品分享",
        body: text || null,
        image_urls: imageUrls,
        status,
        audit_status: audit.audit_status,
        audit_provider: audit.provider,
        audit_reason: auditReasonFromItems(audit.items) || null,
        audit_metadata: audit,
        audited_at: new Date().toISOString(),
        metadata,
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    if (status === "published") {
      await recordCreatorContent(supabase, auth.user.id, {
        sourceType: "community_post",
        sourceId: String(data.id),
      }).catch((error) => {
        console.warn("[creator-level] failed to record community post", error);
      });
    }

    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    if (e instanceof TencentCloudConfigError) {
      return NextResponse.json(
        { success: false, error: e.message, missing: e.missing },
        { status: 503 }
      );
    }
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
