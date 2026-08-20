# 腾讯云短信验证码接入

短信登录采用以下主链路：

1. `POST /api/v1/auth/send-sms` 在严格模式下先返回 `CAPTCHA_REQUIRED`。
2. Flutter Web 使用受限 iframe，Android/iOS 使用 WebView 打开
   `/api/v1/auth/captcha/challenge`，动态加载腾讯验证码 2.0 `TJCaptcha.js`。
3. 挑战页每次用 AppSecretKey 生成短时 AES-256-GCM `aidEncrypted`；客户端只取得
   `ticket` 与 `randstr`，不会取得 AppSecretKey。
4. BFF 调腾讯 `DescribeCaptchaResult` 二次核验，只有 `CaptchaCode=1` 且风险等级在
   配置范围内才继续；`trerror_` 容灾票据一律失败关闭。
5. 通过验证码后，数据库 RPC 原子执行应用全局、IP、手机号三层限流。
6. 服务端使用 `crypto.randomInt` 生成 6 位验证码，只保存带独立 Pepper 的 HMAC-SHA256。
7. 腾讯云 `SendSms` 返回明确的 `Code=Ok` 后，验证码才进入可验证状态。
8. `POST /api/v1/auth/verify-sms` 通过数据库 RPC 原子消费验证码，最多允许 5 次尝试。
9. 手机号身份关联与 `user_profiles` 更新由单个数据库 RPC 原子完成；新 Auth 用户若关联失败会补偿删除。
10. 验证成功后，服务端生成并兑换一次性 Supabase Magic Link，向 Flutter 返回标准 Auth Session。

## 腾讯验证码控制台

1. 图形验证 → 验证管理，新建客户端类型为 **Web/App**、场景为 **短信场景**的验证。
2. 建议初期选择“始终验证”或“可疑验证”，风控等级至少“平衡”；高风险期改为
   “安全优先”并使用文字/图形点选。
3. 确认代码已部署后，开启 **CaptchaAppId 强制校验**；代码使用 GCM、随机 12 字节
   IV 和 5 分钟密文有效期，可配合控制台“一次一密”。
4. 配置请求量激增、拦截率升高等验证码告警。
5. Flutter Web 来源加入 `TENCENT_CAPTCHA_ALLOWED_ORIGINS`。由于原生 App 按腾讯官方
   方式通过 WebView 接入，不建议对混合应用盲目开启域名强校验。

## 腾讯云控制台

- 开通短信服务并创建短信应用，取得 `SmsSdkAppId`。
- 创建国内短信签名与验证码正文模板，等待审核和运营商报备通过。
- 模板变量顺序必须与 `TENCENT_SMS_TEMPLATE_PARAM_ORDER` 一致：
  - 只有验证码变量：`code`
  - 验证码和有效分钟数：`code,ttl_minutes`
- 建议启用腾讯云发送频率限制、验证码防盗刷监控、日发送阈值和告警联系人。
- 建议初始控制台阈值：同号码 `1 条/60 秒、5 条/小时、10 条/自然日`；国内短信
  日提醒值应明显低于日硬限额。实际数值需结合正式上线后的正常峰值调整。
- 应用早期可从 `100 条/小时、500 条/日` 的 BFF 硬熔断开始；规模增长前先依据
  监控数据调整，不能直接取消全局限额。
- CAM 密钥只授予发送短信所需的最小权限。

## 上线前配置

按 `web/.env.production.example` 配置：

- `TENCENT_CLOUD_SECRET_ID`
- `TENCENT_CLOUD_SECRET_KEY`
- `TENCENT_SMS_SDK_APP_ID`
- `TENCENT_SMS_SIGN_NAME`
- `TENCENT_SMS_TEMPLATE_ID`
- `SMS_OTP_PEPPER`（独立高熵随机值）
- `TENCENT_CAPTCHA_APP_ID`
- `TENCENT_CAPTCHA_APP_SECRET_KEY`（只放 BFF，绝不能放 Flutter）
- `TENCENT_CAPTCHA_ALLOWED_ORIGINS=https://artiqore.com`

依次执行 `supabase/migrations/*_harden_sms_auth.sql` 与
`supabase/migrations/*_harden_sms_global_limits.sql`，完成真实验证码和短信验收后再设置：

```dotenv
TENCENT_CAPTCHA_REQUIRED=1
```

缺少任意关键配置或迁移时，接口会失败关闭，不会模拟验证或发送成功。

## 安全边界

- 迁移会撤销 `sms_verifications` 与 `auth_provider_links` 对 `PUBLIC`、`anon`、`authenticated` 的直接访问。
- 历史明文验证码在迁移执行时会被清空并失效。
- 数据库 RPC 使用事务级 advisory lock，确保同一手机号的发送限流和验证码消费不会被并发绕过。
- 全局 advisory lock 将应用级小时/日计数与验证码预留合并为一个原子决策，轮换 IP
  和手机号也不能突破应用硬上限。
- 全局熔断触发时 BFF 输出不含手机号/IP 的 `[sms-security]` 结构化告警日志，可接入
  现有日志平台；腾讯云控制台告警仍需单独配置。
- 腾讯票据在 BFF 二次校验；仅篡改 Flutter 或直接请求短信 API 无法伪造验证结果。
- API 不返回、不记录验证码和原始请求 IP。

## 上线验收

1. 未携带票据调用 `send-sms`，确认返回 HTTP `428` 和 `CAPTCHA_REQUIRED`。
2. 正常完成人机验证，确认只发送一条短信并开始 60 秒倒计时。
3. 重放同一 `ticket + randstr`，确认腾讯票据校验拒绝，且没有新增短信记录。
4. 模拟 `trerror_` 容灾票据、`EvilLevel=100`、过期票据和错误 AppId，均应失败。
5. 将测试环境全局小时阈值临时设为 2，第三次请求应在调用 `SendSms` 前返回 `429`。
6. 在腾讯短信控制台配置告警联系人、国内短信提醒/日硬限额、发送频率限制和
   验证码防盗刷监控；这些控制台开关无法由仓库代码代替。
