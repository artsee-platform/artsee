# 腾讯 IM 仅允许 BFF 发消息

Flutter 仍需要 UserSig 登录腾讯 IM 以接收消息，因此不能把“客户端拿不到 UserSig”
作为安全边界。本工程通过腾讯 IM 的两个消息前回调，把发送权限收口到 Next.js BFF：

- `C2C.CallbackBeforeSendMsg`
- `Group.CallbackBeforeSendMsg`

回调地址：

```text
https://artiqore.com/api/v1/im/callback
```

## 服务端校验

回调入口按顺序执行：

1. 校验 `SdkAppid` 与服务端配置一致。
2. 按腾讯协议校验 `Sign=sha256(Token + RequestTime)`，时间偏差最多 60 秒。
3. 只接受腾讯标记为 `OptPlatform=RESTAPI` 的消息；Android、iOS、Web SDK
   直接发送会被拒绝。
4. 校验 BFF 放在 `CloudCustomData` 中的一次性随机票据。
5. 原子匹配发送账号、接收账号/群 ID 和消息体 SHA-256，并删除票据。
6. 放行时从 `CloudCustomData` 删除票据后再下发，接收端无法取得可重放票据。

票据表启用 RLS，并撤销 `PUBLIC`、`anon`、`authenticated` 的全部权限；只有
`service_role` 可以签发或原子消费。严格模式下腾讯消息 REST 请求只尝试一次，避免
第一次已投递但响应丢失后，用已消费票据进行第二次发送。

## 部署顺序

1. 应用迁移：
   `supabase/migrations/20260809201008_tencent_im_bff_callback_permits.sql`。
2. 生成独立回调 Token：

   ```bash
   openssl rand -hex 32
   ```

3. 在生产环境配置：

   ```dotenv
   TENCENT_IM_CALLBACK_TOKEN=<与腾讯控制台一致的独立随机 Token>
   TENCENT_IM_REQUIRE_BFF_CALLBACK=1
   TENCENT_IM_CALLBACK_PERMIT_TTL_SECONDS=45
   ```

4. 先部署代码并确认 `/api/v1/im/callback` 公网 HTTPS 可达。
5. 腾讯云控制台 → 即时通信 IM → 消息服务 Chat → 回调配置：
   - 回调 URL 填上面的地址；
   - 开启“鉴权”，Token 与环境变量完全一致；
   - 开启“发单聊消息之前回调”；
   - 开启“群内发言之前回调”；
   - “事件发生之前回调失败的处理策略”选择不下发；
   - 不要开启“允许客户端禁用前回调”；
   - 关闭“允许客户端禁用审核”。

不要在控制台回调尚未部署时先开启消息前回调，否则严格失败策略会阻断全部消息。

## 验收

1. 通过 App/BFF 发送单聊和群聊消息，应成功投递。
2. 使用测试 UserSig 直接调用 Flutter/原生 SDK 发送相同消息，应返回腾讯消息前回调
   拒绝错误，接收端不能收到。
3. 重复提交已经消费的票据，应被拒绝。
4. 使用错误 SDKAppID、过期 `RequestTime`、错误 `Sign` 或非 `RESTAPI` 平台，
   回调均应返回 `ErrorCode: 1`。
5. 临时停止回调服务，确认控制台失败策略确实阻止消息下发，然后立即恢复服务。

消息内容审核仍在 BFF 写入数据库和签发票据之前完成。回调路径只做恒定时间验签和
一次数据库原子删除，避免在腾讯固定的 2 秒回调时限内再次调用内容安全 API。
