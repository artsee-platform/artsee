import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getUserFromBearer } from '@/lib/api/auth-user';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

export async function POST(req: NextRequest) {
  try {
    const user = await getUserFromBearer(req);
    
    if (!user) {
      return NextResponse.json(
        { message: '未登录，请先登录' },
        { status: 401 }
      );
    }

    const requestBody = (await req.json()) as Record<string, unknown>;
    
    console.log('📥 收到的请求体:', JSON.stringify(requestBody, null, 2));
    
    // 支持驼峰和下划线命名，优先使用下划线命名
    const userRole = requestBody.user_role ?? requestBody.userRole;
    const targetDegree = requestBody.target_degree ?? requestBody.targetDegree;
    const currentEducationStage = requestBody.current_education_stage ?? requestBody.currentEducationStage;
    const targetDirections = requestBody.target_directions ?? requestBody.targetDirections;
    const targetMajors = requestBody.target_majors ?? requestBody.targetMajors;
    const targetCountries = requestBody.target_countries ?? requestBody.targetCountries;
    const schoolTypePreference = requestBody.school_type_preference ?? requestBody.schoolTypePreference;
    const rankingSensitivity = requestBody.ranking_sensitivity ?? requestBody.rankingSensitivity;
    const cityPreference = requestBody.city_preference ?? requestBody.cityPreference;
    const portfolioStatus = requestBody.portfolio_status ?? requestBody.portfolioStatus;
    const portfolioStyleTendency = requestBody.portfolio_style_tendency ?? requestBody.portfolioStyleTendency;
    const englishTestType = requestBody.english_test_type ?? requestBody.englishTestType;
    const englishTestScore = requestBody.english_test_score ?? requestBody.englishTestScore;
    const otherLanguages = requestBody.other_languages ?? requestBody.otherLanguages;
    const totalBudgetRange = requestBody.total_budget_range ?? requestBody.totalBudgetRange;
    const scholarshipNeed = requestBody.scholarship_need ?? requestBody.scholarshipNeed;
    const familySupportLevel = requestBody.family_support_level ?? requestBody.familySupportLevel;
    const targetIntake = requestBody.target_intake ?? requestBody.targetIntake;
    const favoriteArtistsOrStyles = requestBody.favorite_artists_or_styles ?? requestBody.favoriteArtistsOrStyles;
    const priorityFactors = requestBody.priority_factors ?? requestBody.priorityFactors;
    const currentSchool = requestBody.current_school ?? requestBody.currentSchool;
    const currentMajor = requestBody.current_major ?? requestBody.currentMajor;
    const gpaOrGrade = requestBody.gpa_or_grade ?? requestBody.gpaOrGrade;
    const hasCompletedOnboarding = requestBody.has_completed_onboarding ?? requestBody.hasCompletedOnboarding;
    const onboardingCompletedAt = requestBody.onboarding_completed_at ?? requestBody.onboardingCompletedAt;
    
    // 旧字段（保持兼容）
    const budgetRange = requestBody.budgetRange;
    const languageLevel = requestBody.languageLevel;
    const timeline = requestBody.timeline;
    const nickname = requestBody.nickname;

    const supabase = createClient(supabaseUrl, supabaseKey);

    // 构建更新数据
    const updateData: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };

    if (nickname) {
      updateData.nickname = nickname;
    }

    if (targetCountries) updateData.target_countries = targetCountries;
    if (targetMajors) updateData.target_majors = targetMajors;
    if (budgetRange) updateData.total_budget_range = budgetRange;
    if (languageLevel) updateData.english_test_score = languageLevel;
    if (timeline) updateData.target_intake = timeline;

    // 用户画像字段 - 新字段体系
    if (userRole) updateData.user_role = userRole;
    if (targetDegree) updateData.target_degree = targetDegree;
    if (currentEducationStage) updateData.current_education_stage = currentEducationStage;
    if (targetDirections) updateData.target_directions = targetDirections;
    if (targetMajors) updateData.target_majors = targetMajors;
    if (targetCountries) updateData.target_countries = targetCountries;
    if (schoolTypePreference) updateData.school_type_preference = schoolTypePreference;
    if (rankingSensitivity) updateData.ranking_sensitivity = rankingSensitivity;
    if (cityPreference) updateData.city_preference = cityPreference;
    if (portfolioStatus) updateData.portfolio_status = portfolioStatus;
    if (portfolioStyleTendency) updateData.portfolio_style_tendency = portfolioStyleTendency;
    if (englishTestType) updateData.english_test_type = englishTestType;
    if (englishTestScore) updateData.english_test_score = englishTestScore;
    if (otherLanguages) updateData.other_languages = otherLanguages;
    if (totalBudgetRange) updateData.total_budget_range = totalBudgetRange;
    if (scholarshipNeed) updateData.scholarship_need = scholarshipNeed;
    if (familySupportLevel) updateData.family_support_level = familySupportLevel;
    if (targetIntake) updateData.target_intake = targetIntake;
    if (favoriteArtistsOrStyles) updateData.favorite_artists_or_styles = favoriteArtistsOrStyles;
    if (priorityFactors) updateData.priority_factors = priorityFactors;
    if (currentSchool) updateData.current_school = currentSchool;
    if (currentMajor) updateData.current_major = currentMajor;
    if (gpaOrGrade) updateData.gpa_or_grade = gpaOrGrade;
    if (hasCompletedOnboarding) {
      updateData.has_completed_onboarding = true;
      updateData.onboarding_completed_at = onboardingCompletedAt || new Date().toISOString();
    }
    
    console.log('📝 构建的 updateData:', JSON.stringify(updateData, null, 2));
    
    // 先获取当前用户资料，用于计算完整度
    const { data: currentProfile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();
    
    console.log('💾 数据库中的当前资料 - user_role:', currentProfile?.user_role);
    console.log('💾 数据库中的当前资料 - target_degree:', currentProfile?.target_degree);
    console.log('💾 数据库中的当前资料 - portfolio_status:', currentProfile?.portfolio_status);
    console.log('💾 数据库中的当前资料 - profile_completion_score:', currentProfile?.profile_completion_score);
    
    // 合并当前资料和更新数据（只合并非 undefined 的字段）
    const mergedProfile = { ...currentProfile };
    Object.keys(updateData).forEach(key => {
      if (updateData[key] !== undefined) {
        mergedProfile[key] = updateData[key];
      }
    });
    
    console.log('🔄 合并前 - currentProfile 字段数:', Object.keys(currentProfile || {}).length);
    console.log('🔄 合并前 - updateData 字段数:', Object.keys(updateData).length);
    console.log('🔄 合并后 - mergedProfile.user_role:', mergedProfile.user_role);
    console.log('🔄 合并后 - mergedProfile.target_degree:', mergedProfile.target_degree);
    
    // 计算画像完整度（基于合并后的完整数据）
    const requiredFields = [
      mergedProfile.user_role,
      mergedProfile.target_degree,
      mergedProfile.target_majors,
      mergedProfile.target_countries,
      mergedProfile.portfolio_status,
      mergedProfile.english_test_score,
      mergedProfile.total_budget_range,
      mergedProfile.target_intake
    ];
    const optionalFields = [
      mergedProfile.current_school,
      mergedProfile.current_major,
      mergedProfile.gpa_or_grade,
      mergedProfile.school_type_preference,
      mergedProfile.portfolio_style_tendency,
      mergedProfile.favorite_artists_or_styles,
      mergedProfile.priority_factors
    ];
    const filledRequired = requiredFields.filter(f => f !== undefined && f !== null && f !== '' && (Array.isArray(f) ? f.length > 0 : true)).length;
    const filledOptional = optionalFields.filter(f => f !== undefined && f !== null && f !== '' && (Array.isArray(f) ? f.length > 0 : true)).length;
    updateData.profile_completion_score = Math.round((filledRequired / requiredFields.length) * 60 + (filledOptional / optionalFields.length) * 40);
    
    console.log('📊 完成度计算:', {
      filledRequired,
      totalRequired: requiredFields.length,
      filledOptional,
      totalOptional: optionalFields.length,
      score: updateData.profile_completion_score
    });
    
    // 如果完成度达到 80%，标记 onboarding 完成
    if (updateData.profile_completion_score >= 80 && !updateData.onboarding_completed_at) {
      updateData.onboarding_completed_at = new Date().toISOString();
      updateData.has_completed_onboarding = true;
    }

    // 更新用户资料；如果注册后 user_profiles 尚未建行，则自动创建。
    const { data: profile, error: updateError } = await supabase
      .from("user_profiles")
      .upsert(
        {
          id: user.id,
          ...updateData,
        },
        { onConflict: "id" }
      )
      .select("*")
      .single();

    if (updateError) {
      console.error("更新用户资料失败:", updateError);
      return NextResponse.json(
        { message: updateError.message || "更新失败" },
        { status: 500 }
      );
    }

    console.log('✅ 更新成功，返回数据中的完成度:', profile?.profile_completion_score);

    return NextResponse.json({
      id: user.id,
      email: user.email,
      username: profile?.nickname || user.user_metadata?.username || "",
      targetCountries: profile?.target_countries || [],
      targetMajors: profile?.target_majors || [],
      budgetRange: profile?.total_budget_range || "",
      languageLevel: profile?.english_test_score || "",
      timeline: profile?.target_intake || "",
      profile_completion_score: profile?.profile_completion_score || 0,
      // 完整的用户画像数据
      userRole: profile?.user_role || null,
      targetDegree: profile?.target_degree || null,
      currentEducationStage: profile?.current_education_stage || null,
      currentSchool: profile?.current_school || null,
      currentMajor: profile?.current_major || null,
      targetDirections: profile?.target_directions || [],
      schoolTypePreference: profile?.school_type_preference || null,
      rankingSensitivity: profile?.ranking_sensitivity || null,
      cityPreference: profile?.city_preference || null,
      portfolioStatus: profile?.portfolio_status || null,
      portfolioStyleTendency: profile?.portfolio_style_tendency || null,
      englishTestType: profile?.english_test_type || null,
      englishTestScore: profile?.english_test_score || null,
      otherLanguages: profile?.other_languages || null,
      totalBudgetRange: profile?.total_budget_range || null,
      scholarshipNeed: profile?.scholarship_need || null,
      familySupportLevel: profile?.family_support_level || null,
      targetIntake: profile?.target_intake || null,
      favoriteArtistsOrStyles: profile?.favorite_artists_or_styles || null,
      priorityFactors: profile?.priority_factors || null,
      onboardingCompletedAt: profile?.onboarding_completed_at || null,
    });
  } catch (error: unknown) {
    console.error("更新用户资料错误:", error);
    const message = error instanceof Error ? error.message : "服务器错误";
    return NextResponse.json(
      { message },
      { status: 500 }
    );
  }
}
