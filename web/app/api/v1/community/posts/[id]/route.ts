import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import {
  auditContent,
  auditReasonFromItems,
  collectAuditText,
  contentStatusForAudit,
} from "@/lib/api/content-safety";
import { contentSafetyErrorResponse } from "@/lib/api/content-safety-http";
import { createServiceClient } from "@/lib/api/supabase-service";
import { recordUploadAuditResults } from "@/lib/api/upload-audit";

type Ctx = { params: Promise<{ id: string }> };
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function GET(_req: NextRequest, ctx: Ctx) {
  try {
    const { id } = await ctx.params;
    if (!UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }
    const user = await getUserFromBearer(_req);
    const supabase = createServiceClient();
    let query = supabase.from("community_posts").select("*").eq("id", id);
    query = user
      ? query.or(`status.eq.published,author_id.eq.${user.id}`)
      : query.eq("status", "published");
    const { data: row, error } = await query.maybeSingle();

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
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    if (body.status !== undefined) {
      return NextResponse.json(
        { success: false, error: "帖子状态不能由客户端直接修改" },
        { status: 400 }
      );
    }
    const hasTitle = body.title !== undefined;
    const hasBody = body.body !== undefined;
    const hasImages = body.image_urls !== undefined;
    if (!hasTitle && !hasBody && !hasImages) {
      return NextResponse.json(
        { success: false, error: "没有可更新的帖子内容" },
        { status: 400 }
      );
    }
    if (hasTitle && typeof body.title !== "string") {
      return NextResponse.json(
        { success: false, error: "帖子标题格式不正确" },
        { status: 400 }
      );
    }
    if (hasBody && body.body !== null && typeof body.body !== "string") {
      return NextResponse.json(
        { success: false, error: "帖子正文格式不正确" },
        { status: 400 }
      );
    }
    if (hasImages && !Array.isArray(body.image_urls)) {
      return NextResponse.json(
        { success: false, error: "帖子图片格式不正确" },
        { status: 400 }
      );
    }
    const supabase = createServiceClient();

    const { data: row, error: readError } = await supabase
      .from("community_posts")
      .select("*")
      .eq("id", id)
      .single();
    if (readError) {
      return NextResponse.json(
        { success: false, error: readError.message },
        { status: 500 }
      );
    }
    if (!row || row.author_id !== user.id) {
      return NextResponse.json({ success: false, error: "无权修改" }, { status: 403 });
    }

    const title = hasTitle ? String(body.title).trim() : String(row.title ?? "").trim();
    const text = hasBody ? String(body.body ?? "").trim() : String(row.body ?? "").trim();
    const imageUrls = hasImages
      ? (body.image_urls as unknown[]).map(String)
      : Array.isArray(row.image_urls)
        ? row.image_urls.map(String)
        : [];
    if (!title && !text && imageUrls.length === 0) {
      return NextResponse.json(
        { success: false, error: "请至少填写标题、正文或上传一张图片" },
        { status: 400 }
      );
    }

    const metadata =
      row.metadata && typeof row.metadata === "object" && !Array.isArray(row.metadata)
        ? (row.metadata as Record<string, unknown>)
        : {};
    const audit = await auditContent({
      userId: user.id,
      text: collectAuditText(title, text, metadata),
      imageUrls,
      scene: metadata.surface === "plaza" ? "plaza_post" : "community_post",
      dataId: id,
    });
    const auditStatus =
      metadata.kind === "market" && audit.audit_status !== "rejected"
        ? "reviewing"
        : audit.audit_status;
    await recordUploadAuditResults(supabase, user.id, imageUrls, audit);
    const patch: Record<string, unknown> = {
      title,
      body: text || null,
      image_urls: imageUrls,
      status: contentStatusForAudit(auditStatus),
      audit_status: auditStatus,
      audit_provider: audit.provider,
      audit_reason: auditReasonFromItems(audit.items) || null,
      audit_metadata:
        metadata.kind === "market"
          ? { ...audit, manual_review_required: true }
          : audit,
      audited_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabase.from("community_posts").update(patch).eq("id", id).select().single();
    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const auditError = contentSafetyErrorResponse(e);
    if (auditError) return auditError;
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
