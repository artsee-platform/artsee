// 全站 Mock 数据

export type University = {
  id: string;
  nameCn: string;
  nameEn: string;
  shortName: string;
  country: string;
  city: string;
  program: string;
  programEn: string;
  duration: string;
  ielts: string;
  gpaMin: string;
  gpaScale: string;
  recommenders: number;
  hasInterview: boolean;
  deadline: string;
  rolling: boolean;
  tuition: string;
  color: string; // gradient color class
  initial: string;
};

export type Case = {
  id: string;
  authorName: string;
  authorAvatar: string;
  undergrad: string;
  gpa: string;
  targetSchool: string;
  targetProgram: string;
  result: "admitted" | "waitlisted" | "rejected";
  excerpt: string;
  coverGradient: string;
  tags: string[];
  likeCount: number;
  commentCount: number;
  saveCount: number;
  createdAt: string;
  year: string;
};

export type Post = {
  id: string;
  authorName: string;
  authorAvatar: string;
  type: "question" | "discussion" | "news";
  title: string;
  content: string;
  tags: string[];
  likeCount: number;
  answerCount: number;
  viewCount: number;
  createdAt: string;
  isMentor: boolean;
};

export type FeedItem = {
  id: string;
  type: "case" | "news" | "topic";
  title: string;
  excerpt: string;
  coverGradient: string;
  schoolTag?: string;
  authorName: string;
  authorAvatar: string;
  likeCount: number;
  commentCount: number;
  createdAt: string;
};

export type ApplicationTracker = {
  id: string;
  schoolName: string;
  programName: string;
  tier: "reach" | "match" | "safety";
  status: "planning" | "preparing" | "submitted" | "interview" | "admitted" | "rejected" | "waitlisted";
  deadline: string;
};

// ─── 院校数据 ───────────────────────────────────────────────
export const universities: University[] = [
  {
    id: "oxford",
    nameCn: "牛津大学",
    nameEn: "University of Oxford",
    shortName: "Oxford",
    country: "英国",
    city: "牛津",
    program: "纯艺术硕士",
    programEn: "MFA Fine Art",
    duration: "1年",
    ielts: "7.5 (7.0)",
    gpaMin: "3.75",
    gpaScale: "4.0",
    recommenders: 3,
    hasInterview: true,
    deadline: "2025-03-15",
    rolling: false,
    tuition: "£29,700/年",
    color: "from-blue-600 to-indigo-700",
    initial: "Ox",
  },
  {
    id: "cambridge",
    nameCn: "剑桥大学",
    nameEn: "University of Cambridge",
    shortName: "Cambridge",
    country: "英国",
    city: "剑桥",
    program: "建筑与城市研究硕士",
    programEn: "MPhil Architecture & Urban Studies",
    duration: "1年",
    ielts: "7.5 (7.0)",
    gpaMin: "3.5",
    gpaScale: "4.0",
    recommenders: 2,
    hasInterview: true,
    deadline: "2025-02-28",
    rolling: false,
    tuition: "£31,497/年",
    color: "from-sky-500 to-blue-600",
    initial: "Cam",
  },
  {
    id: "imperial-rca",
    nameCn: "帝国理工 + 皇家艺术学院",
    nameEn: "Imperial College London & RCA",
    shortName: "IDE",
    country: "英国",
    city: "伦敦",
    program: "创新设计工程",
    programEn: "Innovation Design Engineering",
    duration: "21个月",
    ielts: "7.0 (6.5)",
    gpaMin: "3.0",
    gpaScale: "4.0",
    recommenders: 2,
    hasInterview: true,
    deadline: "2025-04-01",
    rolling: false,
    tuition: "£38,500/年",
    color: "from-purple-600 to-violet-700",
    initial: "IDE",
  },
  {
    id: "ucl",
    nameCn: "伦敦大学学院",
    nameEn: "University College London",
    shortName: "UCL",
    country: "英国",
    city: "伦敦",
    program: "纯艺术硕士",
    programEn: "Fine Art MFA",
    duration: "18个月",
    ielts: "6.5 (6.0)",
    gpaMin: "3.0",
    gpaScale: "4.0",
    recommenders: 1,
    hasInterview: true,
    deadline: "滚动录取",
    rolling: true,
    tuition: "£27,900/年",
    color: "from-emerald-500 to-teal-600",
    initial: "UCL",
  },
  {
    id: "edinburgh",
    nameCn: "爱丁堡大学",
    nameEn: "University of Edinburgh",
    shortName: "Edinburgh",
    country: "英国",
    city: "爱丁堡",
    program: "当代艺术实践",
    programEn: "Contemporary Art Practice MA",
    duration: "1年",
    ielts: "6.5 (6.0)",
    gpaMin: "3.25",
    gpaScale: "4.0",
    recommenders: 2,
    hasInterview: false,
    deadline: "滚动录取",
    rolling: true,
    tuition: "£24,800/年",
    color: "from-rose-500 to-pink-600",
    initial: "Edin",
  },
  {
    id: "csm",
    nameCn: "中央圣马丁",
    nameEn: "Central Saint Martins",
    shortName: "CSM",
    country: "英国",
    city: "伦敦",
    program: "纯艺术硕士",
    programEn: "MA Fine Art",
    duration: "2年",
    ielts: "6.5 (5.5)",
    gpaMin: "荣誉学位",
    gpaScale: "英制",
    recommenders: 2,
    hasInterview: true,
    deadline: "2025-03-31",
    rolling: false,
    tuition: "£26,200/年",
    color: "from-blue-500 to-indigo-600",
    initial: "CSM",
  },
  {
    id: "camberwell",
    nameCn: "坎伯韦尔艺术学院",
    nameEn: "Camberwell College of Arts",
    shortName: "Camberwell",
    country: "英国",
    city: "伦敦",
    program: "纯艺术（油画）",
    programEn: "MA Fine Art: Painting",
    duration: "15个月",
    ielts: "6.5 (5.5)",
    gpaMin: "荣誉学位",
    gpaScale: "英制",
    recommenders: 2,
    hasInterview: true,
    deadline: "2025-03-31",
    rolling: false,
    tuition: "£25,100/年",
    color: "from-fuchsia-500 to-purple-600",
    initial: "CAM",
  },
];

// ─── 案例数据 ────────────────────────────────────────────────
export const cases: Case[] = [
  {
    id: "c1",
    authorName: "小艺同学",
    authorAvatar: "🎨",
    undergrad: "中央美术学院",
    gpa: "3.8/4.0",
    targetSchool: "牛津大学",
    targetProgram: "MFA Fine Art",
    result: "admitted",
    excerpt: "备考两年，终于拿到鲁斯金的录取！分享我的作品集准备全过程，从概念到执行，踩了太多坑...",
    coverGradient: "from-blue-500 via-indigo-500 to-purple-600",
    tags: ["纯艺", "英国", "MFA", "作品集"],
    likeCount: 342,
    commentCount: 56,
    saveCount: 218,
    createdAt: "2025-12-15",
    year: "2025",
  },
  {
    id: "c2",
    authorName: "建筑狗阿明",
    authorAvatar: "🏛️",
    undergrad: "同济大学",
    gpa: "3.6/4.0",
    targetSchool: "剑桥大学",
    targetProgram: "MPhil Architecture",
    result: "admitted",
    excerpt: "剑桥建筑申请成功！研究计划怎么写？IELTS 7.5 备考路线分享，附面试真题复盘...",
    coverGradient: "from-sky-400 via-blue-500 to-cyan-600",
    tags: ["建筑", "剑桥", "研究计划"],
    likeCount: 289,
    commentCount: 43,
    saveCount: 176,
    createdAt: "2025-11-20",
    year: "2025",
  },
  {
    id: "c3",
    authorName: "设计师CC",
    authorAvatar: "⚡",
    undergrad: "香港理工大学",
    gpa: "3.4/4.0",
    targetSchool: "帝国理工+RCA",
    targetProgram: "Innovation Design Engineering",
    result: "admitted",
    excerpt: "IDE 录取！帝国理工和 RCA 的双硕士课程到底值不值？亲身经历告诉你选校逻辑...",
    coverGradient: "from-violet-500 via-purple-500 to-indigo-600",
    tags: ["设计工程", "IDE", "双硕士"],
    likeCount: 521,
    commentCount: 89,
    saveCount: 334,
    createdAt: "2025-10-08",
    year: "2025",
  },
  {
    id: "c4",
    authorName: "油画er",
    authorAvatar: "🖌️",
    undergrad: "广州美术学院",
    gpa: "3.5/4.0",
    targetSchool: "UCL",
    targetProgram: "Fine Art MFA",
    result: "admitted",
    excerpt: "UCL 斯莱德录取！18个月的课程设置超级特别，作品集要20张图，我的选图逻辑分享...",
    coverGradient: "from-emerald-400 via-teal-500 to-green-600",
    tags: ["纯艺", "UCL", "斯莱德"],
    likeCount: 198,
    commentCount: 31,
    saveCount: 145,
    createdAt: "2025-09-14",
    year: "2025",
  },
  {
    id: "c5",
    authorName: "摄影控Lily",
    authorAvatar: "📷",
    undergrad: "北京电影学院",
    gpa: "3.7/4.0",
    targetSchool: "爱丁堡大学",
    targetProgram: "Contemporary Art Practice",
    result: "admitted",
    excerpt: "爱丁堡当代艺术录取！作品集用了10页PDF，如何在有限篇幅内讲好一个艺术故事...",
    coverGradient: "from-rose-400 via-pink-500 to-fuchsia-600",
    tags: ["摄影", "爱丁堡", "当代艺术"],
    likeCount: 267,
    commentCount: 38,
    saveCount: 189,
    createdAt: "2025-08-22",
    year: "2025",
  },
  {
    id: "c6",
    authorName: "插画少女",
    authorAvatar: "✏️",
    undergrad: "四川美术学院",
    gpa: "3.3/4.0",
    targetSchool: "中央圣马丁",
    targetProgram: "MA Fine Art",
    result: "admitted",
    excerpt: "CSM 录取！GPA 不高照样上名校，文书和视频任务才是制胜关键，分享我的备考思路...",
    coverGradient: "from-blue-400 via-indigo-500 to-violet-600",
    tags: ["插画", "CSM", "视频任务"],
    likeCount: 445,
    commentCount: 72,
    saveCount: 298,
    createdAt: "2025-07-30",
    year: "2025",
  },
  {
    id: "c7",
    authorName: "装置艺术家K",
    authorAvatar: "🔮",
    undergrad: "中国美术学院",
    gpa: "3.9/4.0",
    targetSchool: "牛津大学",
    targetProgram: "MFA Fine Art",
    result: "waitlisted",
    excerpt: "等候名单一年后放弃了牛津，转身申请到了 RCA，分享这段奇妙的申请旅程...",
    coverGradient: "from-slate-500 via-gray-600 to-zinc-700",
    tags: ["装置艺术", "等候", "心路历程"],
    likeCount: 312,
    commentCount: 94,
    saveCount: 201,
    createdAt: "2025-06-18",
    year: "2025",
  },
  {
    id: "c8",
    authorName: "雕塑系小王",
    authorAvatar: "🗿",
    undergrad: "鲁迅美术学院",
    gpa: "3.6/4.0",
    targetSchool: "坎伯韦尔艺术学院",
    targetProgram: "MA Fine Art: Painting",
    result: "admitted",
    excerpt: "坎伯韦尔油画硕士录取！伦敦艺术大学系的申请和 CSM 有什么区别？全面对比...",
    coverGradient: "from-fuchsia-400 via-purple-500 to-violet-600",
    tags: ["雕塑", "坎伯韦尔", "UAL"],
    likeCount: 156,
    commentCount: 24,
    saveCount: 112,
    createdAt: "2025-05-10",
    year: "2025",
  },
];

// ─── 论坛帖子 ────────────────────────────────────────────────
export const posts: Post[] = [
  {
    id: "p1",
    authorName: "艺留小白",
    authorAvatar: "🌱",
    type: "question",
    title: "牛津 MFA 和 UCL MFA 到底选哪个？两者的差异有多大？",
    content: "我现在两个都拿到了 offer，牛津是1年、UCL是18个月，学费差不多，想听听过来人的意见...",
    tags: ["牛津", "UCL", "选校"],
    likeCount: 89,
    answerCount: 23,
    viewCount: 1204,
    createdAt: "2天前",
    isMentor: false,
  },
  {
    id: "p2",
    authorName: "Maya导师",
    authorAvatar: "👩‍🎨",
    type: "discussion",
    title: "【干货】2026年英国艺术类院校申请时间轴整理（附截止日期）",
    content: "每年这个时候都有同学问截止日期，统一整理一下2026年各院校的申请时间节点，包括CSM、UAL、牛津、UCL...",
    tags: ["时间轴", "申请季", "干货"],
    likeCount: 567,
    answerCount: 45,
    viewCount: 8920,
    createdAt: "1周前",
    isMentor: true,
  },
  {
    id: "p3",
    authorName: "IELTS奋斗者",
    authorAvatar: "📚",
    type: "question",
    title: "雅思考了 6.0，还有机会申请 UCL 吗？求安慰也求建议",
    content: "UCL 要求 6.5，我目前最高分是 6.0，还有3个月备考时间，想知道有没有可能冲上去...",
    tags: ["雅思", "UCL", "备考"],
    likeCount: 34,
    answerCount: 18,
    viewCount: 892,
    createdAt: "3天前",
    isMentor: false,
  },
  {
    id: "p4",
    authorName: "设计圈小李",
    authorAvatar: "🎯",
    type: "news",
    title: "【资讯】中央圣马丁 2026 秋季 MA Fine Art 已开放申请",
    content: "CSM 官网今日更新，2026年秋季入学的纯艺硕士已正式开放申请通道，截止日期为2025年3月31日...",
    tags: ["CSM", "资讯", "申请开放"],
    likeCount: 234,
    answerCount: 12,
    viewCount: 4510,
    createdAt: "5天前",
    isMentor: false,
  },
  {
    id: "p5",
    authorName: "作品集焦虑症",
    authorAvatar: "😰",
    type: "question",
    title: "作品集15张图的选图逻辑是什么？越多越好还是精选？",
    content: "牛津要求最多15张静态图，我有30多张候选作品，不知道选图逻辑是以系列感为主还是展示多元性...",
    tags: ["作品集", "选图", "牛津"],
    likeCount: 123,
    answerCount: 29,
    viewCount: 2340,
    createdAt: "4天前",
    isMentor: false,
  },
  {
    id: "p6",
    authorName: "Luke导师",
    authorAvatar: "👨‍🏫",
    type: "discussion",
    title: "【经验分享】帝国理工+RCA IDE 面试深度复盘，附常见问题清单",
    content: "IDE 的面试和普通艺术院校很不一样，需要同时展现工程思维和设计感，整理了我准备时的思路...",
    tags: ["IDE", "面试", "帝国理工"],
    likeCount: 389,
    answerCount: 56,
    viewCount: 6780,
    createdAt: "2周前",
    isMentor: true,
  },
  {
    id: "p7",
    authorName: "爱丁堡在读",
    authorAvatar: "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
    type: "discussion",
    title: "在爱丁堡读艺术研究生半年感受：城市、课程、生活成本全记录",
    content: "来这里读了半年了，想说说和预想不同的地方。苏格兰的生活节奏和伦敦完全不一样，课程强度也超出预期...",
    tags: ["爱丁堡", "在读", "生活"],
    likeCount: 445,
    answerCount: 67,
    viewCount: 9230,
    createdAt: "3天前",
    isMentor: false,
  },
  {
    id: "p8",
    authorName: "剑桥申请者",
    authorAvatar: "🎓",
    type: "question",
    title: "剑桥 MAUS 的研究计划要写建筑方向还是城市研究方向更好申？",
    content: "我的背景是建筑本科，但对城市研究也很感兴趣，MAUS 是交叉学科，不知道研究计划写哪个方向更有优势...",
    tags: ["剑桥", "研究计划", "建筑"],
    likeCount: 67,
    answerCount: 11,
    viewCount: 1120,
    createdAt: "1天前",
    isMentor: false,
  },
];

// ─── 首页信息流 ──────────────────────────────────────────────
export const feedItems: FeedItem[] = [
  {
    id: "f1",
    type: "case",
    title: "牛津 MFA 录取经历：从零开始准备作品集的18个月",
    excerpt: "我是芝加哥大学视觉艺术本科，GPA 3.8，分享我从决定申请到拿到录取通知的完整历程...",
    coverGradient: "from-blue-500 via-indigo-500 to-purple-600",
    schoolTag: "牛津大学 · MFA",
    authorName: "小艺同学",
    authorAvatar: "🎨",
    likeCount: 342,
    commentCount: 56,
    createdAt: "2天前",
  },
  {
    id: "f2",
    type: "news",
    title: "2026 英国艺术类留学最新动态：多所顶校申请要求变化",
    excerpt: "牛津鲁斯金、CSM、UCL斯莱德等院校2026年招生要求已更新，部分学校IELTS有所调整...",
    coverGradient: "from-slate-700 via-slate-600 to-zinc-700",
    authorName: "艺见心资讯",
    authorAvatar: "📰",
    likeCount: 891,
    commentCount: 124,
    createdAt: "1天前",
  },
  {
    id: "f3",
    type: "case",
    title: "IDE 双硕士录取！帝国理工+RCA 申请全过程记录",
    excerpt: "两所顶校联合课程，21个月的设计工程培训，分享我的作品集PDF和视频自我介绍准备方法...",
    coverGradient: "from-violet-500 via-purple-500 to-indigo-600",
    schoolTag: "帝国理工+RCA · IDE",
    authorName: "设计师CC",
    authorAvatar: "⚡",
    likeCount: 521,
    commentCount: 89,
    createdAt: "3天前",
  },
  {
    id: "f4",
    type: "topic",
    title: "#作品集改稿记录 一个装置艺术系列的诞生",
    excerpt: "从最初的草稿到最终提交给牛津的版本，记录三个月的改稿历程，每次修改的原因都写清楚了...",
    coverGradient: "from-blue-400 via-indigo-500 to-violet-600",
    schoolTag: "#作品集话题",
    authorName: "装置艺术家K",
    authorAvatar: "🔮",
    likeCount: 267,
    commentCount: 43,
    createdAt: "5天前",
  },
  {
    id: "f5",
    type: "case",
    title: "爱丁堡当代艺术录取，GPA 3.7 的摄影系学生怎么准备作品集",
    excerpt: "选了10页A4 PDF格式，里面有静态摄影作品也有视频链接，告诉大家我的选图逻辑...",
    coverGradient: "from-rose-400 via-pink-500 to-fuchsia-600",
    schoolTag: "爱丁堡大学 · MA",
    authorName: "摄影控Lily",
    authorAvatar: "📷",
    likeCount: 198,
    commentCount: 31,
    createdAt: "1周前",
  },
];

// ─── 申请追踪 ────────────────────────────────────────────────
export const myTrackers: ApplicationTracker[] = [
  { id: "t1", schoolName: "牛津大学", programName: "MFA Fine Art", tier: "reach", status: "submitted", deadline: "2025-03-15" },
  { id: "t2", schoolName: "UCL", programName: "Fine Art MFA", tier: "match", status: "interview", deadline: "滚动录取" },
  { id: "t3", schoolName: "爱丁堡大学", programName: "Contemporary Art Practice", tier: "match", status: "admitted", deadline: "滚动录取" },
  { id: "t4", schoolName: "坎伯韦尔艺术学院", programName: "MA Fine Art", tier: "safety", status: "admitted", deadline: "2025-03-31" },
];

// ─── Story 头像（院校） ──────────────────────────────────────
export const stories = [
  { id: "s0", name: "全部", initial: "全", color: "from-orange-500 to-amber-500", isAll: true },
  { id: "s1", name: "牛津", initial: "Ox", color: "from-blue-600 to-indigo-700" },
  { id: "s2", name: "剑桥", initial: "Cam", color: "from-sky-500 to-blue-600" },
  { id: "s3", name: "帝国+RCA", initial: "IDE", color: "from-purple-600 to-violet-700" },
  { id: "s4", name: "UCL", initial: "UCL", color: "from-emerald-500 to-teal-600" },
  { id: "s5", name: "CSM", initial: "CSM", color: "from-blue-500 to-indigo-600" },
  { id: "s6", name: "爱丁堡", initial: "Edin", color: "from-rose-500 to-pink-600" },
];

// ─── 工具函数 ────────────────────────────────────────────────
export const resultLabel: Record<Case["result"], string> = {
  admitted: "🎉 录取",
  waitlisted: "⏳ 等候",
  rejected: "❌ 拒绝",
};

export const resultColor: Record<Case["result"], string> = {
  admitted: "bg-green-100 text-green-700",
  waitlisted: "bg-yellow-100 text-yellow-700",
  rejected: "bg-red-100 text-red-600",
};

export const statusLabel: Record<ApplicationTracker["status"], string> = {
  planning: "规划中",
  preparing: "准备材料",
  submitted: "已提交",
  interview: "面试中",
  admitted: "已录取",
  rejected: "已拒绝",
  waitlisted: "等候名单",
};

export const statusColor: Record<ApplicationTracker["status"], string> = {
  planning: "bg-gray-100 text-gray-600",
  preparing: "bg-blue-100 text-blue-700",
  submitted: "bg-purple-100 text-purple-700",
  interview: "bg-amber-100 text-amber-700",
  admitted: "bg-green-100 text-green-700",
  rejected: "bg-red-100 text-red-600",
  waitlisted: "bg-yellow-100 text-yellow-700",
};

export const tierLabel: Record<ApplicationTracker["tier"], string> = {
  reach: "冲刺",
  match: "匹配",
  safety: "保底",
};

export const tierColor: Record<ApplicationTracker["tier"], string> = {
  reach: "text-red-500",
  match: "text-blue-500",
  safety: "text-green-500",
};
