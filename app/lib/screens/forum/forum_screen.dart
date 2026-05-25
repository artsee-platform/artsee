import 'package:flutter/material.dart';
import '../tools/ai_consult_screen.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// 学习页 — 完全对齐 _artist_ref LearnView
/// ═══════════════════════════════════════════════════════════════

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => ForumScreenState();
}

class ForumScreenState extends State<ForumScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void switchToToolsAndOpenAiConsult() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiConsultScreen()),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: kCobalt,
              indicatorWeight: 2,
              labelColor: kCobalt,
              unselectedLabelColor: context.artC.ink.withValues(alpha: 0.35),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              dividerColor: context.artC.silver.withValues(alpha: 0.5),
              tabs: const [
                Tab(text: '工具集'),
                Tab(text: '课程中心'),
                Tab(text: '院校与资讯'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ToolsTab(),
                  _CoursesTab(),
                  _SchoolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoursesTab extends StatelessWidget {
  const _CoursesTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '作品集辅导：RCA/UAL 申请全攻略',
        '留学辅导',
        'Premium',
        'https://picsum.photos/seed/course0/800/450'
      ),
      (
        '当代油画技法：从构图到色彩表达',
        '技法课',
        '¥1,200',
        'https://picsum.photos/seed/course1/800/450'
      ),
      (
        '艺术家职业商业课：定价、版权与合同',
        '职业发展',
        '¥800',
        'https://picsum.photos/seed/course2/800/450'
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusLarge),
              border:
                  Border.all(color: context.artC.silver.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(kRadiusLarge),
                      topRight: Radius.circular(kRadiusLarge),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item.$4,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: context.artC.ink.withValues(alpha: 0.15),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kCobalt.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kCobalt.withValues(alpha: 0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.artC.ink,
                          height: 1.3,
                          fontFamily: 'Noto Serif SC',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kCobalt,
                            ),
                          ),
                          Icon(Icons.arrow_forward,
                              size: 18,
                              color: context.artC.ink.withValues(alpha: 0.2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        'AI咨询',
        Icons.auto_awesome_outlined,
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiConsultScreen()),
            ),
      ),
      (
        '院校查询',
        Icons.school_outlined,
        () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('院校查询功能开发中')),
            ),
      ),
      (
        '专业查询',
        Icons.menu_book_outlined,
        () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('专业查询功能开发中')),
            ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.92,
        children: tools.map((tool) {
          return GestureDetector(
            onTap: tool.$3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.artC.ink.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(tool.$2, size: 26, color: kCobalt),
                ),
                const SizedBox(height: 12),
                Text(
                  tool.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SchoolsTab extends StatelessWidget {
  const _SchoolsTab();

  @override
  Widget build(BuildContext context) {
    final schools = [
      (
        'Royal College of Art',
        'London, UK',
        '#1 Art & Design',
        'https://picsum.photos/seed/rca/800/400'
      ),
      (
        'University of the Arts London',
        'London, UK',
        '#2 Art & Design',
        'https://picsum.photos/seed/ual/800/400'
      ),
    ];

    final news = [
      '2025年秋季入学申请截止日期汇总',
      '作品集准备：如何展现你的批判性思维',
      '艺术生就业前景报告：数字媒体与跨学科趋势',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...schools.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: AspectRatio(
                aspectRatio: 2 / 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kRadiusLarge),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        s.$4,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.artC.ink.withValues(alpha: 0.0),
                              context.artC.ink.withValues(alpha: 0.6),
                              context.artC.ink.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              s.$3,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kCobaltMuted,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.$1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Noto Serif SC',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusLarge),
              border:
                  Border.all(color: context.artC.silver.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全球艺术资讯',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.4),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                ...news.map((n) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.artC.ink.withValues(alpha: 0.75),
                              fontFamily: 'Noto Serif SC',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.north_east,
                            size: 18,
                            color: context.artC.ink.withValues(alpha: 0.2)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
