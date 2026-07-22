import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { isRetiredCommercialAgencyType } from "@/lib/api/organization-visibility";
import { createServiceClient } from "@/lib/api/supabase-service";

type Row = Record<string, unknown>;
type SupabaseServiceClient = ReturnType<typeof createServiceClient>;

const BUSINESS_ROLES = new Set([
  "official_association",
  "official_partner",
  "school_official",
  "gallery_exhibition",
  "event_organizer",
  "hotel_culture_space",
  "brand_partner",
  "art_media_community",
  "other_service",
]);

function toStringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean).slice(0, 20);
}

function toOptionalString(value: unknown) {
  if (typeof value !== "string") return undefined;
  const text = value.trim();
  return text.length > 0 ? text : undefined;
}

function firstLabeledValue(items: string[], label: string) {
  const prefix = `${label}：`;
  for (const item of items) {
    if (!item.startsWith(prefix)) continue;
    const value = item.slice(prefix.length).trim();
    if (value) return value;
  }
  return undefined;
}

function compactObject(value: Row) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => {
      if (entry == null) return false;
      if (typeof entry === "string") return entry.trim().length > 0;
      if (Array.isArray(entry)) return entry.length > 0;
      return true;
    })
  );
}

function businessRole(value: string | undefined) {
  return value && BUSINESS_ROLES.has(value) ? value : "other_service";
}

async function ensureBusinessOnboardingReview(
  supabase: SupabaseServiceClient,
  input: {
    userId: string;
    userRole?: string;
    userType?: string;
    verificationIntent?: string;
    businessName?: string;
    businessCity?: string;
    businessContact?: string;
    businessChannel?: string;
    businessIntro?: string;
    businessNeeds: string[];
    businessMaterials: string[];
    businessProofFiles: string[];
  }
) {
  const role = businessRole(input.userRole);
  const userRoleIsBusiness = input.userRole
    ? BUSINESS_ROLES.has(input.userRole)
    : false;
  const shouldCreateReview =
    input.userType === "business" ||
    input.verificationIntent === "business_review" ||
    userRoleIsBusiness;
  if (!shouldCreateReview || !input.businessName) return null;

  const organizationMetadata = compactObject({
    source: "onboarding",
    city: input.businessCity,
    contact: input.businessContact,
    channel: input.businessChannel,
    summary: input.businessIntro,
    needs: input.businessNeeds,
    materials: input.businessMaterials,
    proof_files: input.businessProofFiles,
  });

  const { data: existingOrganization, error: lookupError } = await supabase
    .from("organizations")
    .select("id,metadata,verification_status")
    .eq("owner_user_id", input.userId)
    .eq("type", role)
    .maybeSingle();
  if (lookupError) throw lookupError;

  const existing = (existingOrganization ?? null) as Row | null;
  const organizationPatch = {
    name: input.businessName,
    type: role,
    owner_user_id: input.userId,
    status: "active",
    verification_status:
      existing?.verification_status === "verified" ? "verified" : "pending",
    metadata: {
      ...((existing?.metadata && typeof existing.metadata === "object"
        ? existing.metadata
        : {}) as Row),
      ...organizationMetadata,
    },
  };

  let organization: Row;
  if (existing?.id) {
    const { data, error } = await supabase
      .from("organizations")
      .update(organizationPatch)
      .eq("id", existing.id)
      .select("*")
      .single();
    if (error) throw error;
    organization = data as Row;
  } else {
    const { data, error } = await supabase
      .from("organizations")
      .insert(organizationPatch)
      .select("*")
      .single();
    if (error) throw error;
    organization = data as Row;
  }

  const organizationId = String(organization.id || "");
  if (organizationId) {
    const { error: memberError } = await supabase
      .from("organization_members")
      .upsert(
        {
          organization_id: organizationId,
          user_id: input.userId,
          role: "owner",
          status: "active",
        },
        { onConflict: "organization_id,user_id" }
      );
    if (memberError) throw memberError;
  }

  if (organization.verification_status === "verified") {
    return { organization, verification: null };
  }

  const { data: pendingVerifications, error: pendingError } = await supabase
    .from("verifications")
    .select("id")
    .eq("user_id", input.userId)
    .eq("type", "business")
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);
  if (pendingError) throw pendingError;

  const existingVerification = Array.isArray(pendingVerifications)
    ? pendingVerifications[0]
    : null;
  if (existingVerification) {
    return { organization, verification: existingVerification };
  }

  const materials = compactObject({
    source: "onboarding",
    organization_id: organizationId,
    organization_name: input.businessName,
    company_name: input.businessName,
    display_name: input.businessName,
    requested_role: role,
    user_role: role,
    city: input.businessCity,
    contact: input.businessContact,
    channel: input.businessChannel,
    note: input.businessIntro,
    business_needs: input.businessNeeds,
    business_materials: input.businessMaterials,
    business_proof_files: input.businessProofFiles,
  });

  const { data: verification, error: verificationError } = await supabase
    .from("verifications")
    .insert({
      user_id: input.userId,
      type: "business",
      materials,
      status: "pending",
    })
    .select("*")
    .single();
  if (verificationError) throw verificationError;

  return { organization, verification };
}

export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    if (!user) {
      return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
    }

    const body = await req.json();
    const requestedUserId = typeof body.userId === "string" ? body.userId : user.id;
    if (requestedUserId !== user.id) {
      return NextResponse.json({ success: false, error: "不能替其他用户完成引导" }, { status: 403 });
    }

    const interestedCategories = toStringArray(body.interestedCategories ?? body.interested_categories);
    const userRole = toOptionalString(body.userRole ?? body.user_role);
    if (isRetiredCommercialAgencyType(userRole)) {
      return NextResponse.json(
        { success: false, error: "该机构类型已下线，请选择画廊、美术馆、协会或其他机构类型" },
        { status: 400 }
      );
    }
    const userType = toOptionalString(body.userType ?? body.user_type ?? userRole);
    const primaryGoal = toOptionalString(body.primaryGoal ?? body.primary_goal);
    const currentStage = toOptionalString(body.currentStage ?? body.current_stage);
    const cityPreference = toOptionalString(body.cityPreference ?? body.city_preference);
    const targetDirections = toStringArray(body.targetDirections ?? body.target_directions);
    const targetMajors = toStringArray(body.targetMajors ?? body.target_majors);
    const eventPreferences = toStringArray(body.eventPreferences ?? body.event_preferences);
    const activityCities = toStringArray(body.activityCities ?? body.activity_cities);
    const verificationIntent = toOptionalString(body.verificationIntent ?? body.verification_intent);
    const goals = toStringArray(body.goals);
    const businessMaterials =
      toStringArray(body.businessMaterials ?? body.business_materials).length > 0
        ? toStringArray(body.businessMaterials ?? body.business_materials)
        : targetMajors.filter((item) => !/^(机构名称|组织名称|联系人|渠道|简介)：/u.test(item));
    const businessProofFiles = toStringArray(
      body.businessProofFiles ?? body.business_proof_files
    );
    const businessName =
      toOptionalString(body.businessName ?? body.business_name) ??
      firstLabeledValue(targetMajors, "机构名称") ??
      firstLabeledValue(targetMajors, "组织名称");
    const businessContact =
      toOptionalString(body.businessContact ?? body.business_contact) ??
      firstLabeledValue(targetMajors, "联系人");
    const businessChannel =
      toOptionalString(body.businessChannel ?? body.business_channel) ??
      firstLabeledValue(targetMajors, "渠道");
    const businessIntro =
      toOptionalString(body.businessIntro ?? body.business_intro) ??
      firstLabeledValue(targetMajors, "简介");
    const businessCity =
      toOptionalString(body.businessCity ?? body.business_city) ??
      cityPreference ??
      activityCities[0];
    const now = new Date().toISOString();
    const completionParts = [
      userRole,
      primaryGoal,
      targetDirections.length > 0,
      cityPreference || activityCities.length > 0,
      currentStage,
      verificationIntent,
      interestedCategories.length > 0,
    ];
    const filledParts = completionParts.filter(Boolean).length;
    const profileCompletionScore = Math.max(45, Math.round((filledParts / completionParts.length) * 100));
    const priorityFactors = [
      ...goals,
      ...(primaryGoal ? [primaryGoal] : []),
      ...eventPreferences.map((item) => `event:${item}`),
      ...(verificationIntent ? [`verification:${verificationIntent}`] : []),
    ];

    const supabase = createServiceClient();
    const upsertData: Record<string, unknown> = {
      id: user.id,
      interested_categories: interestedCategories,
      target_directions: targetDirections,
      target_majors: targetMajors,
      priority_factors: priorityFactors,
      has_completed_onboarding: true,
      profile_completion_score: profileCompletionScore,
      onboarding_completed_at: now,
      updated_at: now,
    };
    if (userRole) upsertData.user_role = userRole;
    if (userType) upsertData.user_type = userType;
    if (cityPreference) {
      upsertData.city_preference = cityPreference;
      upsertData.location = cityPreference;
    } else if (activityCities[0]) {
      upsertData.location = activityCities[0];
    }
    if (currentStage) {
      upsertData.portfolio_status = currentStage;
      if (userRole === "student") upsertData.current_education_stage = currentStage;
    }
    if (targetMajors.length > 0) {
      upsertData.favorite_artists_or_styles = targetMajors.join("、");
    }

    const { data: profile, error } = await supabase
      .from("user_profiles")
      .upsert(upsertData, { onConflict: "id" })
      .select("*")
      .single();

    if (error) {
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    let businessReview: Awaited<ReturnType<typeof ensureBusinessOnboardingReview>> = null;
    try {
      businessReview = await ensureBusinessOnboardingReview(supabase, {
        userId: user.id,
        userRole,
        userType,
        verificationIntent,
        businessName,
        businessCity,
        businessContact,
        businessChannel,
        businessIntro,
        businessNeeds: goals,
        businessMaterials,
        businessProofFiles,
      });
    } catch (reviewError) {
      const msg = reviewError instanceof Error ? reviewError.message : String(reviewError);
      return NextResponse.json({ success: false, error: msg || "机构入驻审核提交失败" }, { status: 500 });
    }

    return NextResponse.json({
      success: true,
      data: profile,
      businessReview,
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ success: false, error: msg || "服务器错误" }, { status: 500 });
  }
}
