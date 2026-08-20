# 腾讯云 IM 离线推送接入

本工程使用与 IM SDK 对齐的 `tencent_cloud_chat_push 8.7.7201`。Flutter
客户端、Android/iOS 原生入口、通知权限、注册/解绑生命周期及通知点击跳转均已接入；
没有在仓库中保存任何控制台凭据。

## 已接入的行为

- 用户在「设置 → 推送通知」明确开启后，客户端才会请求系统通知权限。
- 腾讯 IM 登录成功后调用 `registerPush`，避免在 `main()` 或隐私授权前注册。
- 注册完成后检查 `getRegistrationID()`；日志只记录是否取得 ID，不打印 ID 本身。
- 退出登录、关闭推送或 IM 被踢下线时调用 `unRegisterPush`。
- 前台/后台及冷启动通知点击共用 `TIMPushListener`；点击参数在登录和新手流程完成后再消费。
- BFF 当前发送的 `Ext` 契约为：
  `{"action":"open_chat","conversation_id":"<uuid>"}`，客户端会打开对应会话。
- Web/桌面端使用安全降级实现，不会调用只支持 Android/iOS 的 MethodChannel。

## Android 上线配置

1. 在腾讯云 IM 控制台开通 Push 服务并完成所需厂商（华为、小米、OPPO、
   vivo、荣耀、魅族、FCM）配置。
2. 从腾讯云控制台下载原始 `timpush-configs.json`，放到：
   `app/android/app/src/main/assets/timpush-configs.json`。
3. 按目标厂商要求放置其配置文件，例如 FCM 的
   `app/android/app/google-services.json`。不要修改厂商要求的文件名。
4. 如果厂商 SDK 要求 Gradle 插件（例如 Google Services 或华为 AGConnect），
   按该厂商控制台生成的接入说明启用；不要在凭据文件到位前盲目启用。
5. 构建时显式打开客户端注册开关：

   ```bash
   flutter build apk --dart-define=TENCENT_PUSH_ENABLED=true
   ```

项目已加入 Android 13+ 通知权限、自定义 `ArtseeApplication`，并固定引入与
Flutter 插件同版本的全部 TIMPush 厂商通道包。控制台下载文件与常见厂商凭据路径
已加入 `.gitignore`。

## iOS 上线配置

1. Apple Developer 的 App ID 与 Xcode Runner target 使用完全一致的 Bundle ID。
2. 在 Runner → Signing & Capabilities 开启 `Push Notifications`，并让对应描述文件
   包含该能力。
3. 在腾讯云控制台上传 APNs `.p8` 或 `.p12`，记录腾讯生成的证书 ID
   (`businessID`)。
4. 构建时启用推送并注入证书 ID：

   ```bash
   flutter build ios \
     --dart-define=TENCENT_PUSH_ENABLED=true \
     --dart-define=TENCENT_PUSH_APNS_CERTIFICATE_ID=1234567
   ```

如需消息触达统计，再配置 Notification Service Extension 与 App Group，并增加：

```bash
--dart-define=TENCENT_PUSH_APPLICATION_GROUP_ID=group.com.example.artsee
```

App Group 只用于可选的触达统计，不是普通离线消息推送的前置条件。

## Push Key 的使用边界

当前 App 已先登录腾讯 IM，再注册 TIMPush。腾讯当前 Flutter 文档允许该模式复用
IM 登录态，因此客户端调用 `registerPush` 时不传 `appKey`，不会把 Push Key 固化进
代码仓库。只有在“不登录 Chat、仅独立使用 Push”的冷启动方案中，才需要把腾讯
Push 客户端密钥作为 `appKey` 传入；它不能与 Chat Key 混用。

## 真机验收

模拟器不能代替厂商/APNs 真机验收。Android 和 iOS 至少各选一台目标设备：

1. 登录 App，在设置中开启推送，并确认系统权限为允许。
2. 查看 `TIMPush` 日志，确认注册返回 code 0，客户端取得 RegistrationID。
3. 把 App 置于后台、杀进程，各发送一条真实会话消息。
4. 确认通知到达，点击后打开正确的 `conversation_id`，且不会重复打开。
5. 关闭推送、退出登录后再次发送，确认设备不再收到该账号的离线推送。

Flutter 当前仍提示腾讯 IM/Push 插件不支持 Swift Package Manager。工程继续使用
CocoaPods；在腾讯插件提供 SPM 支持前，不要切换 iOS 依赖管理方式。
