import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";
import { errorResponse } from "@/lib/api/route-helpers";

type SavedSchoolRow = {
  id: string;
  school_id: string;
  saved_at: string;
};

function normalizeSavedSchool(
  row: SavedSchoolRow,
  schoolById: Map<string, Record<string, unknown>>
) {
  const school = schoolById.get(row.school_id);
  return {
    ...(school ?? {}),
    school_id: row.school_id,
    saved_school_id: row.id,
    saved_at: row.saved_at,
  };
}

async function fetchSavedSchoolsWithDetails(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string
) {
  const { data: savedRows, error, count } = await supabase
    .from("saved_schools")
    .select("id, school_id, saved_at", { count: "exact" })
    .eq("user_id", userId)
    .order("saved_at", { ascending: false });
  if (error) throw error;

  const rows = (savedRows ?? []) as SavedSchoolRow[];
  const schoolIds = rows.map((row) => row.school_id).filter(Boolean);
  if (schoolIds.length === 0) {
    return { savedSchools: [], count: count ?? 0 };
  }

  const { data: schools, error: schoolsError } = await supabase
    .from("schools")
    .select("*")
    .in("id", schoolIds);
  if (schoolsError) throw schoolsError;

  const schoolById = new Map(
    ((schools ?? []) as Record<string, unknown>[]).map((school) => [
      school.id?.toString() ?? "",
      school,
    ])
  );
  return {
    savedSchools: rows.map((row) => normalizeSavedSchool(row, schoolById)),
    count: count ?? rows.length,
  };
}

function schoolName(school: Record<string, unknown>) {
  return (
    school.name_zh?.toString().trim() ||
    school.name_en?.toString().trim() ||
    "目标院校"
  );
}

function buildTasks(targetNames: string[]) {
  const firstTarget = targetNames[0];
  if (targetNames.length === 0) {
    return [
      ["第1周", "确认申请方向、预算、城市偏好和大致入学时间"],
      ["第1周", "列出 6-8 个候选项目，并标出冲刺、匹配和保底"],
      ["第2周", "整理成绩单、语言成绩、推荐人和经历清单"],
      ["第2周", "确定作品集主题、项目顺序和需要补做的内容"],
      ["第3周", "核对候选项目的截止日期、作品集要求和文书要求"],
      ["第4周", "完成第一版个人陈述大纲和作品集目录"],
      ["第2个月", "完成第一版作品集，并找老师或机构做一次反馈"],
      ["第3个月", "按批次提交申请，并记录账号、费用和材料状态"],
    ];
  }

  const targetText = targetNames.slice(0, 3).join(" / ");
  return [
    ["6月", `确认目标院校池：${targetText}`],
    ["6月", "逐校核对项目方向、截止日期和作品集要求"],
    ["6月", "整理语言成绩、成绩单和推荐人清单"],
    ["7月", "完成第一版作品集结构和项目排序"],
    ["7月", `为 ${firstTarget} 准备定制文书素材`],
    ["7月", "联系推荐人并确认推荐信提交方式"],
    ["8月", "投递第一批优先项目并记录账号状态"],
    ["8月", "复查申请材料、费用和奖学金入口"],
  ];
}

export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    const supabase = createServiceClient();

    const { data: profile } = await supabase
      .from("user_profiles")
      .select("*")
      .eq("id", user.id)
      .maybeSingle();
    if (!profile?.has_completed_onboarding) {
      return NextResponse.json({ success: false, code: "NO_PROFILE", error: "请先完善申请画像" }, { status: 400 });
    }

    const { savedSchools, count: savedSchoolCount } =
      await fetchSavedSchoolsWithDetails(supabase, user.id);
    const targetNames = savedSchools.map(schoolName);
    const summary =
      targetNames.length > 0
        ? `根据你的 onboarding 信息，并参考 ${targetNames.join("、")} 生成的申请计划。`
        : "根据你的 onboarding 信息生成的申请计划。";

    const { data: plan, error: planError } = await supabase
      .from("application_plans")
      .insert({
        user_id: user.id,
        target_year: "2026 Fall",
        status: "active",
        summary,
      })
      .select("*")
      .single();
    if (planError) return errorResponse(planError);

    const rows = buildTasks(targetNames).map(([month, title], index) => ({
      plan_id: plan.id,
      user_id: user.id,
      month_label: month,
      title,
      status: "todo",
      sort_order: index,
    }));
    const { data: tasks, error: taskError } = await supabase
      .from("application_plan_tasks")
      .insert(rows)
      .select("*")
      .order("sort_order", { ascending: true });
    if (taskError) return errorResponse(taskError);

    return NextResponse.json({
      success: true,
      data: {
        state: "generated",
        saved_school_count: savedSchoolCount ?? 0,
        saved_schools: savedSchools,
        plan,
        tasks: tasks ?? [],
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
