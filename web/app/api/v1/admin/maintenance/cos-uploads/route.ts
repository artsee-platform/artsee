import { NextRequest, NextResponse } from "next/server";
import { requireAdmin } from "@/lib/api/require-admin";
import { createServiceClient } from "@/lib/api/supabase-service";
import { deleteTencentCosUpload } from "@/lib/api/cos-upload-deletion";
import { errorResponse } from "@/lib/api/route-helpers";

type Row = { id: string };

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanupSecret() {
  return (
    process.env.COS_UPLOAD_CLEANUP_CRON_SECRET ||
    process.env.ADMIN_MAINTENANCE_CRON_SECRET ||
    ""
  );
}

async function authorize(req: NextRequest) {
  const configuredSecret = cleanupSecret();
  const requestSecret = cleanText(req.headers.get("x-artiqore-cron-secret"));
  if (configuredSecret && requestSecret === configuredSecret) {
    return { ok: true, actor: "cron" } as const;
  }

  const admin = await requireAdmin(req);
  if ("response" in admin) {
    return { ok: false, response: admin.response } as const;
  }
  return { ok: true, actor: admin.user.id } as const;
}

function cleanupLimit(req: NextRequest) {
  const requested = Number.parseInt(new URL(req.url).searchParams.get("limit") ?? "", 10);
  return Number.isFinite(requested) ? Math.min(Math.max(requested, 1), 100) : 25;
}

export async function POST(req: NextRequest) {
  try {
    const auth = await authorize(req);
    if (!auth.ok) return auth.response;

    const ranAt = new Date().toISOString();
    const { data, error } = await createServiceClient()
      .from("upload_files")
      .select("id")
      .eq("provider", "tencent_cos")
      .eq("upload_status", "pending")
      .lt("expires_at", ranAt)
      .limit(cleanupLimit(req));
    if (error) return errorResponse(error);

    const deleted: string[] = [];
    const skipped: string[] = [];
    const failed: string[] = [];
    for (const row of (data ?? []) as Row[]) {
      try {
        const result = await deleteTencentCosUpload({ uploadId: row.id });
        if (result.status === "deleted") deleted.push(row.id);
        else skipped.push(row.id);
      } catch (error) {
        console.error("[cos-upload-cleanup] failed", {
          uploadId: row.id,
          error: error instanceof Error ? error.message : String(error),
        });
        failed.push(row.id);
      }
    }

    return NextResponse.json(
      {
        success: failed.length === 0,
        ran_at: ranAt,
        actor: auth.actor,
        data: {
          scanned: (data ?? []).length,
          deleted: deleted.length,
          skipped: skipped.length,
          failed: failed.length,
          failed_upload_ids: failed,
        },
      },
      { status: failed.length === 0 ? 200 : 502 }
    );
  } catch (error) {
    return errorResponse(error);
  }
}
