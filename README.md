# Artsee / Artiqore 艺衡

> **艺术留学智能申请平台 - 让艺术梦想触手可及**

Artsee（艺衡）是一个面向艺术留学生的智能申请辅助平台，整合院校信息、AI 咨询、申请管理、案例分享等功能，帮助学生高效完成艺术留学申请全流程。

---

## 📋 目录

- [核心功能](#核心功能)
- [技术架构](#技术架构)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [开发指南](#开发指南)
- [测试](#测试)
- [部署](#部署)
- [文档](#文档)

---

## 🎯 核心功能

### 1. AI 智能咨询
- **个性化画像**：根据用户背景、目标专业、预算等生成申请画像
- **智能问答**：基于知识库的 RAG 系统，回答院校、专业、申请相关问题
- **院校推荐**：AI 分析匹配度，推荐冲刺/匹配/保底院校
- **流式对话**：实时打字机效果，提升用户体验

### 2. 申请清单管理
- **CRUD 操作**：添加、查看、更新、删除申请项
- **智能分层**：AI 自动分析院校匹配度，建议分层（reach/match/safety）
- **时间线生成**：根据 deadline 自动生成倒排任务时间线
- **状态跟踪**：规划中、准备材料、已提交、已录取、未录取

### 3. 院校与专业数据
- **院校列表**：支持按国家、城市、排名筛选
- **专业详情**：学位、学制、学费、申请要求、作品集要求
- **搜索功能**：关键词搜索院校和专业
- **媒体资源**：院校 logo、校园图片、专业封面

### 4. 案例分享
- **录取案例**：查看其他学生的录取经历
- **案例关联**：申请项下方自动推荐相关案例
- **筛选功能**：按院校、专业、录取结果筛选

### 5. 社区互动
- **帖子发布**：分享申请经验、作品集心得
- **评论互动**：点赞、评论、收藏
- **内容推荐**：首页智能推荐优质内容

---

## 🏗 技术架构

### 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      Artsee 系统架构                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Flutter Mobile App (iOS/Android)          │    │
│  │                                                        │    │
│  │  • AI 咨询对话                                          │    │
│  │  • 申请清单管理                                         │    │
│  │  • 院校/专业浏览                                        │    │
│  │  • 案例分享                                            │    │
│  │  • 社区互动                                            │    │
│  │                                                        │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                       │
│                         │ HTTPS/REST API                        │
│                         │ (Bearer Token Auth)                   │
│                         ▼                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           Next.js 15 Backend (BFF)                     │    │
│  │                                                        │    │
│  │  • RESTful API (/api/v1/*)                             │    │
│  │  • AI 咨询 Pipeline (RAG + LLM)                        │    │
│  │  • 知识库检索 (Embedding + Vector Search)              │    │
│  │  • 用户认证 (Supabase Auth)                            │    │
│  │  • 管理后台 (/admin)                                   │    │
│  │                                                        │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                       │
│                         │ PostgreSQL + RLS                      │
│                         ▼                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │            Supabase (Database + Auth + Storage)        │    │
│  │                                                        │    │
│  │  • PostgreSQL (院校、专业、用户、申请清单)              │    │
│  │  • Auth (用户认证与会话管理)                            │    │
│  │  • Storage (头像、校园图片、作品集)                     │    │
│  │  • Realtime (可选，未来扩展)                            │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              External Services                         │    │
│  │                                                        │    │
│  │  • Moonshot AI / OpenAI (LLM)                          │    │
│  │  • Xinference / Ollama (Embedding)                     │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 模块职责

| 模块 | 技术栈 | 职责 |
|------|--------|------|
| **Flutter APP** | Flutter 3.x + Dart | 移动客户端，所有用户交互界面 |
| **Next.js Backend** | Next.js 15 + TypeScript | BFF 层，提供统一 API + AI 能力 |
| **Supabase** | PostgreSQL + Auth + Storage | 数据存储、用户认证、文件管理 |
| **LLM** | Moonshot / OpenAI | AI 对话生成 |
| **Embedding** | Xinference / Ollama / OpenAI | 知识库向量化 |

## 🛠 技术栈

### Flutter APP

| 技术 | 版本 | 用途 |
|------|------|------|
| **Flutter** | 3.x | 跨平台移动开发框架 |
| **Dart** | 3.x | 编程语言 |
| **http** | - | HTTP 客户端（调用 Web API） |
| **Supabase Flutter** | - | Supabase 客户端（Auth + Storage） |

### Next.js Backend

| 技术 | 版本 | 用途 |
|------|------|------|
| **Next.js** | 15.5.18 | 服务端框架 + API Routes |
| **React** | 19.1.0 | UI 组件（管理后台） |
| **TypeScript** | 5.x | 类型安全 |
| **Supabase JS** | 2.49.1 | 数据库 + Auth 客户端 |
| **OpenAI SDK** | 6.33.0 | LLM 调用 |
| **Vitest** | 3.2.4 | 单元测试 + 集成测试 |
| **Tailwind CSS** | 4.x | 样式系统 |

### 数据库与服务

| 技术 | 用途 |
|------|------|
| **Supabase PostgreSQL** | 关系型数据库 |
| **Supabase Auth** | 用户认证与会话管理 |
| **Supabase Storage** | 文件存储（头像、图片） |
| **Row Level Security** | 数据权限控制 |
| **Moonshot AI** | 大语言模型（主要） |
| **OpenAI** | 大语言模型（备用） |
| **Xinference** | 本地 Embedding 服务 |

---

## 📁 项目结构

```
artsee/
├── app/                          # 📱 Flutter 移动应用
│   ├── lib/
│   │   ├── main.dart             # 应用入口
│   │   ├── config/               # 配置（API 地址、测试账号）
│   │   ├── services/             # API 服务层
│   │   │   └── backend_api_service.dart
│   │   ├── models/               # 数据模型
│   │   ├── screens/              # 页面
│   │   │   ├── home/             # AI Home
│   │   │   ├── application/      # 申请清单
│   │   │   ├── schools/          # 院校列表
│   │   │   ├── programs/         # 专业列表
│   │   │   ├── cases/            # 案例分享
│   │   │   └── community/        # 社区
│   │   └── widgets/              # 通用组件
│   ├── test/                     # 单元测试
│   ├── pubspec.yaml
│   └── README.md
│
├── web/                          # 🌐 Next.js 后端服务
│   ├── app/
│   │   ├── api/v1/               # RESTful API
│   │   │   ├── ai/               # AI 咨询、分析
│   │   │   ├── auth/             # 用户认证
│   │   │   ├── schools/          # 院校数据
│   │   │   ├── programs/         # 专业数据
│   │   │   ├── tracker/          # 申请清单
│   │   │   ├── cases/            # 案例
│   │   │   └── community/        # 社区
│   │   ├── admin/                # 管理后台
│   │   └── chat/                 # 流式对话
│   ├── lib/
│   │   ├── api/                  # API 工具
│   │   ├── ai/                   # AI 逻辑
│   │   ├── knowledge/            # 知识库 RAG
│   │   └── pipelines/            # 咨询 Pipeline
│   ├── tests/                    # Vitest 测试
│   ├── docs/migrations/          # 数据库 Migration
│   └── README.md
│
├── tests/                        # 🧪 集成测试
│   └── backend/
│       └── supabase-health.mjs   # 后端健康检查
│
├── scripts/                      # 🔧 脚本工具
│   ├── ensure-dev-test-user.mjs  # 创建测试用户
│   ├── deploy-web.sh             # 部署脚本
│   └── browser-admin-e2e.mjs     # E2E 测试
│
├── docs/                         # 📚 文档
│   ├── AGENTS.md                 # AI 助手开发指南
│   ├── APP_DEVELOPMENT.md        # APP 开发指南
│   ├── ADMIN_SETUP.md            # 管理员设置
│   └── ...
│
├── .cursor/skills/               # 🤖 AI 技能
│   ├── port-manager/             # 端口管理
│   └── jinhui-stack-debug/       # 调试指南
│
├── package.json                  # 项目根配置
├── AGENTS.md                     # 项目总览（AI 必读）
└── README.md                     # 本文件
```

---

## � 快速开始

### 环境要求
- **Node.js** 20+
- **Flutter SDK** 3.x
- **Supabase** 账号

### 1. 克隆仓库

```bash
git clone https://github.com/artsee-platform/artsee.git
cd artsee
```

### 2. 安装依赖

```bash
# 项目根依赖
npm install

# Web 依赖
cd web && npm install && cd ..

# Flutter 依赖
cd app && flutter pub get && cd ..
```

### 3. 配置环境变量

复制示例文件：

```bash
cp web/.env.development.example web/.env.local
```

填写必要变量（详见 `web/README.md`）。

### 4. 初始化数据库

在 Supabase Dashboard → SQL Editor 中执行 `web/docs/migrations/` 下的 SQL 文件（按序号顺序）。

### 5. 创建测试用户

```bash
npm run ensure:dev-user
```

### 6. 启动开发服务器

```bash
# 启动 Web 后端（默认端口 3000）
npm run dev:web

# 启动 Flutter APP（需连接设备或模拟器）
npm run dev:app
```

---

## 🛠 开发指南

### 常用命令

```bash
# Web 开发
npm run dev:web          # 启动 Web 开发服务器
npm run build:web        # 构建 Web 生产版本
npm run lint:web         # ESLint 检查
npm run test:web         # 运行 Web 测试

# Flutter 开发
npm run dev:app          # 启动 Flutter APP
npm run build:app        # 构建 APP

# 测试
npm run test:backend     # 后端健康检查
npm run ensure:dev-user  # 创建/修复测试用户
npm run e2e:admin        # 管理后台 E2E 测试

# 部署
npm run deploy:web       # 部署 Web 到生产服务器
```

### 开发流程

1. **后端优先**：新功能先在 `web/app/api/v1/` 实现 API
2. **测试验证**：使用 `npm run test:backend` 验证接口
3. **Flutter 集成**：在 `app/lib/services/backend_api_service.dart` 中调用
4. **UI 实现**：在 `app/lib/screens/` 中实现界面

### 调试技巧

遇到问题时，按以下顺序排查：

1. **后端 API** → `npm run test:backend`
2. **数据库** → Supabase Dashboard
3. **网络** → 检查 API 基址配置
4. **权限** → 检查 RLS 策略

详见 [`.cursor/skills/jinhui-stack-debug/SKILL.md`](.cursor/skills/jinhui-stack-debug/SKILL.md)

---

## 🧪 测试

### 后端测试

```bash
# Supabase 健康检查
npm run test:backend

# Web API 契约测试
npm run test:web
```

### Flutter 测试

```bash
cd app
flutter test
```

---

## 🚢 部署

### Web 后端部署

```bash
# 自动部署到生产服务器（artiqore.com）
npm run deploy:web
```

**部署流程：**
1. 本地构建 Next.js
2. 通过 SSH 上传到服务器
3. PM2 重启服务

**服务器信息：**
- 地址：`artiqore.com`
- 目录：`~/website/artsee/web`
- PM2 应用名：`artsee-web`
- 端口：3000（Nginx 反代）

### Flutter APP 发布

```bash
cd app

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---

## 📚 文档

### 核心文档

| 文档 | 说明 |
|------|------|
| **[AGENTS.md](AGENTS.md)** | 🤖 AI 助手开发指南（必读） |
| **[web/README.md](web/README.md)** | 🌐 Web 后端完整文档 |
| **[app/README.md](app/README.md)** | 📱 Flutter APP 开发指南 |
| **[DATABASE_REPORT.md](DATABASE_REPORT.md)** | 💾 数据库结构报告 |

### 技能文档

| 文档 | 说明 |
|------|------|
| **[port-manager](.cursor/skills/port-manager/SKILL.md)** | 端口管理工具 |
| **[jinhui-stack-debug](.cursor/skills/jinhui-stack-debug/SKILL.md)** | 调试指南 |

### 业务文档

| 文档 | 说明 |
|------|------|
| **[docs/APP_DEVELOPMENT.md](docs/APP_DEVELOPMENT.md)** | APP 开发环境搭建 |
| **[docs/ADMIN_SETUP.md](docs/ADMIN_SETUP.md)** | 管理员设置指南 |
| **[docs/api-design/](docs/api-design/)** | API 设计文档 |

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## 📄 许可证

Copyright © 2026 Artsee / Artiqore 艺衡. All rights reserved.
