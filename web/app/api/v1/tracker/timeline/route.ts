import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

type TrackerRow = {
  school_name: string | null;
  program_name: string | null;
  deadline: string | null;
  status: string | null;
};

function addDays(date: Date, days: number): string {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next.toISOString().slice(0, 10);
}

function minusDays(raw: string, days: number): string {
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return addDays(new Date(), 14);
  date.setDate(date.getDate() - days);
  return date.toISOString().slice(0, 10);
}

/** GET /api/v1/tracker/timeline — 基于申请清单生成倒排时间线 */
export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const supabase = createServiceClient();
    const { data, error } = await supabase
      .from("application_tracker")
      .select("school_name, program_name, deadline, status")
      .eq("user_id", user.id)
      .order("deadline", { ascending: true, nullsFirst: false });

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    const rows = (data ?? []) as TrackerRow[];
    const today = new Date();
    const timeline = rows.flatMap((row, index) => {
      const schoolName = row.school_name || "申请院校";
      const subject = row.program_name ? `${schoolName} ${row.program_name}` : schoolName;
      const deadline = row.deadline || addDays(today, 60 + index * 14);
      if (row.status === "submitted" || row.status === "admitted" || row.status === "rejected") {
        return [];
      }
      return [
        {
          date: minusDays(deadline, 45),
          task: `完成 ${subject} 作品集初稿`,
          schoolName,
          priority: "high",
        },
        {
          date: minusDays(deadline, 21),
          task: `确认 ${subject} 文书、推荐信和成绩材料`,
          schoolName,
          priority: "medium",
        },
        {
          date: minusDays(deadline, 3),
          task: `提交 ${subject} 申请并检查付款状态`,
          schoolName,
          priority: "high",
        },
      ];
    }).sort((a, b) => a.date.localeCompare(b.date));

    return NextResponse.json({ success: true, timeline });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ success: false, error: msg }, { status: 500 });
  }
}
