import 'dart:ui';

import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'application/application_screen.dart';
import 'auth/login_screen.dart';
import 'create/create_post_screen.dart';
import 'home/ai_home_screen.dart';
import 'home/home_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/orders_screen.dart';
import 'profile/profile_screen.dart';
import 'programs/program_list_enhanced_screen.dart';
import 'schools/school_list_screen.dart';
import '../services/supabase_service.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// Artiqore 艺衡 · 青花瓷典藏版 — 总入口（对齐艺术家 Web 原型）
/// 底部：悬浮式深色胶囊导航；右下：情境化「+」按钮
/// 子页：首页、申请、社区、消息；个人入口收进左侧抽屉。
/// ═══════════════════════════════════════════════════════════════

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _applicationTabIndex = 0;
  int _communityTabIndex = 0;
  bool _applicationSearchActive = false;
  bool _communitySearchActive = false;
  bool _aiNavigationRevealed = true;
  int _aiSidebarRequestToken = 0;
  int _homeScreenRefreshToken = 0;
  final TextEditingController _messageSearchController =
      TextEditingController();

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: '申请',
    ),
    _NavItem(
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      label: '社区',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      label: '消息',
    ),
  ];

  Future<void> _openCreatePost() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (!mounted || created != true) return;
    setState(() {
      _currentIndex = 2;
      _homeScreenRefreshToken++;
    });
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(kRadiusLarge)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF5).withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(kRadiusLarge)),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6), width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.artC.ink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSheetOption(
                          icon: Icons.add_photo_alternate_outlined,
                          label: '发布图文',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openCreatePost();
                          },
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.artC.ink,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMedium)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kCobalt.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: kCobalt, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.artC.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLoginOrProfile() async {
    if (!SupabaseService.isLoggedIn) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    _showProfileDrawer();
  }

  Future<void> _showProfileDrawer() async {
    if (!SupabaseService.isLoggedIn) {
      await _openLoginOrProfile();
      return;
    }
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '个人菜单',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _ProfileDrawerPanel(
            onProfileTap: () {
              Navigator.of(ctx).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              );
            },
            onSettingsTap: () {
              Navigator.of(ctx).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const _DrawerFeatureScreen(
                    title: '设置',
                    subtitle: '账号、安全、通知和显示设置都会收在这里。',
                    icon: Icons.settings_outlined,
                    actions: ['账号与安全', '通知设置', '显示与主题', '隐私设置'],
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  bool _currentApplicationToolsVisible(int tabIndex) {
    return switch (tabIndex) {
      0 => SchoolListScreen.schoolListKey.currentState?.searchToolsVisible ??
          false,
      1 => ProgramListEnhancedScreen
              .programListKey.currentState?.searchToolsVisible ??
          false,
      _ => false,
    };
  }

  @override
  void dispose() {
    _messageSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final headerHeight = _currentIndex == 0 ? 35.0 : 56.0;
    final showFloatingNav = _currentIndex != 0 || _aiNavigationRevealed;

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: statusBarHeight + headerHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                AiHomeScreen(
                  navigationRevealed: _aiNavigationRevealed,
                  onRevealNavigation: () {
                    if (!_aiNavigationRevealed) {
                      setState(() => _aiNavigationRevealed = true);
                    }
                  },
                  onHideNavigation: () {
                    if (_aiNavigationRevealed) {
                      setState(() => _aiNavigationRevealed = false);
                    }
                  },
                  sidebarRequestToken: _aiSidebarRequestToken,
                ),
                ApplicationScreen(
                  tabIndex: _applicationTabIndex,
                  onSchoolSearchToolsChanged: (visible) {
                    if (_currentIndex == 1 &&
                        _applicationTabIndex == 0 &&
                        _applicationSearchActive != visible) {
                      setState(() => _applicationSearchActive = visible);
                    }
                  },
                  onProgramSearchToolsChanged: (visible) {
                    if (_currentIndex == 1 &&
                        _applicationTabIndex == 1 &&
                        _applicationSearchActive != visible) {
                      setState(() => _applicationSearchActive = visible);
                    }
                  },
                ),
                HomeScreen(
                  key: ValueKey('home_$_homeScreenRefreshToken'),
                  role: _communityTabIndex == 0
                      ? CommunityRole.student
                      : CommunityRole.artist,
                  searchActive: _communitySearchActive,
                ),
                const MessagesScreen(),
              ],
            ),
          ),
          Positioned(
            top: statusBarHeight,
            left: 0,
            right: 0,
            child: _Header(
              height: headerHeight,
              leadingIcon: _currentIndex == 0
                  ? Icons.history_rounded
                  : Icons.person_outline_rounded,
              leadingTooltip: _currentIndex == 0 ? '最近聊天' : '我的',
              onLeadingTap: _currentIndex == 0
                  ? () => setState(() => _aiSidebarRequestToken++)
                  : () => _openLoginOrProfile(),
              showLeading: _currentIndex != 1,
              applicationTabIndex:
                  _currentIndex == 1 ? _applicationTabIndex : null,
              communityTabIndex: _currentIndex == 2 ? _communityTabIndex : null,
              onApplicationTabChanged: (index) {
                setState(() {
                  _applicationTabIndex = index;
                  _applicationSearchActive =
                      _currentApplicationToolsVisible(index);
                });
              },
              searchActive: (_currentIndex == 1 && _applicationSearchActive) ||
                  (_currentIndex == 2 && _communitySearchActive),
              onSearchTap: () {
                if (_currentIndex == 1 && _applicationTabIndex == 0) {
                  final visible = SchoolListScreen.schoolListKey.currentState
                      ?.toggleSearchTools();
                  if (visible != null) {
                    setState(() => _applicationSearchActive = visible);
                  }
                } else if (_currentIndex == 1 && _applicationTabIndex == 1) {
                  final visible = ProgramListEnhancedScreen
                      .programListKey.currentState
                      ?.toggleSearchTools();
                  if (visible != null) {
                    setState(() => _applicationSearchActive = visible);
                  }
                } else if (_currentIndex == 2) {
                  setState(() {
                    _communitySearchActive = !_communitySearchActive;
                  });
                }
              },
              onCommunityTabChanged: (index) {
                setState(() => _communityTabIndex = index);
              },
              searchController:
                  _currentIndex == 3 ? _messageSearchController : null,
              searchHint: '搜索消息、联系人、提醒',
              onSearchChanged: (value) {
                messagesSearchQueryNotifier.value = value;
              },
              onSearchClear: () {
                _messageSearchController.clear();
                messagesSearchQueryNotifier.value = '';
              },
            ),
          ),
          if (showFloatingNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (_currentIndex == 0 &&
                      details.primaryDelta != null &&
                      details.primaryDelta! > 8) {
                    setState(() => _aiNavigationRevealed = false);
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_currentIndex == 2)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 16, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _ArtiqoreFab(onPressed: _showCreateSheet),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Center(child: _buildFloatingNav()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: context.artC.ink.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              return _NavButton(
                item: item,
                isSelected: _currentIndex == index,
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                    if (index == 0) {
                      _aiNavigationRevealed = true;
                    }
                  });
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final double height;
  final IconData leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeadingTap;
  final bool showLeading;
  final int? applicationTabIndex;
  final int? communityTabIndex;
  final ValueChanged<int>? onApplicationTabChanged;
  final ValueChanged<int>? onCommunityTabChanged;
  final bool searchActive;
  final VoidCallback? onSearchTap;
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const _Header({
    required this.height,
    required this.leadingIcon,
    required this.leadingTooltip,
    this.onLeadingTap,
    this.showLeading = true,
    this.applicationTabIndex,
    this.communityTabIndex,
    this.onApplicationTabChanged,
    this.onCommunityTabChanged,
    this.searchActive = false,
    this.onSearchTap,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
    this.onSearchClear,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  @override
  Widget build(BuildContext context) {
    const topControlSize = 44.0;
    final applicationTabIndex = widget.applicationTabIndex;
    final communityTabIndex = widget.communityTabIndex;
    final searchController = widget.searchController;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.95),
        border: Border(
          bottom:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.15)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (widget.showLeading) ...[
            GestureDetector(
              onTap: widget.onLeadingTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: topControlSize,
                height: topControlSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: context.artC.silver.withValues(alpha: 0.65)),
                ),
                alignment: Alignment.center,
                child: Tooltip(
                  message: widget.leadingTooltip,
                  child: Icon(
                    widget.leadingIcon,
                    size: 22,
                    color: context.artC.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (applicationTabIndex != null) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  final labels = ['院校', '专业', '案例', '我的'];
                  final active = applicationTabIndex == index;
                  return GestureDetector(
                    onTap: () => widget.onApplicationTabChanged?.call(index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: topControlSize,
                      width: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            labels[index],
                            style: TextStyle(
                              color: active
                                  ? context.artC.ink
                                  : context.artC.ink.withValues(alpha: 0.34),
                              fontSize: 17,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: active ? 24 : 0,
                            height: 2,
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
              ),
            ),
            if (applicationTabIndex < 2)
              SizedBox(
                width: topControlSize,
                height: topControlSize,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: widget.searchActive
                        ? kCobalt.withValues(alpha: 0.08)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: widget.onSearchTap,
                    icon: Icon(
                      widget.searchActive
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                    ),
                    color: widget.searchActive ? kCobalt : context.artC.ink,
                    iconSize: widget.searchActive ? 26 : 28,
                    padding: EdgeInsets.zero,
                    tooltip: widget.searchActive ? '收起搜索' : '搜索',
                  ),
                ),
              )
            else
              const SizedBox(width: topControlSize, height: topControlSize),
          ] else if (communityTabIndex != null) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(2, (index) {
                  final labels = ['学生', '艺术家'];
                  final active = communityTabIndex == index;
                  return GestureDetector(
                    onTap: () => widget.onCommunityTabChanged?.call(index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: topControlSize,
                      width: 86,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            labels[index],
                            style: TextStyle(
                              color: active
                                  ? context.artC.ink
                                  : context.artC.ink.withValues(alpha: 0.34),
                              fontSize: 17,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: active ? 24 : 0,
                            height: 2,
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
              ),
            ),
            SizedBox(
              width: topControlSize,
              height: topControlSize,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: widget.searchActive
                      ? kCobalt.withValues(alpha: 0.08)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: widget.onSearchTap,
                  icon: Icon(
                    widget.searchActive
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                  ),
                  color: widget.searchActive ? kCobalt : context.artC.ink,
                  iconSize: widget.searchActive ? 26 : 28,
                  padding: EdgeInsets.zero,
                  tooltip: widget.searchActive ? '收起搜索' : '搜索',
                ),
              ),
            ),
          ] else
            Expanded(
              child: Container(
                height: topControlSize,
                decoration: BoxDecoration(
                  color: context.artC.silver.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search,
                        size: 16,
                        color: context.artC.ink.withValues(alpha: 0.35)),
                    const SizedBox(width: 8),
                    if (searchController == null) ...[
                      Expanded(
                        child: Text(
                          '搜索',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.artC.ink.withValues(alpha: 0.35),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: widget.onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: widget.searchHint ?? '搜索',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.artC.ink.withValues(alpha: 0.35),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) {
                            return const SizedBox(width: 6);
                          }
                          return IconButton(
                            onPressed: widget.onSearchClear,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: context.artC.ink.withValues(alpha: 0.35),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: '清空',
                          );
                        },
                      ),
                    ],
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileDrawerPanel extends StatelessWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const _ProfileDrawerPanel({
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  void _openFeature(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    List<String> actions = const [],
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DrawerFeatureScreen(
          title: title,
          subtitle: subtitle,
          icon: icon,
          actions: actions,
        ),
      ),
    );
  }

  void _openOrders(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.78;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width.clamp(300.0, 380.0),
        height: double.infinity,
        color: const Color(0xFFF8F8F8),
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    children: [
                      _DrawerProfileHeader(onTap: onProfileTap),
                      const SizedBox(height: 12),
                      _DrawerPrimaryAction(
                        icon: Icons.person_add_alt_1_outlined,
                        label: '添加好友',
                        onTap: () => _openFeature(
                          context,
                          title: '添加好友',
                          subtitle: '通过手机号、邮箱或二维码找到同学、顾问和创作者。',
                          icon: Icons.person_add_alt_1_outlined,
                          actions: ['搜索用户', '扫码添加', '通讯录匹配'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DrawerCard(
                        children: [
                          _DrawerMenuItem(
                            icon: Icons.tips_and_updates_outlined,
                            label: '创作者中心',
                            hasDot: true,
                            onTap: () => _openFeature(
                              context,
                              title: '创作者中心',
                              subtitle: '管理内容发布、案例投稿、数据表现和创作者权益。',
                              icon: Icons.tips_and_updates_outlined,
                              actions: ['内容管理', '案例投稿', '数据概览', '权益中心'],
                            ),
                          ),
                        ],
                      ),
                      _DrawerCard(
                        children: [
                          _DrawerMenuItem(
                            icon: Icons.inventory_2_outlined,
                            label: '我的草稿',
                            onTap: () => _openFeature(
                              context,
                              title: '我的草稿',
                              subtitle: '保存中的帖子、案例和申请记录会显示在这里。',
                              icon: Icons.inventory_2_outlined,
                              actions: ['帖子草稿', '案例草稿', '申请记录草稿'],
                            ),
                          ),
                          _DrawerMenuItem(
                            icon: Icons.emoji_events_outlined,
                            label: '我的活动',
                            badge: '新',
                            onTap: () => _openFeature(
                              context,
                              title: '我的活动',
                              subtitle: '查看报名活动、线上讲座、作品集点评和提醒。',
                              icon: Icons.emoji_events_outlined,
                              actions: ['已报名', '待开始', '历史活动'],
                            ),
                          ),
                          _DrawerMenuItem(
                            icon: Icons.history_outlined,
                            label: '浏览记录',
                            onTap: () => _openFeature(
                              context,
                              title: '浏览记录',
                              subtitle: '最近看过的院校、专业、案例和帖子会保存在这里。',
                              icon: Icons.history_outlined,
                              actions: ['院校记录', '专业记录', '案例记录', '帖子记录'],
                            ),
                          ),
                          _DrawerMenuItem(
                            icon: Icons.file_download_outlined,
                            label: '我的下载',
                            onTap: () => _openFeature(
                              context,
                              title: '我的下载',
                              subtitle: '资料包、申请清单和作品集模板下载记录。',
                              icon: Icons.file_download_outlined,
                              actions: ['资料包', '申请清单', '作品集模板'],
                            ),
                          ),
                        ],
                      ),
                      _DrawerCard(
                        children: [
                          _DrawerMenuItem(
                            icon: Icons.receipt_long_outlined,
                            label: '订单',
                            onTap: () => _openOrders(context),
                          ),
                          _DrawerMenuItem(
                            icon: Icons.shopping_cart_outlined,
                            label: '购物车',
                            onTap: () => _openFeature(
                              context,
                              title: '购物车',
                              subtitle: '已加入的课程、服务和资料产品会显示在这里。',
                              icon: Icons.shopping_cart_outlined,
                              actions: ['申请服务', '作品集课程', '资料产品'],
                            ),
                          ),
                          _DrawerMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: '钱包',
                            onTap: () => _openFeature(
                              context,
                              title: '钱包',
                              subtitle: '余额、优惠券、积分和付款方式管理。',
                              icon: Icons.account_balance_wallet_outlined,
                              actions: ['余额', '优惠券', '积分', '付款方式'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DrawerQuickAction(
                      icon: Icons.qr_code_scanner_outlined,
                      label: '扫一扫',
                      onTap: () => _openFeature(
                        context,
                        title: '扫一扫',
                        subtitle: '扫描二维码添加好友、打开资料或加入活动。',
                        icon: Icons.qr_code_scanner_outlined,
                        actions: ['扫描二维码', '我的二维码'],
                      ),
                    ),
                    _DrawerQuickAction(
                      icon: Icons.support_agent_outlined,
                      label: '帮助与客服',
                      onTap: () => _openFeature(
                        context,
                        title: '帮助与客服',
                        subtitle: '常见问题、订单咨询和人工客服入口。',
                        icon: Icons.support_agent_outlined,
                        actions: ['常见问题', '订单咨询', '联系人工客服'],
                      ),
                    ),
                    _DrawerQuickAction(
                      icon: Icons.settings_outlined,
                      label: '设置',
                      onTap: onSettingsTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerFeatureScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> actions;

  const _DrawerFeatureScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.artC.silver.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: context.artC.ink,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.artC.ink.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: kCobalt, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: context.artC.ink.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (actions.isEmpty)
              _DrawerFeatureTile(
                icon: Icons.inbox_outlined,
                title: '暂无内容',
                subtitle: '稍后再来看看',
                onTap: () {},
              )
            else
              for (final action in actions) ...[
                _DrawerFeatureTile(
                  icon: icon,
                  title: action,
                  subtitle: '即将开放',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _DrawerFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.artC.silver.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.artC.porcelain.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: kCobalt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.artC.ink.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: context.artC.ink.withValues(alpha: 0.22),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerProfileHeader extends StatelessWidget {
  final VoidCallback onTap;

  const _DrawerProfileHeader({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final email = user?.email ?? '';
    final nickname = (metadata['nickname'] as String?)?.trim();
    final displayName = nickname != null && nickname.isNotEmpty
        ? nickname
        : (email.isNotEmpty ? email.split('@').first : 'Artsee 用户');
    final avatarUrl = (metadata['avatar_url'] as String?)?.trim() ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: kCobalt.withValues(alpha: 0.12)),
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _DrawerAvatarFallback(),
                      )
                    : const _DrawerAvatarFallback(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      color: Color(0xFF2C2C2C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '查看个人主页与申请资产',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF2C2C2C).withValues(alpha: 0.42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: const Color(0xFF2C2C2C).withValues(alpha: 0.22),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAvatarFallback extends StatelessWidget {
  const _DrawerAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '艺',
        style: TextStyle(
          color: kCobalt,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DrawerCard extends StatelessWidget {
  final List<Widget> children;

  const _DrawerCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: children),
    );
  }
}

class _DrawerPrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerPrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: const Color(0xFF3E3E3E)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.1,
                  color: Color(0xFF2C2C2C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: const Color(0xFF2C2C2C).withValues(alpha: 0.22),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasDot;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hasDot = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF3E3E3E)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  color: Color(0xFF2C2C2C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (hasDot)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2F55),
                  shape: BoxShape.circle,
                ),
              ),
            if (badge != null)
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2F55),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF555555), size: 25),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 右下角「+」：不用 InkWell，避免 Web 上方形水波纹与浅蓝渐变伪影
class _ArtiqoreFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _ArtiqoreFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kCobalt,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.artC.ink.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        widget.isSelected ? kCobalt : context.artC.ink.withValues(alpha: 0.26);
    final icon = widget.item.label == '社区'
        ? _CommunityNavIcon(color: iconColor)
        : Icon(
            widget.isSelected ? widget.item.activeIcon : widget.item.icon,
            size: 25,
            color: iconColor,
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
          ],
        ),
      ),
    );
  }
}

class _CommunityNavIcon extends StatelessWidget {
  final Color color;

  const _CommunityNavIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 25,
      child: CustomPaint(
        painter: _CommunityNavIconPainter(color),
      ),
    );
  }
}

class _CommunityNavIconPainter extends CustomPainter {
  final Color color;

  const _CommunityNavIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    canvas.drawCircle(Offset(w * 0.5, h * 0.22), h * 0.18, paint);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.24, h * 0.42, w * 0.52, h * 0.5),
        topLeft: Radius.circular(w * 0.18),
        topRight: Radius.circular(w * 0.18),
        bottomLeft: Radius.circular(w * 0.05),
        bottomRight: Radius.circular(w * 0.05),
      ),
      paint,
    );

    canvas.drawCircle(Offset(w * 0.18, h * 0.32), h * 0.15, paint);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.01, h * 0.55, w * 0.3, h * 0.36),
        topLeft: Radius.circular(w * 0.12),
        topRight: Radius.circular(w * 0.12),
        bottomLeft: Radius.circular(w * 0.04),
      ),
      paint,
    );

    canvas.drawCircle(Offset(w * 0.82, h * 0.32), h * 0.15, paint);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.69, h * 0.55, w * 0.3, h * 0.36),
        topLeft: Radius.circular(w * 0.12),
        topRight: Radius.circular(w * 0.12),
        bottomRight: Radius.circular(w * 0.04),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CommunityNavIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
