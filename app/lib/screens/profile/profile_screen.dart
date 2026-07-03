import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../consultation/organization_list_screen.dart';
import '../create/create_post_screen.dart';
import '../mentors/mentor_application_screen.dart';
import '../mentors/mentor_list_screen.dart';
import '../onboarding/art_interest_onboarding_screen.dart';
import '../publish/publish_artist_screen.dart';
import 'application_workspace_screen.dart';
import 'contract_archive_screen.dart';
import 'content_submissions_screen.dart';
import 'creator_center_screen.dart';
import 'identity_verification_screen.dart';
import 'membership_center_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'profile_edit_screen.dart';
import 'public_user_profile_screen.dart';
import 'team_invitations_screen.dart';
import 'package:artsee_app/theme/artsee_theme_controller.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// 我的页 — 完全对齐 _artist_ref ProfileView，接入真实用户数据
/// ═══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onOpenMainTab;
  final ValueChanged<bool>? onDrawerChanged;

  const ProfileScreen({super.key, this.onOpenMainTab, this.onDrawerChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  int _savedSchoolCount = 0;
  int _unreadNotificationCount = 0;
  int _walletPaidAmountCents = 0;
  int _walletPendingOrderCount = 0;
  int _walletPaidOrderCount = 0;
  List<AppCommunityPost> _profileShowcasePosts = const [];
  List<AppCommunityPost> _profileSavedPosts = const [];
  bool _loading = true;
  int _profileShowcaseTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SupabaseService.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final p = await SupabaseService.fetchProfile();
    var savedSchoolCount = 0;
    var unreadNotificationCount = 0;
    var walletPaidAmountCents = 0;
    var walletPendingOrderCount = 0;
    var walletPaidOrderCount = 0;
    var profileShowcasePosts = <AppCommunityPost>[];
    var profileSavedPosts = <AppCommunityPost>[];
    try {
      final saved = await BackendApiService.fetchSavedSchools(limit: 1);
      savedSchoolCount = saved.count ?? saved.data.length;
    } catch (_) {
      savedSchoolCount = 0;
    }
    try {
      unreadNotificationCount =
          await BackendApiService.fetchUnreadNotificationCount();
    } catch (_) {
      unreadNotificationCount = 0;
    }
    try {
      final orders = await BackendApiService.fetchMyOrders(limit: 50);
      for (final order in orders) {
        final status = order['status']?.toString() ?? 'pending';
        final amount = _asInt(order['amount_total']);
        if (status == 'paid') {
          walletPaidOrderCount += 1;
          walletPaidAmountCents += amount;
        }
        if (_profileWalletOrderNeedsPayment(status)) {
          walletPendingOrderCount += 1;
        }
      }
    } catch (_) {
      walletPaidAmountCents = 0;
      walletPendingOrderCount = 0;
      walletPaidOrderCount = 0;
    }
    try {
      final posts = await BackendApiService.fetchCommunityPosts(limit: 50);
      final nonQaPosts = posts
          .where((post) => post.metadata['kind']?.toString() != 'qa')
          .toList();
      final currentUserId = SupabaseService.currentUser?.id;
      final ownPosts = currentUserId == null
          ? const <AppCommunityPost>[]
          : nonQaPosts.where((post) => post.authorId == currentUserId).toList();
      profileShowcasePosts = (ownPosts.isNotEmpty ? ownPosts : nonQaPosts)
          .take(9)
          .toList(growable: false);
    } catch (_) {
      profileShowcasePosts = const [];
    }
    try {
      profileSavedPosts =
          await BackendApiService.fetchSavedCommunityPosts(limit: 20);
    } catch (_) {
      profileSavedPosts = const [];
    }
    if (mounted) {
      setState(() {
        _profile = p;
        _savedSchoolCount = savedSchoolCount;
        _unreadNotificationCount = unreadNotificationCount;
        _walletPaidAmountCents = walletPaidAmountCents;
        _walletPendingOrderCount = walletPendingOrderCount;
        _walletPaidOrderCount = walletPaidOrderCount;
        _profileShowcasePosts = profileShowcasePosts;
        _profileSavedPosts = profileSavedPosts;
        _loading = false;
      });
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
    _load();
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.signOut();
    if (mounted) setState(() => _profile = null);
  }

  String get _nickname {
    final n = _profile?['nickname'] as String?;
    if (n != null && n.isNotEmpty) return n;
    final email = SupabaseService.currentUser?.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Artsee用户';
  }

  String get _avatarUrl => _profile?['avatar_url'] as String? ?? '';

  bool get _isVerified => _profile?['is_verified'] == true;

  bool get _isBusinessUser => _profile?['user_type'] == 'business';

  bool get _hasCompletedOnboarding =>
      _profile?['has_completed_onboarding'] == true;

  String get _roleKey => _profile?['user_role']?.toString() ?? '';

  String get _roleLabel {
    const personal = {
      'student': '艺术学生 / 申请者',
      'artist': '艺术家 / 创作者',
      'collector': '艺术爱好者 / 收藏者',
      'parent': '家长 / 陪同决策者',
    };
    const business = {
      'study_abroad_agency': '艺术留学机构',
      'portfolio_training': '艺术培训 / 作品集机构',
      'gallery_exhibition': '画廊 / 展览机构',
      'event_organizer': '艺术活动主办方',
      'hotel_culture_space': '酒店 / 文旅空间',
      'brand_partner': '品牌合作方',
      'art_media_community': '艺术媒体 / 社群',
      'other_service': '其他艺术服务商',
    };
    return (_isBusinessUser ? business[_roleKey] : personal[_roleKey]) ??
        (_isBusinessUser ? '机构 / 商家入驻' : '个人用户');
  }

  String get _stageLabel {
    final raw = _profile?['portfolio_status']?.toString() ??
        _profile?['current_education_stage']?.toString() ??
        '';
    const stages = {
      'exploring': '刚开始了解',
      'target_ready': '已有目标国家 / 学校',
      'portfolio_preparing': '正在准备作品集',
      'works_ready': '已有部分作品',
      'applying': '正在申请中',
      'admitted': '已录取 / 已在读',
      'pending_business_review': '入驻待审核',
      'just_learning': '刚开始了解',
      'child_has_interest': '孩子已有艺术方向',
      'target_country': '已有目标国家 / 院校',
      'application_planning': '正在规划申请',
    };
    return stages[raw] ??
        (raw.isEmpty ? (_isBusinessUser ? '未认证' : '待补全') : raw);
  }

  String get _stageShortLabel {
    final label = _stageLabel;
    const shortLabels = {
      '刚开始了解': '探索中',
      '已有目标国家 / 学校': '定校中',
      '正在准备作品集': '作品集中',
      '已有部分作品': '作品中',
      '正在申请中': '申请中',
      '已录取 / 已在读': '已录取',
      '孩子已有艺术方向': '定方向',
      '已有目标国家 / 院校': '定校中',
      '正在规划申请': '规划中',
      '待补全': '待完善',
    };
    return shortLabels[label] ?? label;
  }

  String get _cityLabel {
    final city = _profile?['city_preference']?.toString();
    final location = _profile?['location']?.toString();
    return (city != null && city.isNotEmpty)
        ? city
        : (location != null && location.isNotEmpty ? location : '城市待补全');
  }

  String get _profileHandle {
    final raw = _profile?['handle']?.toString() ??
        _profile?['username']?.toString() ??
        SupabaseService.currentUser?.email?.split('@').first;
    final handle = raw?.trim();
    if (handle != null && handle.isNotEmpty) {
      return '@${handle.replaceFirst(RegExp(r'^@'), '').replaceAll(RegExp(r'\s+'), '_')}';
    }
    return '@artsee_user';
  }

  String get _profileBio {
    final raw = _profile?['bio']?.toString() ??
        _profile?['introduction']?.toString() ??
        _profile?['description']?.toString();
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    if (_isBusinessUser) {
      return '位于$_cityLabel，提供$_roleLabel相关服务，案例和团队信息会沉淀在公开主页。';
    }
    if (_roleKey == 'artist') {
      return '关注${_directionSummary()}，持续更新作品、创作过程和展览记录。';
    }
    if (_roleKey == 'student') {
      return '正在整理作品集、申请动态和院校经验，关注${_directionSummary()}。';
    }
    if (_roleKey == 'mentor') {
      return '分享作品集案例、申请判断和面试经验，帮助学生理解作品与院校匹配。';
    }
    return '参与艺术社区讨论，收藏作品、院校案例和申请经验。';
  }

  PublicUserProfileKind get _publicProfileKind {
    if (_roleKey == 'artist') return PublicUserProfileKind.artist;
    if (_roleKey == 'student') return PublicUserProfileKind.student;
    if (_roleKey == 'mentor') return PublicUserProfileKind.mentor;
    return PublicUserProfileKind.user;
  }

  int get _followersCount => _profileInt(
        ['followers_count', 'follower_count'],
        _isBusinessUser
            ? 1280
            : _roleKey == 'artist'
                ? 842
                : _roleKey == 'mentor'
                    ? 536
                    : 96,
      );

  int get _followingCount => _profileInt(
        ['following_count', 'followings_count'],
        28 + _savedSchoolCount,
      );

  String get _businessName {
    for (final item in _asStringList(_profile?['target_majors'])) {
      if (item.startsWith('机构名称：')) {
        return item.replaceFirst('机构名称：', '').trim();
      }
    }
    return _nickname;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  int _profileInt(List<String> keys, int fallback) {
    for (final key in keys) {
      final value = _profile?[key];
      final parsed = _asInt(value);
      if (parsed > 0) return parsed;
    }
    return fallback;
  }

  String _joinLabels(List<String> raw, Map<String, String> labels,
      {String fallback = '待补全'}) {
    final items = raw
        .where((item) => !item.startsWith('business_'))
        .map((item) => labels[item] ?? item)
        .take(3)
        .toList();
    return items.isEmpty ? fallback : items.join('、');
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return _buildGuestView();
    }
    if (_loading) {
      return Scaffold(
        backgroundColor: context.artC.porcelain,
        body: const Center(
            child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5)),
      );
    }
    return _buildProfileView();
  }

  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 8,
              child: ListenableBuilder(
                listenable: ArtseeThemeController.instance,
                builder: (context, _) {
                  final dark = ArtseeThemeController.instance.isDark;
                  return IconButton(
                    onPressed: () => ArtseeThemeController.instance.toggle(),
                    icon: Icon(
                      dark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                      color: context.artC.ink.withValues(alpha: 0.55),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: context.artC.silver.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '艺',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: kCobalt),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '登录后解锁全部功能',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.artC.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '申请追踪 · 案例分享 · 论坛互动',
                      style: TextStyle(
                          fontSize: 13,
                          color: context.artC.ink.withValues(alpha: 0.45)),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _openLogin,
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: kCobalt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Center(
                          child: Text(
                            '登录 / 注册',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
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
    );
  }

  Widget _buildProfileView() {
    final bottomSpacer = MediaQuery.of(context).padding.bottom + 200;

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      drawerScrimColor: Colors.black.withValues(alpha: 0.36),
      drawer: _buildProfileDrawer(),
      onDrawerChanged: widget.onDrawerChanged,
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (scaffoldContext) => SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomSpacer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(
                  onMenuTap: () {
                    widget.onDrawerChanged?.call(true);
                    Scaffold.of(scaffoldContext).openDrawer();
                  },
                ),
                Transform.translate(
                  offset: const Offset(0, -82),
                  child: _buildProfileContentPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({required VoidCallback onMenuTap}) {
    final title = _isBusinessUser ? _businessName : _nickname;
    final topInset = MediaQuery.of(context).padding.top;
    final coverUrl = _coverUrl;
    final heroHeight = topInset + 318.0;
    const avatarSize = 86.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ProfileCoverFallback(
                      seed: _profileHandle,
                    ),
                  )
                : _ProfileCoverFallback(seed: _profileHandle),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.54),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 22,
            right: 22,
            child: Row(
              children: [
                _HeroIconButton(
                  icon: Icons.menu_rounded,
                  onTap: onMenuTap,
                ),
                const Spacer(),
                _HeroEditButton(
                  onTap: !_isBusinessUser && !_hasCompletedOnboarding
                      ? _openOnboardingEditor
                      : _openEditProfile,
                ),
                const SizedBox(width: 12),
                _HeroIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () => _openPlaceholder('我的名片'),
                ),
                const SizedBox(width: 12),
                _HeroIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: _isBusinessUser
                      ? _openBusinessPublicProfile
                      : _openPublicProfile,
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            right: 24,
            top: topInset + 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HeroProfileAvatar(
                  size: avatarSize,
                  imageUrl: _avatarUrl,
                  fallback: title,
                  verified: _isVerified,
                  business: _isBusinessUser,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Artsee ID：${_profileHandle.replaceFirst('@', '')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.68),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'IP：$_cityLabel · $_stageShortLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            right: 24,
            top: topInset + 194,
            child: _HeroStatsRow(
              followers: _followersCount,
              following: _followingCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContentPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _buildProfileShowcaseSection(),
    );
  }

  Widget _buildProfileDrawer() {
    final drawerWidth = (MediaQuery.of(context).size.width * 0.82)
        .clamp(300.0, 348.0)
        .toDouble();
    final title = _isBusinessUser ? _businessName : _nickname;
    final drawerBottomPadding = MediaQuery.of(context).padding.bottom + 132;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: context.artC.porcelain,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Builder(
          builder: (drawerContext) {
            void run(VoidCallback action) {
              Navigator.of(drawerContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) action();
              });
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(18, 18, 18, drawerBottomPadding),
              children: [
                Row(
                  children: [
                    _InstagramAvatar(
                      imageUrl: _avatarUrl,
                      fallback: title,
                      verified: _isVerified,
                      business: _isBusinessUser,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildDrawerSection([
                  _MenuAction(
                      '编辑主页',
                      Icons.edit_outlined,
                      !_isBusinessUser && !_hasCompletedOnboarding
                          ? _openOnboardingEditor
                          : _openEditProfile),
                  _MenuAction(
                      '创作者中心', Icons.auto_awesome_outlined, _openCreatorCenter),
                  _MenuAction(
                      '艺术家入驻', Icons.palette_outlined, _openArtistOnboarding),
                  _MenuAction(
                    _isBusinessUser ? '查看机构主页' : '查看公开主页',
                    Icons.open_in_new_rounded,
                    _isBusinessUser
                        ? _openBusinessPublicProfile
                        : _openPublicProfile,
                  ),
                ], run),
                _buildDrawerSection([
                  _MenuAction(
                    '申请计划',
                    Icons.assignment_turned_in_outlined,
                    () => _openApplicationWorkspace(
                      ApplicationWorkspaceKind.applicationPlan,
                    ),
                  ),
                  _MenuAction(
                    '作品集任务',
                    Icons.auto_awesome_mosaic_outlined,
                    () => _openApplicationWorkspace(
                      ApplicationWorkspaceKind.portfolioTasks,
                    ),
                  ),
                  _MenuAction(
                    '我的活动',
                    Icons.event_available_outlined,
                    () => widget.onOpenMainTab?.call(2),
                  ),
                  _MenuAction(
                    '我的合作',
                    Icons.handshake_outlined,
                    () => widget.onOpenMainTab?.call(2),
                  ),
                ], run),
                _buildDrawerSection([
                  _MenuAction('我的草稿', Icons.inventory_2_outlined,
                      () => _openPlaceholder('我的草稿')),
                  _MenuAction(
                      '发布记录', Icons.layers_outlined, _openContentSubmissions),
                  _MenuAction('我的收藏', Icons.bookmark_border_rounded,
                      () => _openPlaceholder('我的收藏')),
                  _MenuAction('浏览记录', Icons.history_rounded,
                      () => _openPlaceholder('浏览记录')),
                ], run),
                _buildDrawerSection([
                  _MenuAction(
                      '消息通知', Icons.notifications_outlined, _openNotifications,
                      badgeText: _unreadNotificationCount > 0
                          ? '$_unreadNotificationCount'
                          : null),
                  _MenuAction(
                      '团队邀请', Icons.group_add_outlined, _openTeamInvitations),
                  if (!_isBusinessUser) ...[
                    _MenuAction(
                        '导师中心', Icons.school_outlined, _openMentorCenter),
                    _MenuAction(
                        '导师预约', Icons.event_note_outlined, _openMentorBookings),
                    _MenuAction('导师咨询', Icons.forum_outlined, _openMentors),
                  ],
                ], run),
                _buildDrawerSection([
                  _MenuAction(
                      '咨询与订单', Icons.receipt_long_outlined, _openOrders),
                  _MenuAction('会员中心', Icons.workspace_premium_outlined,
                      _openMembershipCenter),
                  _MenuAction('身份认证', Icons.verified_outlined,
                      _openIdentityVerification),
                  _MenuAction(
                      '合同存档', Icons.description_outlined, _openContractArchive),
                ], run),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DrawerBottomAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: '扫一扫',
                        onTap: () => run(() => _openPlaceholder('扫一扫')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DrawerBottomAction(
                        icon: Icons.headset_mic_outlined,
                        label: '帮助与客服',
                        onTap: () => run(() => _openPlaceholder('帮助与客服')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DrawerBottomAction(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        onTap: () => run(_openSettings),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerSection(
    List<_MenuAction> items,
    void Function(VoidCallback action) run,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return _DrawerMenuTile(
            item: item,
            showDivider: index < items.length - 1,
            onTap: () => run(item.onTap),
          );
        }),
      ),
    );
  }

  String get _coverUrl {
    final raw = _profile?['cover_url']?.toString() ??
        _profile?['banner_url']?.toString() ??
        _profile?['background_url']?.toString() ??
        '';
    if (raw.trim().isNotEmpty) return raw.trim();
    return 'https://picsum.photos/seed/artsee_profile_cover_${Uri.encodeComponent(_profileHandle)}/900/700';
  }

  String _directionSummary({String fallback = '待补全'}) {
    const directionLabels = {
      'fine_art': '纯艺',
      'design': '设计',
      'photo_video': '影像 / 摄影',
      'new_media': '新媒体',
      'curation': '策展',
      'art_market': '艺术市场',
      'art_education': '艺术教育',
      'space_culture': '空间 / 文旅',
    };
    return _joinLabels(
      _asStringList(_profile?['target_directions']),
      directionLabels,
      fallback: fallback,
    );
  }

  Future<void> _openEditProfile() async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(initialProfile: _profile),
      ),
    );
    if (refreshed == true) _load();
  }

  Future<void> _openOnboardingEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ArtInterestOnboardingScreen(
          onCompleted: () => Navigator.of(context).pop(),
        ),
      ),
    );
    _load();
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SettingsScreen(
          isBusinessUser: _isBusinessUser,
          onSignOut: _signOut,
        ),
      ),
    );
  }

  void _closeWorkspaceThen(VoidCallback action) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _openPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title - 节点二待实现')),
    );
  }

  void _openPublicProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfileScreen(
          name: _isBusinessUser ? _businessName : _nickname,
          handle: _profileHandle,
          avatarUrl: _avatarUrl,
          roleLabel: _roleLabel,
          bio: _profileBio,
          kind: _publicProfileKind,
          featuredAnswerContext: '我的讨论回答',
          featuredAnswer: '回答、评论和社区观点会沉淀在这里，方便别人从讨论进入主页后继续了解我。',
        ),
      ),
    );
  }

  void _openBusinessPublicProfile() {
    final organizationId = _profile?['organization_id']?.toString() ??
        _profile?['primary_organization_id']?.toString();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganizationDetailScreen(
          initialOrg: {
            if (organizationId != null && organizationId.isNotEmpty)
              'id': organizationId,
            'name': _businessName,
            'type': _roleKey,
            'status': _isVerified ? 'active' : 'pending',
            'verification_status': _isVerified ? 'verified' : 'pending',
            'city': _cityLabel,
            'focus_areas': _asStringList(_profile?['target_directions']),
            'supports_online': true,
            'supports_offline': false,
            'rating': 0,
            'review_count': 0,
            'contract_count': 0,
            'metadata': {
              'summary': _profileBio,
              if (_avatarUrl.isNotEmpty) 'avatar_url': _avatarUrl,
              'response_speed': '2小时内',
            },
          },
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          isBusinessUser: _isBusinessUser,
        ),
      ),
    );
    _load();
  }

  Future<void> _openMentors() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MentorListScreen()),
    );
    _load();
  }

  Future<void> _openMentorCenter() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MentorServicesScreen(),
      ),
    );
    _load();
  }

  Future<void> _openMentorBookings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MentorBookingsScreen(),
      ),
    );
    _load();
  }

  Future<void> _openCreatorCenter() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CreatorCenterScreen(),
      ),
    );
    _load();
  }

  Future<void> _openArtistOnboarding() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PublishArtistScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openContentSubmissions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ContentSubmissionsScreen(),
      ),
    );
    _load();
  }

  Future<void> _openIdentityVerification() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IdentityVerificationScreen(
          initialType: _isBusinessUser ? 'business' : _roleKey,
          initialBusinessRole: _isBusinessUser ? _roleKey : null,
        ),
      ),
    );
    _load();
  }

  Future<void> _openTeamInvitations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TeamInvitationsScreen(),
      ),
    );
    _load();
  }

  Widget _buildProfileShowcaseSection() {
    const tabs = ['动态', '收藏', '钱包'];
    final selectedTab = _profileShowcaseTab.clamp(0, tabs.length - 1).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileShowcaseTabStrip(
          tabs: tabs,
          selectedIndex: selectedTab,
          onChanged: (index) => setState(() => _profileShowcaseTab = index),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildProfileShowcaseBody(selectedTab),
        ),
      ],
    );
  }

  Widget _buildProfileShowcaseBody(int selectedTab) {
    return switch (selectedTab) {
      0 => _ProfileWorksPreview(
          key: const ValueKey('activity'),
          posts: _profileShowcasePosts,
          emptyTitle: '还没有动态',
          emptySubtitle: '发布作品、现场或灵感记录后，会出现在这里。',
          onPostTap: _openCommunityPost,
          onEmptyTap: _openCreatePost,
        ),
      1 => _ProfileWorksPreview(
          key: const ValueKey('saved'),
          posts: _profileSavedPosts,
          emptyTitle: '还没有收藏',
          emptySubtitle: '去发现页收藏喜欢的作品、经验和灵感记录。',
          onPostTap: _openCommunityPost,
          onEmptyTap: _openExploreTab,
        ),
      _ => _ProfileWalletPreview(
          key: const ValueKey('wallet'),
          paidAmountCents: _walletPaidAmountCents,
          pendingOrderCount: _walletPendingOrderCount,
          paidOrderCount: _walletPaidOrderCount,
          onOrdersTap: _openOrders,
          onMembershipTap: _openMembershipCenter,
          onCouponsTap: () => _openPlaceholder('优惠券'),
          onTransactionsTap: () => _openPlaceholder('交易记录'),
        ),
    };
  }

  Future<void> _openCommunityPost(AppCommunityPost post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
    _load();
  }

  Future<void> _openCreatePost() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreatePostScreen()),
    );
    _load();
  }

  void _openExploreTab() {
    final openMainTab = widget.onOpenMainTab;
    if (openMainTab != null) {
      openMainTab(2);
      return;
    }
    _openPlaceholder('发现');
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
    );
  }

  void _openMembershipCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MembershipCenterScreen()),
    );
  }

  void _openContractArchive() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContractArchiveScreen()),
    );
  }

  void _openApplicationWorkspace(ApplicationWorkspaceKind kind) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationWorkspaceScreen(
          kind: kind,
          onOpenSchools: () => _closeWorkspaceThen(
            () => widget.onOpenMainTab?.call(1),
          ),
          onOpenExplore: () => _closeWorkspaceThen(
            () => widget.onOpenMainTab?.call(2),
          ),
          onOpenProfileSetup: () => _closeWorkspaceThen(_openOnboardingEditor),
        ),
      ),
    )
        .then((_) {
      if (mounted) _load();
    });
  }
}

class _MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;

  const _MenuAction(
    this.label,
    this.icon,
    this.onTap, {
    this.badgeText,
  });
}

class _MenuBadge extends StatelessWidget {
  final String text;

  const _MenuBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileCoverFallback extends StatelessWidget {
  final String seed;

  const _ProfileCoverFallback({required this.seed});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF2F3F66),
      const Color(0xFF6E5D47),
      const Color(0xFF465C4E),
      const Color(0xFF5D5869),
    ];
    final color = colors[seed.hashCode.abs() % colors.length];
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -18,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -56,
            bottom: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class _HeroEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 5),
            Text(
              '编辑主页',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
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

class _HeroProfileAvatar extends StatelessWidget {
  final double size;
  final String imageUrl;
  final String fallback;
  final bool verified;
  final bool business;

  const _HeroProfileAvatar({
    required this.size,
    required this.imageUrl,
    required this.fallback,
    required this.verified,
    required this.business,
  });

  @override
  Widget build(BuildContext context) {
    final ch = fallback.isNotEmpty ? fallback.substring(0, 1) : '艺';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _heroAvatarFallback(ch),
                  )
                : _heroAvatarFallback(ch),
          ),
        ),
        Positioned(
          right: -1,
          bottom: 5,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: verified ? kCobalt : const Color(0xFF9AA3B2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Icon(
              business ? Icons.storefront_outlined : Icons.check_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroAvatarFallback(String ch) {
    return Container(
      color: const Color(0xFFEAF1FF),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroStatsRow extends StatelessWidget {
  final int followers;
  final int following;

  const _HeroStatsRow({
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('关注', following),
      ('粉丝', followers),
    ];
    return Row(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: 22),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _compactProfileNumber(item.$2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: ' ${item.$1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  final _MenuAction item;
  final bool showDivider;
  final VoidCallback onTap;

  const _DrawerMenuTile({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.artC.ink.withValues(alpha: 0.84);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Row(
              children: [
                const SizedBox(width: 18),
                Icon(
                  item.icon,
                  size: 26,
                  color: context.artC.ink.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (item.badgeText != null) ...[
                  _MenuBadge(text: item.badgeText!),
                  const SizedBox(width: 10),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: context.artC.ink.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Divider(
                height: 1,
                color: context.artC.silver.withValues(alpha: 0.22),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerBottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerBottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.artC.cardIconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(
              icon,
              size: 25,
              color: context.artC.ink.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _compactProfileNumber(int value) {
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

bool _profileWalletOrderNeedsPayment(String status) {
  return status == 'pending' ||
      status == 'checkout_created' ||
      status == 'failed' ||
      status == 'expired';
}

String _profileMoneyFromCents(int cents) {
  final amount = cents / 100;
  return '¥${amount.toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
}

class _ProfileShowcaseTabStrip extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ProfileShowcaseTabStrip({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          ...List.generate(tabs.length, (index) {
            final active = selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tabs[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? context.artC.ink
                            : context.artC.ink.withValues(alpha: 0.42),
                        fontSize: 17,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: active ? 28 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: kCobalt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('主页内容搜索 - 节点二待实现')),
              );
            },
            child: SizedBox(
              width: 42,
              height: 44,
              child: Icon(
                Icons.search_rounded,
                size: 28,
                color: context.artC.ink.withValues(alpha: 0.56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileWorksPreview extends StatelessWidget {
  final List<AppCommunityPost> posts;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<AppCommunityPost> onPostTap;
  final VoidCallback onEmptyTap;

  const _ProfileWorksPreview({
    super.key,
    required this.posts,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onPostTap,
    required this.onEmptyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEmptyTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: kCobalt,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emptyTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      emptySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.28),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        mainAxisExtent: 238,
      ),
      itemBuilder: (_, index) {
        final post = posts[index];
        return _ProfileWorkTile(
          post: post,
          index: index,
          onTap: () => onPostTap(post),
        );
      },
    );
  }
}

class _ProfileWorkTile extends StatelessWidget {
  final AppCommunityPost post;
  final int index;
  final VoidCallback onTap;

  const _ProfileWorkTile({
    required this.post,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : '';
    final coverUrl = imageUrl.isNotEmpty
        ? imageUrl
        : 'https://picsum.photos/seed/artsee_profile_${Uri.encodeComponent(post.id)}/640/760';
    final title = post.title.trim().isNotEmpty
        ? post.title.trim()
        : (post.body?.trim().isNotEmpty == true ? post.body!.trim() : '作品动态');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
              color: context.artC.ink.withValues(alpha: 0.026),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _ProfileWorkFallback(index: index),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (post.imageUrls.length > 1)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.44),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.collections_outlined,
                          color: Colors.white,
                          size: 14,
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
                  height: 1.24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
              child: Row(
                children: [
                  Icon(
                    post.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 14,
                    color: post.likedByMe
                        ? const Color(0xFFE64565)
                        : context.artC.ink.withValues(alpha: 0.34),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _compactProfileNumber(post.likeCount),
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.42),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 13,
                    color: context.artC.ink.withValues(alpha: 0.32),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _compactProfileNumber(post.commentCount),
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.42),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
}

class _ProfileWorkFallback extends StatelessWidget {
  final int index;

  const _ProfileWorkFallback({required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const [Color(0xFFE7EEF8), Color(0xFFB9C7D7)],
      const [Color(0xFFF0ECE4), Color(0xFFBEB8AA)],
      const [Color(0xFFE8F3EE), Color(0xFFB2CBC0)],
      const [Color(0xFFF4E8EA), Color(0xFFD2B5BD)],
    ][index % 4];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white.withValues(alpha: 0.72),
          size: 30,
        ),
      ),
    );
  }
}

class _ProfileWalletPreview extends StatelessWidget {
  final int paidAmountCents;
  final int pendingOrderCount;
  final int paidOrderCount;
  final VoidCallback onOrdersTap;
  final VoidCallback onMembershipTap;
  final VoidCallback onCouponsTap;
  final VoidCallback onTransactionsTap;

  const _ProfileWalletPreview({
    super.key,
    required this.paidAmountCents,
    required this.pendingOrderCount,
    required this.paidOrderCount,
    required this.onOrdersTap,
    required this.onMembershipTap,
    required this.onCouponsTap,
    required this.onTransactionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final paidAmount = _profileMoneyFromCents(paidAmountCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.artC.deepPanel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Artsee 钱包',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kCobalt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '安全托管',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '可用余额',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '¥0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '累计已支付',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      paidAmount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: _WalletMetric(label: '优惠券', value: '0张')),
            const SizedBox(width: 8),
            Expanded(
              child: _WalletMetric(label: '待支付', value: '$pendingOrderCount笔'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WalletMetric(label: '已支付', value: '$paidOrderCount笔'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.18,
          children: [
            _WalletActionTile(
              icon: Icons.receipt_long_outlined,
              title: '我的订单',
              subtitle:
                  pendingOrderCount > 0 ? '$pendingOrderCount 笔待处理' : '查看购买记录',
              badgeText: pendingOrderCount > 0 ? '$pendingOrderCount' : null,
              onTap: onOrdersTap,
            ),
            _WalletActionTile(
              icon: Icons.workspace_premium_outlined,
              title: '会员权益',
              subtitle: '权益与服务',
              onTap: onMembershipTap,
            ),
            _WalletActionTile(
              icon: Icons.local_offer_outlined,
              title: '优惠券',
              subtitle: '抵扣券与活动券',
              onTap: onCouponsTap,
            ),
            _WalletActionTile(
              icon: Icons.sync_alt_rounded,
              title: '交易记录',
              subtitle: '支付与退款',
              onTap: onTransactionsTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletMetric extends StatelessWidget {
  final String label;
  final String value;

  const _WalletMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
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
            label,
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
    );
  }
}

class _WalletActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  const _WalletActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: kCobalt, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: kCobalt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.48),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
}

class _InstagramAvatar extends StatelessWidget {
  final String imageUrl;
  final String fallback;
  final bool verified;
  final bool business;

  const _InstagramAvatar({
    required this.imageUrl,
    required this.fallback,
    required this.verified,
    required this.business,
  });

  @override
  Widget build(BuildContext context) {
    final ch = fallback.isNotEmpty ? fallback.substring(0, 1) : '艺';
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: verified
                  ? kCobalt
                  : context.artC.silver.withValues(alpha: 0.75),
              width: 1.4,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.artC.cardIconBg,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallbackText(ch),
                    )
                  : _avatarFallbackText(ch),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: verified
                  ? kCobalt
                  : context.artC.silver.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              business ? Icons.storefront_outlined : Icons.person_rounded,
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallbackText(String ch) {
    return Center(
      child: Text(
        ch,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: kCobalt,
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  final bool isBusinessUser;
  final VoidCallback onSignOut;

  const _SettingsScreen({
    required this.isBusinessUser,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsSection(
            title: '账号与安全',
            items: [
              _SettingsItem(
                icon: Icons.lock_outline,
                title: '修改密码',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.phone_outlined,
                title: '手机号绑定',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.email_outlined,
                title: '邮箱绑定',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          _SettingsSection(
            title: '通知设置',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: '推送通知',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.message_outlined,
                title: '消息通知',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          _SettingsSection(
            title: '显示与偏好',
            items: [
              _SettingsItem(
                icon: ArtseeThemeController.instance.isDark
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round,
                title: '深色模式',
                trailing: Switch(
                  value: ArtseeThemeController.instance.isDark,
                  onChanged: (_) => ArtseeThemeController.instance.toggle(),
                  activeThumbColor: kCobalt,
                ),
                onTap: () => ArtseeThemeController.instance.toggle(),
              ),
            ],
          ),
          _SettingsSection(
            title: '关于',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                title: '关于艺见心',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: '用户协议',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.help_outline,
                title: '帮助与反馈',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSignOut();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '退出登录',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中...')),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.5),
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.artC.ink.withValues(alpha: 0.7)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.artC.ink,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: context.artC.ink.withValues(alpha: 0.3),
          ),
      onTap: onTap,
    );
  }
}
