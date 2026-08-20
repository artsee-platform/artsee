import { createHash } from "crypto";
import { createClient, type User } from "@supabase/supabase-js";
import { createServiceClient } from "@/lib/api/supabase-service";
import type { NormalizedPhone } from "@/lib/api/tencent-sms";

export class PhoneAuthSessionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PhoneAuthSessionError";
  }
}

function getPublicAuthClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ||
    process.env.SUPABASE_ANON_KEY?.trim();
  if (!url || !key) throw new PhoneAuthSessionError("Supabase Auth 配置不完整");
  return createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

function internalEmail(phone: string) {
  const digest = createHash("sha256").update(phone, "utf8").digest("hex").slice(0, 32);
  return `phone.${digest}@auth.artsee.internal`;
}

async function scanAuthUserByPhone(phone: string) {
  const service = createServiceClient();
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await service.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw new PhoneAuthSessionError("无法查询手机号账号");
    const match = data.users.find((user) => user.phone === phone);
    if (match) return match;
    if (data.users.length < 1000) return null;
  }
  throw new PhoneAuthSessionError("手机号账号数量超过安全查询范围");
}

async function findLinkedUser(phone: string) {
  const service = createServiceClient();
  const { data: link, error: linkError } = await service
    .from("auth_provider_links")
    .select("user_id")
    .eq("provider", "phone")
    .eq("provider_user_id", phone)
    .maybeSingle();
  if (linkError) throw new PhoneAuthSessionError("无法查询手机号关联账号");
  if (!link?.user_id) return null;

  const { data, error } = await service.auth.admin.getUserById(link.user_id);
  if (error || !data.user) throw new PhoneAuthSessionError("手机号关联账号不存在");
  return data.user;
}

async function createOrFindPhoneUser(phone: NormalizedPhone) {
  const service = createServiceClient();
  const linked = await findLinkedUser(phone.e164);
  if (linked) return { user: linked, isNewUser: false };

  const email = internalEmail(phone.e164);
  const { data, error } = await service.auth.admin.createUser({
    phone: phone.e164,
    phone_confirm: true,
    email,
    email_confirm: true,
    app_metadata: { auth_origin: "tencent_sms" },
    user_metadata: {
      phone: phone.nationalNumber,
      country_code: phone.countryCode,
    },
  });

  if (!error && data.user) return { user: data.user, isNewUser: true };

  const existing = await scanAuthUserByPhone(phone.e164);
  if (!existing) {
    throw new PhoneAuthSessionError(error?.message || "创建手机号账号失败");
  }
  return { user: existing, isNewUser: false };
}

async function ensureUserEmail(user: User, phone: string) {
  if (user.email) return user;
  const service = createServiceClient();
  const { data, error } = await service.auth.admin.updateUserById(user.id, {
    email: internalEmail(phone),
    email_confirm: true,
  });
  if (error || !data.user) throw new PhoneAuthSessionError("无法准备手机号登录会话");
  return data.user;
}

export async function issuePhoneAuthSession(phone: NormalizedPhone) {
  const service = createServiceClient();
  const account = await createOrFindPhoneUser(phone);
  const user = await ensureUserEmail(account.user, phone.e164);
  const email = user.email;
  if (!email) throw new PhoneAuthSessionError("手机号账号缺少内部登录标识");

  let profile: Record<string, unknown> | null = null;
  const { data: linkedProfile, error: linkError } = await service.rpc(
    "link_phone_auth_user",
    {
      p_user_id: user.id,
      p_e164: phone.e164,
      p_national_number: phone.nationalNumber,
      p_country_code: phone.countryCode,
    }
  );
  if (linkError) {
    if (account.isNewUser) {
      const { error: cleanupError } = await service.auth.admin.deleteUser(user.id);
      if (cleanupError) {
        throw new PhoneAuthSessionError("手机号账号关联失败，且新账号回滚失败");
      }
    }
    throw new PhoneAuthSessionError("无法原子保存手机号账号关联与用户资料");
  }
  if (
    linkedProfile &&
    typeof linkedProfile === "object" &&
    !Array.isArray(linkedProfile)
  ) {
    profile = linkedProfile as Record<string, unknown>;
  }

  const { data: link, error: generateLinkError } = await service.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  const tokenHash = link?.properties?.hashed_token;
  if (generateLinkError || !tokenHash) {
    throw new PhoneAuthSessionError("无法生成手机号登录会话");
  }

  const publicAuth = getPublicAuthClient();
  const { data: verified, error: verifyError } = await publicAuth.auth.verifyOtp({
    token_hash: tokenHash,
    type: "magiclink",
  });
  if (verifyError || !verified.session || !verified.user) {
    throw new PhoneAuthSessionError("无法兑换手机号登录会话");
  }

  return {
    isNewUser: account.isNewUser,
    user: {
      id: verified.user.id,
      phone: phone.nationalNumber,
      country_code: phone.countryCode,
      role: typeof profile?.role === "string" ? profile.role : "user",
      profile,
    },
    session: {
      access_token: verified.session.access_token,
      refresh_token: verified.session.refresh_token,
      expires_in: verified.session.expires_in,
      expires_at: verified.session.expires_at,
      token_type: verified.session.token_type,
    },
  };
}
