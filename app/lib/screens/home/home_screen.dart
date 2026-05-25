import 'package:flutter/material.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';
import '../../services/backend_api_service.dart';
import '../../models/models.dart';
import '../community/community_post_detail_screen.dart';

/// 社区首页：首屏直接展示内容流，分类与身份作为轻量过滤工具。

const _greyscale = ColorFilter.matrix([
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

const _kFallbackBanner = HomeContent(
  id: 'fallback_banner',
  sectionType: 'hero_banner',
  title: '灵感碎片的万合\n青花新境',
  subtitle: 'SPECIAL / 陶瓷重构专场',
  imageUrl:
      'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&q=80&w=2000',
  linkText: '立即观展 (Virtual Access)',
  displayOrder: 0,
  isActive: true,
  createdAt: '',
  updatedAt: '',
);

const _kFallbackHotHalls = <HomeContent>[
  HomeContent(
    id: 'fallback_hot_1',
    sectionType: 'hot_hall',
    title: '解构青花：数字维度的传统重塑',
    imageUrl:
        'https://images.unsplash.com/photo-1626074311105-0255c4d3609c?auto=format&fit=crop&q=80&w=800',
    badge: 'LIVE NOW',
    displayOrder: 0,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_hot_2',
    sectionType: 'hot_hall',
    title: '媒介考古：模拟时代的感官记忆',
    imageUrl:
        'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?auto=format&fit=crop&q=80&w=800',
    badge: 'LIVE NOW',
    displayOrder: 1,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_hot_3',
    sectionType: 'hot_hall',
    title: '光影变迁：叙事性空间的数字边界',
    imageUrl:
        'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&q=80&w=800',
    badge: 'LIVE NOW',
    displayOrder: 2,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_hot_4',
    sectionType: 'hot_hall',
    title: '赛博禅意：机械冥想与算法秩序',
    imageUrl:
        'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80&w=800',
    badge: 'LIVE NOW',
    displayOrder: 3,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_hot_5',
    sectionType: 'hot_hall',
    title: '极简空间：光影与白墙的对话',
    imageUrl:
        'https://images.unsplash.com/photo-1554188248-986adbb73be4?auto=format&fit=crop&q=80&w=800',
    badge: 'LIVE NOW',
    displayOrder: 4,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
];

const _kFallbackRecentExhibitions = <HomeContent>[
  HomeContent(
    id: 'fallback_recent_1',
    sectionType: 'recent_exhibition',
    title: '威尼斯双年展中国馆主题发布',
    imageUrl:
        'https://images.unsplash.com/photo-1494438639946-1ebd1d20bf85?auto=format&fit=crop&q=80&w=1200',
    displayOrder: 0,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_recent_2',
    sectionType: 'recent_exhibition',
    title: '西岸美术馆：丝绸与光影',
    imageUrl:
        'https://images.unsplash.com/photo-1554188248-986adbb73be4?auto=format&fit=crop&q=80&w=800',
    displayOrder: 1,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
  HomeContent(
    id: 'fallback_recent_3',
    sectionType: 'recent_exhibition',
    title: '当代摄影：城市褶皱',
    imageUrl:
        'https://images.unsplash.com/photo-1541701494587-cb58502866ab?auto=format&fit=crop&q=80&w=800',
    displayOrder: 2,
    isActive: true,
    createdAt: '',
    updatedAt: '',
  ),
];

const _kFallbackCommunityPosts = <AppCommunityPost>[
  AppCommunityPost(
    id: 'fallback_community_1',
    title: 'RCA 作品集面试前一周，我把项目顺序全部重排了',
    body: '分享一下从 research 到 final outcome 的叙事调整，尤其是 critique 后怎么删掉不必要的项目。',
    imageUrls: [],
    likeCount: 312,
    commentCount: 89,
    viewCount: 4200,
    createdAt: '2026-05-23T11:20:00Z',
    authorNickname: 'Mia',
  ),
  AppCommunityPost(
    id: 'fallback_community_2',
    title: 'RISD 今年截止日期更新，早申材料最好提前两周准备',
    body: '整理了院校页面和邮件里的重点，包括语言成绩、推荐信和 portfolio upload 的细节。',
    imageUrls: [],
    likeCount: 48,
    commentCount: 12,
    viewCount: 980,
    createdAt: '2026-05-22T16:00:00Z',
    authorNickname: 'Artlink Advisor',
  ),
  AppCommunityPost(
    id: 'fallback_community_3',
    title: 'GPA 3.2 逆袭伦艺，我的文书到底改了什么',
    body: '不是堆经历，而是把作品、背景和申请动机放在同一个逻辑里说清楚。',
    imageUrls: [],
    likeCount: 176,
    commentCount: 34,
    viewCount: 2100,
    createdAt: '2026-05-21T08:30:00Z',
    authorNickname: 'Leo',
  ),
  AppCommunityPost(
    id: 'fallback_community_4',
    title: '作品集排版避坑：不要让版式抢走项目本身',
    body: '最近帮同学看了 20 多份 portfolio，最常见的问题是信息密度、留白和图文层级失衡。',
    imageUrls: [],
    likeCount: 224,
    commentCount: 57,
    viewCount: 3300,
    createdAt: '2026-05-20T13:45:00Z',
    authorNickname: 'Studio Y',
  ),
];

const _studentCommunityCategories = <_CommunityCategory>[
  _CommunityCategory(label: '全部', keywords: []),
  _CommunityCategory(label: '申请经验', keywords: ['申请', '文书', '面试', 'GPA']),
  _CommunityCategory(label: '录取案例', keywords: ['录取', 'offer', '逆袭']),
  _CommunityCategory(
      label: '院校资讯', keywords: ['院校', '截止', 'RISD', 'RCA', '伦艺']),
  _CommunityCategory(label: '作品集准备', keywords: ['作品集', 'portfolio', '排版']),
  _CommunityCategory(label: '问答求建议', keywords: ['建议', '求问', '怎么']),
];

class HomeScreen extends StatefulWidget {
  final CommunityRole? role;
  final bool? searchActive;

  const HomeScreen({
    super.key,
    this.role,
    this.searchActive,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Keeps old hot-reload timer closures from a previous implementation harmless.
  final PageController _carouselCtrl = PageController();
  final TextEditingController _searchController = TextEditingController();
  int? _artistCarouselPage;
  HomeContent? _artistHeroBanner;
  List<HomeContent>? _artistHotHalls;
  List<HomeContent>? _artistRecentExhibitions;
  String _selectedCommunityCategory = '全部';
  String _searchQuery = '';
  List<AppCommunityPost> _communityPosts = _kFallbackCommunityPosts;
  bool _communityLoading = true;
  String? _communityError;

  CommunityRole get _role => widget.role ?? CommunityRole.student;
  bool get _searchActive => widget.searchActive ?? false;

  @override
  void initState() {
    super.initState();
    _loadCommunityPosts();
    _loadArtistHomeData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousRole = oldWidget.role ?? CommunityRole.student;
    if (previousRole != _role) {
      setState(() => _selectedCommunityCategory = '全部');
    }
    final previousSearchActive = oldWidget.searchActive ?? false;
    if (previousSearchActive && !_searchActive) {
      _searchController.clear();
      setState(() => _searchQuery = '');
    }
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityPosts({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _communityLoading = true;
        _communityError = null;
      });
    }
    try {
      final posts = await BackendApiService.fetchCommunityPosts(limit: 40);
      if (!mounted) return;
      setState(() {
        _communityPosts = posts.isNotEmpty ? posts : _kFallbackCommunityPosts;
        _communityLoading = false;
        _communityError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _communityPosts = _kFallbackCommunityPosts;
        _communityLoading = false;
        _communityError = e.toString();
      });
    }
  }

  Future<void> _loadArtistHomeData() async {
    try {
      final contents = await BackendApiService.fetchHomeContents();
      if (!mounted) return;
      final banners = contents
          .where((c) => c.sectionType == 'hero_banner' && c.isActive)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      final halls = contents
          .where((c) => c.sectionType == 'hot_hall' && c.isActive)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      final recents = contents
          .where((c) => c.sectionType == 'recent_exhibition' && c.isActive)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      setState(() {
        if (banners.isNotEmpty) _artistHeroBanner = banners.first;
        if (halls.isNotEmpty) _artistHotHalls = halls;
        if (recents.isNotEmpty) _artistRecentExhibitions = recents;
      });
    } catch (e) {
      debugPrint('HomeScreen _loadArtistHomeData error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = mainTabBottomInset(context);
    if (_role == CommunityRole.artist) {
      return _buildArtistHome(bottom);
    }
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_communityError != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => _loadCommunityPosts(),
                    icon: const Icon(Icons.refresh_rounded),
                    color: context.artC.ink,
                    tooltip: '刷新',
                  ),
                ),
              ] else
                const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _searchActive
                    ? Padding(
                        key: const ValueKey('community-search-open'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CommunitySearchBar(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchQuery = value.trim());
                          },
                          onClear: () {
                            if (_searchController.text.isEmpty) return;
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('community-search-closed'),
                      ),
              ),
              _buildCommunityCategoryBar(),
              const SizedBox(height: 16),
              _buildCommunityFeed(),
              SizedBox(height: bottom),
            ],
          ),
        ),
      ),
    );
  }

  HomeContent get _artistBanner => _artistHeroBanner ?? _kFallbackBanner;

  List<HomeContent> get _artistHalls => _artistHotHalls ?? _kFallbackHotHalls;

  List<HomeContent> get _artistRecents =>
      _artistRecentExhibitions ?? _kFallbackRecentExhibitions;

  List<_CommunityCategory> get _communityCategories =>
      _studentCommunityCategories;

  List<AppCommunityPost> get _visibleCommunityPosts {
    final category = _communityCategories.firstWhere(
      (item) => item.label == _selectedCommunityCategory,
      orElse: () => _communityCategories.first,
    );
    final sourcePosts = _communityPosts;
    final categorized = category.keywords.isEmpty
        ? sourcePosts
        : sourcePosts.where((post) {
            final text = [
              post.title,
              post.body ?? '',
            ].join(' ').toLowerCase();
            return category.keywords.any(
              (keyword) => text.contains(keyword.toLowerCase()),
            );
          }).toList();
    if (_searchQuery.isEmpty) return categorized;
    final query = _searchQuery.toLowerCase();
    return categorized.where((post) {
      final text = [
        post.title,
        post.body ?? '',
        post.authorNickname ?? '',
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Widget _buildCommunityCategoryBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _communityCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _communityCategories[index];
          final selected = category.label == _selectedCommunityCategory;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCommunityCategory = category.label;
            }),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? kCobalt : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? kCobalt
                      : context.artC.silver.withValues(alpha: 0.42),
                ),
              ),
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : context.artC.ink.withValues(alpha: 0.56),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityFeed() {
    final posts = _visibleCommunityPosts;
    if (_communityLoading && _communityPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.4),
        ),
      );
    }

    if (posts.isEmpty) {
      return _CommunityEmptyState(onReset: () {
        setState(() => _selectedCommunityCategory = '全部');
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedCommunityCategory == '全部'
                  ? '热门讨论'
                  : _selectedCommunityCategory,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.artC.ink,
              ),
            ),
            const SizedBox(width: 8),
            if (_communityLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...posts.map((post) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CommunityFeedCard(
              post: post,
              category: _categoryLabelForPost(post),
            ),
          );
        }),
      ],
    );
  }

  String _categoryLabelForPost(AppCommunityPost post) {
    final text = [
      post.title,
      post.body ?? '',
    ].join(' ').toLowerCase();
    for (final category in _communityCategories.skip(1)) {
      if (category.keywords.any(
        (keyword) => text.contains(keyword.toLowerCase()),
      )) {
        return category.label;
      }
    }
    return _role == CommunityRole.student ? '讨论' : '动态';
  }

  Widget _buildArtistHome(double bottom) {
    final halls = _artistHalls;
    final page = _artistCarouselPage ?? 0;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              _buildHotHallHeader(),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _carouselCtrl,
                  onPageChanged: (i) => setState(() {
                    _artistCarouselPage = i;
                  }),
                  itemCount: halls.length,
                  padEnds: false,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _HotHallCard(item: halls[i]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(halls.length, (i) {
                  final on = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: on ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: on
                          ? kCobalt
                          : context.artC.silver.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 44),
              _buildHeroBanner(),
              const SizedBox(height: 12),
              _buildRecentSection(),
              SizedBox(height: bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final banner = _artistBanner;
    final imageUrl = banner.imageUrl ??
        'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&q=80&w=2000';
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusLarge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/home_banner.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.artC.silver.withValues(alpha: 0.35),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.artC.ink.withValues(alpha: 0),
                    context.artC.ink.withValues(alpha: 0.25),
                    context.artC.ink.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (banner.subtitle != null && banner.subtitle!.isNotEmpty)
                    Text(
                      banner.subtitle!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kCobalt.withValues(alpha: 0.95),
                        letterSpacing: 3.2,
                      ),
                    ),
                  if (banner.subtitle != null && banner.subtitle!.isNotEmpty)
                    const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      banner.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        height: 1.15,
                        color: Colors.white,
                        fontFamily: 'Noto Serif SC',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (banner.linkText != null && banner.linkText!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.artC.porcelain,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        banner.linkText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotHallHeader() {
    return Text(
      '热门展厅',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: context.artC.ink,
        fontFamily: 'Noto Serif SC',
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '近期展会',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.artC.ink,
            fontFamily: 'Noto Serif SC',
          ),
        ),
        const SizedBox(height: 20),
        ..._artistRecents.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _RecentExhibitionTile(item: item),
          ),
        ),
      ],
    );
  }
}

class _CommunitySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CommunitySearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 21,
            color: context.artC.ink.withValues(alpha: 0.34),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索社区内容、作者',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.32),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: context.artC.ink.withValues(alpha: 0.36),
            ),
            tooltip: '清空',
          ),
        ],
      ),
    );
  }
}

class _HotHallCard extends StatelessWidget {
  final HomeContent item;

  const _HotHallCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: _greyscale,
            child: Image.network(
              item.imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: context.artC.silver.withValues(alpha: 0.35),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  context.artC.ink.withValues(alpha: 0.82),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    fontFamily: 'Noto Serif SC',
                  ),
                ),
                const SizedBox(height: 8),
                if (item.badge != null && item.badge!.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: kCobalt,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentExhibitionTile extends StatelessWidget {
  final HomeContent item;

  const _RecentExhibitionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusMedium),
      child: SizedBox(
        height: 104,
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: ColorFiltered(
                colorFilter: _greyscale,
                child: Image.network(
                  item.imageUrl ?? '',
                  fit: BoxFit.cover,
                  height: 104,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.artC.silver.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: context.artC.ink,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedCard extends StatefulWidget {
  final AppCommunityPost post;
  final String category;

  const _CommunityFeedCard({
    required this.post,
    required this.category,
  });

  @override
  State<_CommunityFeedCard> createState() => _CommunityFeedCardState();
}

class _CommunityFeedCardState extends State<_CommunityFeedCard> {
  late bool _liked;
  late int _likeCount;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
  }

  Future<void> _toggleLike() async {
    if (_likeBusy || widget.post.id.startsWith('fallback_')) return;
    
    final previousLiked = _liked;
    final previousCount = _likeCount;
    
    setState(() {
      _liked = !_liked;
      _likeCount = _liked ? _likeCount + 1 : _likeCount - 1;
      _likeBusy = true;
    });
    
    try {
      final result = previousLiked
          ? await BackendApiService.unlikeCommunityPost(widget.post.id)
          : await BackendApiService.likeCommunityPost(widget.post.id);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
        _likeBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
        _likeBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e'), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = (widget.post.body ?? '').trim();
    final firstImage = widget.post.imageUrls.isNotEmpty ? widget.post.imageUrls.first : null;
    return GestureDetector(
      onTap: widget.post.id.startsWith('fallback_')
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityPostDetailScreen(
                    postId: widget.post.id,
                    initialPost: widget.post,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.artC.silver.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CommunityAvatarBubble(post: widget.post),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.post.authorNickname ?? 'Artsee 用户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink.withValues(alpha: 0.68),
                    ),
                  ),
                ),
                Text(
                  timeAgo(widget.post.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.category,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: kCobalt,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              widget.post.title.isNotEmpty ? widget.post.title : '社区动态',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.28,
                fontWeight: FontWeight.w900,
                color: context.artC.ink,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.48,
                  fontWeight: FontWeight.w500,
                  color: context.artC.ink.withValues(alpha: 0.52),
                ),
              ),
            ],
            if (firstImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.network(
                    firstImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.artC.silver.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: context.artC.ink.withValues(alpha: 0.36)),
                const SizedBox(width: 4),
                Text(
                  '${_formatCount(widget.post.commentCount)} 回复',
                  style: _communityMetaStyle(context),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _likeBusy ? null : _toggleLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _liked ? Icons.favorite : Icons.favorite_border_rounded,
                        size: 15,
                        color: _liked ? Colors.red : context.artC.ink.withValues(alpha: 0.36),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatCount(_likeCount)} 赞',
                        style: _communityMetaStyle(context).copyWith(
                          color: _liked ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: context.artC.ink.withValues(alpha: 0.18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityAvatarBubble extends StatelessWidget {
  final AppCommunityPost post;

  const _CommunityAvatarBubble({required this.post});

  @override
  Widget build(BuildContext context) {
    final avatar = post.authorAvatarUrl;
    final name = post.authorNickname ?? 'A';
    return ClipOval(
      child: Container(
        width: 34,
        height: 34,
        color: kCobalt.withValues(alpha: 0.08),
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _CommunityAvatarInitial(name),
              )
            : _CommunityAvatarInitial(name),
      ),
    );
  }
}

class _CommunityAvatarInitial extends StatelessWidget {
  final String name;

  const _CommunityAvatarInitial(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: kCobalt,
        ),
      ),
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  final VoidCallback onReset;

  const _CommunityEmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 42,
              color: context.artC.ink.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 12),
            Text(
              '这个分类暂时没有动态',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.artC.ink,
              ),
            ),
            const SizedBox(height: 14),
            CobaltButton(label: '查看全部', onTap: onReset),
          ],
        ),
      ),
    );
  }
}

class _CommunityCategory {
  final String label;
  final List<String> keywords;

  const _CommunityCategory({
    required this.label,
    required this.keywords,
  });
}

TextStyle _communityMetaStyle(BuildContext context) {
  return TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: context.artC.ink.withValues(alpha: 0.42),
  );
}

String _formatCount(int value) {
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceAll('.0', '')}万';
  }
  return '$value';
}

enum CommunityRole { student, artist }
