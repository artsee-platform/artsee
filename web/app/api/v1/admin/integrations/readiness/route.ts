import { NextRequest, NextResponse } from "next/server";

import {
  buildIntegrationReadinessReport,
  type IntegrationReadinessProbes,
} from "@/lib/api/integration-readiness";
import { requireAdmin } from "@/lib/api/require-admin";
import { createServiceClient } from "@/lib/api/supabase-service";

export const runtime = "nodejs";

type ServiceClient = ReturnType<typeof createServiceClient>;

async function probeTable(
  supabase: ServiceClient,
  table: string,
  columns: string
) {
  try {
    const { error } = await supabase
      .from(table)
      .select(columns, { count: "exact", head: true })
      .limit(1);
    return !error;
  } catch {
    return false;
  }
}

async function probeSmsGlobalLimiter(supabase: ServiceClient) {
  try {
    const { error } = await supabase.rpc("reserve_sms_verification", {
      p_phone: "+8600000000000",
      p_country_code: "+86",
      p_purpose: "readiness_probe",
      p_code_hash: "0".repeat(64),
      p_expires_at: new Date(Date.now() + 60_000).toISOString(),
      p_ip_hash: "0".repeat(64),
      p_phone_cooldown_seconds: 0,
      p_phone_hourly_limit: 0,
      p_phone_daily_limit: 0,
      p_ip_hourly_limit: 0,
      p_ip_daily_limit: 0,
      p_global_hourly_limit: 0,
      p_global_daily_limit: 0,
    });
    return Boolean(error?.message?.includes("SMS_RATE_CONFIG_INVALID"));
  } catch {
    return false;
  }
}

async function collectProbes(): Promise<IntegrationReadinessProbes> {
  const supabase = createServiceClient();
  const [
    supabaseCore,
    cosUploadSchema,
    smsSchema,
    smsGlobalLimiter,
    imPermitSchema,
  ] = await Promise.all([
    probeTable(supabase, "user_profiles", "id,role"),
    probeTable(
      supabase,
      "upload_files",
      "id,expected_size,access_level,upload_status"
    ),
    probeTable(
      supabase,
      "sms_verifications",
      "id,verification_code_hash,request_ip_hash,delivery_status"
    ),
    probeSmsGlobalLimiter(supabase),
    probeTable(
      supabase,
      "tencent_im_send_permits",
      "token_hash,target_kind,msg_body_sha256,expires_at"
    ),
  ]);
  return {
    supabaseCore,
    cosUploadSchema,
    smsSchema,
    smsGlobalLimiter,
    imPermitSchema,
  };
}

export async function GET(request: NextRequest) {
  const admin = await requireAdmin(request);
  if ("response" in admin) return admin.response;

  const report = buildIntegrationReadinessReport({
    probes: await collectProbes(),
  });
  return NextResponse.json(report, {
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
