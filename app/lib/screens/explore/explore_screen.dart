import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import '../community/community_post_detail_screen.dart';
import '../programs/program_list_enhanced_screen.dart';
import '../schools/school_list_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// 发现页 — 完全对齐 _artist_ref DiscoverView
/// ═══════════════════════════════════════════════════════════════

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<CommunityFeedTabState> _communityKey =
      GlobalKey<CommunityFeedTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void showCommunityFeed({bool refresh = false}) {
    if (_tabController.index != 2) {
      _tabController.animateTo(2);
    }
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _communityKey.currentState?.refresh();
      });
    }
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
              isScrollable: false,
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
                Tab(text: '院校'),
                Tab(text: '专业'),
                Tab(text: '推荐'),
                Tab(text: '问答'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const SchoolListScreen(),
                  const ProgramListEnhancedScreen(),
                  CommunityFeedTab(key: _communityKey),
                  const _QaTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityFeedTab extends StatefulWidget {
  const CommunityFeedTab({super.key});

  @override
  State<CommunityFeedTab> createState() => CommunityFeedTabState();
}

class CommunityFeedTabState extends State<CommunityFeedTab> {
  List<AppCommunityPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final posts = await BackendApiService.fetchCommunityPosts(limit: 40);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _posts.isEmpty) {
      return const LoadingIndicator();
    }

    if (_error != null && _posts.isEmpty) {
      return _CommunityError(message: _error!, onRetry: () => refresh());
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        color: kCobalt,
        onRefresh: () => refresh(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 60, 20, mainTabBottomInset(context)),
          children: [
            Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 44,
              color: context.artC.ink.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 14),
            Text(
              '还没有社区内容',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.artC.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '点击右下角 + 发布第一篇作品、灵感或申请记录。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.artC.ink.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kCobalt,
      onRefresh: () => refresh(showLoading: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 3 : 2;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.fromLTRB(20, 20, 20, mainTabBottomInset(context)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              childAspectRatio: 0.58,
            ),
            itemCount: _posts.length,
            itemBuilder: (context, i) => _CommunityPostCard(post: _posts[i]),
          );
        },
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  final AppCommunityPost post;

  const _CommunityPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final firstImage = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    final subtitle = (post.body ?? '').trim();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPostDetailScreen(
              postId: post.id,
              initialPost: post,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusMedium),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstImage != null)
                    Image.network(
                      firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _CommunityImageFallback(post: post),
                    )
                  else
                    _CommunityImageFallback(post: post),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.artC.porcelain.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(kRadiusSmall),
                      ),
                      child: Row(
                        children: [
                          _CommunityAvatar(post: post, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post.authorNickname ?? 'Artsee 用户',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.artC.ink.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.title.isNotEmpty ? post.title : '作品分享',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: context.artC.ink,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: context.artC.ink.withValues(alpha: 0.4),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.favorite_border,
                  size: 13, color: context.artC.ink.withValues(alpha: 0.35)),
              const SizedBox(width: 3),
              Text(
                _shortCount(post.likeCount),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.42),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chat_bubble_outline,
                  size: 13, color: context.artC.ink.withValues(alpha: 0.35)),
              const SizedBox(width: 3),
              Text(
                _shortCount(post.commentCount),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.42),
                ),
              ),
              const Spacer(),
              Text(
                timeAgo(post.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: context.artC.ink.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityImageFallback extends StatelessWidget {
  final AppCommunityPost post;

  const _CommunityImageFallback({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.artC.silver.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      child: Text(
        post.title.isNotEmpty ? post.title : '作品分享',
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: kCobalt.withValues(alpha: 0.82),
          fontFamily: 'Noto Serif SC',
        ),
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  final AppCommunityPost post;
  final double size;

  const _CommunityAvatar({required this.post, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatar = post.authorAvatarUrl;
    final name = post.authorNickname ?? 'A';
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: kCobalt.withValues(alpha: 0.09),
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarInitial(name: name),
              )
            : _AvatarInitial(name: name),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String name;

  const _AvatarInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: kCobalt,
        ),
      ),
    );
  }
}

class _CommunityError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CommunityError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: context.artC.ink.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.artC.ink.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 16),
            CobaltButton(label: '重试', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

String _shortCount(int value) {
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceAll('.0', '')}万';
  }
  return '$value';
}

class _QaTab extends StatelessWidget {
  const _QaTab();

  @override
  Widget build(BuildContext context) {
    final questions = [
      ('艺术留学怎么选校？有哪些避坑指南？', '128 位艺术家已参与讨论', '留学申请'),
      ('如何跟顶奢酒店达成长期艺术合作？', '86 位策展人已参与讨论', '市场与商业'),
      ('一二级市场规则是什么？艺术家如何定价？', '210 位专业人士已参与讨论', '职业发展'),
    ];

    final categories = [
      '留学申请',
      '专业学习',
      '职业发展',
      '市场与商业',
      '版权与法律',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 问题列表
          ...questions.map((q) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(kRadiusMedium),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      q.$3,
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
                    q.$1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink,
                      height: 1.35,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.artC.ink.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          // 分类卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.artC.ink,
              borderRadius: BorderRadius.circular(kRadiusLarge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '问答分类',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...categories.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 提问按钮
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: kCobalt,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: kCobalt.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '我要提问',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
