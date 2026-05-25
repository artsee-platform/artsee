import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type Ctx = { params: Promise<{ id: string }> };

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** PATCH /api/v1/tracker/:id — 更新申请项 */
export async function PATCH(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    const body = await req.json();
    const patch: Record<string, string | null> = {};

    for (const key of ["tier", "status", "notes", "deadline", "program_name", "school_name"]) {
      if (Object.prototype.hasOwnProperty.call(body, key)) {
        patch[key] = cleanText(body[key]);
      }
    }

    if (Object.keys(patch).length === 0) {
      return NextResponse.json({ success: false, error: "没有可更新字段" }, { status: 400 });
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("application_tracker")
      .update(patch)
      .eq("id", id)
      .eq("user_id", user.id)
      .select("*")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }
    if (!data) {
      return NextResponse.json({ success: false, error: "未找到申请项" }, { status: 404 });
    }

    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

/** DELETE /api/v1/tracker/:id — 删除申请项 */
export async function DELETE(req: NextRequest, ctx: Ctx) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const { id } = await ctx.params;
    const supabase = createServiceClient();
    const { error } = await supabase
      .from("application_tracker")
      .delete()
      .eq("id", id)
      .eq("user_id", user.id);

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
