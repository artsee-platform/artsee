# User Profile Context

This context file is the shared contract for AI routes that need to personalize
Artsee / Artiqore recommendations from `user_profiles`.

## Source Of Truth

- Table: `public.user_profiles`
- Write API: `POST /api/v1/auth/update-profile`
- Read helper for AI routes: `web/lib/memory/load-profile.ts`
- Prompt formatter: `web/lib/memory/profile-formatter.ts`

AI routes should call `loadUserProfile(user.id)` instead of querying Supabase
directly. This keeps profile loading, timeouts, null handling, and field mapping
consistent.

## Core Fields

Required onboarding fields:

- `user_role`: `student | parent | working_professional | artist`
- `target_degree`: `foundation | bachelor | master | phd | non_degree`
- `current_education_stage`: `high_school | university_undergrad | graduated | working`
- `target_majors`: array of detailed major ids
- `target_countries`: array of country codes
- `portfolio_status`: `not_started | brainstorming | in_progress | mostly_done | refining`
- `target_intake`: intake id such as `2026_fall`

Important profile fields:

- `current_school`
- `current_major`
- `gpa_or_grade`
- `target_directions`
- `school_type_preference`
- `ranking_sensitivity`
- `city_preference`
- `portfolio_style_tendency`
- `english_test_type`
- `english_test_score`
- `total_budget_range`
- `scholarship_need`
- `family_support_level`
- `favorite_artists_or_styles`
- `priority_factors`

Completion metadata:

- `profile_completion_score`
- `has_completed_onboarding`
- `onboarding_completed_at`

## AI Usage Pattern

```ts
import { getUserFromBearer } from "@/lib/api/auth-user";
import { loadUserProfile, formatFullProfile } from "@/lib/memory";

const user = await getUserFromBearer(req);
const profile = user ? await loadUserProfile(user.id) : null;
const profileContext = profile
  ? formatFullProfile(profile, {
      identity: true,
      constraints: true,
      preferences: "full",
    })
  : "";
```

Use `profileContext` as a system prompt supplement. Treat user constraints such
as `target_countries`, `total_budget_range`, `scholarship_need`, and
`target_intake` as hard or high-priority constraints unless the user explicitly
asks to explore outside them.

## Current Consumer

- `web/app/api/v1/ai/schools/search/route.ts` already reads this profile via
  `loadUserProfile` and injects the formatted context into the AI prompt.
