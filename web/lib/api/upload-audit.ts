import type { AuditContentResult, AuditItemResult } from "@/lib/api/content-safety";
import { createServiceClient } from "@/lib/api/supabase-service";

function auditStatusForItem(item: AuditItemResult) {
  if (item.suggestion === "pass") return "approved";
  if (item.suggestion === "block") return "rejected";
  return "reviewing";
}

export async function recordUploadAuditResults(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  imageUrls: string[],
  audit: AuditContentResult
) {
  const imageItems = audit.items.filter((item) => item.type === "image");
  await Promise.all(
    imageItems.map(async (item, index) => {
      const fileUrl = imageUrls[index];
      if (!fileUrl) return;
      const { error } = await supabase
        .from("upload_files")
        .update({
          audit_status: auditStatusForItem(item),
          audit_provider: audit.provider,
          audit_metadata: {
            suggestion: item.suggestion,
            label: item.label,
            sub_label: item.sub_label,
            score: item.score,
            request_id: item.request_id,
          },
          audited_at: new Date().toISOString(),
        })
        .eq("user_id", userId)
        .eq("file_url", fileUrl);
      if (error) {
        console.warn("[content-safety] failed to persist upload audit", {
          fileUrl,
          message: error.message,
        });
      }
    })
  );
}
