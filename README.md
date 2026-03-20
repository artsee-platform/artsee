# Artsee

发现、收藏和分享艺术品的最佳平台。

## 项目结构

```
artsee/
├── app/                # Flutter 移动应用
│   ├── lib/           # Dart 源代码
│   ├── android/       # Android 配置
│   ├── ios/           # iOS 配置
│   └── pubspec.yaml   # Flutter 依赖
├── web/               # Next.js 网站和后端 API
│   ├── app/          # Next.js App Router
│   ├── components/   # React 组件
│   ├── lib/          # 工具库和 Supabase 配置
│   └── public/       # 静态资源
├── init_data/         # 初始化数据 (已加入 .gitignore)
└── .vscode/          # VS Code 配置
```

## 技术栈

### 移动应用 (app/)
- **框架**: Flutter
- **样式**: tailwindcss_build
- **组件库**: shadcn_ui
- **语言**: Dart

### 网站/后端 (web/)
- **框架**: Next.js 15 + React 19
- **样式**: Tailwind CSS 4
- **组件库**: shadcn/ui
- **数据库**: Supabase
- **语言**: TypeScript

## 快速开始

### 环境要求
- Node.js 18+
- Flutter SDK
- Dart SDK

### 安装依赖

```bash
# 安装 Web 依赖
npm install

# 安装 App 依赖
cd app && flutter pub get
```

### 运行开发服务器

```bash
# 运行 Web 开发服务器
npm run dev:web

# 运行 App (需要先连接设备或模拟器)
npm run dev:app
```

### 构建生产版本

```bash
# 构建 Web
npm run build:web

# 构建 App
cd app && flutter build apk  # Android
cd app && flutter build ios  # iOS
```

## 环境变量

创建 `web/.env.local` 文件：

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## 许可证

MIT
