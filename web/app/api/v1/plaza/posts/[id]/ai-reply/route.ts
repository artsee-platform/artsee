import { NextRequest, NextResponse } from "next/server";
import { isAuthzResponse, requireUser } from "@/lib/api/authz";
import { createServiceClient } from "@/lib/api/supabase-service";
import { PLAZA_UUID_RE } from "@/lib/api/plaza";
import {
  createPlazaAiReply,
  objectValue,
  PlazaAiConfigError,
  PlazaAiReplyError,
  stringValue,
} from "@/lib/api/plaza-ai-reply";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: NextRequest, ctx: Ctx) {
  try {
    const auth = await requireUser(req);
    if (isAuthzResponse(auth)) return auth.response;

    const { id } = await ctx.params;
    if (!PLAZA_UUID_RE.test(id)) {
      return NextResponse.json({ success: false, error: "无效的帖子 ID" }, { status: 400 });
    }

    const body = objectValue(await req.json().catch(() => ({})));
    const parentValue = body.parent_id ?? body.comment_id;
    const parentId = parentValue ? String(parentValue) : null;
    if (parentId && !PLAZA_UUID_RE.test(parentId)) {
      return NextResponse.json({ success: false, error: "无效的父评论 ID" }, { status: 400 });
    }

    const data = await createPlazaAiReply(createServiceClient(), {
      postId: id,
      parentId,
      trigger: "manual",
      triggeredByUserId: auth.user.id,
      persona: stringValue(body.persona, "艺见锐评员"),
      userPrompt: stringValue(body.prompt ?? body.user_message ?? body.context),
    });

    if (!data) {
      return NextResponse.json(
        { success: false, error: "这条评论已经有 AI 回复，或 AI 不会回复 AI 评论" },
        { status: 409 }
      );
    }

    return NextResponse.json({ success: true, data }, { status: 201 });
  } catch (e: unknown) {
    if (e instanceof PlazaAiConfigError) {
      return NextResponse.json(
        {
          success: false,
          error: "未配置广场 AI 回复模型",
          missing: e.missing,
        },
        { status: 503 }
      );
    }
    if (e instanceof PlazaAiReplyError) {
      return NextResponse.json(
        { success: false, error: e.message },
        { status: e.status }
      );
    }

    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
