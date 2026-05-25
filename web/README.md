# Artsee Web Backend

> **艺术留学智能申请平台 - Next.js 后端服务**

Artsee 的 Next.js 后端服务（BFF - Backend for Frontend），为 Flutter 移动客户端和未来 Web 前端提供统一的 RESTful API 接口，涵盖 AI 咨询、知识库检索、院校/专业数据、申请清单管理、社区内容等核心业务。

---

## 📋 目录

- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [API 文档](#api-文档)
- [开发指南](#开发指南)
- [测试](#测试)
- [部署](#部署)
- [环境变量](#环境变量)

---

## 🛠 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **Next.js** | 15.5.18 | 服务端框架 + API Routes |
| **React** | 19.1.0 | UI 组件（管理后台页面） |
| **TypeScript** | 5.x | 类型安全 |
| **Supabase** | 2.49.1 | 数据库 + Auth + Storage |
| **OpenAI SDK** | 6.33.0 | LLM 调用（支持 Moonshot 等兼容接口） |
| **Vitest** | 3.2.4 | 单元测试 + 集成测试 |
| **Tailwind CSS** | 4.x | 样式（管理后台） |

---

## 📁 项目结构

```
web/
├── app/
│   ├── api/                    # API Routes
│   │   ├── v1/                 # 版本化 API（对外）
│   │   │   ├── ai/             # AI 咨询、分析、搜索
│   │   │   ├── auth/           # 用户认证、资料管理
│   │   │   ├── cases/          # 录取案例
│   │   │   ├── community/      # 社区帖子、评论
│   │   │   ├── home-contents/  # 首页内容
│   │   │   ├── knowledge/      # 知识库搜索
│   │   │   ├── programs/       # 专业数据
│   │   │   ├── schools/        # 院校数据
│   │   │   ├── tracker/        # 申请清单 CRUD
│   │   │   └── upload/         # 文件上传
│   │   └── chat/               # 流式对话（SSE）
│   ├── admin/                  # 管理后台页面
│   └── [locale]/               # 国际化路由
├── lib/
│   ├── api/                    # API 工具函数
│   │   ├── auth-user.ts        # 用户认证
│   │   ├── supabase-service.ts # Supabase Service Role 客户端
│   │   └── supabase-client.ts  # Supabase 浏览器客户端
│   ├── ai/                     # AI 相关逻辑
│   │   ├── llm-client.ts       # LLM 调用封装
│   │   ├── knowledge-search.ts # 知识库检索
│   │   └── prompt-templates.ts # Prompt 模板
│   └── utils/                  # 通用工具
├── scripts/                    # 数据导入、测试脚本
├── tests/                      # 测试文件
│   └── api/                    # API 契约测试
├── docs/                       # 文档
│   └── migrations/             # 数据库 Migration SQL
├── .env.development.example    # 开发环境变量示例
├── .env.production.example     # 生产环境变量示例
└── package.json
```

---

## 🚀 快速开始

### 1. 环境准备

**前置要求：**
- Node.js 20+
- npm 或 pnpm
- Supabase 项目（或本地 Supabase）

### 2. 安装依赖

```bash
cd web
npm install
```

### 3. 配置环境变量

复制示例文件并填写：

```bash
cp .env.development.example .env.local
```

**必填变量：**
```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# LLM（Moonshot 或 OpenAI 兼容）
MOONSHOT_API_KEY=your-moonshot-key
MOONSHOT_BASE_URL=https://api.moonshot.cn/v1

# 可选：OpenAI
OPENAI_API_KEY=your-openai-key
```

### 4. 运行数据库 Migration

在 Supabase Dashboard → SQL Editor 中执行 `docs/migrations/` 下的 SQL 文件（按序号顺序）。

### 5. 启动开发服务器

```bash
npm run dev
```

默认端口：**3000**（可通过 `PORT` 环境变量修改）

访问：
- API 健康检查：`http://localhost:3000/api/v1/health`
- 管理后台：`http://localhost:3000/admin`

---

## 📡 API 文档

### 基础信息

- **Base URL（开发）**：`http://localhost:3000/api/v1`
- **Base URL（生产）**：`https://artiqore.com/api/v1`
- **认证方式**：Bearer Token（通过 Supabase Auth）
- **响应格式**：JSON

### 通用响应结构

**成功：**
```json
{
  "success": true,
  "data": { ... }
}
```

**失败：**
```json
{
  "success": false,
  "error": "错误信息"
}
```

---

### 🔐 认证 API (`/api/v1/auth`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/auth/signup` | 用户注册 | ❌ |
| POST | `/auth/login` | 用户登录 | ❌ |
| POST | `/auth/logout` | 用户登出 | ✅ |
| GET | `/auth/profile` | 获取用户资料 | ✅ |
| PATCH | `/auth/update-profile` | 更新用户资料 | ✅ |
| POST | `/auth/upload-avatar` | 上传头像 | ✅ |

---

### 🤖 AI API (`/api/v1/ai`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/ai/consult` | AI 咨询（含画像注入、知识检索） | ✅ |
| POST | `/ai/analyze` | 院校匹配度分析（批量） | ✅ |
| POST | `/ai/school-search` | AI 院校搜索 | ✅ |
| GET | `/chat` | 流式对话（SSE） | ✅ |

**示例：AI 咨询**
```bash
curl -X POST http://localhost:3000/api/v1/ai/consult \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "我想申请交互设计，推荐哪些学校？"
  }'
```

---

### 🏫 院校 API (`/api/v1/schools`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/schools` | 获取院校列表（支持过滤） | ❌ |
| GET | `/schools/:id` | 获取院校详情 | ❌ |

**查询参数：**
- `keyword` - 关键词搜索
- `country` - 国家过滤
- `city` - 城市过滤
- `limit` / `offset` - 分页

---

### 📚 专业 API (`/api/v1/programs`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/programs` | 获取专业列表 | ❌ |
| GET | `/programs/:id` | 获取专业详情 | ❌ |

---

### 📋 申请清单 API (`/api/v1/tracker`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/tracker` | 获取我的申请清单 | ✅ |
| POST | `/tracker` | 添加申请项 | ✅ |
| PATCH | `/tracker/:id` | 更新申请项（分层/状态） | ✅ |
| DELETE | `/tracker/:id` | 删除申请项 | ✅ |
| GET | `/tracker/timeline` | 生成申请时间线 | ✅ |

**示例：添加申请项**
```bash
curl -X POST http://localhost:3000/api/v1/tracker \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "school_id": "123",
    "school_name": "皇家艺术学院",
    "program_name": "交互设计 MA",
    "tier": "reach"
  }'
```

---

### 📝 案例 API (`/api/v1/cases`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/cases` | 获取录取案例列表 | ❌ |
| GET | `/cases/:id` | 获取案例详情 | ❌ |

---

### 💬 社区 API (`/api/v1/community`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/community/posts` | 获取帖子列表 | ❌ |
| POST | `/community/posts` | 发布帖子 | ✅ |
| GET | `/community/posts/:id` | 获取帖子详情 | ❌ |
| POST | `/community/posts/:id/like` | 点赞/取消点赞 | ✅ |

---

### 🔍 知识库 API (`/api/v1/knowledge`)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/knowledge/search` | 知识库语义搜索 | ✅ |

---

## 🧪 测试

### 运行所有测试

```bash
npm test
```

### 运行 API 契约测试

```bash
npm run test:watch
```

### 测试覆盖范围

- ✅ API 契约测试（`tests/api/contract.test.ts`）
- ✅ 后端健康检查（项目根 `npm run test:backend`）

---

## 🚢 部署

### 生产构建

```bash
npm run build
npm run start
```

### 部署到服务器

项目根目录提供了自动化部署脚本：

```bash
# 在项目根目录执行
npm run deploy:web
```

**部署流程：**
1. 本地构建 Next.js
2. 通过 SSH 上传到服务器（`artiqore.com`）
3. 服务器上通过 PM2 重启服务

**服务器配置：**
- 目录：`~/website/artsee/web`
- PM2 应用名：`artsee-web`
- 端口：3000（Nginx 反代到 80/443）

---

## 🔧 开发指南

### 添加新 API

1. 在 `app/api/v1/` 下创建新目录
2. 创建 `route.ts` 文件
3. 导出 `GET` / `POST` / `PATCH` / `DELETE` 等方法
4. 使用 `getUserFromBearer()` 进行认证
5. 使用 `createServiceClient()` 访问数据库

**示例：**
```typescript
import { NextRequest, NextResponse } from "next/server";
import { getUserFromBearer } from "@/lib/api/auth-user";
import { createServiceClient } from "@/lib/api/supabase-service";

export async function GET(req: NextRequest) {
  const user = await getUserFromBearer(req);
  if (!user) {
    return NextResponse.json({ success: false, error: "未授权" }, { status: 401 });
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("your_table")
    .select("*")
    .eq("user_id", user.id);

  if (error) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ success: true, data });
}
```

### 数据库 Migration

1. 在 `docs/migrations/` 下创建新 SQL 文件（按序号命名）
2. 在 Supabase Dashboard → SQL Editor 中执行
3. 更新相关 TypeScript 类型定义

### AI Prompt 管理

所有 Prompt 模板位于 `lib/ai/prompt-templates.ts`，统一管理便于优化。

---

## 🌍 环境变量

### 开发环境 (`.env.local`)

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# LLM
MOONSHOT_API_KEY=sk-...
MOONSHOT_BASE_URL=https://api.moonshot.cn/v1

# 可选
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1

# 开发端口（可选，默认 3000）
PORT=9090
```

### 生产环境

生产环境变量通过服务器环境变量或 `.env.production` 配置，**不要提交到 Git**。

---

## 📚 相关文档

- [项目总览](../AGENTS.md)
- [Flutter 客户端](../app/README.md)
- [调试指南](../.cursor/skills/jinhui-stack-debug/SKILL.md)
- [数据库报告](../DATABASE_REPORT.md)

---

## 🤝 贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## 📄 License

Copyright © 2026 Artsee / Artiqore 艺衡. All rights reserved.
