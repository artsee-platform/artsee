import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** GET /api/v1/tracker — 获取我的申请清单 */
export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("application_tracker")
      .select("*")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false });

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data: data ?? [] });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}

/** POST /api/v1/tracker — 添加到申请清单 */
export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const body = await req.json();
    const schoolId = cleanText(body.school_id);
    const programId = cleanText(body.program_id);
    const schoolName = cleanText(body.school_name);
    const programName = cleanText(body.program_name);
    const tier = cleanText(body.tier) ?? "match";
    const status = cleanText(body.status) ?? "planning";
    const deadline = cleanText(body.deadline);
    const notes = cleanText(body.notes);

    if (!schoolId && !programId && !schoolName) {
      return NextResponse.json(
        { success: false, error: "school_id、program_id 或 school_name 至少需要一个" },
        { status: 400 }
      );
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("application_tracker")
      .insert({
        user_id: user.id,
        school_id: schoolId,
        program_id: programId,
        school_name: schoolName ?? "未命名院校",
        program_name: programName,
        tier,
        status,
        deadline,
        notes,
      })
      .select("*")
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data }, { status: 201 });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
