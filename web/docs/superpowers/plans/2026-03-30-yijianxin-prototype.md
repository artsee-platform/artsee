# 艺见心 APP 原型 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建艺见心 APP 完整可运行的 Web 原型，含 5 大页面、Mock 数据、完整 UI 设计系统

**Architecture:** Next.js 16 App Router，移动端优先（max-w-sm 居中），纯 Mock 数据（无需 Supabase），Tailwind CSS 4 + shadcn/ui 组件

**Tech Stack:** Next.js 16, React 19, Tailwind CSS 4, lucide-react, shadcn/ui

---

## 文件结构

```
app/
├── layout.tsx                    ← 修改：加字体、颜色变量
├── globals.css                   ← 修改：加 orange 主色、字体导入
├── page.tsx                      ← 修改：首页（发现流）
├── explore/page.tsx              ← 新建：探索页（院校库）
├── cases/page.tsx                ← 新建：案例&灵感库
├── forum/page.tsx                ← 新建：论坛社区
└── profile/page.tsx              ← 新建：我的（个人中心）

components/
├── layout/
│   ├── bottom-nav.tsx            ← 新建：底部 5-Tab 导航
│   ├── top-bar.tsx               ← 新建：顶部导航栏
│   └── mobile-shell.tsx         ← 新建：手机壳容器（桌面居中）
├── home/
│   ├── feed-card.tsx             ← 新建：信息流卡片
│   └── story-bar.tsx             ← 新建：顶部故事条（院校动态）
├── explore/
│   ├── university-card.tsx       ← 新建：院校卡片
│   └── filter-chips.tsx          ← 新建：筛选标签条
├── cases/
│   ├── case-card.tsx             ← 新建：案例瀑布流卡片
│   └── waterfall-grid.tsx        ← 新建：双列瀑布流容器
├── forum/
│   └── post-card.tsx             ← 新建：论坛帖子卡片
└── profile/
    ├── stat-bar.tsx              ← 新建：关注/粉丝/获赞统计
    └── tracker-card.tsx          ← 新建：申请追踪卡片

lib/
└── mock-data.ts                  ← 新建：全站 Mock 数据
```

---

### Task 1: 设计系统基础（globals.css + layout.tsx）

**Files:**
- Modify: `app/globals.css`
- Modify: `app/layout.tsx`

- [ ] 更新 globals.css，注入 orange 主色系和字体变量
- [ ] 更新 layout.tsx，引入 Google Fonts (Poppins + Noto Sans SC)，设置 metadata

---

### Task 2: Mock 数据

**Files:**
- Create: `lib/mock-data.ts`

- [ ] 写全站 mock 数据（院校、案例、帖子、用户）

---

### Task 3: 布局组件

**Files:**
- Create: `components/layout/mobile-shell.tsx`
- Create: `components/layout/bottom-nav.tsx`
- Create: `components/layout/top-bar.tsx`

- [ ] 创建手机壳容器（桌面端居中模拟 App）
- [ ] 创建底部 5-Tab 导航（首页/探索/案例/论坛/我的）
- [ ] 创建顶部栏（Logo + 搜索 + 通知）

---

### Task 4: 首页

**Files:**
- Create: `components/home/story-bar.tsx`
- Create: `components/home/feed-card.tsx`
- Modify: `app/page.tsx`

- [ ] Story 条（院校头像滚动）
- [ ] Feed 卡片（图片+标题+标签+互动数）
- [ ] 首页组装

---

### Task 5: 探索页

**Files:**
- Create: `components/explore/filter-chips.tsx`
- Create: `components/explore/university-card.tsx`
- Create: `app/explore/page.tsx`

- [ ] 筛选标签条（国家/专业/IELTS）
- [ ] 院校卡片（Logo+名称+申请要求摘要）
- [ ] 探索页组装（搜索框 + 筛选 + 列表）

---

### Task 6: 案例&灵感库页

**Files:**
- Create: `components/cases/case-card.tsx`
- Create: `components/cases/waterfall-grid.tsx`
- Create: `app/cases/page.tsx`

- [ ] 案例卡片（封面图+学校tag+申请结果badge）
- [ ] 双列瀑布流容器
- [ ] 案例页组装（Tab切换：案例/灵感）

---

### Task 7: 论坛页

**Files:**
- Create: `components/forum/post-card.tsx`
- Create: `app/forum/page.tsx`

- [ ] 帖子卡片（用户头像+问题标题+互动数）
- [ ] 论坛页组装（Tab：问答/话题/资讯）

---

### Task 8: 我的页面

**Files:**
- Create: `components/profile/stat-bar.tsx`
- Create: `components/profile/tracker-card.tsx`
- Create: `app/profile/page.tsx`

- [ ] 个人主页头部（头像+背景+统计）
- [ ] 申请追踪卡片（进度时间轴）
- [ ] 我的页面组装

---

### Task 9: 安装依赖 & 启动

- [ ] npm install
- [ ] npm run dev 验证可运行
