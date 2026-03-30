import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../cases/case_detail_screen.dart';
import '../forum/post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppCase> _cases = [];
  List<AppPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.fetchFeedCases(),
      SupabaseService.fetchFeedPosts(),
    ]);
    if (mounted) {
      setState(() {
        _cases = results[0] as List<AppCase>;
        _posts = results[1] as List<AppPost>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              title: const Text('艺见心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
              backgroundColor: Colors.white,
              floating: true,
              snap: true,
              actions: [
                IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.grey), onPressed: () {}),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(child: LoadingIndicator())
            else ...[
              // Hero banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimary, kPrimaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🎉 今日精选', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('2026秋季英国艺术留学\n申请季正式开启', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.4)),
                        const SizedBox(height: 4),
                        const Text('牛津 · 剑桥 · UCL · CSM 同步更新 →', style: TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),

              // School stories
              SliverToBoxAdapter(child: _SchoolStories()),

              // Feed title
              const SliverToBoxAdapter(
                child: SectionHeader(title: '发现 · 精选', action: '查看全部'),
              ),

              // Mixed feed
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final caseIdx = i ~/ 2;
                    final postIdx = i ~/ 2;
                    if (i.isEven && caseIdx < _cases.length) {
                      return _CaseFeedCard(c: _cases[caseIdx], onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: _cases[caseIdx].id)));
                      });
                    } else if (i.isOdd && postIdx < _posts.length) {
                      return _PostFeedCard(p: _posts[postIdx], onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: _posts[postIdx].id)));
                      });
                    }
                    return null;
                  },
                  childCount: (_cases.length + _posts.length),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolStories extends StatelessWidget {
  final List<Map<String, String>> schools = const [
    {'name': '牛津大学', 'initial': 'Ox'},
    {'name': '剑桥大学', 'initial': 'Cam'},
    {'name': '中央圣马丁', 'initial': 'CSM'},
    {'name': 'UCL', 'initial': 'UCL'},
    {'name': '皇家艺术学院', 'initial': 'RCA'},
    {'name': '爱丁堡大学', 'initial': 'Edin'},
  ];

  const _SchoolStories();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: schools.length,
        itemBuilder: (ctx, i) {
          final s = schools[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: schoolGradient(s['name']),
                    shape: BoxShape.circle,
                    border: Border.all(color: kPrimary.withOpacity(0.4), width: 2),
                  ),
                  child: Center(child: Text(s['initial']!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(height: 4),
                Text(s['name']!, style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaseFeedCard extends StatelessWidget {
  final AppCase c;
  final VoidCallback onTap;

  const _CaseFeedCard({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: schoolGradient(c.targetSchool),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Positioned(top: 10, left: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(99)),
                    child: const Text('案例', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  )),
                  if (c.targetSchool != null)
                    Positioned(bottom: 10, left: 10, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(c.targetSchool!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                    )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (c.excerpt != null)
                    Text(c.excerpt!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(radius: 10, backgroundColor: kPrimary,
                        child: Text(c.isAnonymous ? '匿' : (c.authorNickname?.substring(0, 1) ?? '?'),
                          style: const TextStyle(color: Colors.white, fontSize: 9))),
                      const SizedBox(width: 6),
                      Text(c.isAnonymous ? '匿名' : (c.authorNickname ?? '用户'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(width: 4),
                      Text('·', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 4),
                      Text(timeAgo(c.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const Spacer(),
                      Icon(Icons.favorite_border, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${c.likeCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${c.commentCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostFeedCard extends StatelessWidget {
  final AppPost p;
  final VoidCallback onTap;

  const _PostFeedCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColors = {
      'question': [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
      'discussion': [const Color(0xFFA855F7), const Color(0xFFEC4899)],
      'news': [const Color(0xFF10B981), const Color(0xFF14B8A6)],
    };
    final typeLabels = {'question': '问答', 'discussion': '讨论', 'news': '资讯'};
    final colors = typeColors[p.type] ?? typeColors['discussion']!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(4)),
                    child: Text(typeLabels[p.type] ?? '讨论', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.content != null)
                    Text(p.content!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(radius: 10, backgroundColor: Colors.grey.shade300,
                        child: Text(p.authorNickname?.substring(0, 1) ?? '?', style: const TextStyle(fontSize: 9, color: Colors.white))),
                      const SizedBox(width: 6),
                      Text(p.authorNickname ?? '用户', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const Spacer(),
                      Icon(Icons.favorite_border, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${p.likeCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(width: 8),
                      Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${p.answerCount}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
