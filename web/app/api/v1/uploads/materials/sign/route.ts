import { NextRequest, NextResponse } from "next/server";
import { isAdminProfile, requireUser } from "@/lib/api/authz";
import { errorResponse } from "@/lib/api/route-helpers";
import { createServiceClient } from "@/lib/api/supabase-service";
import {
  isOwnedSubmissionMaterialPath,
  materialPathFromUrlOrPath,
  SUBMISSION_MATERIALS_BUCKET,
} from "@/lib/api/submission-materials";
import {
  createTencentCosGetUrl,
  isOwnedTencentCosKey,
  tencentCosKeyFromUrlOrKey,
} from "@/lib/api/tencent-cos";
import { TencentCloudConfigError } from "@/lib/api/tencent-cloud";

type Body = {
  path?: unknown;
  url?: unknown;
  contract_id?: unknown;
};

type Row = Record<string, unknown>;

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizedMaterialReference(value: string) {
  return tencentCosKeyFromUrlOrKey(value) ?? materialPathFromUrlOrPath(value);
}

async function canAccessContractFile(input: {
  supabase: ReturnType<typeof createServiceClient>;
  contractId: string;
  userId: string;
  requestedReference: string;
  isAdmin: boolean;
}) {
  if (!input.contractId) return false;
  const { data, error } = await input.supabase
    .from("contracts")
    .select("id,user_id,organization_id,file_url")
    .eq("id", input.contractId)
    .maybeSingle();
  if (error) throw error;
  const contract = (data ?? null) as Row | null;
  if (!contract) return false;

  const contractReference = normalizedMaterialReference(cleanText(contract.file_url));
  if (!contractReference || contractReference !== input.requestedReference) return false;
  if (input.isAdmin || contract.user_id === input.userId) return true;

  const organizationId = cleanText(contract.organization_id);
  if (!organizationId) return false;
  const { data: membership, error: membershipError } = await input.supabase
    .from("organization_members")
    .select("id")
    .eq("organization_id", organizationId)
    .eq("user_id", input.userId)
    .eq("status", "active")
    .in("role", ["owner", "admin"])
    .maybeSingle();
  if (membershipError) throw membershipError;
  return Boolean(membership);
}

export async function POST(req: NextRequest) {
  try {
    const auth = await requireUser(req);
    if ("response" in auth) return auth.response;

    const body = (await req.json().catch(() => ({}))) as Body;
    const raw = cleanText(body.path) || cleanText(body.url);
    const contractId = cleanText(body.contract_id);
    if (!raw) {
      return NextResponse.json(
        { success: false, error: "无效材料路径" },
        { status: 400 }
      );
    }

    const isAdmin = isAdminProfile(auth.profile);
    const supabase = createServiceClient();
    const cosKey = tencentCosKeyFromUrlOrKey(raw);
    if (cosKey) {
      const { data, error } = await supabase
        .from("upload_files")
        .select("id,user_id,file_url,object_key,scene,access_level,upload_status")
        .eq("provider", "tencent_cos")
        .eq("object_key", cosKey)
        .maybeSingle();
      if (error) return errorResponse(error);
      const upload = (data ?? null) as Row | null;
      if (!upload || upload.upload_status !== "completed") {
        return NextResponse.json(
          { success: false, error: "材料文件不存在或尚未完成上传" },
          { status: 404 }
        );
      }

      const contractAccess = await canAccessContractFile({
        supabase,
        contractId,
        userId: auth.user.id,
        requestedReference: cosKey,
        isAdmin,
      });
      const isOwner =
        upload.user_id === auth.user.id && isOwnedTencentCosKey(cosKey, auth.user.id);
      if (!isAdmin && !isOwner && !contractAccess) {
        return NextResponse.json(
          { success: false, error: "无权访问该材料" },
          { status: 403 }
        );
      }

      const expiresIn = 10 * 60;
      return NextResponse.json({
        success: true,
        provider: "tencent_cos",
        key: cosKey,
        signed_url: createTencentCosGetUrl(cosKey, expiresIn),
        expires_in: expiresIn,
      });
    }

    const path = materialPathFromUrlOrPath(raw);
    if (!path) {
      return NextResponse.json(
        { success: false, error: "无效材料路径" },
        { status: 400 }
      );
    }

    const contractAccess = await canAccessContractFile({
      supabase,
      contractId,
      userId: auth.user.id,
      requestedReference: path,
      isAdmin,
    });
    if (
      !isAdmin &&
      !contractAccess &&
      !isOwnedSubmissionMaterialPath(path, auth.user.id)
    ) {
      return NextResponse.json(
        { success: false, error: "无权访问该材料" },
        { status: 403 }
      );
    }

    const { data, error } = await supabase.storage
      .from(SUBMISSION_MATERIALS_BUCKET)
      .createSignedUrl(path, 10 * 60);
    if (error) return errorResponse(error);

    return NextResponse.json({
      success: true,
      provider: "supabase",
      path,
      signed_url: data?.signedUrl ?? null,
      expires_in: 10 * 60,
    });
  } catch (e) {
    if (e instanceof TencentCloudConfigError) {
      return NextResponse.json(
        { success: false, error: e.message, missing: e.missing },
        { status: 503 }
      );
    }
    return errorResponse(e);
  }
}
