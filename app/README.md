# Artsee Flutter APP

> **艺术留学智能申请平台 - Flutter 移动客户端**

Artsee 的 Flutter 移动应用，为艺术留学生提供 AI 咨询、申请管理、院校浏览、案例分享等核心功能。

---

## 📋 目录

- [核心功能](#核心功能)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [开发指南](#开发指南)
- [测试](#测试)
- [构建与发布](#构建与发布)
- [配置说明](#配置说明)

---

## 🎯 核心功能

### 1. AI Home - 智能咨询
- **流式对话**：实时打字机效果的 AI 对话
- **院校卡片**：AI 回复中自动展示院校信息卡片
- **智能推荐**：基于对话内容推荐院校和案例
- **快速提示**：4 个快速问题入口
- **对话历史**：本地持久化对话记录

### 2. 申请清单管理
- **CRUD 操作**：添加、查看、更新、删除申请项
- **智能分层**：AI 自动分析并建议分层（冲刺/匹配/保底）
- **时间线生成**：根据 deadline 自动生成倒排任务
- **状态跟踪**：规划中、准备材料、已提交、已录取、未录取
- **案例关联**：申请项下方显示相关录取案例
- **院校搜索**：添加时支持搜索院校（自动带 school_id）

### 3. 院校与专业
- **院校列表**：支持按国家、城市、排名筛选
- **院校详情**：logo、校园图片、基本信息、专业列表
- **专业列表**：支持按学位、作品集要求筛选
- **专业详情**：学位、学制、学费、申请要求、作品集要求
- **搜索功能**：关键词搜索院校和专业

### 4. 案例分享
- **案例列表**：查看其他学生的录取案例
- **案例详情**：目标院校、专业、背景、作品集、录取结果
- **筛选功能**：按院校、专业、录取结果筛选

### 5. 社区互动
- **帖子列表**：浏览社区帖子
- **帖子详情**：查看帖子内容、评论
- **点赞收藏**：点赞、收藏帖子
- **发布帖子**：分享申请经验、作品集心得

---

## 🛠 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **Flutter** | 3.x | 跨平台移动开发框架 |
| **Dart** | 3.5+ | 编程语言 |
| **http** | 1.2.2 | HTTP 客户端（调用 Web API） |
| **Supabase Flutter** | 2.5.0 | Supabase 客户端（Auth + Storage） |
| **go_router** | 14.2.0 | 路由管理 |
| **shared_preferences** | 2.2.3 | 本地存储 |
| **image_picker** | 1.0.7 | 图片选择 |
| **record** | 5.2.1 | 录音功能 |
| **audioplayers** | 5.2.1 | 音频播放 |

---

## 📁 项目结构

```
app/
├── lib/
│   ├── main.dart                 # 应用入口
│   │
│   ├── config/                   # 配置
│   │   ├── api_config.dart       # API 基址配置
│   │   └── dev_test_account.dart # 测试账号配置
│   │
│   ├── services/                 # 服务层
│   │   ├── backend_api_service.dart  # 后端 API 封装
│   │   └── supabase_service.dart     # Supabase 服务
│   │
│   ├── models/                   # 数据模型
│   │   ├── models.dart           # 模型导出
│   │   ├── school.dart           # 院校模型
│   │   ├── program.dart          # 专业模型
│   │   ├── case.dart             # 案例模型
│   │   ├── community_post.dart   # 帖子模型
│   │   └── application_tracker_item.dart  # 申请项模型
│   │
│   ├── screens/                  # 页面
│   │   ├── home/                 # AI Home
│   │   │   └── ai_home_screen.dart
│   │   ├── application/          # 申请清单
│   │   │   ├── application_screen.dart
│   │   │   └── my_tracker_screen.dart
│   │   ├── schools/              # 院校列表
│   │   │   ├── school_list_screen.dart
│   │   │   └── school_detail_screen.dart
│   │   ├── programs/             # 专业列表
│   │   │   ├── program_list_enhanced_screen.dart
│   │   │   └── program_detail_screen.dart
│   │   ├── cases/                # 案例分享
│   │   │   ├── cases_screen.dart
│   │   │   └── case_detail_screen.dart
│   │   ├── community/            # 社区
│   │   │   ├── community_screen.dart
│   │   │   └── post_detail_screen.dart
│   │   └── profile/              # 个人中心
│   │       └── profile_screen.dart
│   │
│   ├── widgets/                  # 通用组件
│   │   └── common.dart           # 通用 Widget
│   │
│   └── theme/                    # 主题
│       └── artsee_ui_colors.dart # 颜色定义
│
├── test/                         # 测试
│   └── backend_api_parse_test.dart
│
├── assets/                       # 资源文件
│   ├── fonts/                    # 字体
│   └── images/                   # 图片
│
├── android/                      # Android 配置
├── ios/                          # iOS 配置
├── pubspec.yaml                  # 依赖配置
├── AGENTS.md                     # AI 助手开发指南
└── README.md                     # 本文件
```

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK** 3.x
- **Dart SDK** 3.5+
- **Android Studio** / **Xcode**（根据目标平台）
- **模拟器** 或 **真机设备**

### 1. 安装依赖

```bash
cd app
flutter pub get
```

### 2. 配置 API 基址

编辑 `lib/config/api_config.dart`，设置后端 API 地址：

```dart
class AppConfig {
  // 本地开发（模拟器）
  static const String API_BASE_URL = 'http://10.0.2.2:3000';
  
  // 或生产环境
  // static const String API_BASE_URL = 'https://artiqore.com';
}
```

**注意：**
- **Android 模拟器**：使用 `10.0.2.2` 访问本机
- **iOS 模拟器**：使用 `localhost` 或 `127.0.0.1`
- **真机**：使用本机局域网 IP（如 `192.168.x.x`）

### 3. 配置测试账号

测试账号已在 `lib/config/dev_test_account.dart` 中定义：

```dart
class DevTestAccount {
  static const String email = 'dev.test@artsee.app';
  static const String password = 'ArtseeDev2026!';
}
```

确保后端已创建此测试用户（在项目根目录执行）：

```bash
npm run ensure:dev-user
```

### 4. 运行应用

```bash
# 列出可用设备
flutter devices

# 运行到指定设备
flutter run -d <device_id>

# 或直接运行（自动选择设备）
flutter run
```

**快速启动（Chrome 调试）：**

```bash
flutter run -d chrome
```

**注意：** Flutter Web 调试会自动启动/复用 Chrome 实例，**不要手动重复打开新 Chrome 窗口**。

---

## 🛠 开发指南

### 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 运行到 Chrome（Web 调试）
flutter run -d chrome

# 热重载（应用运行时按 r）
# 热重启（应用运行时按 R）

# 代码分析
flutter analyze

# 运行测试
flutter test

# 清理构建缓存
flutter clean

# 查看设备列表
flutter devices
```

### 开发流程

1. **后端 API 优先**：确保后端 API 已实现并可用
2. **模型定义**：在 `lib/models/` 中定义数据模型
3. **服务层封装**：在 `lib/services/backend_api_service.dart` 中封装 API 调用
4. **UI 实现**：在 `lib/screens/` 中实现界面
5. **测试验证**：运行 `flutter analyze` 和 `flutter test`

### 调试技巧

**遇到问题时，按以下顺序排查：**

1. **后端 API** → 在项目根目录运行 `npm run test:backend`
2. **网络连接** → 检查 API 基址配置（`lib/config/api_config.dart`）
3. **数据模型** → 检查 `fromJson` 方法是否与后端响应一致
4. **权限问题** → 检查 Supabase Auth Token 是否有效
5. **Flutter 错误** → 查看控制台错误信息

详见 [调试指南](../.cursor/skills/jinhui-stack-debug/SKILL.md)

### 添加新页面

1. 在 `lib/screens/` 下创建新目录
2. 创建 `*_screen.dart` 文件
3. 在 `main.dart` 中添加路由
4. 在底部导航栏中添加入口（如需要）

### 调用后端 API

所有 API 调用统一通过 `BackendApiService` 封装：

```dart
import 'package:artsee_app/services/backend_api_service.dart';

// 示例：获取院校列表
final result = await BackendApiService.fetchSchools(
  keyword: '皇艺',
  limit: 10,
);

// 示例：添加到申请清单
final item = await BackendApiService.addToTracker(
  schoolId: '123',
  schoolName: '皇家艺术学院',
  tier: 'reach',
);
```

---

## 🧪 测试

### 运行所有测试

```bash
flutter test
```

### 运行代码分析

```bash
flutter analyze
```

### 测试覆盖范围

- ✅ 数据模型 `fromJson` 测试（`test/backend_api_parse_test.dart`）
- ✅ 代码静态分析（`flutter analyze`）

---

## 📦 构建与发布

### Android

```bash
# Debug 版本
flutter build apk --debug

# Release 版本
flutter build apk --release

# App Bundle（推荐上传 Google Play）
flutter build appbundle --release
```

**输出位置：**
- APK：`build/app/outputs/flutter-apk/app-release.apk`
- AAB：`build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
# Release 版本
flutter build ios --release
```

**注意：** iOS 构建需要在 macOS 上进行，并配置好 Apple Developer 账号。

### Web

```bash
flutter build web --release
```

**输出位置：** `build/web/`

---

## ⚙️ 配置说明

### API 基址配置

**文件：** `lib/config/api_config.dart`

```dart
class AppConfig {
  // 开发环境
  static const String API_BASE_URL = 'http://10.0.2.2:3000';
  
  // 生产环境
  // static const String API_BASE_URL = 'https://artiqore.com';
}
```

**环境切换：**
- 开发时使用本地地址
- 发布前改为生产地址
- 或使用 `--dart-define` 传递环境变量

### 测试账号配置

**文件：** `lib/config/dev_test_account.dart`

```dart
class DevTestAccount {
  static const String email = 'dev.test@artsee.app';
  static const String password = 'ArtseeDev2026!';
}
```

**说明：**
- 此账号用于开发和测试
- 与后端测试账号保持一致
- 在项目根目录运行 `npm run ensure:dev-user` 创建/修复

### Supabase 配置

**文件：** `lib/services/supabase_service.dart`

Supabase URL 和 Anon Key 在此文件中配置，用于：
- 用户认证（Auth）
- 文件上传（Storage）
- 实时订阅（Realtime，可选）

---

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| **[AGENTS.md](AGENTS.md)** | AI 助手开发指南（本目录） |
| **[../AGENTS.md](../AGENTS.md)** | 项目总览（根目录） |
| **[../web/README.md](../web/README.md)** | Web 后端文档 |
| **[../.cursor/skills/jinhui-stack-debug/](../.cursor/skills/jinhui-stack-debug/)** | 调试指南 |

---

## 🤝 贡献

1. 遵循现有代码风格
2. 运行 `flutter analyze` 确保无错误
3. 添加必要的测试
4. 提交前运行 `flutter test`

---

## 📄 许可证

Copyright © 2026 Artsee / Artiqore 艺衡. All rights reserved.
