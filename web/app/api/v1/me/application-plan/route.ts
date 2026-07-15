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

export async function GET(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });

    const supabase = createServiceClient();
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("*")
      .eq("id", user.id)
      .maybeSingle();
    const { savedSchools, count: savedSchoolCount } =
      await fetchSavedSchoolsWithDetails(supabase, user.id);
    const { data: plan, error: planError } = await supabase
      .from("application_plans")
      .select("*")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (planError) return errorResponse(planError);

    let tasks: unknown[] = [];
    if (plan?.id) {
      const { data, error } = await supabase
        .from("application_plan_tasks")
        .select("*")
        .eq("user_id", user.id)
        .eq("plan_id", plan.id)
        .order("sort_order", { ascending: true });
      if (error) return errorResponse(error);
      tasks = data ?? [];
    }

    const hasProfile = Boolean(profile?.has_completed_onboarding);
    const state = plan
      ? "generated"
      : !hasProfile
        ? "no_profile"
        : "ready_to_generate";

    return NextResponse.json({
      success: true,
      data: {
        state,
        profile,
        saved_school_count: savedSchoolCount ?? 0,
        saved_schools: savedSchools,
        plan,
        tasks,
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
