import { createServiceClient } from "@/lib/api/supabase-service";
import {
  deleteTencentCosObject,
  isOwnedTencentCosKey,
  TencentCosValidationError,
} from "@/lib/api/tencent-cos";

type UploadRow = {
  id: string;
  user_id: string;
  bucket: string | null;
  object_key: string | null;
  upload_status: string | null;
};

export type TencentCosUploadDeletion =
  | { status: "not_found" }
  | {
      status: "deleted";
      uploadId: string;
      key: string;
      previousStatus: string | null;
      objectWasMissing: boolean;
    };

export async function deleteTencentCosUpload(input: {
  uploadId: string;
  userId?: string;
}): Promise<TencentCosUploadDeletion> {
  const supabase = createServiceClient();
  let lookup = supabase
    .from("upload_files")
    .select("id,user_id,bucket,object_key,upload_status")
    .eq("id", input.uploadId)
    .eq("provider", "tencent_cos");
  if (input.userId) lookup = lookup.eq("user_id", input.userId);

  const { data, error } = await lookup.maybeSingle();
  if (error) throw error;
  if (!data) return { status: "not_found" };

  const upload = data as UploadRow;
  const key = typeof upload.object_key === "string" ? upload.object_key.trim() : "";
  if (!key || !isOwnedTencentCosKey(key, upload.user_id)) {
    throw new TencentCosValidationError("COS 上传记录的对象归属无效");
  }

  const deletedObject = await deleteTencentCosObject({
    key,
    expectedBucket: upload.bucket,
  });

  // Delete the database row only after COS confirms the object is absent.
  // If this final step fails, a retry is safe because DELETE Object is
  // idempotent and a missing object is treated as success.
  const { error: deleteError } = await supabase
    .from("upload_files")
    .delete()
    .eq("id", upload.id)
    .eq("user_id", upload.user_id)
    .eq("provider", "tencent_cos")
    .eq("object_key", key)
    .select("id")
    .maybeSingle();
  if (deleteError) throw deleteError;

  return {
    status: "deleted",
    uploadId: upload.id,
    key,
    previousStatus: upload.upload_status,
    objectWasMissing: deletedObject.alreadyMissing,
  };
}
