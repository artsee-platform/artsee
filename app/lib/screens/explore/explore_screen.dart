import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../community/community_post_detail_screen.dart';
import '../events/event_feed_widgets.dart';
import '../events/my_events_screen.dart';
import '../forum/ask_question_screen.dart';
import '../forum/forum_screen.dart';
import '../profile/public_user_profile_screen.dart';
import '../publish/publish_artist_screen.dart';
import 'discover_search_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onTabChanged;
  final VoidCallback? onCreateTap;

  const ExploreScreen({
    super.key,
    this.onTabChanged,
    this.onCreateTap,
  });

  @override
  State<ExploreScreen> createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  static const int _tabCount = 4;
  late TabController _tabController;
  final GlobalKey<_CooperationTabState> _cooperationKey =
      GlobalKey<_CooperationTabState>();
  final GlobalKey<_ExhibitionTabState> _exhibitionKey =
      GlobalKey<_ExhibitionTabState>();
  final GlobalKey<_CommunityFeedTabState> _feedKey =
      GlobalKey<_CommunityFeedTabState>();
  final GlobalKey<MarketplaceSurfaceState> _marketKey =
      GlobalKey<MarketplaceSurfaceState>();
  List<String> _searchKeywords = List.filled(
    _tabCount,
    '',
    growable: true,
  );
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _createTabController();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  int _clampTabIndex(int index) {
    if (index < 0) return 0;
    if (index >= _tabCount) return _tabCount - 1;
    return index;
  }

  void _createTabController({int initialIndex = 0}) {
    _activeTabIndex = _clampTabIndex(initialIndex);
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: _activeTabIndex,
    );
    _tabController.addListener(_handleTabChanged);
  }

  void _ensureTabController() {
    if (_tabController.length == _tabCount) return;
    final currentIndex = _clampTabIndex(_activeTabIndex);
    final oldController = _tabController;
    oldController.removeListener(_handleTabChanged);
    _createTabController(initialIndex: currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
  }

  void _ensureSearchKeywords() {
    if (_searchKeywords.length == _tabCount) return;
    final next = List<String>.filled(_tabCount, '', growable: true);
    for (var index = 0;
        index < next.length && index < _searchKeywords.length;
        index++) {
      next[index] = _searchKeywords[index];
    }
    _searchKeywords = next;
  }

  int get _safeTabIndex {
    return _clampTabIndex(_activeTabIndex);
  }

  String _searchKeywordAt(int index) {
    _ensureSearchKeywords();
    if (index < 0 || index >= _searchKeywords.length) return '';
    return _searchKeywords[index];
  }

  void _handleTabChanged() {
    final nextIndex = _clampTabIndex(_tabController.index);
    if (_activeTabIndex != nextIndex) {
      setState(() => _activeTabIndex = nextIndex);
      widget.onTabChanged?.call();
      return;
    }
    if (!_tabController.indexIsChanging) {
      widget.onTabChanged?.call();
      setState(() {});
    }
  }

  int get activeTabIndex => _safeTabIndex;

  bool get isDynamicTabActive => _safeTabIndex == 2;

  void _selectTab(int index) {
    final nextIndex = _clampTabIndex(index);
    if (_activeTabIndex != nextIndex) {
      setState(() => _activeTabIndex = nextIndex);
      widget.onTabChanged?.call();
    }
    if (_tabController.index != nextIndex) {
      _tabController.animateTo(nextIndex);
    }
  }

  String get searchKeyword => _searchKeywordAt(_safeTabIndex);

  String get searchHint => switch (_safeTabIndex) {
        0 => '搜索合作机会、艺术家、驻留、城市',
        1 => '搜索活动、展览、沙龙、讲座、城市',
        2 => '搜索作品、动态、作者、标签',
        3 => '搜索艺术品、工艺品、出版、定制',
        _ => '搜索发现资源',
      };

  String get _createTooltip => switch (_safeTabIndex) {
        0 => '发布合作',
        1 => '发布活动',
        2 => '发布动态',
        3 => '发布市集商品',
        _ => '发布',
      };

  Future<void> openQuestionComposer({
    String? initialTitle,
    String? initialCategory,
  }) {
    return _openQuestionComposer(
      initialTitle: initialTitle,
      initialCategory: initialCategory,
    );
  }

  void applySearch(String keyword) {
    setState(() => _searchKeywords[_safeTabIndex] = keyword.trim());
  }

  Future<void> _openQuestionComposer({
    String? initialTitle,
    String? initialCategory,
  }) async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后发布问题');
    if (!mounted || !loggedIn) return;
    final navigator = Navigator.of(context);
    final createdTitle = await navigator.push<String?>(
      MaterialPageRoute(
        builder: (_) => AskQuestionScreen(
          initialTitle: initialTitle,
          initialCategory: initialCategory,
          searchKeyword: searchKeyword,
        ),
      ),
    );
    if (!mounted || createdTitle == null) return;
    _marketKey.currentState?.refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问题已发布，会推荐给相关方向用户')),
    );
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => DiscoverSearchScreen(
          initialKeyword: searchKeyword,
          initialTabIndex: _safeTabIndex,
        ),
      ),
    );
    if (!mounted || result == null) return;
    applySearch(result);
  }

  Future<void> _openArtCalendar() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭艺术日历',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ArtCalendarDrawer(
          onDismiss: () => Navigator.of(dialogContext).pop(),
          onOpenActivities: () => _closeCalendarAndRun(
            dialogContext,
            () => _switchToActivityTab(),
          ),
          onOpenEvent: (event) => _closeCalendarAndRun(
            dialogContext,
            () => _focusActivity(event),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _closeCalendarAndRun(BuildContext dialogContext, VoidCallback action) {
    Navigator.of(dialogContext).pop();
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      action();
    });
  }

  void _switchToActivityTab() {
    _tabController.animateTo(1);
    widget.onTabChanged?.call();
    setState(() {});
  }

  void _focusActivity(Map<String, dynamic> event) {
    final title = event['title']?.toString().trim() ?? '';
    _tabController.animateTo(1);
    if (title.isNotEmpty) {
      setState(() => _searchKeywords[1] = title);
    } else {
      setState(() {});
    }
    widget.onTabChanged?.call();
  }

  void refreshActiveTab() {
    switch (_safeTabIndex) {
      case 0:
        _cooperationKey.currentState?._load();
        break;
      case 1:
        _exhibitionKey.currentState?._load();
        break;
      case 2:
        _feedKey.currentState?._load();
        break;
      case 3:
        _marketKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureTabController();
    _ensureSearchKeywords();
    final bottom = mainTabBottomInset(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExploreChannelHeader(
                controller: _tabController,
                selectedIndex: _safeTabIndex,
                onTabSelected: _selectTab,
                onCalendarTap: _openArtCalendar,
                onSearchTap: _openSearchScreen,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CooperationTab(
                      key: _cooperationKey,
                      bottom: bottom,
                      searchKeyword: _searchKeywordAt(0),
                    ),
                    _ExhibitionTab(
                      key: _exhibitionKey,
                      bottom: bottom,
                      searchKeyword: _searchKeywordAt(1),
                    ),
                    _CommunityFeedTab(
                      key: _feedKey,
                      bottom: bottom,
                      searchKeyword: _searchKeywordAt(2),
                    ),
                    MarketplaceSurface(
                      key: _marketKey,
                      bottom: bottom,
                      searchKeyword: _searchKeywordAt(3),
                      onCreateTap: widget.onCreateTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.onCreateTap != null && _safeTabIndex != 2)
            Positioned(
              right: 20,
              bottom: bottom + 10,
              child: _ExploreCreateFab(
                tooltip: _createTooltip,
                onTap: widget.onCreateTap!,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExploreCreateFab extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _ExploreCreateFab({
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ExploreCreateFab> createState() => _ExploreCreateFabState();
}

class _ExploreCreateFabState extends State<_ExploreCreateFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kCobalt,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kCobalt.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CooperationTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _CooperationTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_CooperationTab> createState() => _CooperationTabState();
}

class _CooperationTabState extends State<_CooperationTab> {
  final GlobalKey<_CooperationRecommendTabState> _feedKey =
      GlobalKey<_CooperationRecommendTabState>();

  void _load() {
    _feedKey.currentState?._load();
  }

  @override
  Widget build(BuildContext context) {
    return _CooperationRecommendTab(
      key: _feedKey,
      bottom: widget.bottom,
      searchKeyword: widget.searchKeyword,
    );
  }
}

class _CooperationRecommendTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _CooperationRecommendTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_CooperationRecommendTab> createState() =>
      _CooperationRecommendTabState();
}

class _CooperationRecommendTabState extends State<_CooperationRecommendTab> {
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _artists = const [];
  final Set<String> _appliedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opportunitiesFuture =
          BackendApiService.fetchOpportunities(limit: 12);
      final artistsFuture = BackendApiService.fetchArtists(limit: 12);
      final opportunitiesResult = await opportunitiesFuture;
      final artistsResult = await artistsFuture;
      if (!mounted) return;
      setState(() {
        _opportunities = opportunitiesResult.data;
        _artists = artistsResult.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _applyOpportunity(Map<String, dynamic> item) async {
    if (!await ensureLoggedIn(context, message: '请先登录后申请合作机会')) {
      return false;
    }
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return false;
    if (_appliedIds.contains(id)) return true;
    try {
      await BackendApiService.applyOpportunity(
        opportunityId: id,
        proposal: '我想申请这个推荐机会，请联系我补充作品集、背景和合作方案。',
      );
      if (!mounted) return false;
      setState(() => _appliedIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请已提交，可在机会进度里继续追踪')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('申请失败：$e')),
      );
      return false;
    }
  }

  void _openOpportunityDetail(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
          item: item,
          applied: _appliedIds.contains(id),
          onApply: () => _applyOpportunity(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingState(bottom: widget.bottom);
    if (_error != null) {
      return _ResourceState(
        bottom: widget.bottom,
        title: '推荐加载失败',
        subtitle: _error!,
        onRetry: _load,
      );
    }

    final opportunityItems = _filterMaps(_opportunities, widget.searchKeyword);
    final artistSource = _withCooperationMockArtists(_artists);
    final certifiedArtistItems = _filterMaps(
      artistSource.where(_isCertifiedArtist).toList(),
      widget.searchKeyword,
    );
    final allArtistItems = _filterMaps(artistSource, widget.searchKeyword);
    final artistItems =
        certifiedArtistItems.isNotEmpty ? certifiedArtistItems : allArtistItems;
    final feedItems = _buildCooperationFeedItems(
      opportunities: opportunityItems,
      artists: artistItems,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(18, 6, 18, widget.bottom + 38),
      children: [
        if (feedItems.isEmpty)
          _EmptyPanel(
            title: widget.searchKeyword.trim().isEmpty ? '暂无推荐合作' : '没有匹配推荐',
            subtitle: widget.searchKeyword.trim().isEmpty
                ? '机会和艺术家审核通过后会显示在这里。'
                : '换一个城市、方向或合作关键词试试。',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: feedItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 152,
            ),
            itemBuilder: (context, index) {
              final feedItem = feedItems[index];
              return switch (feedItem.kind) {
                _CooperationFeedKind.opportunity => _CompactOpportunityCard(
                    item: feedItem.item,
                    onOpen: () => _openOpportunityDetail(feedItem.item),
                  ),
                _CooperationFeedKind.artist => _CompactArtistCard(
                    artist: feedItem.item,
                  ),
              };
            },
          ),
      ],
    );
  }
}

enum _CooperationFeedKind { opportunity, artist }

class _CooperationFeedItem {
  final _CooperationFeedKind kind;
  final Map<String, dynamic> item;

  const _CooperationFeedItem({
    required this.kind,
    required this.item,
  });
}

List<_CooperationFeedItem> _buildCooperationFeedItems({
  required List<Map<String, dynamic>> opportunities,
  required List<Map<String, dynamic>> artists,
}) {
  final items = <_CooperationFeedItem>[];
  var opportunityIndex = 0;
  var artistIndex = 0;
  final startWithOpportunities = opportunities.length >= artists.length;

  void addOpportunities(int count) {
    for (var i = 0;
        i < count && opportunityIndex < opportunities.length;
        i += 1) {
      items.add(
        _CooperationFeedItem(
          kind: _CooperationFeedKind.opportunity,
          item: opportunities[opportunityIndex],
        ),
      );
      opportunityIndex += 1;
    }
  }

  void addArtists(int count) {
    for (var i = 0; i < count && artistIndex < artists.length; i += 1) {
      items.add(
        _CooperationFeedItem(
          kind: _CooperationFeedKind.artist,
          item: artists[artistIndex],
        ),
      );
      artistIndex += 1;
    }
  }

  while (
      opportunityIndex < opportunities.length || artistIndex < artists.length) {
    if (startWithOpportunities) {
      addOpportunities(2);
      addArtists(2);
    } else {
      addArtists(2);
      addOpportunities(2);
    }
  }
  return items;
}

List<Map<String, dynamic>> _withCooperationMockArtists(
  List<Map<String, dynamic>> artists,
) {
  if (artists.length >= 6) return artists;

  final seen = artists
      .map((item) =>
          item['id']?.toString() ??
          item['user_id']?.toString() ??
          item['handle']?.toString() ??
          item['display_name']?.toString() ??
          '')
      .where((item) => item.isNotEmpty)
      .toSet();
  final merged = <Map<String, dynamic>>[...artists];

  for (final mock in _cooperationMockArtists) {
    final key = mock['id']?.toString() ?? '';
    if (!seen.add(key)) continue;
    merged.add(mock);
    if (merged.length >= 6) break;
  }
  return merged;
}

const List<Map<String, dynamic>> _cooperationMockArtists = [
  {
    'id': 'mock-artist-lin-ye',
    'user_id': '',
    'display_name': '林也',
    'handle': 'linye.studio',
    'avatar_url':
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80',
    'city': '上海',
    'status': 'published',
    'verification_status': 'verified',
    'verification_badges': ['平台认证', '展览认证'],
    'art_fields': ['装置', '新媒体'],
    'cooperation_status': 'available',
    'cooperation_intent': '寻找空间共创、展览委托和声音装置项目合作。',
    'portfolio_count': 18,
    'exhibition_count': 6,
    'bio': '关注城市声音、材料记忆与空间叙事的艺术家。',
    'metadata': {
      'cooperation_types': ['exhibition', 'public_art'],
    },
  },
  {
    'id': 'mock-artist-chen-mo',
    'user_id': '',
    'display_name': '陈墨',
    'handle': 'chenmo.photo',
    'avatar_url':
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=240&q=80',
    'city': '伦敦',
    'status': 'published',
    'verification_status': 'approved',
    'verification_badges': ['教育背景认证'],
    'art_fields': ['摄影', '影像'],
    'cooperation_status': 'available',
    'cooperation_intent': '开放艺术家访谈、出版拍摄和留学作品集项目合作。',
    'portfolio_count': 24,
    'exhibition_count': 4,
    'bio': '摄影与影像创作者，长期拍摄迁徙、身份和青年文化。',
    'metadata': {
      'cooperation_types': ['workshop', 'brand'],
    },
  },
  {
    'id': 'mock-artist-yu-nan',
    'user_id': '',
    'display_name': '余南',
    'handle': 'yunan.painting',
    'avatar_url':
        'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=crop&w=240&q=80',
    'city': '北京',
    'status': 'published',
    'verification_status': 'verified',
    'verification_badges': ['职业认证'],
    'art_fields': ['绘画', '插画'],
    'cooperation_status': 'busy',
    'cooperation_intent': '近期接受小型联名、艺术书和插画委托排期。',
    'portfolio_count': 31,
    'exhibition_count': 8,
    'bio': '绘画与插画艺术家，作品围绕梦境、身体和日常物件展开。',
    'metadata': {
      'cooperation_types': ['brand', 'exhibition'],
    },
  },
  {
    'id': 'mock-artist-maya',
    'user_id': '',
    'display_name': 'Maya Zhou',
    'handle': 'maya.zhou',
    'avatar_url':
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=240&q=80',
    'city': '纽约',
    'status': 'published',
    'verification_status': 'verified',
    'verification_badges': ['平台认证'],
    'art_fields': ['策展', '公共艺术'],
    'cooperation_status': 'available',
    'cooperation_intent': '可参与青年艺术家群展策划、驻留项目评审和工作坊。',
    'portfolio_count': 12,
    'exhibition_count': 11,
    'bio': '独立策展人，关注公共空间、社群协作和艺术教育。',
    'metadata': {
      'cooperation_types': ['public_art', 'workshop'],
    },
  },
  {
    'id': 'mock-artist-he-shu',
    'user_id': '',
    'display_name': '何述',
    'handle': 'heshu.design',
    'avatar_url':
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=240&q=80',
    'city': '广州',
    'status': 'published',
    'verification_status': 'approved',
    'verification_badges': ['职业认证'],
    'art_fields': ['视觉设计', '品牌'],
    'cooperation_status': 'available',
    'cooperation_intent': '接收品牌视觉、展览视觉系统和艺术衍生品合作。',
    'portfolio_count': 27,
    'exhibition_count': 3,
    'bio': '视觉设计师，服务艺术机构、独立出版和文化品牌。',
    'metadata': {
      'cooperation_types': ['brand'],
    },
  },
  {
    'id': 'mock-artist-noah',
    'user_id': '',
    'display_name': 'Noah Kim',
    'handle': 'noah.kim.media',
    'avatar_url':
        'https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=240&q=80',
    'city': '首尔',
    'status': 'published',
    'verification_status': 'verified',
    'verification_badges': ['展览认证'],
    'art_fields': ['互动媒体', 'AI 艺术'],
    'cooperation_status': 'available',
    'cooperation_intent': '寻找互动影像、AI 展演和跨校创作小组合作。',
    'portfolio_count': 15,
    'exhibition_count': 5,
    'bio': '互动媒体艺术家，使用机器学习、影像和实时声音创作。',
    'metadata': {
      'cooperation_types': ['exhibition', 'workshop'],
    },
  },
];

class _OpportunityTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _OpportunityTab({
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_OpportunityTab> createState() => _OpportunityTabState();
}

class _OpportunityTabState extends State<_OpportunityTab> {
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _appliedIds = {};
  String _quickFilter = '全部';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchOpportunities(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = result.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _apply(Map<String, dynamic> item) async {
    if (!await ensureLoggedIn(context, message: '请先登录后申请合作机会')) {
      return false;
    }
    final id = item['id'].toString();
    if (_appliedIds.contains(id)) return true;
    final submitted = await _showOpportunityApplySheet(item);
    if (!mounted || submitted != true) return false;
    setState(() => _appliedIds.add(id));
    return true;
  }

  Future<bool?> _showOpportunityApplySheet(Map<String, dynamic> item) async {
    final proposalCtrl = TextEditingController();
    final portfolioCtrl = TextEditingController();
    final experienceCtrl = TextEditingController();
    var submitting = false;
    var proposalError = '';
    final title = item['title']?.toString() ?? '未命名机会';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            final proposal = proposalCtrl.text.trim();
            setSheetState(() {
              proposalError = proposal.length < 10 ? '申请说明至少写 10 个字' : '';
            });
            if (proposalError.isNotEmpty || submitting) return;
            setSheetState(() => submitting = true);
            try {
              await BackendApiService.applyOpportunity(
                opportunityId: item['id'].toString(),
                proposal: [
                  proposal,
                  if (portfolioCtrl.text.trim().isNotEmpty)
                    '作品集链接：${portfolioCtrl.text.trim()}',
                  if (experienceCtrl.text.trim().isNotEmpty)
                    '相关经验：${experienceCtrl.text.trim()}',
                ].join('\n\n'),
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(true);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('申请已提交，可在机会进度里继续追踪')),
              );
            } catch (e) {
              if (!sheetContext.mounted) return;
              setSheetState(() => submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('申请失败：$e')),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(30),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.artC.silver.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '申请这个机会',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Noto Serif SC',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withOpacity(0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ApplyTextField(
                      controller: proposalCtrl,
                      label: '申请说明',
                      hint: '说明你为什么适合这个项目、能提交什么作品或方案。',
                      maxLines: 4,
                      error: proposalError,
                    ),
                    const SizedBox(height: 12),
                    _ApplyTextField(
                      controller: portfolioCtrl,
                      label: '作品集链接',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 12),
                    _ApplyTextField(
                      controller: experienceCtrl,
                      label: '相关经验',
                      hint: '类似合作、展览、商业项目经验，可选',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(sheetContext).pop(false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: submitting ? null : submit,
                            child: Text(submitting ? '提交中' : '提交申请'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    proposalCtrl.dispose();
    portfolioCtrl.dispose();
    experienceCtrl.dispose();
    return result;
  }

  void _openDetail(Map<String, dynamic> item) {
    final id = item['id'].toString();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
          item: item,
          applied: _appliedIds.contains(id),
          onApply: () => _apply(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingState(bottom: widget.bottom);
    if (_error != null) {
      return _ResourceState(
        bottom: widget.bottom,
        title: '机会加载失败',
        subtitle: _error!,
        onRetry: _load,
      );
    }

    final visibleItems = _filterMaps(_items, widget.searchKeyword)
        .where((item) => _matchesOpportunityQuickFilter(item, _quickFilter))
        .toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 88),
      children: [
        _SectionHeader(title: '合作机会', action: '${visibleItems.length} 条'),
        const SizedBox(height: 8),
        _FilterHintBar(
          chips: const ['全部', '高预算', '同城', '本周截止', '适合学生', '驻留项目'],
          selected: _quickFilter,
          onSelected: (filter) => setState(() => _quickFilter = filter),
        ),
        const SizedBox(height: 14),
        if (visibleItems.isEmpty)
          _EmptyPanel(
            title: widget.searchKeyword.trim().isEmpty ? '暂无合作机会' : '没有匹配机会',
            subtitle: widget.searchKeyword.trim().isEmpty
                ? '点击右下角 + 发布第一条机会。'
                : '换一个关键词，或发布新的合作机会。',
          )
        else
          ...visibleItems.map((item) {
            final id = item['id'].toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OpportunityCard(
                item: item,
                applied: _appliedIds.contains(id),
                onOpen: () => _openDetail(item),
                onApply: () => _apply(item),
              ),
            );
          }),
      ],
    );
  }
}

class _CommunityFeedTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _CommunityFeedTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends State<_CommunityFeedTab> {
  List<AppCommunityPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await BackendApiService.fetchCommunityPosts(limit: 40);
      if (!mounted) return;
      setState(() {
        _posts = posts
            .where((post) => post.metadata['kind']?.toString() != 'qa')
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = const [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openPost(AppCommunityPost post) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingState(bottom: widget.bottom);
    if (_error != null) {
      return _ResourceState(
        bottom: widget.bottom,
        title: '动态加载失败',
        subtitle: _error!,
        onRetry: _load,
      );
    }

    final keyword = widget.searchKeyword.trim().toLowerCase();
    final visiblePosts = keyword.isEmpty
        ? _posts
        : _posts.where((post) {
            return [
              post.title,
              post.body ?? '',
              post.authorNickname ?? '',
              post.metadata['post_type']?.toString() ?? '',
              post.metadata['tags']?.toString() ?? '',
            ].join(' ').toLowerCase().contains(keyword);
          }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 88),
        children: [
          if (visiblePosts.isEmpty)
            _EmptyPanel(
              title: keyword.isEmpty ? '暂无动态' : '没有匹配动态',
              subtitle: keyword.isEmpty
                  ? '用户发布的作品、现场和灵感记录会显示在这里。'
                  : '换一个作品、作者或标签关键词试试。',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: visiblePosts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 15,
                mainAxisExtent: 252,
              ),
              itemBuilder: (context, index) {
                final post = visiblePosts[index];
                return _CommunityFeedCard(
                  post: post,
                  onTap: () => _openPost(post),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CommunityFeedCard extends StatelessWidget {
  final AppCommunityPost post;
  final VoidCallback onTap;

  const _CommunityFeedCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    final author = post.authorNickname?.trim().isNotEmpty == true
        ? post.authorNickname!.trim()
        : 'Artsee 用户';
    final title = post.title.trim().isNotEmpty
        ? post.title.trim()
        : (post.body?.trim().isNotEmpty == true ? post.body!.trim() : '作品动态');
    final statusLabel = switch (post.status) {
      'reviewing' => '审核中',
      'draft' => '草稿',
      _ => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.028),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _CommunityFeedFallback(
                            seed: post.id,
                            title: title,
                          ),
                        )
                      : _CommunityFeedFallback(seed: post.id, title: title),
                  if (statusLabel != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  height: 1.28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
              child: Text(
                '$author · ${_compactExploreCount(post.likeCount)} likes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.32),
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedFallback extends StatelessWidget {
  final String seed;
  final String title;

  const _CommunityFeedFallback({
    required this.seed,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(seed);
    return Image.network(
      'https://picsum.photos/seed/artsee_feed_$encoded/420/520',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _CommunityFeedColorFallback(
        seed: seed,
        title: title,
      ),
    );
  }
}

class _CommunityFeedColorFallback extends StatelessWidget {
  final String seed;
  final String title;

  const _CommunityFeedColorFallback({
    required this.seed,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      (const Color(0xFFE7EEF8), const Color(0xFF4C6FFF)),
      (const Color(0xFFF6F8FC), const Color(0xFF001D51)),
      (const Color(0xFFE8F3EE), const Color(0xFF2F7D5E)),
      (const Color(0xFFF4E8EA), const Color(0xFFB94F68)),
    ];
    final item = colors[seed.hashCode.abs() % colors.length];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.$1, item.$2.withValues(alpha: 0.18)],
        ),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.72),
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _compactExploreCount(int value) {
  if (value >= 10000) {
    final v = value / 10000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}w';
  }
  if (value >= 1000) {
    final v = value / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}k';
  }
  return '$value';
}

class _ExhibitionTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _ExhibitionTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_ExhibitionTab> createState() => _ExhibitionTabState();
}

class _ExhibitionTabState extends State<_ExhibitionTab> {
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _myItems = const [];
  final Set<String> _appliedIds = {};
  String _quickFilter = '全部';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BackendApiService.fetchEvents(limit: 30),
        BackendApiService.fetchEvents(limit: 30, type: 'salon'),
      ]);
      var myItems = <Map<String, dynamic>>[];
      try {
        final applications =
            await BackendApiService.fetchMyEventApplications(limit: 30);
        myItems = applications.data
            .map(artseeEventFromApplication)
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        myItems = const [];
      }
      final appliedIds = myItems
          .map((event) => event['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final events = _mergeEventLists([
        myItems,
        ...results.map((result) => result.data),
      ]);
      if (!mounted) return;
      setState(() {
        _items = events;
        _myItems = myItems;
        _appliedIds
          ..clear()
          ..addAll(appliedIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _apply(Map<String, dynamic> item) async {
    if (!await ensureLoggedIn(context, message: '请先登录后报名活动')) {
      return false;
    }
    final id = item['id'].toString();
    if (_appliedIds.contains(id)) return true;
    final confirmed = await _showEventApplyConfirm(item);
    if (confirmed != true) return false;
    try {
      await BackendApiService.applyEvent(
        eventId: id,
        applyNote: '我想报名参加该活动。',
      );
      if (!mounted) return false;
      setState(() {
        _appliedIds.add(id);
        if (!_myItems.any((event) => event['id']?.toString() == id)) {
          _myItems = [
            {
              ...item,
              'application_status': 'pending',
            },
            ..._myItems,
          ];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('报名已提交，活动通知会进入私信/预约记录')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('报名失败：$e')),
      );
      return false;
    }
  }

  Future<bool?> _showEventApplyConfirm(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '未命名活动';
    final city = item['city']?.toString();
    final venue = item['venue']?.toString();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: context.artC.porcelain,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '确认报名',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Noto Serif SC',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    _formatDate(item['start_time']),
                    if (city != null && city.isNotEmpty) city,
                    if (venue != null && venue.isNotEmpty) venue,
                  ].join(' · '),
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.46),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '报名后将进入待确认状态，活动通知会进入私信/预约记录。',
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.46),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('确认报名'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    final id = item['id'].toString();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExhibitionDetailScreen(
          item: item,
          applied: _appliedIds.contains(id),
          onApply: () => _apply(item),
        ),
      ),
    );
  }

  Future<void> _openMyEvents() async {
    if (!await ensureLoggedIn(context, message: '请先登录后查看你的活动')) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MyEventsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingState(bottom: widget.bottom);
    if (_error != null) {
      return _ResourceState(
        bottom: widget.bottom,
        title: '活动加载失败',
        subtitle: _error!,
        onRetry: _load,
      );
    }
    final visibleItems = _filterMaps(_items, widget.searchKeyword)
        .where((item) => _matchesExhibitionQuickFilter(item, _quickFilter))
        .toList();
    visibleItems.sort(compareArtseeEventsByStart);
    final personalItems = _myItems.isNotEmpty
        ? _myItems
        : _items
            .where((item) => _appliedIds.contains(item['id']?.toString()))
            .toList();
    final groups = groupArtseeEventsByDay(visibleItems);
    const filters = ['全部', '展览', '沙龙', '讲座', '工作坊', '开放日', '说明会'];
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 2, 20, widget.bottom + 88),
      children: [
        ArtseeActivityPersonalSection(
          events: personalItems,
          onOpen: _openDetail,
          onOpenAll: _openMyEvents,
        ),
        const SizedBox(height: 22),
        ArtseeActivityRecommendationHeader(
          filterLabel: _quickFilter == '全部' ? '附近' : _quickFilter,
          selectedFilter: _quickFilter,
          filters: filters,
          onSelected: (filter) => setState(() => _quickFilter = filter),
        ),
        const SizedBox(height: 16),
        if (visibleItems.isEmpty)
          ArtseeActivityFeedEmpty(
            title: widget.searchKeyword.trim().isEmpty ? '暂无展览活动' : '没有匹配活动',
            subtitle: widget.searchKeyword.trim().isEmpty
                ? '点击右下角 + 发布展览、沙龙或工作坊。'
                : '换一个关键词，或发布新的活动。',
          )
        else ...[
          ArtseeActivitySponsoredSlot(
            event: visibleItems.first,
            onOpen: () => _openDetail(visibleItems.first),
          ),
          const SizedBox(height: 18),
          ...groups.map(
            (group) => ArtseeActivityDateSection(
              group: group,
              appliedIds: _appliedIds,
              onOpen: _openDetail,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArtistTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _ArtistTab({
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_ArtistTab> createState() => _ArtistTabState();
}

class _ArtistTabState extends State<_ArtistTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String _artCategory = '全部门类';
  String _region = '全部地区';
  String _verificationLevel = '全部认证';
  String _cooperationType = '全部合作';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchArtists(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = result.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openArtistOnboarding() async {
    if (!await ensureLoggedIn(context, message: '请先登录后创建艺术家档案')) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PublishArtistScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingState(bottom: widget.bottom);
    if (_error != null) {
      return _ResourceState(
        bottom: widget.bottom,
        title: '艺术家加载失败',
        subtitle: _error!,
        onRetry: _load,
      );
    }
    final certifiedItems = _items.where(_isCertifiedArtist).toList();
    final query = [
      widget.searchKeyword,
      _searchCtrl.text,
    ].where((item) => item.trim().isNotEmpty).join(' ');
    final visibleItems = _filterMaps(certifiedItems, query)
        .where(
          (item) => _matchesArtistStructuredFilters(
            item,
            artCategory: _artCategory,
            region: _region,
            verificationLevel: _verificationLevel,
            cooperationType: _cooperationType,
          ),
        )
        .toList();
    final availableCount = certifiedItems
        .where((item) =>
            (item['cooperation_status']?.toString() ?? 'available') ==
            'available')
        .length;

    if (visibleItems.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 88),
        children: [
          _ArtistLibraryHeader(
            totalCount: certifiedItems.length,
            availableCount: availableCount,
            onApply: _openArtistOnboarding,
          ),
          const SizedBox(height: 14),
          _ArtistSearchField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _ArtistFilterPanel(
            artCategory: _artCategory,
            region: _region,
            verificationLevel: _verificationLevel,
            cooperationType: _cooperationType,
            onArtCategoryChanged: (value) =>
                setState(() => _artCategory = value),
            onRegionChanged: (value) => setState(() => _region = value),
            onVerificationLevelChanged: (value) =>
                setState(() => _verificationLevel = value),
            onCooperationTypeChanged: (value) =>
                setState(() => _cooperationType = value),
          ),
          const SizedBox(height: 14),
          _EmptyPanel(
            title: certifiedItems.isEmpty ? '暂无认证艺术家' : '没有匹配艺术家',
            subtitle: certifiedItems.isEmpty
                ? '认证艺术家通过审核后会显示在这里，可以先申请入驻。'
                : '换一个艺术方向、城市、认证等级或合作关键词试试。',
          ),
          const SizedBox(height: 14),
          _ArtistOnboardingPanel(onStart: _openArtistOnboarding),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 88),
      children: [
        _ArtistLibraryHeader(
          totalCount: certifiedItems.length,
          availableCount: availableCount,
          onApply: _openArtistOnboarding,
        ),
        const SizedBox(height: 14),
        _ArtistSearchField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _ArtistFilterPanel(
          artCategory: _artCategory,
          region: _region,
          verificationLevel: _verificationLevel,
          cooperationType: _cooperationType,
          onArtCategoryChanged: (value) => setState(() => _artCategory = value),
          onRegionChanged: (value) => setState(() => _region = value),
          onVerificationLevelChanged: (value) =>
              setState(() => _verificationLevel = value),
          onCooperationTypeChanged: (value) =>
              setState(() => _cooperationType = value),
        ),
        const SizedBox(height: 14),
        _ArtistListSummary(
          visibleCount: visibleItems.length,
          totalCount: certifiedItems.length,
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _ArtistCard(
            artist: visibleItems[index],
          ),
        ),
        const SizedBox(height: 16),
        _ArtistOnboardingPanel(onStart: _openArtistOnboarding),
      ],
    );
  }
}

class _ExploreChannelHeader extends StatelessWidget {
  final TabController controller;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCalendarTap;
  final VoidCallback onSearchTap;

  const _ExploreChannelHeader({
    required this.controller,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onCalendarTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = context.artC.silver.withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: dividerColor),
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _ExploreHeaderIconButton(
                icon: Icons.calendar_month_outlined,
                onTap: onCalendarTap,
                tooltip: '艺术日历',
              ),
              Expanded(
                child: Center(
                  child: _ExploreChannelTabs(
                    controller: controller,
                    selectedIndex: selectedIndex,
                    onTabSelected: onTabSelected,
                  ),
                ),
              ),
              _ExploreHeaderIconButton(
                icon: Icons.search_rounded,
                onTap: onSearchTap,
                tooltip: '搜索发现',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ExploreHeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = context.artC.ink.withValues(alpha: 0.84);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtCalendarDrawer extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onOpenActivities;
  final ValueChanged<Map<String, dynamic>> onOpenEvent;

  const _ArtCalendarDrawer({
    required this.onDismiss,
    required this.onOpenActivities,
    required this.onOpenEvent,
  });

  @override
  State<_ArtCalendarDrawer> createState() => _ArtCalendarDrawerState();
}

class _ArtCalendarDrawerState extends State<_ArtCalendarDrawer> {
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _myEvents = const [];
  bool _loading = true;
  String? _error;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BackendApiService.fetchEvents(limit: 40),
        BackendApiService.fetchEvents(limit: 40, type: 'salon'),
      ]);
      var events = _mergeEventLists(results.map((result) => result.data));
      var myEvents = <Map<String, dynamic>>[];
      try {
        final applications =
            await BackendApiService.fetchMyEventApplications(limit: 30);
        myEvents = applications.data
            .map((application) {
              final event = application['events'];
              if (event is Map<String, dynamic>) {
                return {
                  ...event,
                  'application_status': application['status'],
                  'ticket_code': application['ticket_code'],
                };
              }
              if (event is Map) {
                return {
                  ...Map<String, dynamic>.from(event),
                  'application_status': application['status'],
                  'ticket_code': application['ticket_code'],
                };
              }
              return <String, dynamic>{};
            })
            .where((event) => event.isNotEmpty)
            .toList();
        events = _mergeEventLists([myEvents, events]);
      } catch (_) {
        myEvents = const [];
      }
      events.sort(_compareEventsByStart);
      myEvents.sort(_compareEventsByStart);
      if (!mounted) return;
      setState(() {
        _events = events;
        _myEvents = myEvents;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<DateTime> get _days {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List<DateTime>.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );
  }

  List<Map<String, dynamic>> get _selectedDayEvents {
    final day = _days[_selectedDay];
    return _events.where((event) {
      final start = _eventStartDate(event);
      return start != null && _isSameDay(start, day);
    }).toList();
  }

  List<Map<String, dynamic>> get _upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((event) {
          final start = _eventStartDate(event);
          return start == null ||
              start.isAfter(now.subtract(const Duration(hours: 2)));
        })
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width >= 430 ? 374.0 : width * 0.86;
    final selectedEvents = _selectedDayEvents;
    final fallbackEvents =
        selectedEvents.isEmpty ? _upcomingEvents : selectedEvents;
    final todayText = _calendarFullDate(DateTime.now());

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: panelWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(12, 0),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '我的艺术日历',
                                  style: TextStyle(
                                    color: context.artC.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  todayText,
                                  style: TextStyle(
                                    color: context.artC.ink
                                        .withValues(alpha: 0.42),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: widget.onDismiss,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _days.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final day = _days[index];
                          return _CalendarDayChip(
                            day: day,
                            selected: index == _selectedDay,
                            onTap: () => setState(() => _selectedDay = index),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (_loading) return const LoadingIndicator();
                          if (_error != null) {
                            return _CalendarErrorPanel(
                              message: _error!,
                              onRetry: _load,
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                            children: [
                              _CalendarSummaryCard(
                                todayCount: _selectedDayEvents.length,
                                weekCount: _events
                                    .where((event) => _isInNextDays(event, 7))
                                    .length,
                                myCount: _myEvents.length,
                                onTap: widget.onOpenActivities,
                              ),
                              const SizedBox(height: 18),
                              _CalendarSectionTitle(
                                title:
                                    selectedEvents.isEmpty ? '可参加活动' : '当天安排',
                                action: '${fallbackEvents.length} 场',
                              ),
                              const SizedBox(height: 10),
                              if (fallbackEvents.isEmpty)
                                _CalendarEmptyPanel(
                                  onOpen: widget.onOpenActivities,
                                )
                              else
                                ...fallbackEvents.map(
                                  (event) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CalendarEventTile(
                                      event: event,
                                      mine: _eventIsMine(event, _myEvents),
                                      onTap: () => widget.onOpenEvent(event),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              const _CalendarSectionTitle(
                                title: '待处理提醒',
                                action: 'REMIND',
                              ),
                              const SizedBox(height: 10),
                              _CalendarReminderTile(
                                icon: Icons.how_to_reg_outlined,
                                title: '活动确认 / 签到',
                                subtitle: _myEvents.isEmpty
                                    ? '报名活动后会在这里显示确认和签到提醒'
                                    : '${_myEvents.length} 场活动可查看报名状态',
                              ),
                              _CalendarReminderTile(
                                icon: Icons.handshake_outlined,
                                title: '合作机会截止',
                                subtitle: '后续会同步你收藏或申请的合作截止日期',
                              ),
                              const SizedBox(height: 24),
                              _CalendarBottomAction(
                                icon: Icons.qr_code_scanner_rounded,
                                label: '扫码签到',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('活动签到会接入扫一扫'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarDayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? kCobalt
                : context.artC.silver.withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _calendarChipTitle(day),
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : context.artC.ink.withValues(alpha: 0.48),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                color: selected ? Colors.white : context.artC.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFamily: 'Noto Serif SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSummaryCard extends StatelessWidget {
  final int todayCount;
  final int weekCount;
  final int myCount;
  final VoidCallback onTap;

  const _CalendarSummaryCard({
    required this.todayCount,
    required this.weekCount,
    required this.myCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        children: [
          _CalendarMetric(label: '今日', value: '$todayCount'),
          _CalendarMetric(label: '本周', value: '$weekCount'),
          _CalendarMetric(label: '已报名', value: '$myCount'),
        ],
      ),
    );
  }
}

class _CalendarMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CalendarMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: kCobalt,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSectionTitle extends StatelessWidget {
  final String title;
  final String action;

  const _CalendarSectionTitle({
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          action,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.34),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool mine;
  final VoidCallback onTap;

  const _CalendarEventTile({
    required this.event,
    required this.mine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? '未命名活动';
    final start = _eventStartDate(event);
    final venue = event['venue']?.toString();
    final city = event['city']?.toString();
    return ArtseeSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 54,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  start == null ? '--' : _monthLabel(start.month),
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.4),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  start == null ? '--' : '${start.day}',
                  style: const TextStyle(
                    color: kCobalt,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Noto Serif SC',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CalendarTypePill(label: _eventTypeLabel(event)),
                    if (mine) ...[
                      const SizedBox(width: 6),
                      const _CalendarTypePill(label: '已报名', strong: true),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    _calendarTime(start),
                    if (city != null && city.isNotEmpty) city,
                    if (venue != null && venue.isNotEmpty) venue,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: context.artC.ink.withValues(alpha: 0.24),
          ),
        ],
      ),
    );
  }
}

class _CalendarTypePill extends StatelessWidget {
  final String label;
  final bool strong;

  const _CalendarTypePill({required this.label, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? kCobalt : context.artC.silver.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              strong ? Colors.white : context.artC.ink.withValues(alpha: 0.5),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CalendarReminderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CalendarReminderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.28)),
            ),
            child: Icon(icon,
                size: 17, color: context.artC.ink.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.38),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CalendarBottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: kCobalt,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kCobalt.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEmptyPanel extends StatelessWidget {
  final VoidCallback onOpen;

  const _CalendarEmptyPanel({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: kCobalt, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '暂无近期活动，去活动页看看展览、沙龙和开放日。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.56),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CalendarErrorPanel({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Icon(
          Icons.event_busy_outlined,
          color: context.artC.ink.withValues(alpha: 0.3),
          size: 34,
        ),
        const SizedBox(height: 12),
        Text(
          '艺术日历加载失败',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.44),
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('重试')),
        ),
      ],
    );
  }
}

class _ExploreChannelTabs extends StatelessWidget {
  final TabController controller;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _ExploreChannelTabs({
    required this.controller,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const _labels = ['合作', '活动', '动态', '市集'];
  static const _accent = kCobalt;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _labels.length; index++)
              _ExploreChannelTab(
                label: _labels[index],
                selected: selectedIndex == index,
                accent: _accent,
                onTap: () => onTabSelected(index),
              ),
          ],
        );
      },
    );
  }
}

class _ExploreChannelTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ExploreChannelTab({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        selected ? context.artC.ink : context.artC.ink.withValues(alpha: 0.42);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.08,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: selected ? (label.length > 2 ? 38 : 30) : 0,
              height: 3.5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOpportunityCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onOpen;

  const _CompactOpportunityCard({
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '未命名机会';
    final type = item['type']?.toString() ?? 'collaboration';
    final city = item['city']?.toString().trim();
    final deadline = item['deadline'];
    final budget = _formatBudget(item['budget_min'], item['budget_max']);
    final typeLabel = _opportunityTypeLabel(type);
    final deadlineText = _formatDeadlineUrgency(deadline);
    final meta = [
      if (city != null && city.isNotEmpty) city,
      budget,
    ].where((item) => item.trim().isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.artC.silver.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.46),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    deadlineText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _deadlineColor(deadline, context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 15.2,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meta.isEmpty ? '详情待补充' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.42),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool applied;
  final VoidCallback onOpen;
  final VoidCallback onApply;

  const _OpportunityCard({
    required this.item,
    required this.applied,
    required this.onOpen,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '未命名机会';
    final type = item['type']?.toString() ?? 'collaboration';
    final city = item['city']?.toString().trim();
    final requirements = item['requirements']?.toString() ?? '';
    final deadline = item['deadline'];
    final budget = _formatBudget(item['budget_min'], item['budget_max']);
    final metadata = item['metadata'] is Map
        ? (item['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final organization = metadata['organization']?.toString();
    final showOrganization = metadata['show_organization'] != false;
    final tags = _extractOpportunityTags(city, requirements);
    final typeLabel = _opportunityTypeLabel(type);
    final deadlineText = _formatDeadlineUrgency(deadline);
    final host =
        !showOrganization || organization == null || organization.isEmpty
            ? '平台认证项目方'
            : organization;
    final description =
        requirements.isEmpty ? '适合有成熟作品集、可执行方案或合作经验的创作者。' : requirements;

    return ArtseeSurface(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      radius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _MiniBadge(text: '机会', color: kCobalt),
              const SizedBox(width: 6),
              _MiniBadge(text: typeLabel, color: const Color(0xFF7A6A56)),
              const Spacer(),
              Text(
                deadlineText,
                style: TextStyle(
                  fontSize: 11,
                  color: _deadlineColor(deadline, context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withOpacity(0.46),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CooperationMetaLine(
                  icon: Icons.apartment_rounded,
                  text: host,
                ),
              ),
              const SizedBox(width: 8),
              if (city != null && city.isNotEmpty)
                _CooperationMetaLine(
                  icon: Icons.place_outlined,
                  text: city,
                ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: tags.take(3).map((tag) => _SoftTag(text: tag)).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: context.artC.silver.withOpacity(0.26)),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  budget,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: applied ? onOpen : onApply,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: applied
                        ? context.artC.silver.withOpacity(0.2)
                        : kCobalt,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        applied ? Border.all(color: context.artC.silver) : null,
                  ),
                  child: Text(
                    applied ? '查看进度' : '申请',
                    style: TextStyle(
                      color: applied
                          ? context.artC.ink.withOpacity(0.7)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CooperationMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CooperationMetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: context.artC.ink.withValues(alpha: 0.32),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.44),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterHintBar extends StatelessWidget {
  final List<String> chips;
  final String? selected;
  final ValueChanged<String>? onSelected;

  const _FilterHintBar({
    required this.chips,
    this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected?.call(chip),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (selected ?? chips.first) == chip
                          ? context.artC.ink
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: context.artC.silver.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: (selected ?? chips.first) == chip
                            ? Colors.white
                            : context.artC.ink.withOpacity(0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class ExhibitionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool applied;
  final Future<bool> Function() onApply;

  const ExhibitionDetailScreen({
    super.key,
    required this.item,
    required this.applied,
    required this.onApply,
  });

  @override
  State<ExhibitionDetailScreen> createState() => _ExhibitionDetailScreenState();
}

class _ExhibitionDetailScreenState extends State<ExhibitionDetailScreen> {
  late bool _applied = widget.applied;
  bool _submitting = false;

  Future<void> _handleApply() async {
    if (_applied || _submitting) return;
    setState(() => _submitting = true);
    final applied = await widget.onApply();
    if (!mounted) return;
    setState(() {
      _applied = applied || _applied;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item['title']?.toString() ?? '未命名活动';
    final summary =
        item['summary']?.toString() ?? item['description']?.toString();
    final city = item['city']?.toString();
    final venue = item['venue']?.toString();
    final coverUrl = item['cover_url']?.toString();
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: context.artC.ink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    Image.network(coverUrl, fit: BoxFit.cover)
                  else
                    Container(color: context.artC.silver.withOpacity(0.28)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          context.artC.ink.withOpacity(0.88),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniBadge(text: 'EVENT', color: kCobalt),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailInfoCard(
                    rows: [
                      ('时间', _formatDate(item['start_time'])),
                      (
                        '地点',
                        [
                          if (city != null && city.isNotEmpty) city,
                          if (venue != null && venue.isNotEmpty) venue,
                        ].join(' · ').isEmpty
                            ? '待定'
                            : [
                                if (city != null && city.isNotEmpty) city,
                                if (venue != null && venue.isNotEmpty) venue,
                              ].join(' · ')
                      ),
                      ('费用', _formatEventFee(item['fee_amount'])),
                      ('状态', _applied ? '已报名 / 待确认' : '可报名'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailSection(
                    title: '活动介绍',
                    body: summary == null || summary.isEmpty
                        ? '这里会展示展览、工作坊或导览的介绍、主题和参与价值。'
                        : summary,
                  ),
                  _DetailSection(
                    title: '适合人群',
                    body: '艺术留学申请者、创作者、策展/艺术市场方向用户，以及希望了解现场资源的人。',
                  ),
                  _DetailSection(
                    title: '报名须知',
                    body: '需提前预约；报名后进入待确认状态；活动通知会进入私信/预约记录。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton.icon(
            onPressed: _applied || _submitting ? null : _handleApply,
            icon: Icon(_applied
                ? Icons.check_circle_rounded
                : Icons.event_available_rounded),
            label: Text(
              _applied
                  ? '已报名'
                  : _submitting
                      ? '提交中'
                      : '立即报名',
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;

  const _CompactArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name']?.toString() ?? '未命名艺术家';
    final handle = _artistHandle(artist);
    final fields = _artistFields(artist);
    final city = artist['city']?.toString().trim();
    final avatarUrl = artist['avatar_url']?.toString();
    final cooperationStatus =
        artist['cooperation_status']?.toString() ?? 'available';
    final isCertified = _isCertifiedArtist(artist);
    final intent = artist['cooperation_intent']?.toString().trim();
    final subtitle = [
      if (city != null && city.isNotEmpty) city,
      if (fields.isNotEmpty) fields.take(2).join('/'),
      if ((city == null || city.isEmpty) && fields.isEmpty) handle,
    ].join(' · ');
    final description = intent != null && intent.isNotEmpty
        ? intent
        : fields.isNotEmpty
            ? '${fields.take(2).join(' / ')}创作者'
            : handle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openArtistProfile(context, artist),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.artC.silver.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ArtistAvatar(name: name, avatarUrl: avatarUrl, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.artC.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (isCertified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: kCobalt,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          subtitle.isEmpty ? handle : subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.artC.ink.withValues(alpha: 0.42),
                            fontSize: 10.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.52),
                  fontSize: 11.5,
                  height: 1.28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: _CooperationStatusInline(status: cooperationStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CooperationStatusInline extends StatelessWidget {
  final String status;

  const _CooperationStatusInline({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = _cooperationStatusColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.78),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          _cooperationStatusLabel(status),
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.46),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name']?.toString() ?? '未命名艺术家';
    final handle = _artistHandle(artist);
    final fields = _artistFields(artist);
    final city = artist['city']?.toString().trim();
    final avatarUrl = artist['avatar_url']?.toString();
    final cooperationStatus =
        artist['cooperation_status']?.toString() ?? 'available';
    final portfolioCount = _artistInt(artist['portfolio_count']);
    final exhibitionCount = _artistInt(artist['exhibition_count']);
    final cooperationTypes = _artistCooperationTypes(artist);
    final intent = artist['cooperation_intent']?.toString().trim();
    final metricText = [
      if (portfolioCount > 0) '$portfolioCount 件作品',
      if (exhibitionCount > 0) '$exhibitionCount 次展览',
      if (portfolioCount == 0 && exhibitionCount == 0) '作品待补充',
    ].join(' · ');

    return ArtseeSurface(
      onTap: () => _openArtistProfile(context, artist),
      padding: const EdgeInsets.all(14),
      radius: 8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArtistAvatar(name: name, avatarUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _MiniBadge(
                      text: '艺术家',
                      color: Color(0xFF047857),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _MiniBadge(
                        text: _cooperationStatusLabel(cooperationStatus),
                        color: _cooperationStatusColor(cooperationStatus),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      color: kCobalt,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    handle,
                    if (city != null && city.isNotEmpty) city,
                    if (fields.isNotEmpty) fields.take(2).join('/'),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.44),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  intent == null || intent.isEmpty
                      ? '开放作品交流、合作邀约和艺术项目沟通。'
                      : intent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          metricText,
                          if (cooperationTypes.isNotEmpty)
                            cooperationTypes.take(2).join(' / '),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.36),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '看主页',
                      style: TextStyle(
                        color: kCobalt,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: kCobalt,
                      size: 18,
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

class _ArtistAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _ArtistAvatar({
    required this.name,
    required this.avatarUrl,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ArtistAvatarFallback(name: name),
              )
            : _ArtistAvatarFallback(name: name),
      ),
    );
  }
}

class _ArtistAvatarFallback extends StatelessWidget {
  final String name;

  const _ArtistAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCobalt.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          name.isEmpty ? '艺' : name.characters.first,
          style: const TextStyle(
            color: kCobalt,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

void _openArtistProfile(BuildContext context, Map<String, dynamic> artist) {
  final name = artist['display_name']?.toString() ?? '未命名艺术家';
  final handle = _artistHandle(artist);
  final fields = _artistFields(artist);
  final avatarUrl = artist['avatar_url']?.toString();

  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PublicUserProfileScreen(
        userId: artist['user_id']?.toString(),
        name: name,
        handle: handle,
        avatarUrl: avatarUrl,
        roleLabel: _artistVerificationLabel(artist),
        bio: artist['bio']?.toString(),
        kind: PublicUserProfileKind.artist,
        featuredActivity:
            '正在展示${fields.isEmpty ? '艺术创作' : fields.join(' / ')}方向的作品与合作意向。',
        featuredAnswerContext: '艺术家观点',
        featuredAnswer: artist['cooperation_intent']?.toString(),
      ),
    ),
  );
}

class _ArtistSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ArtistSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: context.artC.ink.withValues(alpha: 0.34), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索艺术家、方向、城市、标签',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.34),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(Icons.close_rounded,
                  color: context.artC.ink.withValues(alpha: 0.3), size: 18),
            ),
        ],
      ),
    );
  }
}

class _ArtistFilterPanel extends StatelessWidget {
  final String artCategory;
  final String region;
  final String verificationLevel;
  final String cooperationType;
  final ValueChanged<String> onArtCategoryChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onVerificationLevelChanged;
  final ValueChanged<String> onCooperationTypeChanged;

  const _ArtistFilterPanel({
    required this.artCategory,
    required this.region,
    required this.verificationLevel,
    required this.cooperationType,
    required this.onArtCategoryChanged,
    required this.onRegionChanged,
    required this.onVerificationLevelChanged,
    required this.onCooperationTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ArtistFilterRow(
          label: '艺术门类',
          values: const ['全部门类', '绘画', '装置', '影像', '摄影', '设计', '新媒体'],
          selected: artCategory,
          onChanged: onArtCategoryChanged,
        ),
        const SizedBox(height: 8),
        _ArtistFilterRow(
          label: '地区',
          values: const ['全部地区', '北京', '上海', '广州', '深圳', '杭州', '伦敦', '纽约'],
          selected: region,
          onChanged: onRegionChanged,
        ),
        const SizedBox(height: 8),
        _ArtistFilterRow(
          label: '认证等级',
          values: const ['全部认证', '平台认证', '展览认证', '教育背景认证', '职业认证'],
          selected: verificationLevel,
          onChanged: onVerificationLevelChanged,
        ),
        const SizedBox(height: 8),
        _ArtistFilterRow(
          label: '可合作类型',
          values: const ['全部合作', '可合作', '展览', '品牌联名', '公共艺术', '讲座工作坊'],
          selected: cooperationType,
          onChanged: onCooperationTypeChanged,
        ),
      ],
    );
  }
}

class _ArtistFilterRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ArtistFilterRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: values.map((value) {
                final active = value == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            active ? context.artC.ink : context.artC.cardIconBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: active
                              ? context.artC.ink
                              : context.artC.silver.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : context.artC.ink.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistListSummary extends StatelessWidget {
  final int visibleCount;
  final int totalCount;

  const _ArtistListSummary({
    required this.visibleCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified_rounded, color: kCobalt, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '认证艺术家 $visibleCount / $totalCount',
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '仅展示已认证',
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ArtistOnboardingPanel extends StatelessWidget {
  final VoidCallback onStart;

  const _ArtistOnboardingPanel({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCobalt.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user_outlined, color: kCobalt),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '申请成为入驻艺术家',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '创建主页、上传作品，审核通过后进入艺术家库。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.48),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('入驻'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCobalt,
              side: BorderSide(color: kCobalt.withValues(alpha: 0.32)),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;

  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
              fontFamily: 'Noto Serif SC',
            ),
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: kCobalt,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _SoftTag extends StatelessWidget {
  final String text;

  const _SoftTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.artC.silver.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.artC.silver.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: context.artC.ink.withOpacity(0.44),
        ),
      ),
    );
  }
}

class _ResourceSectionTitle extends StatelessWidget {
  final String title;
  final String action;

  const _ResourceSectionTitle({
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: kCobalt,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  final double bottom;

  const _LoadingState({required this.bottom});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 80, 20, bottom),
      children: [
        Center(
          child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
        ),
      ],
    );
  }
}

class _ResourceState extends StatelessWidget {
  final double bottom;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _ResourceState({
    required this.bottom,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 44, 20, bottom),
      children: [
        _EmptyPanel(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('重试')),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyPanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_circle_outline, color: kCobalt, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withOpacity(0.42),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBudget(dynamic min, dynamic max) {
  final minValue = min is int ? min : int.tryParse(min?.toString() ?? '');
  final maxValue = max is int ? max : int.tryParse(max?.toString() ?? '');
  String money(int value) {
    if (value >= 10000) return '¥${(value / 10000).toStringAsFixed(0)}w';
    return '¥$value';
  }

  if (minValue != null && maxValue != null) {
    return '${money(minValue)}-${money(maxValue)}';
  }
  if (maxValue != null) return '最高 ${money(maxValue)}';
  if (minValue != null) return '最低 ${money(minValue)}';
  return '预算面议';
}

String _formatDate(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  if (date == null) return '长期开放';
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _formatEventFee(dynamic raw) {
  final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (value == null || value <= 0) return '免费 / 预约制';
  return '¥$value';
}

List<Map<String, dynamic>> _filterMaps(
  List<Map<String, dynamic>> items,
  String keyword,
) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) return items;
  return items.where((item) {
    final text = item.entries
        .map((entry) => '${entry.key} ${entry.value}')
        .join(' ')
        .toLowerCase();
    return text.contains(query);
  }).toList();
}

String _monthLabel(int month) {
  const labels = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return labels[month - 1];
}

bool _matchesOpportunityQuickFilter(Map<String, dynamic> item, String filter) {
  if (filter == '全部') return true;
  final budgetMin = item['budget_min'] is int
      ? item['budget_min'] as int
      : int.tryParse(item['budget_min']?.toString() ?? '');
  final budgetMax = item['budget_max'] is int
      ? item['budget_max'] as int
      : int.tryParse(item['budget_max']?.toString() ?? '');
  final deadline = DateTime.tryParse(item['deadline']?.toString() ?? '');
  final city = item['city']?.toString().toLowerCase() ?? '';
  final tags = item['tags']?.toString().toLowerCase() ?? '';
  final description = item['description']?.toString().toLowerCase() ?? '';

  return switch (filter) {
    '高预算' => (budgetMax != null && budgetMax >= 50000) ||
        (budgetMin != null && budgetMin >= 30000),
    '同城' => city.contains('上海') ||
        city.contains('北京') ||
        city.contains('深圳') ||
        city.contains('广州'),
    '本周截止' =>
      deadline != null && deadline.difference(DateTime.now()).inDays <= 7,
    '适合学生' => tags.contains('学生') ||
        description.contains('学生') ||
        (budgetMax != null && budgetMax <= 10000),
    '驻留项目' => tags.contains('驻留') ||
        description.contains('驻留') ||
        description.contains('residency'),
    _ => true,
  };
}

List<({String title, String body})> _opportunityProcessItems(String type) {
  final normalized = type.toLowerCase();
  if (normalized == 'residency') {
    return const [
      (title: '提交申请材料', body: '用作品集、个人说明和驻留计划完成初筛。'),
      (title: '项目方确认', body: '项目方会根据方向、档期和空间资源进行匹配。'),
      (title: '沟通驻留方案', body: '确认驻留周期、产出形式、预算和展示方式。'),
      (title: '进入执行', body: '通过后可继续在机会进度中跟进节点。'),
    ];
  }
  if (normalized == 'exhibition') {
    return const [
      (title: '提交作品资料', body: '上传作品集、简历和适合本展览主题的作品说明。'),
      (title: '策展初筛', body: '策展团队会评估作品方向、媒介和展示条件。'),
      (title: '确认参展细节', body: '沟通运输、保险、布展时间和授权边界。'),
      (title: '展览执行', body: '入选后进入布展、宣传和现场执行阶段。'),
    ];
  }
  return const [
    (title: '提交合作意向', body: '说明你的创作方向、可交付内容和相关经验。'),
    (title: '项目方筛选', body: '项目方会基于作品集、预算和执行能力做初步判断。'),
    (title: '沟通方案', body: '确认创意方向、周期、版权授权和付款节点。'),
    (title: '合作落地', body: '双方确认后进入项目执行与成果验收。'),
  ];
}

bool _matchesExhibitionQuickFilter(Map<String, dynamic> item, String filter) {
  if (filter == '全部') return true;
  final raw = item.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' ')
      .toLowerCase();
  final date = DateTime.tryParse(item['start_time']?.toString() ?? '');
  final fee = item['fee_amount'] is int
      ? item['fee_amount'] as int
      : int.tryParse(item['fee_amount']?.toString() ?? '');
  return switch (filter) {
    '展览' =>
      raw.contains('展览') || raw.contains('exhibition') || raw.contains('show'),
    '沙龙' => raw.contains('沙龙') || raw.contains('salon'),
    '讲座' =>
      raw.contains('讲座') || raw.contains('lecture') || raw.contains('talk'),
    '工作坊' =>
      raw.contains('工作坊') || raw.contains('workshop') || raw.contains('studio'),
    '开放日' => raw.contains('开放日') ||
        raw.contains('open day') ||
        raw.contains('open_day'),
    '说明会' => raw.contains('说明会') ||
        raw.contains('info session') ||
        raw.contains('application'),
    '本周' => date != null && date.difference(DateTime.now()).inDays <= 7,
    '同城' => raw.contains('上海') ||
        raw.contains('北京') ||
        raw.contains('纽约') ||
        raw.contains('伦敦'),
    '免费' => fee == null || fee <= 0 || raw.contains('免费'),
    '预约制' => raw.contains('预约') || raw.contains('reservation'),
    '线上' => raw.contains('线上') ||
        raw.contains('online') ||
        raw.contains('zoom') ||
        raw.contains('vr'),
    _ => true,
  };
}

List<Map<String, dynamic>> _mergeEventLists(
  Iterable<List<Map<String, dynamic>>> groups,
) {
  final seen = <String>{};
  final merged = <Map<String, dynamic>>[];
  for (final item in groups.expand((items) => items)) {
    final id = item['id']?.toString();
    final key = id != null && id.isNotEmpty
        ? id
        : '${item['type'] ?? ''}|${item['title'] ?? ''}|${item['start_time'] ?? ''}';
    if (seen.add(key)) merged.add(item);
  }
  return merged;
}

String _eventTypeLabel(Map<String, dynamic> item) {
  final raw = item.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' ')
      .toLowerCase();
  if (raw.contains('salon') || raw.contains('沙龙')) return '沙龙';
  if (raw.contains('lecture') || raw.contains('talk') || raw.contains('讲座')) {
    return '讲座';
  }
  if (raw.contains('workshop') || raw.contains('工作坊')) return '工作坊';
  if (raw.contains('open day') ||
      raw.contains('open_day') ||
      raw.contains('开放日')) {
    return '开放日';
  }
  if (raw.contains('info session') ||
      raw.contains('briefing') ||
      raw.contains('application') ||
      raw.contains('说明会')) {
    return '说明会';
  }
  if (raw.contains('exhibition') ||
      raw.contains('展览') ||
      raw.contains('gallery')) {
    return '展览';
  }
  return '活动';
}

DateTime? _eventStartDate(Map<String, dynamic> item) {
  final raw = item['start_time'] ??
      item['startTime'] ??
      item['event_start_at'] ??
      item['scheduled_at'] ??
      item['date'];
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw?.toString() ?? '');
}

int _compareEventsByStart(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aStart = _eventStartDate(a);
  final bStart = _eventStartDate(b);
  if (aStart == null && bStart == null) {
    return (a['title']?.toString() ?? '').compareTo(
      b['title']?.toString() ?? '',
    );
  }
  if (aStart == null) return 1;
  if (bStart == null) return -1;
  return aStart.compareTo(bStart);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isInNextDays(Map<String, dynamic> event, int days) {
  final start = _eventStartDate(event);
  if (start == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = today.add(Duration(days: days));
  return !start.isBefore(today) && start.isBefore(end);
}

bool _eventIsMine(
  Map<String, dynamic> event,
  List<Map<String, dynamic>> myEvents,
) {
  final id = event['id']?.toString();
  final title = event['title']?.toString();
  final start = event['start_time']?.toString();
  return myEvents.any((item) {
    final itemId = item['id']?.toString();
    if (id != null && id.isNotEmpty && itemId == id) return true;
    return item['title']?.toString() == title &&
        item['start_time']?.toString() == start;
  });
}

String _calendarFullDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日 ${_weekdayCn(date.weekday)}';
}

String _calendarChipTitle(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (_isSameDay(day, today)) return '今天';
  if (_isSameDay(day, today.add(const Duration(days: 1)))) return '明天';
  return _weekdayCn(day.weekday);
}

String _weekdayCn(int weekday) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final index = weekday.clamp(1, 7) - 1;
  return labels[index];
}

String _calendarTime(DateTime? date) {
  if (date == null) return '时间待定';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ApplyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final String? error;

  const _ApplyTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: error != null && error!.isNotEmpty
                    ? Colors.red
                    : context.artC.silver.withOpacity(0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: error != null && error!.isNotEmpty
                    ? Colors.red
                    : context.artC.silver.withOpacity(0.4),
              ),
            ),
          ),
        ),
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class OpportunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool applied;
  final Future<bool> Function() onApply;

  const OpportunityDetailScreen({
    super.key,
    required this.item,
    required this.applied,
    required this.onApply,
  });

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  late bool _applied = widget.applied;
  bool _submitting = false;

  Future<void> _handleApply() async {
    if (_applied || _submitting) return;
    setState(() => _submitting = true);
    final applied = await widget.onApply();
    if (!mounted) return;
    setState(() {
      _applied = applied || _applied;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item['title']?.toString() ?? '未命名机会';
    final description = item['description']?.toString() ?? '暂无详细说明';
    final type = item['type']?.toString() ?? 'collaboration';
    final typeLabel = _opportunityTypeLabel(type);
    final budget = _formatBudget(item['budget_min'], item['budget_max']);
    final deadline = _formatDate(item['deadline']);
    final deadlineUrgency = _formatDeadlineUrgency(item['deadline']);
    final city = item['city']?.toString() ?? '不限';
    final requirements = item['requirements']?.toString() ?? '';
    final metadata = item['metadata'] is Map
        ? (item['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final organization = metadata['organization']?.toString();
    final showOrganization = metadata['show_organization'] != false;
    final deliverable = metadata['deliverable']?.toString();
    final materials = metadata['required_materials'] is List
        ? (metadata['required_materials'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final tags = _extractOpportunityTags(city, requirements);
    final partner =
        !showOrganization || organization == null || organization.isEmpty
            ? '平台认证项目方'
            : organization;
    final deliverableText = deliverable == null || deliverable.isEmpty
        ? '作品集方案 / 初步合作提案'
        : deliverable;
    final materialText =
        materials.isEmpty ? '作品集 + 简历 + 初步方案' : materials.join(' + ');

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '合作机会',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark_border_rounded,
                color: context.artC.ink, size: 21),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('机会收藏功能稍后开放')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.paddingOf(context).bottom + 118,
        ),
        children: [
          _OpportunityDetailHero(
            title: title,
            typeLabel: typeLabel,
            deadlineUrgency: deadlineUrgency,
            description: description,
            tags: tags,
          ),
          const SizedBox(height: 14),
          _OpportunityMetricRow(
            budget: budget,
            deadline: deadline,
            city: city,
          ),
          const SizedBox(height: 14),
          _OpportunityPartnerCard(
            partner: partner,
            deliverable: deliverableText,
            materials: materialText,
          ),
          const SizedBox(height: 18),
          const _ResourceSectionTitle(title: '项目说明', action: 'BRIEF'),
          const SizedBox(height: 10),
          _OpportunityBodyCard(
            description,
          ),
          const SizedBox(height: 18),
          const _ResourceSectionTitle(title: '申请要求', action: 'MATCH'),
          const SizedBox(height: 10),
          _OpportunityRequirementCard(
            requirements: requirements,
            materials: materials,
            city: city,
          ),
          const SizedBox(height: 18),
          const _ResourceSectionTitle(title: '合作流程', action: 'PROCESS'),
          const SizedBox(height: 10),
          _OpportunityProcessCard(
            items: _opportunityProcessItems(type),
          ),
        ],
      ),
      bottomNavigationBar: _OpportunityDetailBottomBar(
        applied: _applied,
        submitting: _submitting,
        budget: budget,
        deadlineUrgency: deadlineUrgency,
        onApply: _handleApply,
      ),
    );
  }
}

class _OpportunityDetailHero extends StatelessWidget {
  final String title;
  final String typeLabel;
  final String deadlineUrgency;
  final String description;
  final List<String> tags;

  const _OpportunityDetailHero({
    required this.title,
    required this.typeLabel,
    required this.deadlineUrgency,
    required this.description,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.artC.deepPanel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OpportunityDarkBadge(label: typeLabel, strong: true),
                    _OpportunityDarkBadge(label: deadlineUrgency),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.12,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: tags
                  .take(4)
                  .map((tag) => _OpportunityDarkBadge(label: '#$tag'))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpportunityDarkBadge extends StatelessWidget {
  final String label;
  final bool strong;

  const _OpportunityDarkBadge({
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? kCobalt : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: strong ? 1 : 0.74),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OpportunityMetricRow extends StatelessWidget {
  final String budget;
  final String deadline;
  final String city;

  const _OpportunityMetricRow({
    required this.budget,
    required this.deadline,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OpportunityMetricTile(
            icon: Icons.payments_outlined,
            label: '预算',
            value: budget,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OpportunityMetricTile(
            icon: Icons.calendar_today_outlined,
            label: '截止',
            value: deadline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OpportunityMetricTile(
            icon: Icons.location_on_outlined,
            label: '城市',
            value: city,
          ),
        ),
      ],
    );
  }
}

class _OpportunityMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OpportunityMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kCobalt, size: 17),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.36),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityPartnerCard extends StatelessWidget {
  final String partner;
  final String deliverable;
  final String materials;

  const _OpportunityPartnerCard({
    required this.partner,
    required this.deliverable,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          _OpportunityInfoLine(
            icon: Icons.verified_user_outlined,
            label: '合作方',
            value: partner,
            strong: true,
          ),
          const SizedBox(height: 14),
          _OpportunityInfoLine(
            icon: Icons.assignment_outlined,
            label: '交付内容',
            value: deliverable,
          ),
          const SizedBox(height: 14),
          _OpportunityInfoLine(
            icon: Icons.folder_copy_outlined,
            label: '申请材料',
            value: materials,
          ),
        ],
      ),
    );
  }
}

class _OpportunityInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  const _OpportunityInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (strong ? kCobalt : context.artC.silver).withValues(
              alpha: strong ? 0.1 : 0.26,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Icon(icon, color: strong ? kCobalt : context.artC.ink, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.38),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpportunityBodyCard extends StatelessWidget {
  final String body;

  const _OpportunityBodyCard(this.body);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Text(
        body,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.62),
          fontSize: 13,
          height: 1.65,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OpportunityRequirementCard extends StatelessWidget {
  final String requirements;
  final List<String> materials;
  final String city;

  const _OpportunityRequirementCard({
    required this.requirements,
    required this.materials,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      requirements.isEmpty ? '适合有成熟作品集、可执行方案或合作经验的创作者。' : requirements,
      '项目城市：$city',
      materials.isEmpty ? '建议准备作品集、简历和初步合作方案。' : '需提交：${materials.join('、')}',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: kCobalt,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        row,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.58),
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OpportunityProcessCard extends StatelessWidget {
  final List<({String title, String body})> items;

  const _OpportunityProcessCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map(
              (entry) => _OpportunityProcessRow(
                index: entry.key,
                item: entry.value,
                last: entry.key == items.length - 1,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OpportunityProcessRow extends StatelessWidget {
  final int index;
  final ({String title, String body}) item;
  final bool last;

  const _OpportunityProcessRow({
    required this.index,
    required this.item,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    index == 0 ? kCobalt : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!last)
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.14),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpportunityDetailBottomBar extends StatelessWidget {
  final bool applied;
  final bool submitting;
  final String budget;
  final String deadlineUrgency;
  final Future<void> Function() onApply;

  const _OpportunityDetailBottomBar({
    required this.applied,
    required this.submitting,
    required this.budget,
    required this.deadlineUrgency,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !applied && !submitting;
    final label = applied
        ? '已申请'
        : submitting
            ? '提交中'
            : '申请此机会';
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 9, 18, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    applied ? '可在机会进度里继续追踪' : deadlineUrgency,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: enabled ? onApply : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled
                      ? kCobalt
                      : context.artC.silver.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? Colors.white
                        : context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _DetailInfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          color: context.artC.ink.withOpacity(0.38),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String body;

  const _DetailSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: context.artC.ink.withOpacity(0.62),
              fontSize: 14,
              height: 1.65,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _cooperationStatusColor(String status) {
  return switch (status) {
    'available' => const Color(0xFF22C55E),
    'busy' => const Color(0xFFF59E0B),
    'unavailable' => const Color(0xFF9CA3AF),
    _ => const Color(0xFF22C55E),
  };
}

String _cooperationStatusLabel(String status) {
  return switch (status) {
    'available' => '可合作',
    'busy' => '档期紧张',
    'unavailable' => '暂不接单',
    _ => '可合作',
  };
}

class ArtistDetailScreen extends StatelessWidget {
  final Map<String, dynamic> artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['display_name']?.toString() ?? '未命名艺术家';
    final fields = (artist['art_fields'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .join(' / ');
    final city = artist['city']?.toString() ?? '不限';
    final bio = artist['bio']?.toString();
    final coverWorkUrl = artist['cover_work_url']?.toString() ??
        artist['featured_work_url']?.toString() ??
        artist['avatar_url']?.toString();
    final cooperationStatus =
        artist['cooperation_status']?.toString() ?? 'available';
    final cooperationIntent = artist['cooperation_intent']?.toString();
    final portfolioCount = artist['portfolio_count'] is int
        ? artist['portfolio_count'] as int
        : int.tryParse(artist['portfolio_count']?.toString() ?? '') ?? 0;
    final exhibitionCount = artist['exhibition_count'] is int
        ? artist['exhibition_count'] as int
        : int.tryParse(artist['exhibition_count']?.toString() ?? '') ?? 0;
    final careerStage = artist['career_stage']?.toString();
    final verificationBadges = artist['verification_badges'];

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: context.artC.ink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverWorkUrl != null && coverWorkUrl.isNotEmpty)
                    Image.network(coverWorkUrl, fit: BoxFit.cover)
                  else
                    Container(color: context.artC.silver.withOpacity(0.28)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          context.artC.ink.withOpacity(0.88),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniBadge(text: '艺术家', color: kCobalt),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cooperationStatusColor(cooperationStatus)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _cooperationStatusColor(cooperationStatus),
                          ),
                        ),
                        child: Text(
                          _cooperationStatusLabel(cooperationStatus),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: _cooperationStatusColor(cooperationStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fields.isEmpty ? '艺术家' : fields,
                    style: TextStyle(
                      color: context.artC.ink.withOpacity(0.58),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: context.artC.ink.withOpacity(0.42)),
                      const SizedBox(width: 4),
                      Text(
                        city,
                        style: TextStyle(
                          color: context.artC.ink.withOpacity(0.42),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (careerStage != null && careerStage.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          ' · $careerStage',
                          style: TextStyle(
                            color: context.artC.ink.withOpacity(0.42),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (verificationBadges != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _VerificationBadge(icon: Icons.verified, label: '实名认证'),
                        _VerificationBadge(icon: Icons.school, label: '学历认证'),
                        _VerificationBadge(icon: Icons.palette, label: '职业认证'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _DetailInfoCard(
                    rows: [
                      ('作品数量', portfolioCount > 0 ? '$portfolioCount 件' : '暂无'),
                      (
                        '展览经历',
                        exhibitionCount > 0 ? '$exhibitionCount 次' : '暂无'
                      ),
                      ('合作状态', _cooperationStatusLabel(cooperationStatus)),
                    ],
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _DetailSection(
                      title: '个人简介',
                      body: bio,
                    ),
                  ],
                  if (cooperationIntent != null &&
                      cooperationIntent.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _DetailSection(
                      title: '合作意向',
                      body: cooperationIntent,
                    ),
                  ],
                  _DetailSection(
                    title: '作品集',
                    body: '艺术家的代表作品将在这里展示。包括作品图片、标题、年份、媒介和作品说明。',
                  ),
                  _DetailSection(
                    title: '展览经历',
                    body: '参展记录、个展、群展等展览经历将在这里展示。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('收藏功能开发中')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('收藏'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: cooperationStatus == 'unavailable'
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('发起合作功能开发中')),
                          );
                        },
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: Text(
                      cooperationStatus == 'unavailable' ? '暂不接单' : '发起合作'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VerificationBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: kCobalt),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: kCobalt,
          ),
        ),
      ],
    );
  }
}

bool _isCertifiedArtist(Map<String, dynamic> item) {
  final status = item['status']?.toString().toLowerCase() ?? '';
  final verification =
      item['verification_status']?.toString().toLowerCase() ?? '';
  return status == 'published' ||
      verification == 'verified' ||
      verification == 'approved' ||
      item['verification_badges'] != null;
}

bool _matchesArtistStructuredFilters(
  Map<String, dynamic> item, {
  required String artCategory,
  required String region,
  required String verificationLevel,
  required String cooperationType,
}) {
  final fields = _artistFields(item).join(' ').toLowerCase();
  final city = item['city']?.toString().toLowerCase() ?? '';
  final verificationText = [
    item['verification_status'],
    item['verification_level'],
    item['verification_badges'],
  ].join(' ').toLowerCase();
  final cooperationText = [
    item['cooperation_status'],
    item['cooperation_intent'],
    _artistCooperationTypes(item).join(' '),
  ].join(' ').toLowerCase();

  final categoryOk = artCategory == '全部门类' ||
      switch (artCategory) {
        '绘画' => fields.contains('绘') ||
            fields.contains('painting') ||
            fields.contains('fine_art'),
        '装置' => fields.contains('装置') || fields.contains('installation'),
        '影像' => fields.contains('影像') || fields.contains('video'),
        '摄影' => fields.contains('摄影') || fields.contains('photo'),
        '设计' => fields.contains('设计') || fields.contains('design'),
        '新媒体' => fields.contains('新媒体') || fields.contains('media'),
        _ => fields.contains(artCategory.toLowerCase()),
      };

  final regionOk = region == '全部地区' || city.contains(region.toLowerCase());

  final verificationOk = verificationLevel == '全部认证' ||
      switch (verificationLevel) {
        '平台认证' => _isCertifiedArtist(item),
        '展览认证' => verificationText.contains('展览') ||
            verificationText.contains('exhibition'),
        '教育背景认证' => verificationText.contains('教育') ||
            verificationText.contains('school'),
        '职业认证' => verificationText.contains('职业') ||
            verificationText.contains('career'),
        _ => true,
      };

  final cooperationOk = cooperationType == '全部合作' ||
      switch (cooperationType) {
        '可合作' => (item['cooperation_status']?.toString() ?? 'available') ==
            'available',
        '展览' => cooperationText.contains('展') ||
            cooperationText.contains('exhibition'),
        '品牌联名' =>
          cooperationText.contains('品牌') || cooperationText.contains('brand'),
        '公共艺术' =>
          cooperationText.contains('公共') || cooperationText.contains('public'),
        '讲座工作坊' => cooperationText.contains('讲座') ||
            cooperationText.contains('工作坊') ||
            cooperationText.contains('workshop'),
        _ => cooperationText.contains(cooperationType.toLowerCase()),
      };

  return categoryOk && regionOk && verificationOk && cooperationOk;
}

List<String> _artistFields(Map<String, dynamic> artist) {
  final raw = artist['art_fields'];
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return const [];
  return text.split(RegExp(r'[,，/、]+')).map((item) => item.trim()).toList();
}

List<String> _artistCooperationTypes(Map<String, dynamic> artist) {
  final metadata = _artistMetadata(artist);
  final raw = metadata['cooperation_types'] ?? artist['cooperation_types'];
  if (raw is List) {
    return raw
        .map((item) => _cooperationTypeLabel(item.toString()))
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final intent = artist['cooperation_intent']?.toString().trim();
  if (intent != null && intent.isNotEmpty) {
    if (intent.contains('展')) return const ['展览'];
    if (intent.contains('品牌')) return const ['品牌联名'];
    if (intent.contains('公共')) return const ['公共艺术'];
  }
  return const [];
}

String _cooperationTypeLabel(String value) {
  return switch (value) {
    'exhibition' => '展览',
    'brand' => '品牌联名',
    'public_art' => '公共艺术',
    'workshop' => '讲座工作坊',
    _ => value,
  };
}

Map<String, dynamic> _artistMetadata(Map<String, dynamic> artist) {
  final raw = artist['metadata'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

String _artistHandle(Map<String, dynamic> artist) {
  final raw = artist['handle']?.toString() ??
      artist['username']?.toString() ??
      artist['slug']?.toString();
  final text = raw?.trim();
  if (text != null && text.isNotEmpty) {
    return text.startsWith('@') ? text : '@$text';
  }
  final name = artist['display_name']?.toString().trim() ?? 'artist';
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (cleaned.isNotEmpty) return '@$cleaned';
  return '@artist_${(name.hashCode.abs() % 99999).toString().padLeft(5, '0')}';
}

String _artistVerificationLabel(Map<String, dynamic> artist) {
  final badges = artist['verification_badges'];
  final text = badges?.toString() ?? '';
  if (text.contains('展')) return '展览认证';
  if (text.contains('学') || text.toLowerCase().contains('school')) {
    return '教育背景认证';
  }
  if (text.contains('职业') || text.toLowerCase().contains('career')) {
    return '职业认证';
  }
  return '平台认证艺术家';
}

int _artistInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class _ArtistLibraryHeader extends StatelessWidget {
  final int totalCount;
  final int availableCount;
  final VoidCallback onApply;

  const _ArtistLibraryHeader({
    required this.totalCount,
    required this.availableCount,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.palette_outlined, color: kCobalt),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已入驻艺术家',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount 位已审核 · $availableCount 位可合作',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('入驻'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCobalt,
              side: BorderSide(color: kCobalt.withValues(alpha: 0.32)),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _opportunityTypeLabel(String type) {
  return switch (type.toLowerCase()) {
    'research' => '研究类',
    'collaboration' => '联名合作',
    'residency' => '驻留项目',
    'competition' => '竞赛征集',
    'exhibition' => '展览邀约',
    'workshop' => '工作坊',
    _ => '合作机会',
  };
}

String _formatDeadlineUrgency(dynamic raw) {
  final deadline = DateTime.tryParse(raw?.toString() ?? '');
  if (deadline == null) return '长期开放';

  final now = DateTime.now();
  final diff = deadline.difference(now).inDays;

  if (diff < 0) return '已截止';
  if (diff == 0) return '今日截止';
  if (diff <= 3) return '即将截止';
  if (diff <= 7) return '本周截止';
  return '剩 $diff 天';
}

Color _deadlineColor(dynamic raw, BuildContext context) {
  final deadline = DateTime.tryParse(raw?.toString() ?? '');
  if (deadline == null) return context.artC.ink.withValues(alpha: 0.38);

  final diff = deadline.difference(DateTime.now()).inDays;

  if (diff < 0) return context.artC.ink.withValues(alpha: 0.28);
  if (diff <= 3) return const Color(0xFF8F3F36);
  if (diff <= 7) return const Color(0xFF8A6D32);
  return context.artC.ink.withValues(alpha: 0.48);
}

List<String> _extractOpportunityTags(String? city, String requirements) {
  final tags = <String>[];

  if (city != null && city.isNotEmpty) {
    tags.add(city);
  }

  final reqLower = requirements.toLowerCase();

  if (reqLower.contains('作品集') || reqLower.contains('portfolio')) {
    tags.add('需作品集');
  }
  if (reqLower.contains('学生') || reqLower.contains('student')) {
    tags.add('适合学生');
  }
  if (reqLower.contains('远程') || reqLower.contains('remote')) {
    tags.add('可远程');
  }
  if (reqLower.contains('传统') ||
      reqLower.contains('工艺') ||
      reqLower.contains('craft')) {
    tags.add('传统工艺');
  }
  if (reqLower.contains('设计') || reqLower.contains('design')) {
    tags.add('设计方向');
  }
  if (reqLower.contains('装置') || reqLower.contains('installation')) {
    tags.add('装置方向');
  }

  if (tags.length == 1 && tags[0] == city) {
    tags.add('查看要求');
  }

  return tags;
}
