# 第三方集成上线自检

后台地址：`/admin/integrations`。对应只读接口：
`GET /api/v1/admin/integrations/readiness`。

## 安全边界

- 接口先验证 Supabase 登录态和 `user_profiles.role=admin`，再创建 Service Role 客户端。
- 返回结果只有环境变量名、是否满足、修复提示；不会返回环境变量值或数据库原始错误。
- 不调用高德或腾讯云的计费 API。数据库探测使用只读 `HEAD` 查询；短信全局限流探测使用零限额参数，函数在写入前以 `SMS_RATE_CONFIG_INVALID` 退出。
- `*_CONSOLE_CONFIGURED` 与 `*_SMOKE_TESTED` 都是非密钥人工确认开关。只有实际核对控制台或完成验收后才能设为 `1`。

## 状态含义

- `有阻塞`：缺少运行必需配置、关键迁移或必须完成的控制台步骤。
- `待验收`：代码链路可用，但仍有告警配置、收费冒烟或真机验收未确认。
- `已就绪`：当前项目能够自动检查及人工确认的项目均已满足。

环境变量清单和默认的 `0` 值见 `web/.env.development.example` 与
`web/.env.production.example`。修改托管环境变量后需重启 Next.js 服务，再在后台重新检查。
