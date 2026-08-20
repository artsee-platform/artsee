export type IntegrationReadinessStatus = "ready" | "attention" | "blocked";
export type IntegrationRequirementSeverity = "blocking" | "warning";
export type IntegrationRequirementKind =
  | "secret"
  | "config"
  | "migration"
  | "console"
  | "smoke_test";

export type IntegrationRequirement = {
  key: string;
  label: string;
  kind: IntegrationRequirementKind;
  severity: IntegrationRequirementSeverity;
  satisfied: boolean;
  remediation: string;
};

export type IntegrationReadinessItem = {
  id: string;
  name: string;
  description: string;
  status: IntegrationReadinessStatus;
  requirements: IntegrationRequirement[];
  documentationUrl: string;
  guidePath: string;
};

export type IntegrationReadinessProbes = {
  supabaseCore: boolean;
  cosUploadSchema: boolean;
  smsSchema: boolean;
  smsGlobalLimiter: boolean;
  imPermitSchema: boolean;
};

export type IntegrationReadinessReport = {
  success: true;
  generated_at: string;
  environment: string;
  summary: {
    total: number;
    ready: number;
    attention: number;
    blocked: number;
  };
  integrations: IntegrationReadinessItem[];
};

function value(env: NodeJS.ProcessEnv, key: string) {
  return env[key]?.trim() ?? "";
}

function configured(env: NodeJS.ProcessEnv, ...keys: string[]) {
  return keys.every((key) => value(env, key).length > 0);
}

function flag(env: NodeJS.ProcessEnv, key: string) {
  return ["1", "true", "yes", "on"].includes(value(env, key).toLowerCase());
}

function positiveInteger(env: NodeJS.ProcessEnv, key: string) {
  const candidate = value(env, key);
  return /^\d+$/.test(candidate) && Number(candidate) > 0;
}

function requirement(input: IntegrationRequirement) {
  return input;
}

function statusFor(requirements: IntegrationRequirement[]) {
  if (
    requirements.some(
      (item) => !item.satisfied && item.severity === "blocking"
    )
  ) {
    return "blocked" as const;
  }
  if (requirements.some((item) => !item.satisfied)) {
    return "attention" as const;
  }
  return "ready" as const;
}

function integration(input: Omit<IntegrationReadinessItem, "status">) {
  return { ...input, status: statusFor(input.requirements) };
}

export function buildIntegrationReadinessReport(input: {
  probes: IntegrationReadinessProbes;
  env?: NodeJS.ProcessEnv;
  now?: Date;
}): IntegrationReadinessReport {
  const env = input.env ?? process.env;
  const sharedTencentCredentials = configured(
    env,
    "TENCENT_CLOUD_SECRET_ID",
    "TENCENT_CLOUD_SECRET_KEY"
  );
  const integrations = [
    integration({
      id: "supabase",
      name: "Supabase",
      description: "Auth、Postgres、Storage 与 BFF 服务端访问基础。",
      documentationUrl: "https://supabase.com/docs/guides/api/securing-your-api",
      guidePath: "docs/SETUP_DATABASE.md",
      requirements: [
        requirement({
          key: "NEXT_PUBLIC_SUPABASE_URL",
          label: "项目 URL 已配置",
          kind: "config",
          severity: "blocking",
          satisfied: configured(env, "NEXT_PUBLIC_SUPABASE_URL"),
          remediation: "在 BFF 环境配置 Supabase 项目 URL。",
        }),
        requirement({
          key: "NEXT_PUBLIC_SUPABASE_ANON_KEY",
          label: "客户端 Key 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: configured(env, "NEXT_PUBLIC_SUPABASE_ANON_KEY"),
          remediation: "配置 Supabase publishable/anon key。",
        }),
        requirement({
          key: "SUPABASE_SERVICE_ROLE_KEY",
          label: "服务端 Service Role 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: configured(env, "SUPABASE_SERVICE_ROLE_KEY"),
          remediation: "仅在 BFF 配置 Service Role，禁止放入 Flutter。",
        }),
        requirement({
          key: "database:user_profiles",
          label: "数据库与管理员资料表可读",
          kind: "migration",
          severity: "blocking",
          satisfied: input.probes.supabaseCore,
          remediation: "检查数据库连接、Data API 暴露设置和 user_profiles 迁移。",
        }),
      ],
    }),
    integration({
      id: "amap",
      name: "高德地图 Web Service",
      description: "地理编码通过 BFF 调用，不向 Flutter 暴露服务端 Key。",
      documentationUrl: "https://lbs.amap.com/api/webservice/guide/api/georegeo",
      guidePath: "web/app/api/v1/maps/geocode/route.ts",
      requirements: [
        requirement({
          key: "AMAP_WEB_SERVICE_KEY",
          label: "Web Service Key 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: configured(env, "AMAP_WEB_SERVICE_KEY"),
          remediation: "创建 Web 服务 Key，并仅配置到 BFF。",
        }),
        requirement({
          key: "AMAP_SMOKE_TESTED",
          label: "生产地理编码冒烟已确认",
          kind: "smoke_test",
          severity: "warning",
          satisfied: flag(env, "AMAP_SMOKE_TESTED"),
          remediation: "成功调用一次受限测试地址后设为 1。",
        }),
      ],
    }),
    integration({
      id: "tencent_cos",
      name: "腾讯云 COS",
      description: "内容上传签名、对象校验、删除与过期清理链路。",
      documentationUrl: "https://cloud.tencent.com/document/product/436",
      guidePath: "docs/TENCENT_CLOUD_CONTENT_PIPELINE.md",
      requirements: [
        requirement({
          key: "TENCENT_CLOUD_SECRET_ID,TENCENT_CLOUD_SECRET_KEY",
          label: "腾讯云 CAM 密钥已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: sharedTencentCredentials,
          remediation: "配置最小权限 CAM 子账号密钥。",
        }),
        requirement({
          key: "TENCENT_COS_BUCKET,TENCENT_COS_REGION",
          label: "Bucket 与地域已配置",
          kind: "config",
          severity: "blocking",
          satisfied:
            configured(env, "TENCENT_COS_BUCKET") &&
            (configured(env, "TENCENT_COS_REGION") ||
              configured(env, "TENCENT_CLOUD_REGION")),
          remediation: "配置 Bucket 名称和实际地域。",
        }),
        requirement({
          key: "database:upload_files",
          label: "COS 上传状态迁移已生效",
          kind: "migration",
          severity: "blocking",
          satisfied: input.probes.cosUploadSchema,
          remediation: "应用 harden_cos_uploads 迁移。",
        }),
        requirement({
          key: "TENCENT_COS_CORS_CONFIGURED",
          label: "Bucket CORS 已核对",
          kind: "console",
          severity: "warning",
          satisfied: flag(env, "TENCENT_COS_CORS_CONFIGURED"),
          remediation: "执行 CORS 脚本并在控制台核对后设为 1。",
        }),
      ],
    }),
    integration({
      id: "content_safety",
      name: "腾讯云内容安全",
      description: "文本与图片在敏感写入前由 BFF 审核。",
      documentationUrl: "https://cloud.tencent.com/document/product/1124",
      guidePath: "docs/TENCENT_CLOUD_CONTENT_PIPELINE.md",
      requirements: [
        requirement({
          key: "TENCENT_CLOUD_SECRET_ID,TENCENT_CLOUD_SECRET_KEY",
          label: "腾讯云 CAM 密钥已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: sharedTencentCredentials,
          remediation: "配置内容安全最小权限 CAM 子账号密钥。",
        }),
        requirement({
          key: "TENCENT_CONTENT_SAFETY_TEXT_BIZ_TYPE",
          label: "文本自定义 BizType 已配置",
          kind: "config",
          severity: "blocking",
          satisfied: configured(env, "TENCENT_CONTENT_SAFETY_TEXT_BIZ_TYPE"),
          remediation: "在控制台创建文本 BizType，并配置其名称。",
        }),
        requirement({
          key: "TENCENT_CONTENT_SAFETY_IMAGE_BIZ_TYPE",
          label: "图片自定义 BizType 已配置",
          kind: "config",
          severity: "blocking",
          satisfied: configured(env, "TENCENT_CONTENT_SAFETY_IMAGE_BIZ_TYPE"),
          remediation: "在控制台创建图片 BizType，并配置其名称。",
        }),
        requirement({
          key: "TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS",
          label: "图片来源域名白名单已配置",
          kind: "config",
          severity: "blocking",
          satisfied:
            configured(env, "TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS") ||
            configured(env, "NEXT_PUBLIC_SUPABASE_URL") ||
            (configured(env, "TENCENT_COS_BUCKET") &&
              (configured(env, "TENCENT_COS_REGION") ||
                configured(env, "TENCENT_CLOUD_REGION"))),
          remediation: "配置平台 COS/Supabase Storage 的 HTTPS 图片域名。",
        }),
        requirement({
          key: "TENCENT_CONTENT_SAFETY_SMOKE_TESTED",
          label: "文本与图片审核冒烟已确认",
          kind: "smoke_test",
          severity: "warning",
          satisfied: flag(env, "TENCENT_CONTENT_SAFETY_SMOKE_TESTED"),
          remediation: "分别验证 pass/review/block 后设为 1。",
        }),
      ],
    }),
    integration({
      id: "tencent_im",
      name: "腾讯云 IM 与 BFF 防绕过",
      description: "单聊、群聊、离线消息及发送前回调授权。",
      documentationUrl: "https://cloud.tencent.com/document/product/269/1522",
      guidePath: "docs/TENCENT_IM_BFF_CALLBACK.md",
      requirements: [
        requirement({
          key: "TENCENT_IM_SDK_APP_ID,TENCENT_IM_SECRET_KEY",
          label: "IM SDKAppID 与 SecretKey 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied:
            positiveInteger(env, "TENCENT_IM_SDK_APP_ID") &&
            configured(env, "TENCENT_IM_SECRET_KEY"),
          remediation: "配置 IM 应用信息，SecretKey 只保存在 BFF。",
        }),
        requirement({
          key: "TENCENT_IM_CALLBACK_TOKEN",
          label: "发送前回调 Token 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: value(env, "TENCENT_IM_CALLBACK_TOKEN").length >= 32,
          remediation: "生成至少 32 字符的独立随机 Token。",
        }),
        requirement({
          key: "TENCENT_IM_REQUIRE_BFF_CALLBACK",
          label: "BFF 严格发送模式已开启",
          kind: "config",
          severity: "blocking",
          satisfied: flag(env, "TENCENT_IM_REQUIRE_BFF_CALLBACK"),
          remediation: "控制台回调就绪后设为 1。",
        }),
        requirement({
          key: "database:tencent_im_send_permits",
          label: "一次性发送票据迁移已生效",
          kind: "migration",
          severity: "blocking",
          satisfied: input.probes.imPermitSchema,
          remediation: "应用 tencent_im_bff_callback_permits 迁移。",
        }),
        requirement({
          key: "TENCENT_IM_CALLBACK_CONSOLE_CONFIGURED",
          label: "控制台前回调与失败不下发已确认",
          kind: "console",
          severity: "blocking",
          satisfied: flag(env, "TENCENT_IM_CALLBACK_CONSOLE_CONFIGURED"),
          remediation: "开启单聊/群聊前回调、失败不下发，关闭客户端禁用后设为 1。",
        }),
      ],
    }),
    integration({
      id: "tencent_push",
      name: "腾讯云 IM 离线推送",
      description: "APNs、Android 厂商/FCM 与 Flutter registerPush。",
      documentationUrl: "https://cloud.tencent.com/document/product/269/105661",
      guidePath: "docs/TENCENT_CLOUD_OFFLINE_PUSH.md",
      requirements: [
        requirement({
          key: "code:registerPush",
          label: "客户端 registerPush 代码已接入",
          kind: "config",
          severity: "blocking",
          satisfied: true,
          remediation: "保持登录后注册、退出时反注册逻辑。",
        }),
        requirement({
          key: "TENCENT_PUSH_CONSOLE_CONFIGURED",
          label: "Push Key、APNs、厂商/FCM 已在控制台配置",
          kind: "console",
          severity: "blocking",
          satisfied: flag(env, "TENCENT_PUSH_CONSOLE_CONFIGURED"),
          remediation: "完成腾讯推送控制台平台凭据配置后设为 1。",
        }),
        requirement({
          key: "TENCENT_PUSH_CLIENT_BUILD_CONFIGURED",
          label: "正式客户端构建参数与原生文件已确认",
          kind: "config",
          severity: "blocking",
          satisfied: flag(env, "TENCENT_PUSH_CLIENT_BUILD_CONFIGURED"),
          remediation: "核对 APNs 证书 ID、厂商配置文件和 dart-define 后设为 1。",
        }),
        requirement({
          key: "TENCENT_PUSH_SMOKE_TESTED",
          label: "iOS/Android 离线到达与点击跳转已验证",
          kind: "smoke_test",
          severity: "warning",
          satisfied: flag(env, "TENCENT_PUSH_SMOKE_TESTED"),
          remediation: "真机杀进程测试通知到达与会话跳转后设为 1。",
        }),
      ],
    }),
    integration({
      id: "tencent_sms",
      name: "腾讯云短信",
      description: "验证码发送、原子限流、防盗刷与 Supabase 登录会话。",
      documentationUrl: "https://cloud.tencent.com/document/product/382/13303",
      guidePath: "docs/TENCENT_CLOUD_SMS.md",
      requirements: [
        requirement({
          key: "TENCENT_CLOUD_SECRET_ID,TENCENT_CLOUD_SECRET_KEY",
          label: "腾讯云 CAM 密钥已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: sharedTencentCredentials,
          remediation: "配置短信发送最小权限 CAM 子账号密钥。",
        }),
        requirement({
          key: "TENCENT_SMS_SDK_APP_ID,TENCENT_SMS_SIGN_NAME,TENCENT_SMS_TEMPLATE_ID",
          label: "短信应用、签名和模板已配置",
          kind: "config",
          severity: "blocking",
          satisfied:
            positiveInteger(env, "TENCENT_SMS_SDK_APP_ID") &&
            configured(env, "TENCENT_SMS_SIGN_NAME") &&
            positiveInteger(env, "TENCENT_SMS_TEMPLATE_ID"),
          remediation: "配置已审核通过的应用、签名和模板 ID。",
        }),
        requirement({
          key: "SMS_OTP_PEPPER",
          label: "验证码哈希 Pepper 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied: Buffer.byteLength(value(env, "SMS_OTP_PEPPER"), "utf8") >= 32,
          remediation: "生成独立的至少 32 字节高熵 Pepper。",
        }),
        requirement({
          key: "database:sms_verifications",
          label: "短信安全表结构迁移已生效",
          kind: "migration",
          severity: "blocking",
          satisfied: input.probes.smsSchema,
          remediation: "应用 harden_sms_auth 迁移。",
        }),
        requirement({
          key: "rpc:reserve_sms_verification(global limits)",
          label: "应用级小时/日熔断迁移已生效",
          kind: "migration",
          severity: "blocking",
          satisfied: input.probes.smsGlobalLimiter,
          remediation: "应用 harden_sms_global_limits 迁移并刷新 PostgREST schema。",
        }),
        requirement({
          key: "TENCENT_SMS_CONSOLE_GUARDS_CONFIGURED",
          label: "控制台频率、日限额和防盗刷告警已确认",
          kind: "console",
          severity: "warning",
          satisfied: flag(env, "TENCENT_SMS_CONSOLE_GUARDS_CONFIGURED"),
          remediation: "配置告警联系人、频率限制、日硬限额和防盗刷监控后设为 1。",
        }),
        requirement({
          key: "TENCENT_SMS_SMOKE_TESTED",
          label: "收费真实短信冒烟已确认",
          kind: "smoke_test",
          severity: "warning",
          satisfied: flag(env, "TENCENT_SMS_SMOKE_TESTED"),
          remediation: "经授权完成一次真实发送和登录后设为 1。",
        }),
      ],
    }),
    integration({
      id: "tencent_captcha",
      name: "腾讯云验证码",
      description: "Flutter Web/APP 人机挑战、AppId 强鉴权与服务端票据核验。",
      documentationUrl: "https://cloud.tencent.com/document/product/1110/36839",
      guidePath: "docs/TENCENT_CLOUD_SMS.md",
      requirements: [
        requirement({
          key: "TENCENT_CAPTCHA_APP_ID,TENCENT_CAPTCHA_APP_SECRET_KEY",
          label: "CaptchaAppId 与 AppSecretKey 已配置",
          kind: "secret",
          severity: "blocking",
          satisfied:
            positiveInteger(env, "TENCENT_CAPTCHA_APP_ID") &&
            configured(env, "TENCENT_CAPTCHA_APP_SECRET_KEY"),
          remediation: "创建 Web/App 类型短信场景验证码并配置密钥。",
        }),
        requirement({
          key: "TENCENT_CAPTCHA_ALLOWED_ORIGINS",
          label: "Flutter Web 来源已配置",
          kind: "config",
          severity: "blocking",
          satisfied: configured(env, "TENCENT_CAPTCHA_ALLOWED_ORIGINS"),
          remediation: "配置实际生产 Flutter Web origin。",
        }),
        requirement({
          key: "TENCENT_CAPTCHA_REQUIRED",
          label: "短信发送前强制验证码已开启",
          kind: "config",
          severity: "blocking",
          satisfied: flag(env, "TENCENT_CAPTCHA_REQUIRED"),
          remediation: "完成真实验收后设为 1。",
        }),
        requirement({
          key: "TENCENT_CAPTCHA_CONSOLE_CONFIGURED",
          label: "AppId 强制校验、一次一密与告警已确认",
          kind: "console",
          severity: "warning",
          satisfied: flag(env, "TENCENT_CAPTCHA_CONSOLE_CONFIGURED"),
          remediation: "在验证码控制台开启安全配置和告警后设为 1。",
        }),
        requirement({
          key: "TENCENT_CAPTCHA_SMOKE_TESTED",
          label: "Web、iOS、Android 票据核验已确认",
          kind: "smoke_test",
          severity: "warning",
          satisfied: flag(env, "TENCENT_CAPTCHA_SMOKE_TESTED"),
          remediation: "三端各完成一次验证和短信前置拦截后设为 1。",
        }),
      ],
    }),
  ];
  const summary = integrations.reduce(
    (result, item) => {
      result[item.status] += 1;
      return result;
    },
    { total: integrations.length, ready: 0, attention: 0, blocked: 0 }
  );

  return {
    success: true,
    generated_at: (input.now ?? new Date()).toISOString(),
    environment: value(env, "NODE_ENV") || "unknown",
    summary,
    integrations,
  };
}
