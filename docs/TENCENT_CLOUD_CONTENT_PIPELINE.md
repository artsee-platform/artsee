# 腾讯云内容上传与审核接入

本文档覆盖当前第一阶段链路：

`客户端选择文件 -> BFF 生成 COS 直传签名 -> 客户端 PUT 到 COS -> BFF 记录 upload_files -> 发帖 -> 腾讯云内容安全审核 -> community_posts 状态落库`

## 1. 环境变量

在 `web/.env.local`、生产服务器 `.env.production` 或托管平台环境变量中配置：

```env
TENCENT_CLOUD_SECRET_ID=
TENCENT_CLOUD_SECRET_KEY=
TENCENT_CLOUD_REGION=ap-guangzhou

# Bucket 名必须包含 appid，例如 artsee-1250000000
TENCENT_COS_BUCKET=
TENCENT_COS_REGION=ap-guangzhou

# 可选：仅在 DNS/HTTPS 已配置完成时用于识别旧链接
# TENCENT_COS_PUBLIC_BASE_URL=https://assets.artiqore.com
TENCENT_COS_SIGN_EXPIRES_SECONDS=600
TENCENT_COS_TIMEOUT_MS=10000
TENCENT_COS_MAX_UPLOADS_PER_10_MINUTES=30
# 未启用 COS 严格签名/隔离私有桶前保持 false
TENCENT_COS_PRIVATE_DIRECT_UPLOAD_ENABLED=false

# 可选：腾讯云内容安全策略
# TENCENT_CONTENT_SAFETY_TEXT_BIZ_TYPE=
# TENCENT_CONTENT_SAFETY_IMAGE_BIZ_TYPE=
# 额外允许送审的图片域名，逗号分隔；COS/Supabase 域名会自动加入
# TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS=assets.artiqore.com
TENCENT_CONTENT_SAFETY_MAX_UNITS_PER_MINUTE=60
TENCENT_CLOUD_TIMEOUT_MS=10000
TENCENT_CLOUD_MAX_ATTEMPTS=2
```

这些变量只允许存在服务端。不要写入 Flutter、浏览器可见配置或 Git。

## 2. Supabase migration

依次执行：

```sql
supabase/migrations/20260618090000_content_audit_and_cos_metadata.sql
supabase/migrations/20260808213000_harden_cos_uploads.sql
```

它会给：

- `community_posts` 增加 `reviewing/rejected` 状态和审核元数据字段。
- `upload_files` 增加 `provider/bucket/object_key` 和审核元数据字段。
- `upload_files` 增加上传会话、访问级别、完成时间、ETag/CRC 字段，并撤销客户端直接写权限。

## 3. COS CORS

腾讯云 COS Bucket 需要允许浏览器或 Flutter Web 直传。

建议 CORS 规则：

```json
[
  {
    "AllowedOrigins": [
      "http://localhost:9090",
      "http://localhost:3003",
      "https://artiqore.com",
      "https://www.artiqore.com"
    ],
    "AllowedMethods": ["GET", "HEAD", "PUT"],
    "AllowedHeaders": [
      "Authorization",
      "Content-Type",
      "Range",
      "x-cos-acl",
      "x-cos-meta-upload-id",
      "x-cos-meta-expected-size",
      "x-cos-server-side-encryption",
      "x-cos-security-token"
    ],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 600
  }
]
```

如果使用新的本地端口，请把实际端口加入 `AllowedOrigins`。

## 4. BFF 接口

### 生成 COS 上传签名

```http
POST /api/v1/uploads/cos/sign
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "file_name": "portfolio.png",
  "content_type": "image/png",
  "size": 1024,
  "scene": "community"
}
```

返回 `upload_id`、`upload_url`、`headers`、`file_url`、`public_url`、`key`。客户端必须原样携带返回头执行 `PUT`；签名会绑定 Content-Length、Content-Type、上传会话元数据、访问级别和 SSE-COS 加密。

社区、头像等场景使用对象级 `public-read`。默认情况下，`contracts/*` 和 `submission-materials/*` 返回 `503 + fallback=supabase_private`，Flutter 会回退到现有 Supabase 私有桶；只有在 COS 已启用严格签名模式或迁移到独立私有 Bucket 后，才允许设置 `TENCENT_COS_PRIVATE_DIRECT_UPLOAD_ENABLED=true`。公开链接使用可直接工作的 COS 源站域名，不依赖未完成 DNS 配置的自定义域名。

### 记录上传完成

```http
POST /api/v1/uploads/cos/complete
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "upload_id": "<sign 接口返回的 upload_id>",
  "key": "uploads/<user-id>/community/xxx.png"
}
```

完成接口不信任客户端 URL、Bucket、类型或大小。它会从上传会话读取期望值，再通过 COS `HEAD Object` 和范围 `GET` 核对对象存在性、长度、Content-Type、会话 ID、服务端加密和文件头；重复完成请求按同一会话幂等返回。

### 删除 COS 上传

```http
DELETE /api/v1/uploads/cos/<upload_id>
Authorization: Bearer <access_token>
```

删除接口只接受上传会话 UUID，不接受客户端提供的对象键。BFF 会读取 `upload_files`，同时校验记录用户、`uploads/<user-id>/` 前缀和当前 Bucket；只有 COS 确认对象已经删除或本来就不存在后，才删除数据库记录。因此 COS 删除失败时记录仍会保留，数据库删除失败时也可通过重复请求安全恢复。

### 清理过期上传会话

```http
POST /api/v1/admin/maintenance/cos-uploads?limit=25
Authorization: Bearer <admin_access_token>
```

该接口只清理已经过期且仍为 `pending` 的腾讯 COS 上传会话，单次上限 100。服务器定时任务也可以携带 `x-artiqore-cron-secret`，使用 `COS_UPLOAD_CLEANUP_CRON_SECRET` 或通用 `ADMIN_MAINTENANCE_CRON_SECRET`。只要有对象清理失败，接口就返回 `502`，便于定时任务告警和重试。

### 私有合同与申请材料

```http
POST /api/v1/uploads/materials/sign
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "url": "<数据库保存的 COS 或 Supabase 文件引用>",
  "contract_id": "<查看合同时传入>"
}
```

学生只能签自己的文件；机构 owner/admin 只能凭属于其机构的合同 ID 签对应合同；平台管理员可用于内容审查。签名链接有效 10 分钟。

### 内容安全审核（仅管理员诊断）

```http
POST /api/v1/content/audit
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "text": "作品集进度分享",
  "image_urls": ["https://assets.artiqore.com/uploads/<user-id>/community/xxx.png"],
  "scene": "community_post"
}
```

## 5. 发帖状态

`POST /api/v1/community/posts` 现在由腾讯云审核结果决定状态：

| 审核结果 | community_posts.status | 前台行为 |
| --- | --- | --- |
| `approved` | `published` | 公开展示，计入创作者成长 |
| `reviewing` | `reviewing` | 不进公开列表，等待后台人工处理 |
| `rejected` | `rejected` | 不进公开列表，客户端提示调整内容 |

腾讯云配置缺失时接口返回 `503`，不会绕过审核直接发布。

帖子编辑同样会重新审核，客户端不能直接修改发布状态；未发布内容只有作者本人可以通过详情接口读取。普通评论、热议评论和圈子创建只在腾讯云明确返回 `Pass` 时写入公开数据，`Review`/`Block` 会返回 `422` 并要求用户修改。

迁移 `20260808183522_harden_content_safety_writes.sql` 会撤销匿名/登录客户端对帖子、评论和圈子表的直接写权限。所有公开 UGC 写入必须经过 BFF，避免绕过腾讯云审核直接调用 Supabase Data API。

审核层默认限制每次 10,000 个 Unicode 字符、最多 9 张图片，只接受平台 COS、Supabase Storage 或 `TENCENT_CONTENT_SAFETY_ALLOWED_IMAGE_HOSTS` 中配置的 HTTPS 域名。调用按用户计费单位限流，并带超时和一次重试；未知审核建议按服务异常失败关闭。

## 6. 本地验证

```bash
cd web
npm test -- --run tests/api/tencent-integrations.test.ts tests/api/cos-deletion.test.ts tests/api/community-post-audit.test.ts tests/api/upload.test.ts
npx eslint app/api/v1/community/posts/route.ts app/api/v1/uploads/cos/sign/route.ts app/api/v1/uploads/cos/complete/route.ts 'app/api/v1/uploads/cos/[id]/route.ts' app/api/v1/admin/maintenance/cos-uploads/route.ts app/api/v1/content/audit/route.ts lib/api/tencent-cloud.ts lib/api/tencent-cos.ts lib/api/cos-upload-deletion.ts lib/api/content-safety.ts tests/api/tencent-integrations.test.ts tests/api/cos-deletion.test.ts tests/api/community-post-audit.test.ts
```

Flutter service 层验证：

```bash
flutter analyze app/lib/services/backend_api_service.dart app/lib/services/storage_service.dart app/lib/models/models.dart app/test/backend_api_parse_test.dart
```
