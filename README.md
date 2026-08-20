# Artsee 艺见心

**艺术留学一站式智能平台** — 院校发现、AI 申请顾问、作品集规划、社区交流

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Next.js](https://img.shields.io/badge/Next.js-15-black?logo=next.js)](https://nextjs.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)

---

## 📱 产品定位

Artsee 是面向艺术留学生、艺术家、收藏者和家长的垂直生态平台，提供：

- **智能 AI 顾问**：根据用户画像（学生/艺术家/收藏者/家长/机构）提供个性化申请规划
- **院校数据库**：20+ 所全球顶尖艺术院校，支持多维对比与目标池管理
- **申请工作区**：申请计划、作品集任务、项目对比、咨询记录一站式管理
- **社区生态**：发现合作机会、展览活动、艺术家资源，发布作品与动态
- **机构入驻**：作品集机构、画廊、品牌方可发布课程、展览、合作机会

---

## 🎯 核心功能

### 1. **动态 AI 画像系统**
根据用户角色自动切换 AI 界面文案与功能：

| 画像 | AI 标题 | 核心场景 |
|------|---------|----------|
| **学生** | 艺见心 AI 申请顾问 | 选校、作品集、时间线规划 |
| **艺术家** | 艺见心 AI 艺术家助手 | 展览申请、品牌合作、作品介绍 |
| **收藏者** | 艺见心 AI 艺术顾问 | 看展推荐、鉴赏入门、收藏路径 |
| **家长** | 艺见心 AI 留学顾问 | 院校费用、申请路径、机构选择 |
| **机构** | 艺见心 AI 机构助手 | 主页优化、课程发布、曝光提升 |

### 2. **院校对比与目标池**
- **目标池管理**：收藏候选院校，标记冲刺/匹配/保底层级
- **6 维雷达图对比**：排名、专业匹配、作品集难度、竞争、预算、城市资源
- **智能推荐**：基于用户画像与目标方向推荐院校

### 3. **申请工作区**
- **申请计划**：自动生成时间线与待办任务
- **作品集任务**：拆解项目要求，跟踪完成进度
- **咨询记录**：保存 AI 对话历史与申请建议
- **项目对比**：多所院校同专业对比分析

### 4. **社区与发现**
- **合作机会**：品牌联名、驻留项目、公共艺术招募
- **展览活动**：画廊展览、艺术沙龙、工作坊预约
- **艺术家库**：按风格、城市、合作状态筛选艺术家
- **图文动态**：发布作品、现场记录、灵感分享

---

### 架构设计

Artsee 采用 **移动优先 + BFF（Backend for Frontend）** 架构：

```
┌─────────────────────────────────────────────────────────────────────┐
│                         系统架构                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    ┌──────────────────────────────────────────────────────────┐    │
│    │                         APP (Flutter)                    │    │
│    │                                                          │    │
│    │   • 核心业务端 - 5 大用户画像（学生/艺术家/收藏者/家长/机构）│    │
│    │   • AI 顾问、院校对比、申请工作区、社区发现                │    │
│    │   • 优先调用 Web BFF API，必要时直连 Supabase Auth/Storage │    │
│    │                                                          │    │
│    └────────────────────────┬─────────────────────────────────┘    │
│                             │                                       │
│                             │ HTTPS/REST API                        │
│                             ▼                                       │
│    ┌──────────────────────────────────────────────────────────┐    │
│    │                    Web (Next.js)                         │    │
│    │                                                          │    │
│    │   • BFF API 层（/api/v1/*）- 业务规则与敏感写操作           │    │
│    │   • AI 咨询管道（OpenAI + RAG + 用户画像注入）              │    │
│    │   • 院校对比、申请计划生成、作品集任务拆解                  │    │
│    │   • 管理后台（/admin）- 数据管理与监控                      │    │
│    │                                                          │    │
│    └────────────────────────┬─────────────────────────────────┘    │
│                             │                                       │
│                             │ SQL/Realtime                          │
│                             ▼                                       │
│    ┌──────────────────────────────────────────────────────────┐    │
│    │              Database (Supabase PostgreSQL)              │    │
│    │                                                          │    │
│    │   • 院校、专业、艺术分类、合作机会、展览、艺术家            │    │
│    │   • 用户画像（user_profiles）、目标池（saved_schools）      │    │
│    │   • 申请工作区（application_plan/portfolio_tasks）          │    │
│    │   • AI 对话历史（ai_conversations）+ 画像快照               │    │
│    │   • 社区内容（community_posts/comments/likes）              │    │
│    │                                                          │    │
│    └──────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **APP** | Flutter 3.24+ / Dart | 跨平台移动端，支持 iOS/Android/Web |
| **Web** | Next.js 15 / TypeScript | React 全栈框架，App Router + Route Handlers |
| **AI** | OpenAI GPT-4 / Embedding | 智能咨询、RAG 检索、画像注入 |
| **数据库** | Supabase PostgreSQL | 关系型数据库 + Auth + Storage + RLS |
| **部署** | PM2 + Nginx + Let's Encrypt | 生产服务器（artiqore.com） |

### 关键依赖

**APP (Flutter)**
- `supabase_flutter` - Supabase 客户端（Auth + Storage）
- `http` - HTTP 请求（调用 Web BFF API）
- `image_picker` - 图片选择与上传
- `speech_to_text` - 语音输入
- `flutter_markdown` - Markdown 渲染

**Web (Next.js)**
- `@supabase/supabase-js` - Supabase 服务端客户端
- `openai` - OpenAI API 调用
- `zod` - 数据验证
- `sharp` - 图片处理
- `@langchain/community` - RAG 检索（可选）

## 📊 数据库结构

### 核心业务表

```
schools (院校)
  └── programs (专业)
       ├── program_admissions (录取要求)
       ├── program_fees (费用)
       └── program_evaluations (难度评估)

auth.users (Supabase Auth)
  └── user_profiles (用户画像)
       ├── saved_schools (目标院校池)
       ├── application_plan (申请计划)
       ├── portfolio_tasks (作品集任务)
       └── ai_conversations (AI 对话历史)

opportunities (合作机会)
exhibitions (展览活动)
artists (艺术家库)

community_posts (社区动态)
  ├── community_comments (评论)
  └── community_likes (点赞)
```

### 用户画像系统

用户在 Onboarding 时选择身份与目标，存储在 `user_profiles` 表：

| 字段 | 说明 | 示例 |
|------|------|------|
| `user_type` | 个人/机构 | `personal` / `business` |
| `user_role` | 用户角色 | `student` / `artist` / `collector` / `parent` |
| `primary_goal` | 主要目标 | `study_abroad` / `exhibition` / `collection` |
| `target_directions` | 关注方向 | `['fine_art', 'design']` |
| `city_preference` | 常用城市 | `北京` / `纽约` |
| `current_stage` | 当前阶段 | `exploring` / `applying` / `enrolled` |

### 关键表说明

| 表名 | 说明 | 当前状态 |
|------|------|----------|
| `schools` | 院校信息（20+ 所） | ✅ 已导入 |
| `programs` | 专业信息 | ✅ 已导入 |
| `opportunities` | 合作机会 | ✅ Mock 数据 |
| `exhibitions` | 展览活动 | ✅ Mock 数据 |
| `artists` | 艺术家库 | ✅ Mock 数据 |
| `user_profiles` | 用户画像 | ✅ 生产环境 |
| `saved_schools` | 目标院校池 | ✅ 生产环境 |
| `application_plan` | 申请计划 | ✅ 生产环境 |
| `ai_conversations` | AI 对话历史 | ✅ 生产环境 |

详细设计见 [`docs/AGENTS.md`](./docs/AGENTS.md) 和 [`supabase/migrations/`](./supabase/migrations/)

## 📁 项目结构

```
artsee/
├── app/                          # 📱 Flutter 移动应用
│   ├── lib/
│   │   ├── main.dart             # 入口
│   │   ├── config/               # 配置（API 基址、开发者测试账号）
│   │   ├── services/             # API 服务层
│   │   │   ├── backend_api_service.dart  # BFF API 调用
│   │   │   └── supabase_service.dart     # Supabase 直连
│   │   ├── screens/              # 页面
│   │   │   ├── home/             # AI 首页（动态画像）
│   │   │   ├── schools/          # 院校浏览与详情
│   │   │   ├── news/             # 院校对比与申请工作区
│   │   │   ├── explore/          # 发现（机会/展览/艺术家）
│   │   │   ├── community/        # 社区（论坛/动态）
│   │   │   ├── profile/          # 个人中心
│   │   │   └── onboarding/       # 用户画像引导
│   │   ├── models/               # 数据模型
│   │   └── theme/                # 青花瓷主题
│   └── pubspec.yaml
│
├── web/                          # 🌐 Next.js BFF + 管理后台
│   ├── app/
│   │   ├── api/v1/               # BFF API 路由
│   │   │   ├── ai/               # AI 咨询、对话、图片分析
│   │   │   ├── schools/          # 院校数据、对比
│   │   │   ├── me/               # 用户工作区（计划/任务/目标池）
│   │   │   └── auth/             # 认证与用户资料
│   │   ├── admin/                # 管理后台
│   │   └── artiqore-ui/          # 旧 React 参考 shell（非生产主站）
│   ├── lib/
│   │   ├── supabase/             # Supabase 服务端配置
│   │   ├── ai/                   # AI 管道（OpenAI + RAG）
│   │   └── pipelines/            # 业务管道（咨询/对比/计划生成）
│   └── package.json
│
├── supabase/migrations/          # 数据库迁移文件
├── scripts/                      # 部署与数据脚本
├── docs/                         # 文档
│   ├── AGENTS.md                 # AI 助手开发指南（必读）
│   ├── ADMIN_SETUP.md            # 管理员配置
│   └── APP_DEVELOPMENT.md        # APP 开发环境
├── tests/backend/                # 后端健康检查
└── README.md                     # 本文件
```

## 🚀 快速开始

### 环境要求
- **Node.js** 18+
- **Flutter SDK** 3.24+
- **Supabase** 账号（或使用现有项目）
- **OpenAI API Key**（用于 AI 咨询功能）

### 1. 克隆仓库

```bash
git clone https://github.com/artsee-platform/artsee.git
cd artsee
```

### 2. 配置环境变量

**项目根目录 `.env`**（用于后端健康检查与脚本）：
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

**Web `.env.local`**（Next.js BFF）：
```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# 高德 Web 服务 API Key（服务端专用，不要放进 Flutter）
AMAP_WEB_SERVICE_KEY=your_amap_web_service_key

# OpenAI（AI 咨询功能）
OPENAI_API_KEY=sk-...

# 可选：RAG 向量检索
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
```

**APP 配置**（`app/lib/config/api_config.dart`）：
- 本地开发默认连接 `http://localhost:9090`（Next.js 开发服务器）
- 生产环境通过 `--dart-define=API_BASE_URL=https://artiqore.com` 注入

### 3. 安装依赖

```bash
# Web 依赖
cd web && npm install

# APP 依赖
cd ../app && flutter pub get
```

### 4. 初始化数据库

在 Supabase Dashboard 的 SQL Editor 中依次执行 `supabase/migrations/` 下的迁移文件（按时间戳顺序）。

或使用 Supabase CLI：
```bash
supabase db push
```

### 5. 创建开发者测试账号

```bash
# 在项目根目录执行
npm run ensure:dev-user
```

这将创建测试账号：
- 邮箱：`dev.test@artsee.app`
- 密码：`ArtseeDev2026!`
- 角色：`admin`（如果 `user_profiles.role` 列存在）

### 6. 运行开发服务器

**启动 Web（BFF API）**：
```bash
cd web
PORT=9090 npm run dev
```

**启动 APP**：
```bash
cd app
flutter run -d <device_id>

# iOS 模拟器
flutter run -d "iPhone 17"

# Android 模拟器
flutter run -d emulator-5554
```

### 7. 验证环境

**后端健康检查**：
```bash
# 在项目根目录
npm run test:backend
```

**访问管理后台**：
- 登录测试账号后访问 `http://localhost:9090/admin`

## 📡 API 设计

### 认证与用户

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/auth/profile` | GET | 获取当前用户画像 |
| `/api/v1/auth/onboarding` | POST | 完成用户画像引导 |
| `/api/v1/auth/logout` | POST | 登出 |

### AI 咨询

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/ai/consult` | POST | AI 咨询（支持画像注入与 mode）|
| `/api/v1/ai/conversations` | GET | 获取对话历史 |
| `/api/v1/ai/conversations` | POST | 创建新对话 |
| `/api/v1/ai/image-analyze` | POST | 图片分析（作品集诊断）|
| `/api/v1/ai/transcribe` | POST | 语音转文字 |

### 院校与专业

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/schools` | GET | 获取院校列表（支持筛选）|
| `/api/v1/schools/:id` | GET | 获取院校详情 |
| `/api/v1/schools/compare` | POST | 院校多维对比（6 维雷达图）|
| `/api/v1/programs` | GET | 获取专业列表 |
| `/api/v1/programs/:id` | GET | 获取专业详情 |

### 申请工作区

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/me/saved-schools` | GET/POST | 目标院校池 |
| `/api/v1/me/saved-schools/:id` | DELETE | 移除目标院校 |
| `/api/v1/me/application-plan` | GET | 获取申请计划 |
| `/api/v1/me/application-plan/generate` | POST | 生成申请计划 |
| `/api/v1/me/portfolio-tasks` | GET | 获取作品集任务 |
| `/api/v1/me/portfolio-tasks/generate` | POST | 生成作品集任务 |
| `/api/v1/me/consultations` | GET | 获取咨询记录 |

### 社区与发现

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/opportunities` | GET | 获取合作机会 |
| `/api/v1/exhibitions` | GET | 获取展览活动 |
| `/api/v1/artists` | GET | 获取艺术家库 |
| `/api/v1/community/posts` | GET/POST | 社区动态 |
| `/api/v1/community/posts/:id` | GET | 动态详情 |

## 🎨 设计系统

项目采用 **青花瓷（Cobalt Blue）** 作为主题色，传达艺术与文化底蕴：

| 颜色 | 色值 | 用途 |
|------|------|------|
| **Cobalt** | `#123DAF` | 主色调、按钮、强调 |
| **Ink** | `#2B2B2D` | 文字颜色 |
| **Porcelain** | `#F7F4EF` | 背景色 |
| **Silver** | `#E5E5E5` | 分割线、边框 |

**字体**：
- 标题：Noto Serif SC（宋体）
- 正文：SF Pro / Roboto

详见 [`docs/DESIGN_SYSTEM.md`](./docs/DESIGN_SYSTEM.md)

## 🗓️ 开发路线图

### ✅ 已完成（v1.0）

- [x] 青花瓷主题设计系统
- [x] 数据库设计与迁移文件
- [x] 用户认证系统（Supabase Auth）
- [x] 动态 AI 画像系统（5 种用户角色）
- [x] 院校数据库（20+ 所顶尖艺术院校）
- [x] 院校对比功能（6 维雷达图）
- [x] 申请工作区（计划/任务/目标池）
- [x] AI 咨询管道（OpenAI + 画像注入）
- [x] 社区发现（机会/展览/艺术家）
- [x] 个人中心重构（动态主按钮）
- [x] 图文动态发布与浏览
- [x] 生产环境部署（artiqore.com）

### 🚧 进行中（v1.1）

- [ ] RAG 知识库检索（院校/专业/案例）
- [ ] 作品集任务拆解优化
- [ ] 机构入驻审核流程
- [ ] 展览活动报名与签到
- [ ] 艺术家主页与作品集展示

### 📋 计划中（v2.0）

- [ ] 微信小程序版本
- [ ] 在线作品集编辑器
- [ ] 视频课程与直播
- [ ] 1v1 咨询预约系统
- [ ] 申请材料协作工具

## 📚 重要文档

| 文档 | 说明 |
|------|------|
| **[AGENTS.md](./docs/AGENTS.md)** | **AI 助手开发指南（必读）** - 项目结构、调试技巧、开发者测试账号 |
| [APP_DEVELOPMENT.md](./docs/APP_DEVELOPMENT.md) | APP 开发环境搭建（含模拟器安装） |
| [ADMIN_SETUP.md](./docs/ADMIN_SETUP.md) | 管理员权限配置 |
| [DATABASE_REPORT.md](./DATABASE_REPORT.md) | 数据库现状报告 |
| [UI_REFERENCE.md](./UI_REFERENCE.md) | UI 参考设计说明 |

## 🤝 贡献指南

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交改动：`git commit -m 'feat: add amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 提交 Pull Request

**提交规范**：遵循 [Conventional Commits](https://www.conventionalcommits.org/)
- `feat:` 新功能
- `fix:` 修复 bug
- `docs:` 文档更新
- `style:` 代码格式调整
- `refactor:` 重构
- `test:` 测试相关

## 📞 联系方式

- **官网**：https://artiqore.com
- **GitHub**：https://github.com/artsee-platform/artsee
- **问题反馈**：[GitHub Issues](https://github.com/artsee-platform/artsee/issues)

## 许可证

MIT
