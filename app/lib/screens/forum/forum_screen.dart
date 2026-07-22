import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/tencent_im_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import 'ask_question_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../messages/add_friend_screen.dart';
import '../messages/light_message_screen.dart';
import '../profile/public_user_profile_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

const _whatsAppGreen = kCobalt;
const _whatsAppGreenLight = kCobalt;
const _whatsAppAccent = kCobalt;
const _whatsAppMuted = Color(0xFF667781);
const _marketFilters = ['全部', '艺术', '工艺', '出版', '定制'];

class ForumScreen extends StatefulWidget {
  final VoidCallback? onTabChanged;

  const ForumScreen({
    super.key,
    this.onTabChanged,
  });

  @override
  State<ForumScreen> createState() => ForumScreenState();
}

class ForumScreenState extends State<ForumScreen>
    with TickerProviderStateMixin {
  static const int _tabCount = 1;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<_ChatTabState> _chatKey = GlobalKey<_ChatTabState>();
  List<String> _searchKeywords = List.filled(
    _tabCount,
    '',
    growable: true,
  );
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _createTabController();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _createTabController({int initialIndex = 0}) {
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_handleTabChanged);
  }

  void _ensureTabController() {
    if (_tabController.length == _tabCount) return;
    final currentIndex =
        _tabController.index < _tabCount ? _tabController.index : _tabCount - 1;
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
    const maxIndex = _tabCount - 1;
    final index = _tabController.index;
    if (index < 0) return 0;
    if (index > maxIndex) return maxIndex;
    return index;
  }

  String _searchKeywordAt(int index) {
    _ensureSearchKeywords();
    if (index < 0 || index >= _searchKeywords.length) return '';
    return _searchKeywords[index];
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    widget.onTabChanged?.call();
  }

  int get activeTabIndex => _safeTabIndex;

  String get searchKeyword => _searchKeywordAt(_safeTabIndex);

  String get searchHint => switch (_safeTabIndex) {
        0 => '搜索消息、联系人、通知',
        _ => '搜索消息',
      };

  IconData get actionIcon => switch (_safeTabIndex) {
        0 => Icons.refresh_rounded,
        _ => Icons.add_rounded,
      };

  void applySearch(String keyword) {
    final value = keyword.trim();
    if (_searchController.text != value) {
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() => _searchKeywords[_safeTabIndex] = value);
  }

  void refreshActiveTab() {
    switch (_safeTabIndex) {
      case 0:
        _chatKey.currentState?._load();
        break;
    }
  }

  void _toggleSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
  }

  void _closeSearch() {
    applySearch('');
    setState(() => _searchExpanded = false);
  }

  void _openFriendCandidates() {
    _chatKey.currentState?._openFriendCandidates();
  }

  void _openCreateGroup() {
    _chatKey.currentState?._openCreateGroupSheet();
  }

  void _openGroupPlaza() {
    _chatKey.currentState?._openGroupPlazaSheet();
  }

  void _openScanEntry() {
    _chatKey.currentState?._openScanEntrySheet();
  }

  void _showAddMenu() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭添加菜单',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _MessageAddMenuOverlay(
          onDismiss: () => Navigator.of(dialogContext).pop(),
          onCreateGroup: () => _closeAddMenuAndRun(
            dialogContext,
            _openCreateGroup,
          ),
          onGroupPlaza: () => _closeAddMenuAndRun(
            dialogContext,
            _openGroupPlaza,
          ),
          onAddFriend: () => _closeAddMenuAndRun(
            dialogContext,
            _openFriendCandidates,
          ),
          onScan: () => _closeAddMenuAndRun(
            dialogContext,
            _openScanEntry,
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
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  void _closeAddMenuAndRun(BuildContext dialogContext, VoidCallback action) {
    Navigator.of(dialogContext).pop();
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureTabController();
    _ensureSearchKeywords();
    final bottom = mainTabBottomInset(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _MessagePageHeader(
                searchExpanded: _searchExpanded,
                searchController: _searchController,
                onSearchTap: _toggleSearch,
                onSearchChanged: applySearch,
                onSearchClose: _closeSearch,
                onAddTap: _showAddMenu,
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: _ChatTab(
                    key: _chatKey,
                    bottom: bottom,
                    searchKeyword: _searchKeywordAt(0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePageHeader extends StatelessWidget {
  final bool searchExpanded;
  final TextEditingController searchController;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClose;
  final VoidCallback onAddTap;

  const _MessagePageHeader({
    required this.searchExpanded,
    required this.searchController,
    required this.onSearchTap,
    required this.onSearchChanged,
    required this.onSearchClose,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: searchExpanded
            ? SizedBox(
                key: const ValueKey('message-search-mode'),
                height: 42,
                child: _MessageSearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onClose: onSearchClose,
                ),
              )
            : SizedBox(
                key: const ValueKey('message-title-mode'),
                height: 42,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '消息',
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    _MessageHeaderIconButton(
                      icon: Icons.search_rounded,
                      tooltip: '搜索消息',
                      onTap: onSearchTap,
                    ),
                    const SizedBox(width: 2),
                    _MessageHeaderIconButton(
                      icon: Icons.add_circle_outline_rounded,
                      tooltip: '添加好友',
                      onTap: onAddTap,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MessageHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MessageHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            color: kCobalt,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _MessageSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _MessageSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 13, right: 4),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: _whatsAppMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    cursorColor: kCobalt,
                    style: const TextStyle(
                      color: Color(0xFF111B21),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索联系人、合作、圈子、通知',
                      hintStyle: TextStyle(
                        color: _whatsAppMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const SizedBox(width: 2);
                    }
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        controller.clear();
                        onChanged('');
                      },
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.close_rounded,
                          color: _whatsAppMuted,
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const SizedBox(
            height: 40,
            child: Center(
              child: Text(
                '取消',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kCobalt,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageAddMenuOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onCreateGroup;
  final VoidCallback onGroupPlaza;
  final VoidCallback onAddFriend;
  final VoidCallback onScan;

  const _MessageAddMenuOverlay({
    required this.onDismiss,
    required this.onCreateGroup,
    required this.onGroupPlaza,
    required this.onAddFriend,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 58;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onDismiss,
            ),
          ),
          Positioned(
            top: top,
            right: 18,
            child: Container(
              width: 162,
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MessageAddMenuItem(
                    icon: Icons.add_comment_outlined,
                    label: '创建群聊',
                    onTap: onCreateGroup,
                  ),
                  const _MessageAddMenuDivider(),
                  _MessageAddMenuItem(
                    icon: Icons.groups_2_outlined,
                    label: '群聊广场',
                    onTap: onGroupPlaza,
                  ),
                  const _MessageAddMenuDivider(),
                  _MessageAddMenuItem(
                    icon: Icons.person_add_alt_1_outlined,
                    label: '添加好友',
                    onTap: onAddFriend,
                  ),
                  const _MessageAddMenuDivider(),
                  _MessageAddMenuItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: '扫一扫',
                    onTap: onScan,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageAddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MessageAddMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              icon,
              size: 22,
              color: context.artC.ink.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _MessageAddMenuDivider extends StatelessWidget {
  const _MessageAddMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, right: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: context.artC.silver.withValues(alpha: 0.38),
      ),
    );
  }
}

class _CreateGroupPayload {
  final String title;
  final String scene;
  final String visibility;
  final String relatedTarget;
  final String announcement;
  final List<String> participantIds;

  const _CreateGroupPayload({
    required this.title,
    required this.scene,
    required this.visibility,
    required this.relatedTarget,
    required this.announcement,
    required this.participantIds,
  });
}

class _GroupSceneOption {
  final String label;
  final String subtitle;
  final IconData icon;

  const _GroupSceneOption({
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

const List<_GroupSceneOption> _groupSceneOptions = [
  _GroupSceneOption(
    label: '院校申请',
    subtitle: '同校同专业申请交流',
    icon: Icons.school_outlined,
  ),
  _GroupSceneOption(
    label: '作品集互助',
    subtitle: '项目反馈和进度互相督促',
    icon: Icons.collections_bookmark_outlined,
  ),
  _GroupSceneOption(
    label: '活动临时群',
    subtitle: '展览、沙龙、开放日同行',
    icon: Icons.event_available_outlined,
  ),
  _GroupSceneOption(
    label: '合作项目',
    subtitle: '找人共创、招募和委托沟通',
    icon: Icons.handshake_outlined,
  ),
];

class _CreateMessageGroupSheet extends StatefulWidget {
  final List<Map<String, dynamic>> friends;
  final Future<Map<String, dynamic>> Function(_CreateGroupPayload payload)
      onCreate;
  final VoidCallback onFindFriends;

  const _CreateMessageGroupSheet({
    required this.friends,
    required this.onCreate,
    required this.onFindFriends,
  });

  @override
  State<_CreateMessageGroupSheet> createState() =>
      _CreateMessageGroupSheetState();
}

class _CreateMessageGroupSheetState extends State<_CreateMessageGroupSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _relatedController = TextEditingController();
  final TextEditingController _announcementController = TextEditingController();
  final Set<String> _selectedFriendIds = <String>{};
  String _selectedScene = _groupSceneOptions.first.label;
  String _visibility = '公开加入';
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    _relatedController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_selectedFriendIds.isEmpty) {
      setState(() => _errorText = '至少选择 1 位好友；如果还没有好友，可以先从添加好友开始。');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final fallbackTitle = '$_selectedScene小组';
    final title = _titleController.text.trim().isEmpty
        ? fallbackTitle
        : _titleController.text.trim();
    try {
      final conversation = await widget.onCreate(
        _CreateGroupPayload(
          title: title,
          scene: _selectedScene,
          visibility: _visibility,
          relatedTarget: _relatedController.text.trim(),
          announcement: _announcementController.text.trim(),
          participantIds: _selectedFriendIds.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(conversation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = '创建失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: context.artC.porcelain,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '创建群聊',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  _MessageSheetTextField(
                    controller: _titleController,
                    label: '群聊名称',
                    hint: '例如 RCA 申请互助小组',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '选择场景',
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 2.28,
                    children: _groupSceneOptions
                        .map(
                          (option) => _GroupSceneTile(
                            option: option,
                            selected: option.label == _selectedScene,
                            onTap: () =>
                                setState(() => _selectedScene = option.label),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _MessageSegmentedChips(
                    label: '加入方式',
                    values: const ['公开加入', '邀请加入'],
                    selected: _visibility,
                    onChanged: (value) => setState(() => _visibility = value),
                  ),
                  const SizedBox(height: 14),
                  _MessageSheetTextField(
                    controller: _relatedController,
                    label: '关联对象',
                    hint: '学校、活动、机会或城市，可选',
                  ),
                  const SizedBox(height: 14),
                  _MessageSheetTextField(
                    controller: _announcementController,
                    label: '群公告',
                    hint: '写一句这个群适合谁、聊什么，可选',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '选择好友',
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedFriendIds.length} 人',
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.friends.isEmpty)
                    Column(
                      children: [
                        const _MessageSheetNotice(
                          icon: Icons.person_add_alt_1_outlined,
                          title: '还没有可邀请的好友',
                          subtitle: '先从右上角加号里的“添加好友”建立连接，再回来创建群聊。',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    Future<void>.delayed(
                                      const Duration(milliseconds: 90),
                                      widget.onFindFriends,
                                    );
                                  },
                            icon: const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 18,
                            ),
                            label: const Text('去添加好友'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kCobalt,
                              side: BorderSide(
                                color: kCobalt.withValues(alpha: 0.36),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ...widget.friends.map(
                      (friend) {
                        final id = _friendId(friend);
                        if (id == null) return const SizedBox.shrink();
                        final selected = _selectedFriendIds.contains(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _GroupFriendTile(
                            friend: friend,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedFriendIds.remove(id);
                                } else {
                                  _selectedFriendIds.add(id);
                                }
                                _errorText = null;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kCobalt,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '创建并进入群聊',
                          style: TextStyle(fontWeight: FontWeight.w900),
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

class _GroupSceneTile extends StatelessWidget {
  final _GroupSceneOption option;
  final bool selected;
  final VoidCallback onTap;

  const _GroupSceneTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kCobalt.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kCobalt.withValues(alpha: 0.5)
                : context.artC.silver.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 20,
              color:
                  selected ? kCobalt : context.artC.ink.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.42),
                      fontSize: 9,
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

class _MessageSegmentedChips extends StatelessWidget {
  final String label;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _MessageSegmentedChips({
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
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
        Row(
          children: values
              .map(
                (value) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: value == selected,
                    label: Text(value),
                    onSelected: (_) => onChanged(value),
                    selectedColor: kCobalt.withValues(alpha: 0.12),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: value == selected
                          ? kCobalt.withValues(alpha: 0.48)
                          : context.artC.silver.withValues(alpha: 0.3),
                    ),
                    labelStyle: TextStyle(
                      color: value == selected ? kCobalt : context.artC.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MessageSheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _MessageSheetTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
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
          minLines: maxLines,
          cursorColor: kCobalt,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.32),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.artC.silver.withValues(alpha: 0.28),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kCobalt.withValues(alpha: 0.54)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageSheetNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageSheetNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kCobalt, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _GroupFriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final bool selected;
  final VoidCallback onTap;

  const _GroupFriendTile({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _friendName(friend);
    final avatarUrl = _friendAvatarUrl(friend);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kCobalt.withValues(alpha: 0.48)
                : context.artC.silver.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 40,
                height: 40,
                child: avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _FriendShortcutFallback(name: name),
                      )
                    : _FriendShortcutFallback(name: name),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _friendRoleLabel(friend),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.44),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  selected ? kCobalt : context.artC.ink.withValues(alpha: 0.24),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPlazaSheet extends StatefulWidget {
  final void Function(
    Map<String, dynamic> circle,
    int index,
    String joinStatus,
  ) onOpenCircle;

  const _GroupPlazaSheet({required this.onOpenCircle});

  @override
  State<_GroupPlazaSheet> createState() => _GroupPlazaSheetState();
}

class _GroupPlazaSheetState extends State<_GroupPlazaSheet> {
  static const List<String> _filters = [
    '推荐',
    '院校',
    '城市',
    '专业',
    '作品集',
    '活动',
    '合作',
  ];

  List<Map<String, dynamic>> _items = const [];
  final Set<String> _joiningIds = <String>{};
  String _selectedFilter = '推荐';
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
      final result = await BackendApiService.fetchCommunityCircles(limit: 40);
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

  Future<void> _joinCircle(Map<String, dynamic> circle, int index) async {
    final status = _groupPlazaJoinStatus(circle);
    if (status == 'joined') {
      _openCircle(circle, index, status);
      return;
    }
    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请正在审核中')),
      );
      return;
    }
    final joinType = _circleJoinType(circle, index);
    if (joinType == 'private') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个群暂时不可加入')),
      );
      return;
    }
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后加入群聊');
    if (!mounted || !loggedIn) return;
    final id = circle['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群聊资料缺少 ID，暂时无法加入')),
      );
      return;
    }
    setState(() => _joiningIds.add(id));
    try {
      final updated = await BackendApiService.joinCommunityCircle(id);
      if (!mounted) return;
      final nextStatus = updated['join_status']?.toString() ??
          (joinType == 'approval' ? 'pending' : 'joined');
      setState(() {
        _joiningIds.remove(id);
        if (index >= 0 && index < _items.length) {
          _items[index] = {..._items[index], ...updated};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextStatus == 'pending'
              ? '申请已提交，审核通过后会通知你'
              : '已加入「${circle['title'] ?? '群聊'}」'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败：$e')),
      );
    }
  }

  void _openCircle(Map<String, dynamic> circle, int index, String status) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      widget.onOpenCircle(circle, index, status);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _items.asMap().entries.where((entry) {
      return _matchesGroupPlazaFilter(
        entry.value,
        entry.key,
        _selectedFilter,
      );
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '群聊广场',
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final filter = _filters[index];
                final selected = filter == _selectedFilter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? kCobalt : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? kCobalt
                            : context.artC.silver.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: selected ? Colors.white : context.artC.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) return const LoadingIndicator();
                if (_error != null) {
                  return _CommunityEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: '群聊广场加载失败',
                    subtitle: _error!,
                    onRetry: _load,
                  );
                }
                if (entries.isEmpty) {
                  return _CommunityEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: '暂无$_selectedFilter群聊',
                    subtitle: '换个分类看看，或从创建群聊开始组织一个新的申请/合作小组。',
                    onRetry: _load,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, visibleIndex) {
                    final entry = entries[visibleIndex];
                    final circle = entry.value;
                    final id = circle['id']?.toString() ?? '$visibleIndex';
                    final status = _groupPlazaJoinStatus(circle);
                    return _GroupPlazaCard(
                      circle: circle,
                      index: entry.key,
                      status: status,
                      busy: _joiningIds.contains(id),
                      onOpen: () => _openCircle(circle, entry.key, status),
                      onJoin: () => _joinCircle(circle, entry.key),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPlazaCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String status;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  const _GroupPlazaCard({
    required this.circle,
    required this.index,
    required this.status,
    required this.busy,
    required this.onOpen,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final title = circle['title']?.toString().trim().isNotEmpty == true
        ? circle['title'].toString().trim()
        : '艺术申请交流群';
    final subtitle = circle['subtitle']?.toString().trim().isNotEmpty == true
        ? circle['subtitle'].toString().trim()
        : _groupPlazaSubtitle(circle, index);
    final tags = _circleTags(circle, index);
    final members = int.tryParse(circle['member_count']?.toString() ?? '') ??
        (24 + index * 7);
    final discussions =
        int.tryParse(circle['today_post_count']?.toString() ?? '') ??
            (3 + index);
    final actionLabel = _groupPlazaActionLabel(circle, index, status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _groupPlazaColor(index).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _groupPlazaIcon(circle, index),
              color: _groupPlazaColor(index),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.48),
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children:
                      tags.take(3).map((tag) => _MiniTag(label: tag)).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  '$members 人 · 今日 $discussions 条讨论',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.36),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            height: 34,
            child: FilledButton(
              onPressed: busy ? null : onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: status == 'joined'
                    ? context.artC.cardIconBg
                    : status == 'pending'
                        ? context.artC.silver.withValues(alpha: 0.5)
                        : kCobalt,
                foregroundColor:
                    status == 'joined' ? context.artC.ink : Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanEntrySheet extends StatelessWidget {
  const _ScanEntrySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '扫一扫',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                children: [
                  _ScanEntryCard(
                    icon: Icons.badge_outlined,
                    title: '扫个人名片',
                    subtitle: '添加好友、查看作品主页和申请背景',
                  ),
                  SizedBox(height: 10),
                  _ScanEntryCard(
                    icon: Icons.groups_2_outlined,
                    title: '扫群邀请',
                    subtitle: '加入院校申请、作品集互助或合作项目群',
                  ),
                  SizedBox(height: 10),
                  _ScanEntryCard(
                    icon: Icons.event_available_outlined,
                    title: '活动签到',
                    subtitle: '展览、沙龙、开放日现场签到和资料领取',
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

class _ScanEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ScanEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title 功能正在接入二维码识别')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: kCobalt, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.48),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.artC.ink.withValues(alpha: 0.24),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceSurface extends StatefulWidget {
  final double bottom;
  final String searchKeyword;
  final VoidCallback? onCreateTap;

  const MarketplaceSurface({
    super.key,
    required this.bottom,
    required this.searchKeyword,
    this.onCreateTap,
  });

  @override
  State<MarketplaceSurface> createState() => MarketplaceSurfaceState();
}

class MarketplaceSurfaceState extends State<MarketplaceSurface> {
  List<AppCommunityPost> _posts = const [];
  final List<_MarketBagEntry> _bagEntries = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = '全部';

  @override
  void initState() {
    super.initState();
    refresh();
    unawaited(_syncBagEntries());
  }

  Future<void> refresh() async {
    await _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await BackendApiService.fetchPlazaPosts(
        limit: 40,
        kind: 'market',
        sort: 'latest',
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
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

  Future<void> openCreateMarketDialog() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布市集商品')) return;
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: '艺术');
    final cityCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate() || submitting) return;
              setDialogState(() => submitting = true);
              final category = categoryCtrl.text.trim();
              final city = cityCtrl.text.trim();
              final price = priceCtrl.text.trim();
              final imageUrl = imageCtrl.text.trim();
              final amountTotal = _marketPriceAmountTotal(price);
              try {
                await BackendApiService.createPlazaPost(
                  title: titleCtrl.text.trim(),
                  body: noteCtrl.text.trim(),
                  imageUrls: imageUrl.isEmpty ? const [] : [imageUrl],
                  kind: 'market',
                  group: category.isEmpty ? '市集' : category,
                  tags: [
                    if (category.isNotEmpty) category,
                    if (city.isNotEmpty) city,
                    if (price.isNotEmpty) price,
                  ],
                  metadata: {
                    'kind': 'market',
                    'category': category.isEmpty ? '艺术' : category,
                    'source': 'market_resource',
                    'city': city,
                    'price': price,
                    if (amountTotal != null) 'amount_total': amountTotal,
                    if (imageUrl.isNotEmpty) 'image_url': imageUrl,
                  },
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                await refresh();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('商品已提交审核，通过后会展示到市集')),
                );
              } catch (e) {
                if (!mounted) return;
                setDialogState(() => submitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('发布失败：$e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('发布市集商品'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '商品标题',
                          hintText: '例如 限量版画 / 陶瓷器物 / 独立画册 / 装裱定制',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? '请填写商品标题'
                                : null,
                      ),
                      TextFormField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          hintText: '艺术 / 工艺 / 出版 / 定制',
                        ),
                      ),
                      TextFormField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: '价格或条件',
                          hintText: '¥199 / 议价 / 接受委托 / 可交换',
                        ),
                      ),
                      TextFormField(
                        controller: imageCtrl,
                        decoration: const InputDecoration(
                          labelText: '商品图片 URL',
                          hintText: '可选。粘贴一张作品或商品图链接',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      TextFormField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: '城市或交付方式',
                          hintText: '线上 / 上海 / 伦敦',
                        ),
                      ),
                      TextFormField(
                        controller: noteCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '商品说明',
                          hintText: '写清楚材质、尺寸、版本、交付或定制方式',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: Text(submitting ? '发布中' : '发布'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      titleCtrl.dispose();
      categoryCtrl.dispose();
      cityCtrl.dispose();
      priceCtrl.dispose();
      imageCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = _visibleListings();
    final fallbackListings = _visibleFallbackListings();
    final displayListings =
        _posts.isEmpty && !_loading ? fallbackListings : listings;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 88),
        children: [
          _MarketFilterRow(
            selected: _selectedFilter,
            bagCount: _bagEntries.length,
            onSelected: (value) => setState(() => _selectedFilter = value),
            onBagTap: () => unawaited(_openShoppingBag()),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingIndicator()
          else ...[
            if (_error != null) ...[
              _MarketNotice(
                title: '市集数据暂时没连上',
                subtitle: '先展示推荐商品样式，稍后下拉刷新即可重试。',
                onRetry: refresh,
              ),
              const SizedBox(height: 14),
            ],
            _MarketplaceSectionHeader(
              title: _selectedFilter == '全部' ? '推荐商品' : '$_selectedFilter商品',
            ),
            const SizedBox(height: 10),
            if (displayListings.isEmpty)
              _MarketNotice(
                title: '没有匹配商品',
                subtitle: '换个关键词或分类试试，也可以发布一件新的市集商品。',
                onRetry: widget.onCreateTap ?? openCreateMarketDialog,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: displayListings.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 30,
                  mainAxisExtent: 274,
                ),
                itemBuilder: (context, index) {
                  final item = displayListings[index];
                  return _MarketListingCard(
                    item: item,
                    onOpen: () => _openListing(item),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  List<_MarketListing> _visibleListings() {
    final keyword = widget.searchKeyword.trim().toLowerCase();
    return _posts
        .map(_listingFromPost)
        .where((item) => _matchesMarketFilter(item))
        .where((item) {
      if (keyword.isEmpty) return true;
      return [
        item.title,
        item.body,
        item.category,
        item.city,
        item.price,
        item.author,
      ].join(' ').toLowerCase().contains(keyword);
    }).toList();
  }

  List<_MarketListing> _visibleFallbackListings() {
    final keyword = widget.searchKeyword.trim().toLowerCase();
    return _fallbackMarketListings
        .where((item) => _matchesMarketFilter(item))
        .where((item) {
      if (keyword.isEmpty) return true;
      return [
        item.title,
        item.body,
        item.category,
        item.city,
        item.price,
        item.author,
      ].join(' ').toLowerCase().contains(keyword);
    }).toList();
  }

  bool _matchesMarketFilter(_MarketListing item) {
    if (_selectedFilter == '全部') return true;
    final raw = '${item.category} ${item.title} ${item.body}'.toLowerCase();
    return switch (_selectedFilter) {
      '艺术' => [
          '艺术',
          '艺术品',
          '原作',
          '绘画',
          '油画',
          '水彩',
          '版画',
          '摄影',
          '雕塑',
          '装置',
          '收藏',
          '画廊',
          'art',
        ].any(raw.contains),
      '工艺' => [
          '工艺',
          '工艺品',
          '非遗',
          '陶瓷',
          '陶艺',
          '木作',
          '漆器',
          '金工',
          '织物',
          '首饰',
          '手作',
          'craft',
        ].any(raw.contains),
      '出版' => [
          '出版',
          '书',
          '书本',
          '书籍',
          '画册',
          '图录',
          'zine',
          '杂志',
          '海报',
          '印刷',
          '资料',
          'pdf',
          '清单',
        ].any(raw.contains),
      '定制' => [
          '定制',
          '委托',
          '服务',
          '装裱',
          '展陈',
          '框',
          '零件',
          '材料',
          '画材',
          '设备',
          '咨询',
          '诊断',
          'commission',
          'custom',
        ].any(raw.contains),
      _ => true,
    };
  }

  _MarketListing _listingFromPost(AppCommunityPost post) {
    final rawCategory = _marketPostMeta(
      post,
      const ['category', 'group', 'type'],
      _inferMarketCategory(post),
    );
    final category = _normalizeMarketCategory(
      rawCategory,
      '${post.title} ${post.body ?? ''}',
    );
    final city = _marketPostMeta(
      post,
      const ['city', 'location', 'mode'],
      '线上',
    );
    final price = _marketPostMeta(
      post,
      const ['price', 'budget', 'amount', 'exchange'],
      '可沟通',
    );
    final author = post.authorNickname?.trim().isNotEmpty == true
        ? post.authorNickname!.trim()
        : '艺见心用户';
    return _MarketListing(
      id: post.id,
      title: post.title.trim().isEmpty ? '未命名商品' : post.title.trim(),
      body: post.body?.trim().isNotEmpty == true
          ? post.body!.trim()
          : '商品详情待补充，可先咨询发布者确认材质、版本和交付方式。',
      category: category,
      city: city,
      price: price,
      author: author,
      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : null,
      post: post,
    );
  }

  String _marketPostMeta(
    AppCommunityPost post,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = post.metadata[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _inferMarketCategory(AppCommunityPost post) {
    final raw = '${post.title} ${post.body ?? ''}'.toLowerCase();
    if ([
      '工艺',
      '工艺品',
      '非遗',
      '陶瓷',
      '陶艺',
      '木作',
      '漆器',
      '金工',
      '织物',
      '首饰',
      '手作',
    ].any(raw.contains)) {
      return '工艺';
    }
    if ([
      '出版',
      '书',
      '书本',
      '书籍',
      '画册',
      '图录',
      'zine',
      '杂志',
      '海报',
      '印刷',
      '资料',
      'pdf',
      '清单',
    ].any(raw.contains)) {
      return '出版';
    }
    if ([
      '定制',
      '委托',
      '服务',
      '装裱',
      '展陈',
      '框',
      '零件',
      '材料',
      '画材',
      '设备',
      '咨询',
      '诊断',
    ].any(raw.contains)) {
      return '定制';
    }
    return '艺术';
  }

  String _normalizeMarketCategory(String value, [String context = '']) {
    final raw = '$value $context'.toLowerCase();
    if ([
      '工艺',
      '工艺品',
      '非遗',
      '陶瓷',
      '陶艺',
      '木作',
      '漆器',
      '金工',
      '织物',
      '首饰',
      '手作',
      'craft',
    ].any(raw.contains)) {
      return '工艺';
    }
    if ([
      '出版',
      '书',
      '书本',
      '书籍',
      '画册',
      '图录',
      'zine',
      '杂志',
      '海报',
      '印刷',
      '资料',
      'pdf',
      '清单',
    ].any(raw.contains)) {
      return '出版';
    }
    if ([
      '定制',
      '委托',
      '服务',
      '装裱',
      '展陈',
      '框',
      '零件',
      '材料',
      '画材',
      '设备',
      '咨询',
      '诊断',
      'commission',
      'custom',
    ].any(raw.contains)) {
      return '定制';
    }
    return '艺术';
  }

  void _openListing(_MarketListing item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MarketListingDetailScreen(
          item: item,
          initiallySaved: _isSavedListing(item),
          initiallyInBag: _isPendingListing(item),
          onSave: _saveListing,
          onAddToBag: _addListingToBag,
          onConsult: _consultListing,
          onCheckout: _checkoutListing,
        ),
      ),
    );
  }

  bool _isSavedListing(_MarketListing item) =>
      _bagEntryFor(item)?.saved == true;

  bool _isPendingListing(_MarketListing item) {
    final entry = _bagEntryFor(item);
    return entry?.pending == true && entry?.consulted != true;
  }

  _MarketBagEntry? _bagEntryFor(_MarketListing item) {
    for (final entry in _bagEntries) {
      if (entry.item.id == item.id) return entry;
    }
    return null;
  }

  void _upsertBagEntry(
    _MarketListing item, {
    bool? saved,
    bool? pending,
    bool? consulted,
    String? message,
    String? conversationId,
    String? orderId,
  }) {
    final index = _bagEntries.indexWhere((entry) => entry.item.id == item.id);
    final current = index >= 0
        ? _bagEntries[index]
        : _MarketBagEntry(
            item: item,
            updatedAt: DateTime.now(),
          );
    final next = current.copyWith(
      item: item,
      saved: saved,
      pending: pending,
      consulted: consulted,
      message: message,
      conversationId: conversationId,
      orderId: orderId,
      updatedAt: DateTime.now(),
    );
    setState(() {
      if (index >= 0) {
        _bagEntries[index] = next;
      } else {
        _bagEntries.insert(0, next);
      }
      _bagEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<bool> _saveListing(_MarketListing item) async {
    if (item.post != null) {
      final loggedIn = await ensureLoggedIn(context, message: '请先登录后收藏商品');
      if (!mounted || !loggedIn) return false;
    }
    try {
      if (item.post != null) {
        await BackendApiService.upsertMarketplaceBagItem(
          listingPostId: item.id,
          saved: true,
        );
      }
      if (!mounted) return false;
      _upsertBagEntry(item, saved: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已收藏「${item.title}」')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败：$e')),
      );
      return false;
    }
  }

  Future<bool> _addListingToBag(_MarketListing item) async {
    if (item.post != null) {
      final loggedIn = await ensureLoggedIn(context, message: '请先登录后加入购物袋');
      if (!mounted || !loggedIn) return false;
    }
    try {
      if (item.post != null) {
        await BackendApiService.upsertMarketplaceBagItem(
          listingPostId: item.id,
          status: 'pending',
        );
      }
      if (!mounted) return false;
      _upsertBagEntry(item, pending: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入购物袋「${item.title}」')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入购物袋失败：$e')),
      );
      return false;
    }
  }

  Future<void> _consultListing(_MarketListing item) async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后咨询市集商品');
    if (!mounted || !loggedIn) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarketConsultSheet(item: item),
    );
    if (!mounted || message == null) return;
    final trimmed = message.trim();

    final peerId = item.post?.authorId?.trim();
    final currentUserId = SupabaseService.currentUser?.id;
    final initialMessage = _marketConsultMessage(item, trimmed);
    if (peerId == null || peerId.isEmpty) {
      _upsertBagEntry(
        item,
        pending: false,
        consulted: true,
        message: trimmed,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LightMessageScreen(
            peer: LightMessagePeer.person(
              name: item.author,
              identityLabel: '市集发布者',
            ),
            initialMessage: initialMessage,
          ),
        ),
      );
      return;
    }
    if (peerId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这是你发布的商品，可以在发布记录里管理')),
      );
      return;
    }

    try {
      final conversation = await BackendApiService.createConversation(
        participantIds: [peerId],
        type: 'direct',
        title: item.author,
        metadata: {
          'source': 'market_listing_consult',
          'market_listing_id': item.id,
          'market_listing_title': item.title,
          'market_listing_category': item.category,
          'market_listing_price': item.price,
          'market_listing_city': item.city,
          'peer_user_id': peerId,
        },
      );
      await BackendApiService.sendConversationMessage(
        conversationId: conversation['id'].toString(),
        body: initialMessage,
        metadata: {
          'source': 'market_listing_consult',
          'market_listing_id': item.id,
          'market_listing_title': item.title,
        },
      );
      if (!mounted) return;
      await BackendApiService.upsertMarketplaceBagItem(
        listingPostId: item.id,
        status: 'consulted',
        message: trimmed,
        conversationId: conversation['id']?.toString(),
      );
      if (!mounted) return;
      _upsertBagEntry(
        item,
        pending: false,
        consulted: true,
        message: trimmed,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LightMessageScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发起咨询失败：$e')),
      );
    }
  }

  Future<void> _checkoutListing(_MarketListing item) async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后购买市集商品');
    if (!mounted || !loggedIn) return;
    if (item.post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('示例商品不能创建真实订单')),
      );
      return;
    }
    try {
      final checkout = await BackendApiService.createMarketplaceOrder(
        listingPostId: item.id,
      );
      if (!mounted) return;
      final order = checkout['order'];
      final orderId = checkout['orderId']?.toString() ??
          (order is Map<String, dynamic> ? order['id']?.toString() : null);
      if (orderId != null && orderId.isNotEmpty) {
        _upsertBagEntry(
          item,
          pending: false,
          consulted: true,
          orderId: orderId,
        );
      }
      final checkoutUrl = checkout['checkoutUrl']?.toString() ?? '';
      if (checkoutUrl.startsWith('/orders/') && orderId != null) {
        await BackendApiService.confirmExistingOrder(orderId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('订单已创建并确认支付')),
        );
        return;
      }
      if (checkoutUrl.isNotEmpty) {
        final url = checkoutUrl.startsWith('http')
            ? checkoutUrl
            : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$checkoutUrl';
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开支付链接：$url')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建订单失败：$e')),
      );
    }
  }

  Future<void> _syncBagEntries({bool showError = false}) async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final remote = await BackendApiService.fetchMarketplaceBag(limit: 80);
      if (!mounted) return;
      setState(() {
        _bagEntries
          ..clear()
          ..addAll(remote.data.map(_bagEntryFromRemote));
      });
    } catch (e) {
      if (!showError || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步购物袋失败：$e')),
      );
    }
  }

  Future<void> _openShoppingBag() async {
    if (SupabaseService.isLoggedIn) {
      await _syncBagEntries(showError: true);
    }
    if (!mounted) return;
    final entries = List<_MarketBagEntry>.unmodifiable(_bagEntries);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MarketShoppingBagScreen(
          entries: entries,
          onOpenListing: _openListing,
          onConsult: _consultListing,
        ),
      ),
    );
  }

  _MarketBagEntry _bagEntryFromRemote(Map<String, dynamic> row) {
    final listingRaw = row['listing'];
    final listing = listingRaw is Map<String, dynamic>
        ? _listingFromPost(AppCommunityPost.fromJson(listingRaw))
        : _fallbackMarketListings.first;
    final status = row['status']?.toString() ?? 'pending';
    return _MarketBagEntry(
      item: listing,
      saved: row['saved'] == true,
      pending: status == 'pending',
      consulted: status == 'consulted' || status == 'ordered',
      message: row['message']?.toString(),
      conversationId: row['conversation_id']?.toString(),
      orderId: row['order_id']?.toString(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class _MarketListing {
  final String id;
  final String title;
  final String body;
  final String category;
  final String city;
  final String price;
  final String author;
  final String? imageUrl;
  final AppCommunityPost? post;

  const _MarketListing({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.city,
    required this.price,
    required this.author,
    this.imageUrl,
    this.post,
  });
}

class _MarketBagEntry {
  final _MarketListing item;
  final bool saved;
  final bool pending;
  final bool consulted;
  final String? message;
  final String? conversationId;
  final String? orderId;
  final DateTime updatedAt;

  const _MarketBagEntry({
    required this.item,
    this.saved = false,
    this.pending = false,
    this.consulted = false,
    this.message,
    this.conversationId,
    this.orderId,
    required this.updatedAt,
  });

  _MarketBagEntry copyWith({
    _MarketListing? item,
    bool? saved,
    bool? pending,
    bool? consulted,
    String? message,
    String? conversationId,
    String? orderId,
    DateTime? updatedAt,
  }) {
    return _MarketBagEntry(
      item: item ?? this.item,
      saved: saved ?? this.saved,
      pending: pending ?? this.pending,
      consulted: consulted ?? this.consulted,
      message: message ?? this.message,
      conversationId: conversationId ?? this.conversationId,
      orderId: orderId ?? this.orderId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<_MarketListing> get _fallbackMarketListings => const [
      _MarketListing(
        id: 'sample-art-print',
        title: '限量版画《Blue Room》',
        body: '艺术家签名限量 30 版，适合收藏、空间陈列或送礼。',
        category: '艺术',
        city: '上海',
        price: '¥1,280',
        author: 'Studio Echo',
      ),
      _MarketListing(
        id: 'sample-craft-ceramic',
        title: '手工陶瓷香器',
        body: '小批量手作器物，非遗工艺可归入工艺品分类。',
        category: '工艺',
        city: '景德镇',
        price: '¥360',
        author: '土与火工坊',
      ),
      _MarketListing(
        id: 'sample-publication-book',
        title: '独立艺术书《Archive Notes》',
        body: '小开本艺术出版物，含访谈、展览照片和创作手稿。',
        category: '出版',
        city: '北京',
        price: '¥128',
        author: '野册出版',
      ),
      _MarketListing(
        id: 'sample-custom-frame',
        title: '展陈装裱与亚克力底座定制',
        body: '面向作品展示、毕业展和小型空间陈列的装裱、底座和展陈零件定制。',
        category: '定制',
        city: '线上 / 广州',
        price: '按尺寸报价',
        author: 'White Cube Works',
      ),
    ];

class _MarketFilterRow extends StatelessWidget {
  final String selected;
  final int bagCount;
  final ValueChanged<String> onSelected;
  final VoidCallback onBagTap;

  const _MarketFilterRow({
    required this.selected,
    required this.bagCount,
    required this.onSelected,
    required this.onBagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _marketFilters
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onSelected(value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.only(
                            left: 2,
                            right: 14,
                            top: 8,
                            bottom: 7,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value,
                                style: TextStyle(
                                  color: selected == value
                                      ? context.artC.ink
                                      : context.artC.ink
                                          .withValues(alpha: 0.34),
                                  fontSize: 13,
                                  fontWeight: selected == value
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: selected == value ? 18 : 0,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  color: context.artC.ink,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '购物袋',
          child: GestureDetector(
            onTap: onBagTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 22,
                    color: context.artC.ink.withValues(alpha: 0.56),
                  ),
                  if (bagCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: kCobalt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          bagCount > 99 ? '99+' : '$bagCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketplaceSectionHeader extends StatelessWidget {
  final String title;

  const _MarketplaceSectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.artC.ink,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _MarketNotice extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _MarketNotice({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCobalt.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: kCobalt, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kCobalt,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.48),
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
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

class _MarketListingCard extends StatelessWidget {
  final _MarketListing item;
  final VoidCallback onOpen;

  const _MarketListingCard({
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final quotedPrice = _isQuotedMarketPrice(item.price);
    return Semantics(
      button: true,
      label: '打开${item.title}详情',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          hoverColor: context.artC.silver.withValues(alpha: 0.08),
          highlightColor: context.artC.silver.withValues(alpha: 0.10),
          splashColor: Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MarketListingThumb(item: item),
              const SizedBox(height: 16),
              Text(
                item.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.34),
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 34,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink
                      .withValues(alpha: quotedPrice ? 0.48 : 0.82),
                  fontSize: quotedPrice ? 11.5 : 12,
                  height: 1.18,
                  fontWeight: quotedPrice ? FontWeight.w500 : FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketListingThumb extends StatelessWidget {
  final _MarketListing item;

  const _MarketListingThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: SizedBox(
          width: double.infinity,
          child: imageUrl == null
              ? _MarketFallbackImage(item: item)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _MarketFallbackImage(item: item),
                ),
        ),
      ),
    );
  }
}

class _MarketFallbackImage extends StatelessWidget {
  final _MarketListing item;

  const _MarketFallbackImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(item.id);
    return Image.network(
      'https://picsum.photos/seed/artsee_market_$encoded/720/520',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: context.artC.silver.withValues(alpha: 0.14),
      ),
    );
  }
}

class _MarketListingDetailScreen extends StatefulWidget {
  final _MarketListing item;
  final bool initiallySaved;
  final bool initiallyInBag;
  final Future<bool> Function(_MarketListing item) onSave;
  final Future<bool> Function(_MarketListing item) onAddToBag;
  final Future<void> Function(_MarketListing item) onConsult;
  final Future<void> Function(_MarketListing item) onCheckout;

  const _MarketListingDetailScreen({
    required this.item,
    required this.initiallySaved,
    required this.initiallyInBag,
    required this.onSave,
    required this.onAddToBag,
    required this.onConsult,
    required this.onCheckout,
  });

  @override
  State<_MarketListingDetailScreen> createState() =>
      _MarketListingDetailScreenState();
}

class _MarketListingDetailScreenState
    extends State<_MarketListingDetailScreen> {
  late bool _saved = widget.initiallySaved;
  late bool _inBag = widget.initiallyInBag;
  bool _saving = false;
  bool _adding = false;
  bool _consulting = false;
  bool _checkingOut = false;

  Future<void> _consult() async {
    if (_consulting) return;
    setState(() => _consulting = true);
    try {
      await widget.onConsult(widget.item);
    } finally {
      if (mounted) setState(() => _consulting = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(widget.item);
      if (saved && mounted) setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addToBag() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final added = await widget.onAddToBag(widget.item);
      if (added && mounted) setState(() => _inBag = true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _checkout() async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      await widget.onCheckout(widget.item);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final quotedPrice = _isQuotedMarketPrice(item.price);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: context.artC.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '收藏',
                    onPressed: _saving ? null : _save,
                    icon: Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 22,
                      color: context.artC.ink.withValues(alpha: 0.54),
                    ),
                  ),
                  IconButton(
                    tooltip: '加入购物袋',
                    onPressed: _adding ? null : _addToBag,
                    icon: Icon(
                      _inBag
                          ? Icons.shopping_bag_rounded
                          : Icons.shopping_bag_outlined,
                      size: 22,
                      color: context.artC.ink.withValues(alpha: 0.54),
                    ),
                  ),
                  IconButton(
                    tooltip: '咨询商品',
                    onPressed: _consulting ? null : _consult,
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 22,
                      color: context.artC.ink.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                children: [
                  _MarketListingThumb(item: item),
                  const SizedBox(height: 22),
                  Text(
                    item.author,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.34),
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 24,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.price,
                    style: TextStyle(
                      color: context.artC.ink
                          .withValues(alpha: quotedPrice ? 0.52 : 0.84),
                      fontSize: quotedPrice ? 14 : 17,
                      height: 1.2,
                      fontWeight:
                          quotedPrice ? FontWeight.w500 : FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.58),
                      fontSize: 14,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _MarketDetailMeta(label: '分类', value: item.category),
                  _MarketDetailMeta(label: '位置', value: item.city),
                  _MarketDetailMeta(label: '发布者', value: item.author),
                  const SizedBox(height: 24),
                  _MarketDetailStepLine(
                    index: '01',
                    title: '加入购物袋',
                    body: '先把感兴趣的作品、工艺品或定制服务放进待咨询清单。',
                    active: _inBag,
                  ),
                  const _MarketDetailStepLine(
                    index: '02',
                    title: '发送咨询',
                    body: '写一句需求，系统会把商品信息一并发给发布者。',
                    active: false,
                  ),
                  const _MarketDetailStepLine(
                    index: '03',
                    title: '消息页沟通',
                    body: '价格、尺寸、交付、定制细节在私信里确认。',
                    active: false,
                  ),
                  if (item.post != null) ...[
                    const SizedBox(height: 26),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityPostDetailScreen(
                              postId: item.post!.id,
                              initialPost: item.post,
                            ),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        '查看发布记录 →',
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _checkingOut ? null : _checkout,
                  icon: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 20,
                    color: _checkingOut
                        ? Colors.white.withValues(alpha: 0.62)
                        : Colors.white,
                  ),
                  label: Text(
                    _checkingOut ? '创建订单中' : '直接购买',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: context.artC.ink,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.62),
                    disabledBackgroundColor:
                        context.artC.ink.withValues(alpha: 0.44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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

class _MarketDetailMeta extends StatelessWidget {
  final String label;
  final String value;

  const _MarketDetailMeta({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.28),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketDetailStepLine extends StatelessWidget {
  final String index;
  final String title;
  final String body;
  final bool active;

  const _MarketDetailStepLine({
    required this.index,
    required this.title,
    required this.body,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              index,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: active ? 0.72 : 0.26),
                fontSize: 11,
                height: 1.28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 11.5,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
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

enum _MarketBagTab { pending, consulted, saved }

class _MarketShoppingBagScreen extends StatefulWidget {
  final List<_MarketBagEntry> entries;
  final ValueChanged<_MarketListing> onOpenListing;
  final Future<void> Function(_MarketListing item) onConsult;

  const _MarketShoppingBagScreen({
    required this.entries,
    required this.onOpenListing,
    required this.onConsult,
  });

  @override
  State<_MarketShoppingBagScreen> createState() =>
      _MarketShoppingBagScreenState();
}

class _MarketShoppingBagScreenState extends State<_MarketShoppingBagScreen> {
  late final List<_MarketBagEntry> _entries = List.of(widget.entries);
  late _MarketBagTab _selected = _initialTab();
  bool _consulting = false;

  _MarketBagTab _initialTab() {
    if (_entries.any((entry) => entry.pending && !entry.consulted)) {
      return _MarketBagTab.pending;
    }
    if (_entries.any((entry) => entry.consulted)) {
      return _MarketBagTab.consulted;
    }
    return _MarketBagTab.saved;
  }

  List<_MarketBagEntry> _entriesFor(_MarketBagTab tab) {
    return switch (tab) {
      _MarketBagTab.pending =>
        _entries.where((entry) => entry.pending && !entry.consulted).toList(),
      _MarketBagTab.consulted =>
        _entries.where((entry) => entry.consulted).toList(),
      _MarketBagTab.saved => _entries.where((entry) => entry.saved).toList(),
    };
  }

  String _labelFor(_MarketBagTab tab) {
    return switch (tab) {
      _MarketBagTab.pending => '待咨询',
      _MarketBagTab.consulted => '已咨询',
      _MarketBagTab.saved => '已收藏',
    };
  }

  Future<void> _consult(_MarketBagEntry entry) async {
    if (_consulting) return;
    setState(() => _consulting = true);
    try {
      await widget.onConsult(entry.item);
      if (!mounted) return;
      setState(() {
        final index =
            _entries.indexWhere((item) => item.item.id == entry.item.id);
        if (index >= 0) {
          _entries[index] = _entries[index].copyWith(
            pending: false,
            consulted: true,
            updatedAt: DateTime.now(),
          );
        }
        _selected = _MarketBagTab.consulted;
      });
    } finally {
      if (mounted) setState(() => _consulting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entriesFor(_selected);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 18, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: context.artC.ink,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '购物袋',
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_entries.length} 件',
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.34),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: _MarketBagTab.values
                    .map(
                      (tab) => Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = tab),
                          behavior: HitTestBehavior.opaque,
                          child: _MarketBagTabLabel(
                            label: _labelFor(tab),
                            count: _entriesFor(tab).length,
                            selected: _selected == tab,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _MarketBagEmptyState(label: _labelFor(_selected))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 28,
                        thickness: 0.8,
                        color: context.artC.silver.withValues(alpha: 0.36),
                      ),
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        return _MarketBagEntryRow(
                          entry: entry,
                          tab: _selected,
                          consulting: _consulting,
                          onOpen: () => widget.onOpenListing(entry.item),
                          onConsult: () => _consult(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketBagTabLabel extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;

  const _MarketBagTabLabel({
    required this.label,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label $count',
          style: TextStyle(
            color: selected
                ? context.artC.ink
                : context.artC.ink.withValues(alpha: 0.32),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: selected ? 18 : 0,
          height: 1.5,
          decoration: BoxDecoration(
            color: context.artC.ink,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _MarketBagEmptyState extends StatelessWidget {
  final String label;

  const _MarketBagEmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Text(
          label == '待咨询'
              ? '还没有待咨询商品。\n在详情页点购物袋图标，先把感兴趣的作品放进来。'
              : label == '已咨询'
                  ? '还没有咨询记录。\n咨询后会自动沉淀到这里，方便回看。'
                  : '还没有收藏。\n点详情页右上角书签即可收藏。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.38),
            fontSize: 13,
            height: 1.65,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MarketBagEntryRow extends StatelessWidget {
  final _MarketBagEntry entry;
  final _MarketBagTab tab;
  final bool consulting;
  final VoidCallback onOpen;
  final VoidCallback onConsult;

  const _MarketBagEntryRow({
    required this.entry,
    required this.tab,
    required this.consulting,
    required this.onOpen,
    required this.onConsult,
  });

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final message = entry.message?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: _MarketListingThumb(item: item),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.34),
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${item.category} · ${item.price}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.46),
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.38),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpen,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '查看详情',
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (tab != _MarketBagTab.consulted) ...[
                    const SizedBox(width: 18),
                    GestureDetector(
                      onTap: consulting ? null : onConsult,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        consulting ? '发起中' : '咨询',
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.54),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketConsultSheet extends StatefulWidget {
  final _MarketListing item;

  const _MarketConsultSheet({required this.item});

  @override
  State<_MarketConsultSheet> createState() => _MarketConsultSheetState();
}

class _MarketConsultSheetState extends State<_MarketConsultSheet> {
  late final TextEditingController _message = TextEditingController(
    text: '我想了解尺寸、库存、交付方式和是否可以继续沟通。',
  );
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '写一句想咨询什么');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '咨询商品',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.author} · ${item.price}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.38),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.artC.silver.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
              ),
              child: TextField(
                controller: _message,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                cursorColor: context.artC.ink,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '写下你想确认的尺寸、版本、库存或交付方式',
                  hintStyle: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.28),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF9F2A2A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _submit,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: context.artC.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  '发送咨询',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

String _marketConsultMessage(_MarketListing item, String message) {
  final note = message.trim();
  return [
    '你好，我在市集看到「${item.title}」，想咨询一下。',
    '',
    '我的问题：$note',
    '',
    '商品信息：${item.category} · ${item.price} · ${item.city}',
  ].join('\n');
}

bool _isQuotedMarketPrice(String price) {
  final raw = price.trim().toLowerCase();
  if (raw.isEmpty) return true;
  return !RegExp(r'\d').hasMatch(raw) ||
      raw.contains('~') ||
      raw.contains('-') ||
      raw.contains('起') ||
      raw.contains('报价') ||
      raw.contains('议价') ||
      raw.contains('沟通') ||
      raw.contains('委托') ||
      raw.contains('custom');
}

int? _marketPriceAmountTotal(String price) {
  final raw = price.trim().replaceAll(',', '');
  if (_isQuotedMarketPrice(raw)) return null;
  final match = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(raw);
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0) return null;
  return (amount * 100).round();
}

class CommunityCircleSurface extends StatefulWidget {
  final double bottom;
  final String searchKeyword;
  final VoidCallback? onCreateCircle;
  final Future<void> Function({
    String? initialTitle,
    String? initialCategory,
  })? onAsk;

  const CommunityCircleSurface({
    super.key,
    required this.bottom,
    required this.searchKeyword,
    this.onCreateCircle,
    this.onAsk,
  });

  @override
  State<CommunityCircleSurface> createState() => CommunityCircleSurfaceState();
}

class CommunityCircleSurfaceState extends State<CommunityCircleSurface> {
  final GlobalKey<_CircleTabState> _circleKey = GlobalKey<_CircleTabState>();
  final GlobalKey<_QaCommunityTabState> _qaKey =
      GlobalKey<_QaCommunityTabState>();

  void refresh() {
    _qaKey.currentState?._load();
    _circleKey.currentState?._load();
  }

  void addCreatedCircle(Map<String, dynamic> circle) {
    _circleKey.currentState?.addCreatedCircle(circle);
    _qaKey.currentState?._load();
  }

  @override
  Widget build(BuildContext context) {
    final onAsk = widget.onAsk;
    if (onAsk != null) {
      return _QaCommunityTab(
        key: _qaKey,
        bottom: widget.bottom,
        searchKeyword: widget.searchKeyword,
        onAsk: onAsk,
      );
    }

    return _CircleTab(
      key: _circleKey,
      bottom: widget.bottom,
      searchKeyword: widget.searchKeyword,
      onCreateCircle: widget.onCreateCircle,
      onAsk: widget.onAsk,
    );
  }
}

class _QaCommunityTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;
  final Future<void> Function({
    String? initialTitle,
    String? initialCategory,
  }) onAsk;

  const _QaCommunityTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
    required this.onAsk,
  });

  @override
  State<_QaCommunityTab> createState() => _QaCommunityTabState();
}

class _QaCommunityTabState extends State<_QaCommunityTab> {
  List<AppCommunityHotTopic> _hotTopics = const [];
  List<AppCommunityPost> _posts = const [];
  List<Map<String, dynamic>> _circles = const [];
  final Map<String, String> _circleJoinStatusOverrides = {};
  final Set<String> _joiningCircleIds = <String>{};
  bool _hotTopicsLoading = true;
  bool _postsLoading = true;
  bool _circlesLoading = true;
  String? _hotTopicsError;
  String? _postsError;
  String? _circlesError;
  String _selectedFilter = '推荐';

  static const filters = [
    '推荐',
    '已加入',
    '留学',
    '作品集',
    '院校',
    '同城',
    '就业',
    '市场',
  ];

  static const blocks = [
    (
      title: '艺术留学',
      count: '申请 / 院校',
      color: Color(0xFFEFF6FF),
      text: Color(0xFF2563EB)
    ),
    (
      title: '作品集',
      count: '叙事 / 诊断',
      color: Color(0xFFF5F3FF),
      text: Color(0xFF7C3AED)
    ),
    (
      title: '行业就业',
      count: '岗位 / 合作',
      color: Color(0xFFECFDF5),
      text: Color(0xFF059669)
    ),
    (
      title: '艺术市场',
      count: '收藏 / 展览',
      color: Color(0xFFF6F8FC),
      text: Color(0xFF001D51)
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      _loadCircles(),
      _loadHotTopics(),
      _loadPosts(),
    ]);
  }

  Future<void> _loadCircles() async {
    setState(() {
      _circlesLoading = true;
      _circlesError = null;
    });
    try {
      final result = await BackendApiService.fetchCommunityCircles(limit: 40);
      if (!mounted) return;
      setState(() {
        _circles = result.data;
        _circlesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _circles = const [];
        _circlesError = e.toString();
        _circlesLoading = false;
      });
    }
  }

  Future<void> _loadHotTopics() async {
    setState(() {
      _hotTopicsLoading = true;
      _hotTopicsError = null;
    });
    try {
      final hotTopics = await BackendApiService.fetchCommunityHotTopics(
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _hotTopics = hotTopics;
        _hotTopicsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hotTopics = const [];
        _hotTopicsError = e.toString();
        _hotTopicsLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });
    try {
      final posts = await BackendApiService.fetchCommunityPosts(
        limit: 30,
        kind: 'qa',
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _postsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = const [];
        _postsError = e.toString();
        _postsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredByBlock = _hotTopics.where(_matchesHotTopicFilter).toList();
    final visibleHotTopics = widget.searchKeyword.isEmpty
        ? filteredByBlock
        : filteredByBlock
            .where((topic) => _matchesSearch(
                  [
                    topic.title,
                    topic.category,
                    topic.tag,
                    topic.metadata['theme']?.toString() ?? '',
                    ...topic.answers.map(
                      (answer) => '${answer.stance} ${answer.content}',
                    ),
                  ].join(' '),
                  widget.searchKeyword,
                ))
            .toList();
    final filteredPostsByBlock = _posts.where(_matchesPostFilter).toList();
    final visiblePosts = widget.searchKeyword.isEmpty
        ? filteredPostsByBlock
        : filteredPostsByBlock
            .where((post) => _matchesSearch(
                  [
                    post.title,
                    post.body ?? '',
                    _postCategory(post),
                    post.metadata['school']?.toString() ?? '',
                    post.metadata['program']?.toString() ?? '',
                    post.metadata['source_circle']?.toString() ?? '',
                  ].join(' '),
                  widget.searchKeyword,
                ))
            .toList();
    final visibleCircleEntries = _visibleCircleEntries();
    final showQuestionPosts =
        _postsLoading || _postsError != null || visiblePosts.isNotEmpty;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 32),
      children: [
        _PillFilterRow(
          values: filters,
          selected: _selectedFilter,
          onSelected: (value) => setState(() => _selectedFilter = value),
        ),
        const SizedBox(height: 12),
        _QuickAskCard(
          onAsk: () => widget.onAsk(initialCategory: _questionInitialCategory),
        ),
        if (showQuestionPosts) ...[
          const SizedBox(height: 18),
          _QuestionPostStrip(
            posts: visiblePosts,
            loading: _postsLoading,
            error: _postsError,
            onRetry: _loadPosts,
            onOpen: _openQuestionPost,
          ),
        ],
        const SizedBox(height: 18),
        _HotTopicStrip(
          topics: visibleHotTopics,
          loading: _hotTopicsLoading,
          error: _hotTopicsError,
          onRetry: _load,
          onTopicOpen: _openHotTopicDiscussion,
          onTopicAsk: _openHotTopicAsk,
        ),
        const SizedBox(height: 18),
        _RelatedCircleStrip(
          entries: visibleCircleEntries,
          loading: _circlesLoading,
          error: _circlesError,
          selectedFilter: _selectedFilter,
          joiningIds: _joiningCircleIds,
          statusFor: _circleJoinStatus,
          onRetry: _loadCircles,
          onOpen: _openCircleDetail,
          onJoin: _handleCircleAction,
        ),
      ],
    );
  }

  String? get _questionInitialCategory => switch (_selectedFilter) {
        '留学' || '院校' => '艺术留学',
        '作品集' => '作品集',
        '就业' => '行业就业',
        '市场' => '艺术市场',
        _ => null,
      };

  bool _matchesHotTopicFilter(AppCommunityHotTopic topic) {
    if (_selectedFilter == '推荐') return true;
    final text = [
      topic.title,
      topic.category,
      topic.tag,
      topic.metadata['theme']?.toString() ?? '',
      topic.metadata['source_circle']?.toString() ?? '',
      ...topic.answers.map((answer) => '${answer.stance} ${answer.content}'),
    ].join(' ');
    if (_selectedFilter == '已加入') {
      return topic.isPinned || _matchesQaFilterText(text);
    }
    return _matchesQaFilterText(text);
  }

  bool _matchesPostFilter(AppCommunityPost post) {
    if (_selectedFilter == '推荐') return true;
    final sourceCircle = post.metadata['source_circle']?.toString() ?? '';
    final text = [
      post.title,
      post.body ?? '',
      _postCategory(post),
      post.metadata['school']?.toString() ?? '',
      post.metadata['program']?.toString() ?? '',
      sourceCircle,
    ].join(' ');
    if (_selectedFilter == '已加入') {
      return sourceCircle.isNotEmpty || _matchesQaFilterText(text);
    }
    return _matchesQaFilterText(text);
  }

  List<MapEntry<int, Map<String, dynamic>>> _visibleCircleEntries() {
    return _circles.asMap().entries.where((entry) {
      final index = entry.key;
      final circle = entry.value;
      if (!_matchesCircleFilter(circle, index)) return false;
      if (widget.searchKeyword.isEmpty) return true;
      return _matchesSearch(
        _groupPlazaSearchText(circle, index),
        widget.searchKeyword,
      );
    }).toList();
  }

  bool _matchesCircleFilter(Map<String, dynamic> circle, int index) {
    if (_selectedFilter == '推荐') return true;
    if (_selectedFilter == '已加入') {
      return _circleJoinStatus(circle, index) == 'joined';
    }
    return _matchesQaFilterText(_groupPlazaSearchText(circle, index));
  }

  bool _matchesQaFilterText(String text) {
    final normalized = text.toLowerCase();
    return switch (_selectedFilter) {
      '已加入' => _containsAny(normalized, ['圈', '社', '校友', '同学', '研习']),
      '留学' => _containsAny(
          normalized,
          [
            '留学',
            '申请',
            '院校',
            'ual',
            'rca',
            'risd',
            'parsons',
            'sva',
            'bu',
            'neu',
            'school',
            'college',
          ],
        ),
      '作品集' => _containsAny(
          normalized,
          ['作品集', 'portfolio', '项目', '叙事', '诊断', '反馈'],
        ),
      '院校' => _containsAny(
          normalized,
          [
            '院校',
            '学校',
            '专业',
            '申请',
            '留学',
            'ual',
            'rca',
            'risd',
            'parsons',
            'sva',
            'bu',
            'neu',
            'university',
            'college',
            'school',
          ],
        ),
      '同城' => _containsAny(
          normalized,
          [
            '同城',
            '城市',
            '上海',
            '北京',
            '伦敦',
            '纽约',
            '波士顿',
            '广州',
            '深圳',
            'city',
          ],
        ),
      '就业' => _containsAny(
          normalized,
          ['就业', '实习', '职业', '岗位', 'career', 'job', '导师', '行业'],
        ),
      '市场' => _containsAny(
          normalized,
          ['市场', '展览', '收藏', '画廊', '策展', '品牌', '委托', 'market'],
        ),
      _ => true,
    };
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((keyword) => text.contains(keyword.toLowerCase()));

  String _postCategory(AppCommunityPost post) =>
      post.metadata['category']?.toString() ?? '艺术留学';

  String _circleId(Map<String, dynamic> circle, int index) =>
      circle['id']?.toString() ?? '${circle['title'] ?? 'circle'}-$index';

  String _circleJoinStatus(Map<String, dynamic> circle, int index) {
    final override = _circleJoinStatusOverrides[_circleId(circle, index)];
    if (override != null) return override;
    return _groupPlazaJoinStatus(circle);
  }

  void _openQuestionPost(AppCommunityPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }

  void _openHotTopicDiscussion(AppCommunityHotTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HotTopicDiscussionScreen(
          topic: topic,
          onAsk: () => _openHotTopicAsk(topic),
        ),
      ),
    );
  }

  Future<void> _openHotTopicAsk(AppCommunityHotTopic topic) {
    return widget.onAsk(
      initialTitle: topic.title,
      initialCategory: topic.category,
    );
  }

  Future<void> _handleCircleAction(
    Map<String, dynamic> circle,
    int index,
  ) async {
    final status = _circleJoinStatus(circle, index);
    if (status == 'joined') {
      _openCircleDetail(circle, index);
      return;
    }
    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请正在审核中')),
      );
      return;
    }
    final joinType = _circleJoinType(circle, index);
    if (joinType == 'private') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个圈子暂时不可加入')),
      );
      return;
    }
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后加入圈子');
    if (!mounted || !loggedIn) return;
    final id = circle['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圈子资料缺少 ID，暂时无法加入')),
      );
      return;
    }
    setState(() => _joiningCircleIds.add(id));
    try {
      final updated = await BackendApiService.joinCommunityCircle(id);
      if (!mounted) return;
      final nextStatus = updated['join_status']?.toString() ??
          (joinType == 'approval' ? 'pending' : 'joined');
      setState(() {
        _joiningCircleIds.remove(id);
        _circleJoinStatusOverrides[_circleId(circle, index)] = nextStatus;
        if (index >= 0 && index < _circles.length) {
          _circles[index] = {..._circles[index], ...updated};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextStatus == 'pending'
              ? '申请已提交，审核通过后会通知你'
              : '已加入「${circle['title'] ?? '艺术圈子'}」'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningCircleIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败：$e')),
      );
    }
  }

  void _openCircleDetail(Map<String, dynamic> circle, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CircleDetailScreen(
          circle: circle,
          index: index,
          joinStatus: _circleJoinStatus(circle, index),
          onJoinChanged: (status) {
            setState(() {
              _circleJoinStatusOverrides[_circleId(circle, index)] = status;
              if (index >= 0 && index < _circles.length) {
                _circles[index] = {..._circles[index], 'join_status': status};
              }
            });
          },
        ),
      ),
    );
  }
}

class _CircleTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;
  final VoidCallback? onCreateCircle;
  final Future<void> Function({
    String? initialTitle,
    String? initialCategory,
  })? onAsk;

  const _CircleTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
    this.onCreateCircle,
    this.onAsk,
  });

  @override
  State<_CircleTab> createState() => _CircleTabState();
}

class _CircleTabState extends State<_CircleTab> {
  List<Map<String, dynamic>> _items = const [];
  List<AppCommunityHotTopic> _hotTopics = const [];
  List<AppCommunityPost> _posts = const [];
  final Map<String, String> _joinStatusOverrides = {};
  bool _loading = true;
  bool _hotTopicsLoading = true;
  bool _postsLoading = true;
  String? _error;
  String? _hotTopicsError;
  String? _postsError;
  String _selectedFilter = '推荐';
  String? _selectedBlock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      _loadCircles(),
      _loadHotTopics(),
      _loadPosts(),
    ]);
  }

  Future<void> _loadCircles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchCommunityCircles(limit: 40);
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

  Future<void> _loadHotTopics() async {
    setState(() {
      _hotTopicsLoading = true;
      _hotTopicsError = null;
    });
    try {
      final hotTopics = await BackendApiService.fetchCommunityHotTopics(
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _hotTopics = hotTopics;
        _hotTopicsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hotTopics = const [];
        _hotTopicsError = e.toString();
        _hotTopicsLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });
    try {
      final posts = await BackendApiService.fetchCommunityPosts(
        limit: 30,
        kind: 'qa',
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _postsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = const [];
        _postsError = e.toString();
        _postsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 32),
        children: [
          _CommunityEmptyState(
            icon: Icons.groups_outlined,
            title: '圈子加载失败',
            subtitle: _error!,
            onRetry: _load,
          ),
        ],
      );
    }
    final searchItems = widget.searchKeyword.isEmpty
        ? _items
        : _items
            .where((circle) => _matchesSearch(
                  '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}',
                  widget.searchKeyword,
                ))
            .toList();
    final visibleItems = _filterCircles(searchItems);
    final joinedItems = _items
        .asMap()
        .entries
        .where((entry) => _circleJoinStatus(entry.value, entry.key) == 'joined')
        .map((entry) => entry.value)
        .toList();
    final filteredHotTopicsByBlock = _selectedBlock == null
        ? _hotTopics
        : _hotTopics
            .where((topic) => topic.category == _selectedBlock)
            .toList();
    final visibleHotTopics = widget.searchKeyword.isEmpty
        ? filteredHotTopicsByBlock
        : filteredHotTopicsByBlock
            .where((topic) => _matchesSearch(
                  [
                    topic.title,
                    topic.category,
                    topic.tag,
                    topic.metadata['theme']?.toString() ?? '',
                    ...topic.answers.map(
                      (answer) => '${answer.stance} ${answer.content}',
                    ),
                  ].join(' '),
                  widget.searchKeyword,
                ))
            .toList();
    final filteredPostsByBlock = _selectedBlock == null
        ? _posts
        : _posts
            .where((post) => _postCategory(post) == _selectedBlock)
            .toList();
    final visiblePosts = widget.searchKeyword.isEmpty
        ? filteredPostsByBlock
        : filteredPostsByBlock
            .where((post) => _matchesSearch(
                  [
                    post.title,
                    post.body ?? '',
                    _postCategory(post),
                    post.metadata['school']?.toString() ?? '',
                    post.metadata['program']?.toString() ?? '',
                    post.metadata['source_circle']?.toString() ?? '',
                  ].join(' '),
                  widget.searchKeyword,
                ))
            .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 72),
      children: [
        _MyCircleStrip(
          items: joinedItems,
          onBrowse: () => setState(() => _selectedFilter = '推荐'),
          onOpen: (circle) {
            final originalIndex = _items.indexOf(circle);
            _openCircleDetail(circle, originalIndex < 0 ? 0 : originalIndex);
          },
        ),
        const SizedBox(height: 18),
        if (widget.onAsk != null) ...[
          _QuickAskCard(
            onAsk: () => widget.onAsk?.call(initialCategory: _selectedBlock),
          ),
          const SizedBox(height: 14),
        ],
        const _CommunitySectionHeader(title: '圈内问答', action: 'QA'),
        const SizedBox(height: 10),
        _BlockChipStrip(
          blocks: _QaCommunityTabState.blocks,
          selectedBlock: _selectedBlock,
          onSelected: (block) {
            setState(() {
              _selectedBlock = _selectedBlock == block ? null : block;
            });
          },
        ),
        const SizedBox(height: 18),
        _HotTopicStrip(
          topics: visibleHotTopics,
          loading: _hotTopicsLoading,
          error: _hotTopicsError,
          onRetry: _loadHotTopics,
          onTopicOpen: _openHotTopicDiscussion,
          onTopicAsk: _openHotTopicAsk,
        ),
        const SizedBox(height: 18),
        _QuestionPostStrip(
          posts: visiblePosts,
          loading: _postsLoading,
          error: _postsError,
          onRetry: _loadPosts,
          onOpen: _openQuestionPost,
        ),
        const SizedBox(height: 22),
        _PillFilterRow(
          values: const ['推荐', '已加入', '留学', '作品集', '同城', '就业', '市场'],
          selected: _selectedFilter,
          onSelected: (value) => setState(() => _selectedFilter = value),
        ),
        const SizedBox(height: 12),
        _CircleResultHeader(
          title: _circleFilterTitle,
          subtitle: _circleFilterSubtitle,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 250,
          ),
          itemBuilder: (context, index) {
            final circle = visibleItems[index];
            final originalIndex = _items.indexOf(circle);
            final circleIndex = originalIndex < 0 ? index : originalIndex;
            return _CircleCard(
              circle: circle,
              index: circleIndex,
              joinStatus: _circleJoinStatus(circle, circleIndex),
              onOpen: () => _openCircleDetail(circle, circleIndex),
              onAction: () => _handleCircleAction(circle, circleIndex),
            );
          },
        ),
        if (visibleItems.isEmpty)
          _CommunityEmptyState(
            icon: Icons.groups_outlined,
            title: _selectedFilter == '已加入' ? '你还没有加入圈子' : '没有匹配的圈子',
            subtitle: _selectedFilter == '已加入'
                ? '先从推荐、留学或作品集方向选择一个圈子加入。'
                : widget.onCreateCircle == null
                    ? '换个专业方向、学校或城市关键词试试。'
                    : '换个专业方向、学校或城市关键词试试，也可以创建一个新圈子。',
            actionLabel: _selectedFilter == '已加入'
                ? '去推荐'
                : widget.onCreateCircle == null
                    ? '重试'
                    : '创建圈子',
            onRetry: () {
              if (_selectedFilter == '已加入') {
                setState(() => _selectedFilter = '推荐');
              } else {
                final onCreateCircle = widget.onCreateCircle;
                if (onCreateCircle != null) {
                  onCreateCircle();
                } else {
                  _load();
                }
              }
            },
          ),
      ],
    );
  }

  String _postCategory(AppCommunityPost post) =>
      post.metadata['category']?.toString() ?? '艺术留学';

  void _openQuestionPost(AppCommunityPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }

  void _openHotTopicDiscussion(AppCommunityHotTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HotTopicDiscussionScreen(
          topic: topic,
          onAsk: () => _openHotTopicAsk(topic),
        ),
      ),
    );
  }

  Future<void> _openHotTopicAsk(AppCommunityHotTopic topic) {
    final onAsk = widget.onAsk;
    if (onAsk == null) return Future<void>.value();
    return onAsk(
      initialTitle: topic.title,
      initialCategory: topic.category,
    );
  }

  List<Map<String, dynamic>> _filterCircles(List<Map<String, dynamic>> source) {
    if (_selectedFilter == '推荐') return source;
    return source
        .asMap()
        .entries
        .where((entry) {
          final circle = entry.value;
          final originalIndex = _items.indexOf(circle);
          final circleIndex = originalIndex < 0 ? entry.key : originalIndex;
          final text =
              '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''} ${circle['city'] ?? ''}'
                  .toLowerCase();
          return switch (_selectedFilter) {
            '已加入' => _circleJoinStatus(circle, circleIndex) == 'joined',
            '留学' =>
              ['留学', '申请', 'ual', 'rca', 'risd', '作品集'].any(text.contains),
            '作品集' => ['作品集', 'portfolio', '诊断', '叙事'].any(text.contains),
            '同城' => ['同城', '上海', '北京', '伦敦', '纽约', 'city'].any(text.contains),
            '就业' => ['就业', '实习', '职业', '岗位', 'career'].any(text.contains),
            '市场' => ['市场', '展览', '收藏', '画廊', 'market'].any(text.contains),
            _ => true,
          };
        })
        .map((entry) => entry.value)
        .toList();
  }

  String _circleJoinStatus(Map<String, dynamic> circle, int index) {
    final id = _circleId(circle, index);
    final override = _joinStatusOverrides[id];
    if (override != null) return override;
    final raw = circle['join_status']?.toString();
    if (raw != null && raw.isNotEmpty) return raw;
    if (index < 2) return 'joined';
    if (index % 5 == 3) return 'pending';
    return 'none';
  }

  String _circleJoinType(Map<String, dynamic> circle, int index) {
    final raw = circle['join_type']?.toString();
    if (raw == 'open' || raw == 'approval' || raw == 'private') return raw!;
    final metadata = circle['metadata'];
    if (metadata is Map) {
      final metaRaw = metadata['join_type']?.toString();
      if (metaRaw == 'open' || metaRaw == 'approval' || metaRaw == 'private') {
        return metaRaw!;
      }
    }
    final text =
        '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
            .toLowerCase();
    if (text.contains('认证') || text.contains('研究') || index % 3 == 0) {
      return 'approval';
    }
    return 'open';
  }

  String _circleId(Map<String, dynamic> circle, int index) =>
      circle['id']?.toString() ?? '${circle['title'] ?? 'circle'}-$index';

  String get _circleFilterTitle => switch (_selectedFilter) {
        '已加入' => '已加入圈子',
        '留学' => '留学圈子',
        '作品集' => '作品集圈子',
        '同城' => '同城圈子',
        '就业' => '就业圈子',
        '市场' => '艺术市场圈子',
        _ => '推荐圈子',
      };

  String get _circleFilterSubtitle => switch (_selectedFilter) {
        '已加入' => '查看你的社群动态和新消息',
        '留学' => '申请、作品集、院校互助相关社群',
        '作品集' => '项目叙事、诊断反馈和作品集经验',
        '同城' => '附近艺术活动、展览和城市社群',
        '就业' => '实习、职业发展和行业资源',
        '市场' => '展览、收藏和艺术市场讨论',
        _ => '根据你的专业方向和社区活跃度推荐',
      };

  Future<void> _handleCircleAction(
      Map<String, dynamic> circle, int index) async {
    final status = _circleJoinStatus(circle, index);
    if (status == 'joined') {
      _openCircleDetail(circle, index);
      return;
    }
    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请正在审核中')),
      );
      return;
    }
    final id = _circleId(circle, index);
    final joinType = _circleJoinType(circle, index);
    if (joinType == 'private') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个圈子暂时不可加入')),
      );
      return;
    }
    if (!await ensureLoggedIn(context, message: '请先登录后加入圈子')) return;
    try {
      final updated = await BackendApiService.joinCommunityCircle(id);
      if (!mounted) return;
      final nextStatus = updated['join_status']?.toString() ??
          (joinType == 'approval' ? 'pending' : 'joined');
      setState(() {
        _joinStatusOverrides[id] = nextStatus;
        if (index >= 0 && index < _items.length) {
          _items[index] = {..._items[index], ...updated};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextStatus == 'pending'
              ? '申请已提交，审核通过后会通知你'
              : '已加入「${circle['title'] ?? '艺术圈子'}」'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败：$e')),
      );
    }
  }

  void _openCircleDetail(Map<String, dynamic> circle, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CircleDetailScreen(
          circle: circle,
          index: index,
          joinStatus: _circleJoinStatus(circle, index),
          onJoinChanged: (status) {
            setState(
              () => _joinStatusOverrides[_circleId(circle, index)] = status,
            );
          },
        ),
      ),
    );
  }

  void addCreatedCircle(Map<String, dynamic> circle) {
    final next = {
      ...circle,
      'join_status': 'joined',
      'member_count': circle['member_count'] ?? 1,
      'today_post_count': circle['today_post_count'] ?? 0,
      'hot_topic': circle['hot_topic'] ?? '发布第一条讨论，开启圈子交流',
    };
    setState(() {
      _items = [next, ..._items];
      _joinStatusOverrides[_circleId(next, 0)] = 'joined';
      _selectedFilter = '已加入';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCircleDetail(next, 0);
    });
  }
}

class _SalonTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _SalonTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_SalonTab> createState() => _SalonTabState();
}

class _SalonTabState extends State<_SalonTab> {
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _reservedSalonIds = {};
  bool _loading = true;
  String? _error;
  String _selectedFilter = '全部';

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
      final result =
          await BackendApiService.fetchEvents(limit: 30, type: 'salon');
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

  Future<void> _apply(Map<String, dynamic> salon, int index) async {
    final id = salon['id']?.toString() ?? 'salon-$index';
    if (_reservedSalonIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('你已经预约过这个沙龙')),
      );
      return;
    }
    final confirmed = await _confirmReservation(salon, index);
    if (confirmed != true) return;
    try {
      await BackendApiService.applyEvent(
        eventId: id,
        applyNote: '我想参加这个艺术沙龙。',
      );
      if (!mounted) return;
      setState(() => _reservedSalonIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预约已提交，你可以在私信中查看活动通知')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('报名失败：$e')),
      );
    }
  }

  Future<bool?> _confirmReservation(Map<String, dynamic> salon, int index) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('预约沙龙'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              salon['title']?.toString() ?? '未命名沙龙',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.calendar_today_outlined,
              text: _formatForumDate(salon['start_time']),
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: salon['venue']?.toString().isNotEmpty == true
                  ? salon['venue'].toString()
                  : salon['city']?.toString() ?? '地点待定',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.payments_outlined,
              text: _formatSalonFeeWithSeats(salon, index),
            ),
            const SizedBox(height: 12),
            Text(
              '预约后，活动通知会发送到私信。',
              style: TextStyle(
                color: context.artC.ink.withOpacity(0.45),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认预约'),
          ),
        ],
      ),
    );
  }

  void openReservations() {
    final reserved = _items.asMap().entries.where((entry) {
      final id = entry.value['id']?.toString() ?? 'salon-${entry.key}';
      return _reservedSalonIds.contains(id);
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReservationSheet(reserved: reserved),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 32),
        children: [
          _CommunityEmptyState(
            icon: Icons.event_outlined,
            title: '沙龙加载失败',
            subtitle: _error!,
            onRetry: _load,
          ),
        ],
      );
    }
    final searchItems = widget.searchKeyword.isEmpty
        ? _items
        : _items
            .where((salon) => _matchesSearch(
                  '${salon['title'] ?? ''} ${salon['summary'] ?? ''} ${salon['description'] ?? ''} ${salon['venue'] ?? ''} ${salon['city'] ?? ''} ${_salonGuestLine(salon, 0)}',
                  widget.searchKeyword,
                ))
            .toList();
    final visibleItems = searchItems
        .asMap()
        .entries
        .where((entry) {
          return _matchesSalonFilter(entry.value, entry.key, _selectedFilter);
        })
        .map((entry) => entry.value)
        .toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 96),
      children: [
        _PillFilterRow(
          values: const ['全部', '留学', '作品集', '校友', '就业', '市场'],
          selected: _selectedFilter,
          onSelected: (value) => setState(() => _selectedFilter = value),
        ),
        const SizedBox(height: 12),
        _CircleResultHeader(
          title: _salonFilterTitle(_selectedFilter),
          subtitle: _salonFilterSubtitle(_selectedFilter),
        ),
        const SizedBox(height: 14),
        if (visibleItems.isEmpty)
          _CommunityEmptyState(
            icon: Icons.event_outlined,
            title: '暂无${_salonFilterTitle(_selectedFilter)}',
            subtitle: '你可以关注该主题，有新活动时我们会通知你。',
            actionLabel: _selectedFilter == '全部' ? '刷新沙龙' : '查看全部',
            onRetry: () {
              if (_selectedFilter == '全部') {
                _load();
              } else {
                setState(() => _selectedFilter = '全部');
              }
            },
          )
        else
          ...visibleItems.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _SalonCard(
                    salon: entry.value,
                    index: entry.key,
                    reserved: _reservedSalonIds.contains(
                      entry.value['id']?.toString() ?? 'salon-${entry.key}',
                    ),
                    onOpen: () => _openSalonDetail(entry.value, entry.key),
                    onApply: () => _apply(entry.value, entry.key),
                  ),
                ),
              ),
      ],
    );
  }

  void _openSalonDetail(Map<String, dynamic> salon, int index) {
    final id = salon['id']?.toString() ?? 'salon-$index';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonDetailScreen(
          salon: salon,
          index: index,
          reserved: _reservedSalonIds.contains(id),
          onReserve: () async {
            await _apply(salon, index);
            return _reservedSalonIds.contains(id);
          },
        ),
      ),
    );
  }

  void addCreatedSalon(Map<String, dynamic> salon) {
    final next = {
      ...salon,
      'status': salon['status'] ?? 'published',
    };
    setState(() {
      _items = [next, ..._items];
      _selectedFilter = '全部';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openSalonDetail(next, 0);
    });
  }
}

class _ChatTab extends StatefulWidget {
  final double bottom;
  final String searchKeyword;

  const _ChatTab({
    super.key,
    required this.bottom,
    required this.searchKeyword,
  });

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  bool _imConnecting = false;
  bool _needsLogin = false;
  String? _error;
  String _selectedFilter = '全部';

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_warmTencentIm());
  }

  Future<void> _load() async {
    if (!SupabaseService.isLoggedIn) {
      setState(() {
        _items = const [];
        _loading = false;
        _imConnecting = false;
        _needsLogin = true;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _needsLogin = false;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchConversations(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = result.data;
        _loading = false;
        _needsLogin = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    unawaited(_warmTencentIm());
    await _load();
  }

  Future<void> _loginAndReload() async {
    final ok = await ensureLoggedIn(context, message: '请先登录后查看私信');
    if (!mounted || !ok) return;
    await _refreshAll();
  }

  Future<void> _warmTencentIm() async {
    if (_imConnecting) return;
    if (!SupabaseService.isLoggedIn) {
      return;
    }

    setState(() => _imConnecting = true);
    try {
      await TencentImService.ensureLoggedIn();
      if (!mounted) return;
      setState(() => _imConnecting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _imConnecting = false);
    }
  }

  bool _matchesConversationFilter(Map<String, dynamic> conversation) {
    if (_selectedFilter == '全部') return true;
    return switch (_selectedFilter) {
      '合作' => _conversationIsCooperation(conversation),
      '圈子' => _conversationIsCircle(conversation),
      '私信' => !_conversationIsCooperation(conversation) &&
          !_conversationIsCircle(conversation),
      _ => true,
    };
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LightMessageScreen(conversation: conversation),
      ),
    );
    if (mounted) unawaited(_refreshAll());
  }

  Future<void> _openFriendCandidates() async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后添加好友');
    if (!mounted || !loggedIn) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddFriendScreen(onFriendAdded: _refreshAll),
      ),
    );
    if (mounted) unawaited(_refreshAll());
  }

  Future<void> _openCreateGroupSheet() async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后创建群聊');
    if (!mounted || !loggedIn) return;
    try {
      final friends = await BackendApiService.fetchFriends(limit: 60);
      if (!mounted) return;
      final conversation = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreateMessageGroupSheet(
          friends: friends,
          onCreate: _createGroupConversation,
          onFindFriends: _openFriendCandidates,
        ),
      );
      if (!mounted || conversation == null) return;
      await _openConversation(conversation);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载好友失败：$e')),
      );
    }
  }

  Future<Map<String, dynamic>> _createGroupConversation(
    _CreateGroupPayload payload,
  ) async {
    final conversation = await BackendApiService.createConversation(
      participantIds: payload.participantIds,
      type: 'group',
      title: payload.title,
      metadata: {
        'source': 'message_create_group',
        'scene': payload.scene,
        'visibility': payload.visibility,
        if (payload.relatedTarget.isNotEmpty)
          'related_target': payload.relatedTarget,
        if (payload.announcement.isNotEmpty)
          'announcement': payload.announcement,
        'identity_label': _groupSceneIdentity(payload.scene),
      },
    );
    if (mounted) await _refreshAll();
    return conversation;
  }

  Future<void> _openGroupPlazaSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupPlazaSheet(
        onOpenCircle: _openCircleFromGroupPlaza,
      ),
    );
  }

  void _openCircleFromGroupPlaza(
    Map<String, dynamic> circle,
    int index,
    String joinStatus,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CircleDetailScreen(
          circle: circle,
          index: index,
          joinStatus: joinStatus,
          onJoinChanged: (_) {},
        ),
      ),
    );
  }

  Future<void> _openScanEntrySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScanEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_needsLogin) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 32),
        children: [
          _CommunityEmptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: '登录后查看私信',
            subtitle: '合作邀约、圈子消息、沙龙通知和好友聊天都会汇总到这里。',
            actionLabel: '去登录',
            onRetry: _loginAndReload,
          ),
        ],
      );
    }
    if (_error != null) {
      final authBlocked = _error!.contains('401') ||
          _error!.contains('400') ||
          _error!.contains('AuthSessionMissingException') ||
          _error!.contains('未授权');
      return ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottom + 32),
        children: [
          _CommunityEmptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: '私信加载失败',
            subtitle: authBlocked ? '登录后可以查看真实合作邀约、圈子消息和沙龙沟通。' : _error!,
            actionLabel: authBlocked ? '去登录' : '刷新',
            onRetry: authBlocked ? _loginAndReload : _load,
          ),
        ],
      );
    }
    final searchItems = widget.searchKeyword.isEmpty
        ? _items
        : _items
            .where((conversation) => _matchesSearch(
                  _conversationSearchText(conversation),
                  widget.searchKeyword,
                ))
            .toList();
    final visibleItems = searchItems.where(_matchesConversationFilter).toList();
    final isFiltered = _selectedFilter != '全部';
    final unreadCount = _items.fold<int>(
      0,
      (total, item) =>
          total +
          (item['unread_count'] is int
              ? item['unread_count'] as int
              : int.tryParse(item['unread_count']?.toString() ?? '') ?? 0),
    );
    final cooperationCount = _items.where(_conversationIsCooperation).length;
    final circleCount = _items.where(_conversationIsCircle).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 10, 0, widget.bottom + 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: _MessageQuickEntryRow(
            interactionCount: unreadCount,
            cooperationCount: cooperationCount,
            circleCount: circleCount,
            onInteractionTap: () => _showMessageCategoryHint(
              '互动通知会聚合赞、收藏、评论和 @，后续会从作品动态和圈子同步到这里。',
            ),
            onCooperationTap: () => setState(() => _selectedFilter = '合作'),
            onCircleTap: () => setState(() => _selectedFilter = '圈子'),
          ),
        ),
        if (visibleItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _CommunityEmptyState(
              icon: Icons.mark_chat_unread_outlined,
              title: widget.searchKeyword.isNotEmpty
                  ? '没有匹配的消息'
                  : isFiltered
                      ? '暂无$_selectedFilter消息'
                      : '暂无消息',
              subtitle: widget.searchKeyword.isNotEmpty
                  ? '换个联系人、合作或通知关键词试试。'
                  : isFiltered
                      ? '切回全部，或等待新的$_selectedFilter消息。'
                      : '新的互动、合作邀约、圈子回复和私信会显示在这里。',
              actionLabel:
                  widget.searchKeyword.isEmpty && isFiltered ? '查看全部' : '刷新消息',
              onRetry: widget.searchKeyword.isEmpty && isFiltered
                  ? () => setState(() => _selectedFilter = '全部')
                  : _refreshAll,
            ),
          )
        else
          ...visibleItems.asMap().entries.map(
                (entry) => _ChatCard(
                  conversation: entry.value,
                  index: entry.key,
                  onTap: () => _openConversation(entry.value),
                ),
              ),
      ],
    );
  }

  void _showMessageCategoryHint(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _MessageQuickEntryRow extends StatelessWidget {
  final int interactionCount;
  final int cooperationCount;
  final int circleCount;
  final VoidCallback onInteractionTap;
  final VoidCallback onCooperationTap;
  final VoidCallback onCircleTap;

  const _MessageQuickEntryRow({
    required this.interactionCount,
    required this.cooperationCount,
    required this.circleCount,
    required this.onInteractionTap,
    required this.onCooperationTap,
    required this.onCircleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MessageQuickEntry(
            icon: Icons.favorite_rounded,
            label: '互动',
            count: interactionCount,
            color: kCobalt,
            background: kCobalt.withValues(alpha: 0.08),
            onTap: onInteractionTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MessageQuickEntry(
            icon: Icons.business_center_rounded,
            label: '合作',
            count: cooperationCount,
            color: kCobalt,
            background: kCobalt.withValues(alpha: 0.08),
            onTap: onCooperationTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MessageQuickEntry(
            icon: Icons.forum_rounded,
            label: '圈子',
            count: circleCount,
            color: kCobalt,
            background: kCobalt.withValues(alpha: 0.08),
            onTap: onCircleTap,
          ),
        ),
      ],
    );
  }
}

class _MessageQuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _MessageQuickEntry({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: kCobalt,
                      border: Border.all(color: Colors.white, width: 1.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialTabs extends StatelessWidget {
  final TabController controller;

  const _SocialTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (label: '圈子', icon: Icons.groups_outlined),
      (label: '私信', icon: Icons.chat_bubble_outline),
    ];
    return ArtseeSegmentedTabs(
      controller: controller,
      tabs: tabs
          .map((tab) => ArtseeSegmentTab(label: tab.label, icon: tab.icon))
          .toList(),
      labelFontSize: 11,
      iconSize: 12.5,
    );
  }
}

class _QuickAskCard extends StatelessWidget {
  final VoidCallback onAsk;

  const _QuickAskCard({required this.onAsk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.auto_awesome, color: kCobalt, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '发起问题',
                  style: TextStyle(
                    color: Color(0xFF15171A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '带上学校、专业、城市或作品方向',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.44),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAsk,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: context.artC.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '提问',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockChipStrip extends StatelessWidget {
  final List<({String title, String count, Color color, Color text})> blocks;
  final String? selectedBlock;
  final ValueChanged<String> onSelected;

  const _BlockChipStrip({
    required this.blocks,
    required this.selectedBlock,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: blocks
            .map(
              (block) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(block.title),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selectedBlock == block.title
                          ? block.color.withValues(alpha: 0.14)
                          : context.artC.cardIconBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selectedBlock == block.title
                            ? block.text.withValues(alpha: 0.3)
                            : context.artC.silver.withValues(alpha: 0.44),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 12,
                          color: selectedBlock == block.title
                              ? block.text
                              : block.text,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          block.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: selectedBlock == block.title
                                ? block.text
                                : context.artC.ink.withValues(alpha: 0.64),
                          ),
                        ),
                      ],
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

class _RelatedCircleStrip extends StatelessWidget {
  final List<MapEntry<int, Map<String, dynamic>>> entries;
  final bool loading;
  final String? error;
  final String selectedFilter;
  final Set<String> joiningIds;
  final String Function(Map<String, dynamic> circle, int index) statusFor;
  final VoidCallback onRetry;
  final void Function(Map<String, dynamic> circle, int index) onOpen;
  final void Function(Map<String, dynamic> circle, int index) onJoin;

  const _RelatedCircleStrip({
    required this.entries,
    required this.loading,
    required this.error,
    required this.selectedFilter,
    required this.joiningIds,
    required this.statusFor,
    required this.onRetry,
    required this.onOpen,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Column(
        children: [
          _RelatedCircleSkeletonCard(),
          SizedBox(height: 10),
          _RelatedCircleSkeletonCard(),
        ],
      );
    } else if (error != null) {
      body = _RelatedCircleNotice(
        icon: Icons.groups_outlined,
        title: '圈子加载失败',
        subtitle: error!,
        actionLabel: '刷新',
        onTap: onRetry,
      );
    } else if (entries.isEmpty) {
      final joined = selectedFilter == '已加入';
      body = _RelatedCircleNotice(
        icon: Icons.groups_outlined,
        title: joined ? '还没有加入圈子' : '暂无相关圈子',
        subtitle: joined ? '先切到推荐或专业方向加入一个圈子。' : '换个方向看看，新的圈子会在这里出现。',
        actionLabel: '刷新',
        onTap: onRetry,
      );
    } else {
      final previewEntries = entries.take(2).toList();
      body = GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: previewEntries.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 188,
        ),
        itemBuilder: (_, visibleIndex) {
          final entry = previewEntries[visibleIndex];
          final circle = entry.value;
          final id = circle['id']?.toString() ?? '${entry.key}';
          final status = statusFor(circle, entry.key);
          return _RelatedCircleCard(
            circle: circle,
            index: entry.key,
            status: status,
            busy: joiningIds.contains(id),
            onOpen: () => onOpen(circle, entry.key),
            onJoin: () => onJoin(circle, entry.key),
            compact: true,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _CommunitySectionHeader(title: '相关圈子')),
            if (!loading && error == null && entries.length > 2)
              GestureDetector(
                onTap: () => _openAllCirclesSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全部 ${entries.length}',
                      style: const TextStyle(
                        color: kCobalt,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: kCobalt, size: 14),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }

  void _openAllCirclesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F7F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '相关圈子',
                            style: TextStyle(
                              color: context.artC.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: context.artC.ink,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: entries.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 188,
                      ),
                      itemBuilder: (_, visibleIndex) {
                        final entry = entries[visibleIndex];
                        final circle = entry.value;
                        final id = circle['id']?.toString() ?? '${entry.key}';
                        final status = statusFor(circle, entry.key);
                        return _RelatedCircleCard(
                          circle: circle,
                          index: entry.key,
                          status: status,
                          busy: joiningIds.contains(id),
                          compact: true,
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            onOpen(circle, entry.key);
                          },
                          onJoin: () => onJoin(circle, entry.key),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RelatedCircleCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String status;
  final bool busy;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  const _RelatedCircleCard({
    required this.circle,
    required this.index,
    required this.status,
    required this.busy,
    this.compact = false,
    required this.onOpen,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final title = circle['title']?.toString().trim().isNotEmpty == true
        ? circle['title'].toString().trim()
        : '艺术申请圈';
    final subtitle = circle['subtitle']?.toString().trim().isNotEmpty == true
        ? circle['subtitle'].toString().trim()
        : _groupPlazaSubtitle(circle, index);
    final category = _circleCategoryBadgeLabel(circle, index);
    final members = int.tryParse(circle['member_count']?.toString() ?? '') ??
        (24 + index * 7);
    final discussions =
        int.tryParse(circle['today_post_count']?.toString() ?? '') ??
            (3 + index);
    final actionLabel = _groupPlazaActionLabel(circle, index, status);

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: EdgeInsets.all(compact ? 13 : 16),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.026),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _QuestionBadge(label: category, dark: true),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  _QuestionBadge(
                    label: _circleTags(circle, index).first,
                    dark: false,
                  ),
                ],
                const Spacer(),
                Text(
                  compact ? '$members人' : '$members 人',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.34),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: compact ? 14.5 : 16,
                height: compact ? 1.18 : 1.24,
                fontWeight: FontWeight.w900,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              subtitle,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.52),
                fontSize: compact ? 10.5 : 11,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 14,
                  color: context.artC.ink.withValues(alpha: 0.34),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    compact ? '今日 $discussions 条' : '今日 $discussions 条讨论',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!compact)
                  _CircleActionButton(
                    actionLabel: actionLabel,
                    status: status,
                    busy: busy,
                    onJoin: onJoin,
                  ),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _CircleActionButton(
                  actionLabel: actionLabel,
                  status: status,
                  busy: busy,
                  onJoin: onJoin,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final String actionLabel;
  final String status;
  final bool busy;
  final VoidCallback onJoin;

  const _CircleActionButton({
    required this.actionLabel,
    required this.status,
    required this.busy,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: FilledButton(
        onPressed: busy ? null : onJoin,
        style: FilledButton.styleFrom(
          backgroundColor: status == 'joined'
              ? Colors.white
              : status == 'pending'
                  ? context.artC.silver.withValues(alpha: 0.5)
                  : context.artC.ink,
          foregroundColor: status == 'joined' ? context.artC.ink : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: status == 'joined'
                  ? context.artC.silver.withValues(alpha: 0.48)
                  : Colors.transparent,
            ),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

String _circleCategoryBadgeLabel(Map<String, dynamic> circle, int index) {
  final raw = circle['category']?.toString().trim().toLowerCase() ?? '';
  final text = _groupPlazaSearchText(circle, index).toLowerCase();
  if (raw.contains('architecture') ||
      raw.contains('space') ||
      text.contains('建筑') ||
      text.contains('空间')) {
    return '建筑空间';
  }
  if (raw.contains('portfolio') ||
      text.contains('作品集') ||
      text.contains('portfolio')) {
    return '作品集';
  }
  if (raw.contains('school') ||
      raw.contains('college') ||
      text.contains('院校') ||
      text.contains('留学') ||
      text.contains('申请') ||
      text.contains('ual') ||
      text.contains('rca')) {
    return '院校申请';
  }
  if (raw.contains('city') ||
      text.contains('同城') ||
      text.contains('城市') ||
      text.contains('伦敦') ||
      text.contains('纽约') ||
      text.contains('上海')) {
    return '同城';
  }
  if (raw.contains('career') ||
      raw.contains('job') ||
      text.contains('就业') ||
      text.contains('实习')) {
    return '就业';
  }
  if (raw.contains('market') ||
      text.contains('市场') ||
      text.contains('展览') ||
      text.contains('画廊')) {
    return '艺术市场';
  }
  if (raw.contains('art') || text.contains('媒介') || text.contains('艺术')) {
    return text.contains('媒介') ? '媒介艺术' : '艺术研究';
  }
  return _circleTags(circle, index).first.replaceFirst('#', '');
}

class _RelatedCircleNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _RelatedCircleNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: kCobalt, size: 20),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: kCobalt,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 32),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCircleSkeletonCard extends StatelessWidget {
  const _RelatedCircleSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: const Row(
        children: [
          _SkeletonLine(width: 48, height: 48, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 128, height: 14),
                SizedBox(height: 9),
                _SkeletonLine(width: 180, height: 10),
                SizedBox(height: 9),
                _SkeletonLine(width: 120, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonLine(width: 72, height: 34, radius: 10),
        ],
      ),
    );
  }
}

class _HotTopicStrip extends StatelessWidget {
  final List<AppCommunityHotTopic> topics;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<AppCommunityHotTopic> onTopicOpen;
  final ValueChanged<AppCommunityHotTopic> onTopicAsk;

  const _HotTopicStrip({
    required this.topics,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTopicOpen,
    required this.onTopicAsk,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Column(
        children: [
          _HotTopicSkeletonCard(),
          SizedBox(height: 12),
          _HotTopicSkeletonCard(),
        ],
      );
    } else if (error != null) {
      body = _CommunityEmptyState(
        icon: Icons.local_fire_department_outlined,
        title: '热议加载失败',
        subtitle: error!,
        onRetry: onRetry,
      );
    } else if (topics.isEmpty) {
      body = _CommunityEmptyState(
        icon: Icons.forum_outlined,
        title: '暂无匹配热议',
        subtitle: '换个方向或搜索词试试，也可以从顶部提问卡发起新的讨论。',
        actionLabel: '刷新热议',
        onRetry: onRetry,
      );
    } else {
      final previewTopics = topics.take(2).toList();
      body = Column(
        children: previewTopics
            .map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HotTopicCard(
                  topic: topic,
                  onOpen: () => onTopicOpen(topic),
                  onAsk: () => onTopicAsk(topic),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _CommunitySectionHeader(title: '本周热议')),
            if (!loading && error == null && topics.length > 2)
              GestureDetector(
                onTap: () => _openAllHotTopicsSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全部 ${topics.length}',
                      style: const TextStyle(
                        color: kCobalt,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: kCobalt, size: 14),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }

  void _openAllHotTopicsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F7F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '本周热议',
                            style: TextStyle(
                              color: context.artC.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: context.artC.ink,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: topics.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final topic = topics[index];
                        return _HotTopicCard(
                          topic: topic,
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            onTopicOpen(topic);
                          },
                          onAsk: () {
                            Navigator.of(sheetContext).pop();
                            onTopicAsk(topic);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuestionPostStrip extends StatelessWidget {
  final List<AppCommunityPost> posts;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<AppCommunityPost> onOpen;

  const _QuestionPostStrip({
    required this.posts,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Column(
        children: [
          _HotTopicSkeletonCard(),
          SizedBox(height: 12),
          _HotTopicSkeletonCard(),
        ],
      );
    } else if (error != null) {
      body = _CommunityEmptyState(
        icon: Icons.help_outline,
        title: '问答加载失败',
        subtitle: error!,
        onRetry: onRetry,
      );
    } else if (posts.isEmpty) {
      body = _CommunityEmptyState(
        icon: Icons.help_outline,
        title: '暂无匹配问题',
        subtitle: '换个方向或搜索词试试，也可以直接发起一个新问题。',
        actionLabel: '刷新问答',
        onRetry: onRetry,
      );
    } else {
      body = Column(
        children: posts
            .map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuestionPostCard(
                  post: post,
                  onTap: () => onOpen(post),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CommunitySectionHeader(title: '问答'),
        const SizedBox(height: 10),
        body,
      ],
    );
  }
}

class _QuestionPostCard extends StatelessWidget {
  final AppCommunityPost post;
  final VoidCallback onTap;

  const _QuestionPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = post.metadata['category']?.toString() ?? '艺术留学';
    final school = post.metadata['school']?.toString();
    final sourceCircle = post.metadata['source_circle']?.toString();
    final body = post.body?.trim();
    final author = post.authorNickname?.trim().isNotEmpty == true
        ? post.authorNickname!.trim()
        : '匿名用户';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.026),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _QuestionBadge(label: category, dark: true),
                if (school != null && school.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _QuestionBadge(label: school, dark: false),
                ] else if (sourceCircle != null && sourceCircle.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _QuestionBadge(label: sourceCircle, dark: false),
                ],
                const Spacer(),
                Text(
                  timeAgo(post.createdAt),
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.34),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                height: 1.24,
                fontWeight: FontWeight.w900,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.52),
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 14,
                  color: context.artC.ink.withValues(alpha: 0.34),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${post.commentCount} 回复 · ${post.likeCount} 赞',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.38),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HotTopicCard extends StatelessWidget {
  final AppCommunityHotTopic topic;
  final VoidCallback onOpen;
  final VoidCallback onAsk;

  const _HotTopicCard({
    required this.topic,
    required this.onOpen,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final answers = topic.answers.take(2).toList();
    final theme = topic.metadata['theme']?.toString();
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _QuestionBadge(label: topic.tag, dark: true),
                const SizedBox(width: 6),
                _QuestionBadge(
                  label: theme?.isNotEmpty == true ? theme! : topic.category,
                  dark: false,
                ),
                const Spacer(),
                Text(
                  '已有 ${topic.participantCount} 人',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.36),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topic.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w900,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const SizedBox(height: 12),
            ...answers.map(
              (answer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: kCobalt,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${answer.stance} · ',
                              style: const TextStyle(
                                color: kCobalt,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(text: answer.content),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.56),
                          fontSize: 10,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: onAsk,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.artC.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '发起讨论',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HotTopicDiscussionScreen extends StatelessWidget {
  final AppCommunityHotTopic topic;
  final Future<void> Function() onAsk;

  const _HotTopicDiscussionScreen({
    required this.topic,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = topic.metadata['theme']?.toString();
    final themeLabel = theme?.isNotEmpty == true ? theme! : topic.category;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final answers = topic.answers;
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
          '热议讨论',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton.icon(
          onPressed: () {
            onAsk();
          },
          icon: const Icon(Icons.edit_square, size: 18),
          label: const Text('发起讨论'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
        children: [
          _HotTopicDiscussionHero(
            topic: topic,
            themeLabel: themeLabel,
          ),
          const SizedBox(height: 14),
          _HotTopicDiscussionStats(topic: topic),
          const SizedBox(height: 20),
          const _CommunitySectionHeader(title: '真实用户观点'),
          const SizedBox(height: 10),
          if (answers.isEmpty)
            _CommunityEmptyState(
              icon: Icons.forum_outlined,
              title: '暂无观点内容',
              subtitle: '这个话题还在整理中，可以先发起一个具体问题。',
              actionLabel: '发起讨论',
              onRetry: () {
                onAsk();
              },
            )
          else ...[
            ...answers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HotTopicAnswerCard(
                      topicId: topic.id,
                      index: entry.key,
                      answer: entry.value,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          _HotTopicDiscussNowCard(
            topic: topic,
            onAsk: onAsk,
          ),
        ],
      ),
    );
  }
}

class _HotTopicDiscussionHero extends StatelessWidget {
  final AppCommunityHotTopic topic;
  final String themeLabel;

  const _HotTopicDiscussionHero({
    required this.topic,
    required this.themeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HotTopicHeroBadge(label: topic.tag, strong: true),
              _HotTopicHeroBadge(label: themeLabel),
              if (topic.isPinned) const _HotTopicHeroBadge(label: '置顶'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            topic.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${topic.category} · 已有 ${topic.participantCount} 人参与 · ${topic.answers.length} 个观点',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotTopicHeroBadge extends StatelessWidget {
  final String label;
  final bool strong;

  const _HotTopicHeroBadge({
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? kCobalt : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: strong ? 1 : 0.76),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HotTopicDiscussionStats extends StatelessWidget {
  final AppCommunityHotTopic topic;

  const _HotTopicDiscussionStats({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HotTopicStatTile(
            label: '参与',
            value: '${topic.participantCount}',
            icon: Icons.people_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HotTopicStatTile(
            label: '观点',
            value: '${topic.answers.length}',
            icon: Icons.forum_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HotTopicStatTile(
            label: '方向',
            value: topic.category,
            icon: Icons.tag_outlined,
          ),
        ),
      ],
    );
  }
}

class _HotTopicStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HotTopicStatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
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
          Icon(icon, color: kCobalt, size: 16),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.38),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotTopicAnswerCard extends StatefulWidget {
  final String topicId;
  final int index;
  final AppCommunityHotTopicAnswer answer;

  const _HotTopicAnswerCard({
    required this.topicId,
    required this.index,
    required this.answer,
  });

  @override
  State<_HotTopicAnswerCard> createState() => _HotTopicAnswerCardState();
}

class _HotTopicAnswerCardState extends State<_HotTopicAnswerCard> {
  late int _likeCount;
  late int _commentCount;
  late int _shareCount;
  bool _liked = false;
  bool _showCommentBox = false;
  bool _commentsLoaded = false;
  bool _commentsLoading = false;
  bool _submittingComment = false;
  List<Map<String, dynamic>> _comments = const [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likeCount = widget.answer.likeCount > 0
        ? widget.answer.likeCount
        : 48 + widget.index * 19;
    _commentCount = widget.answer.commentCount > 0
        ? widget.answer.commentCount
        : 6 + widget.index * 3;
    _shareCount = widget.answer.shareCount > 0
        ? widget.answer.shareCount
        : 2 + widget.index;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (!await ensureLoggedIn(context, message: '请先登录后赞同观点')) return;
    final previousLiked = _liked;
    final previousCount = _likeCount;
    final nextLiked = !previousLiked;
    setState(() {
      _liked = nextLiked;
      _likeCount += nextLiked ? 1 : -1;
    });

    try {
      final result = nextLiked
          ? await BackendApiService.likeHotTopicAnswer(
              topicId: widget.topicId,
              answerIndex: widget.index,
            )
          : await BackendApiService.unlikeHotTopicAnswer(
              topicId: widget.topicId,
              answerIndex: widget.index,
            );
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        if (widget.answer.likeCount > 0 || result.likeCount > previousCount) {
          _likeCount = result.likeCount;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('赞同失败：$e')),
      );
    }
  }

  Future<void> _toggleCommentBox() async {
    setState(() => _showCommentBox = !_showCommentBox);
    if (_showCommentBox) {
      await _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (_commentsLoaded || _commentsLoading) return;
    setState(() => _commentsLoading = true);
    try {
      final comments = await BackendApiService.fetchHotTopicAnswerComments(
        topicId: widget.topicId,
        answerIndex: widget.index,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoaded = true;
        _commentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论加载失败：$e')),
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submittingComment) return;
    if (!await ensureLoggedIn(context, message: '请先登录后评论观点')) return;

    setState(() => _submittingComment = true);
    try {
      final comment = await BackendApiService.createHotTopicAnswerComment(
        topicId: widget.topicId,
        answerIndex: widget.index,
        body: text,
      );
      final nextCount = comment['comment_count'] is int
          ? comment['comment_count'] as int
          : _commentCount + 1;
      if (!mounted) return;
      setState(() {
        _commentCount = nextCount;
        _comments = [..._comments, comment];
        _commentsLoaded = true;
        _submittingComment = false;
        _commentController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评论已发布')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论失败：$e')),
      );
    }
  }

  void _share() {
    setState(() => _shareCount += 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已生成转发入口')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    final index = widget.index;
    final authorName = _hotTopicAuthorName(answer, index);
    final handle = _hotTopicAuthorHandle(answer, index);
    final role = _hotTopicAuthorRole(answer, index);
    final color = _hotTopicAuthorAccent(role, index);
    final avatarUrl = _hotTopicAuthorAvatar(answer, index);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PublicUserProfileScreen(
                    userId: answer.authorId,
                    name: authorName,
                    handle: handle,
                    avatarUrl: avatarUrl,
                    roleLabel: role,
                    kind: _hotTopicProfileKind(role),
                    bio: '$role，参与艺术讨论与作品观点分享。',
                    featuredAnswerContext: '来自热议讨论的回答',
                    featuredAnswer: answer.content,
                  ),
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HotTopicAvatar(
                  url: avatarUrl,
                  name: authorName,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.artC.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            color: color,
                            size: 15,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.artC.ink.withValues(alpha: 0.38),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HotTopicIdentityChip(label: role, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            answer.content,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.58,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HotTopicActionButton(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '赞同',
                value: _likeCount,
                active: _liked,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 8),
              _HotTopicActionButton(
                icon: Icons.mode_comment_outlined,
                label: '评论',
                value: _commentCount,
                onTap: _toggleCommentBox,
              ),
              const SizedBox(width: 8),
              _HotTopicActionButton(
                icon: Icons.ios_share_rounded,
                label: '转发',
                value: _shareCount,
                onTap: _share,
              ),
            ],
          ),
          if (_showCommentBox) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '回复 $authorName 的观点...',
                        isDense: true,
                      ),
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submittingComment ? null : _submitComment,
                    style: FilledButton.styleFrom(
                      backgroundColor: kCobalt,
                      minimumSize: const Size(58, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      '发送',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_commentsLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2, color: kCobalt),
            ] else if (_comments.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._comments.take(3).map(
                    (comment) => _HotTopicCommentPreview(comment: comment),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HotTopicAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final Color color;

  const _HotTopicAvatar({
    required this.url,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        name.characters.take(1).toString(),
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url!,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _HotTopicCommentPreview extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _HotTopicCommentPreview({required this.comment});

  @override
  Widget build(BuildContext context) {
    final profile = comment['user_profiles'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    final name = profileMap?['nickname']?.toString().trim();
    final body = comment['body']?.toString().trim() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.66),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: '${name?.isNotEmpty == true ? name! : '社区用户'}：',
              style: TextStyle(
                color: context.artC.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}

class _HotTopicIdentityChip extends StatelessWidget {
  final String label;
  final Color color;

  const _HotTopicIdentityChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HotTopicActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool active;
  final VoidCallback onTap;

  const _HotTopicActionButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? kCobalt : context.artC.ink.withValues(alpha: 0.44);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? kCobalt.withValues(alpha: 0.08)
                : context.artC.porcelain,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '$label $value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _hotTopicAuthorName(AppCommunityHotTopicAnswer answer, int index) {
  final name = answer.authorName?.trim();
  if (name != null && name.isNotEmpty) return name;
  const names = ['沈予白', 'Mia Chen', '陆川霖 Lin', '王教授', '艺见心顾问团'];
  return names[index % names.length];
}

String _hotTopicAuthorHandle(AppCommunityHotTopicAnswer answer, int index) {
  final handle = answer.authorHandle?.trim();
  if (handle != null && handle.isNotEmpty) {
    return handle.startsWith('@') ? handle : '@$handle';
  }
  const handles = [
    '@shen-yubai',
    '@mia.chen',
    '@lin-studio',
    '@prof-wang',
    '@artiqore-advisor'
  ];
  return handles[index % handles.length];
}

String _hotTopicAuthorRole(AppCommunityHotTopicAnswer answer, int index) {
  final role = answer.authorRole?.trim();
  if (role != null && role.isNotEmpty) return role;
  const roles = ['认证艺术家', '在读学生', '认证艺术家', '认证导师', '机构顾问'];
  return roles[index % roles.length];
}

PublicUserProfileKind _hotTopicProfileKind(String role) {
  if (role.contains('艺术家')) return PublicUserProfileKind.artist;
  if (role.contains('学生') || role.contains('在读')) {
    return PublicUserProfileKind.student;
  }
  if (role.contains('导师') || role.contains('顾问')) {
    return PublicUserProfileKind.mentor;
  }
  return PublicUserProfileKind.user;
}

Color _hotTopicAuthorAccent(String role, int index) {
  if (role.contains('机构') || role.contains('顾问')) {
    return const Color(0xFF8D5AD7);
  }
  if (role.contains('导师')) {
    return kCobalt;
  }
  if (role.contains('艺术家')) {
    return const Color(0xFF2F9B7A);
  }
  if (role.contains('学生')) {
    return const Color(0xFF7A6A56);
  }
  const colors = [
    kCobalt,
    Color(0xFF2F9B7A),
    Color(0xFF8D5AD7),
    Color(0xFF7A6A56),
  ];
  return colors[index % colors.length];
}

String? _hotTopicAuthorAvatar(AppCommunityHotTopicAnswer answer, int index) {
  final avatar = answer.authorAvatarUrl?.trim();
  if (avatar != null && avatar.isNotEmpty) return avatar;
  return 'https://i.pravatar.cc/160?u=artsee-hot-topic-$index';
}

class _HotTopicDiscussNowCard extends StatelessWidget {
  final AppCommunityHotTopic topic;
  final Future<void> Function() onAsk;

  const _HotTopicDiscussNowCard({
    required this.topic,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onAsk();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCobalt,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.edit_square,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '发起一条新讨论',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _HotTopicSkeletonCard extends StatelessWidget {
  const _HotTopicSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 92, height: 22, radius: 999),
          SizedBox(height: 18),
          _SkeletonLine(width: 230, height: 16),
          SizedBox(height: 8),
          _SkeletonLine(width: 180, height: 16),
          SizedBox(height: 18),
          _SkeletonLine(width: 240, height: 10),
          SizedBox(height: 10),
          _SkeletonLine(width: 210, height: 10),
          SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: _SkeletonLine(width: 82, height: 28, radius: 999),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonLine({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _QuestionBadge extends StatelessWidget {
  final String label;
  final bool dark;

  const _QuestionBadge({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? kCobalt : context.artC.silver.withOpacity(0.34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : context.artC.ink.withOpacity(0.54),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PillFilterRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _PillFilterRow({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values
            .map(
              (value) => GestureDetector(
                onTap: () => onSelected(value),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? context.artC.ink
                        : context.artC.silver.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: selected == value
                          ? Colors.white
                          : context.artC.ink.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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

class _MyCircleStrip extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onBrowse;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _MyCircleStrip({
    required this.items,
    required this.onBrowse,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return GestureDetector(
        onTap: onBrowse,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.artC.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '还没有加入圈子',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '选择一个专业方向，找到同频创作者',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.54),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '浏览推荐',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final display = items;
    final totalUnread = display.length * 12;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的圈子',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${display.length} 个已加入 · $totalUnread 条新动态',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.52),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'JOINED',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...display.take(2).map(
                (circle) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => onOpen(circle),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            circle['title']?.toString() ?? '艺术圈子',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '12 新',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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

class _CircleResultHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CircleResultHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.artC.ink.withOpacity(0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.auto_awesome, color: kCobalt, size: 16),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: context.artC.silver.withOpacity(0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.artC.ink.withOpacity(0.46),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;
  final VoidCallback onOpen;
  final VoidCallback onAction;

  const _CircleCard({
    required this.circle,
    required this.index,
    required this.joinStatus,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final title = circle['title']?.toString() ?? '未命名圈子';
    final category = circle['category']?.toString().isNotEmpty == true
        ? circle['category'].toString()
        : 'Art Circle';
    final memberCount = circle['member_count'] ?? (index + 1) * 128;
    final discussions =
        int.tryParse(circle['today_post_count']?.toString() ?? '') ??
            (8 + index * 5);
    final tags = _circleTags(circle, index);
    final hotTopic = _circleHotTopic(circle, index);
    final icon = _circleIcon(circle, index);
    final action = _circleActionStyle(context, circle, index, joinStatus);

    return ArtseeSurface(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.artC.silver.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: kCobalt,
              size: 21,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.16,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            circle['subtitle']?.toString().isNotEmpty == true
                ? circle['subtitle'].toString()
                : category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: context.artC.ink.withOpacity(0.46),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: tags.take(2).map((tag) => _MiniTag(label: tag)).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '热议：$hotTopic',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withOpacity(0.56),
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$memberCount 人 · 今日 $discussions 条',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink.withOpacity(0.38),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: action.background,
                borderRadius: BorderRadius.circular(12),
                border: action.borderColor == null
                    ? null
                    : Border.all(color: action.borderColor!),
              ),
              child: Text(
                action.label,
                style: TextStyle(
                  color: action.foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;
  final ValueChanged<String> onJoinChanged;

  const CircleDetailScreen({
    super.key,
    required this.circle,
    required this.index,
    required this.joinStatus,
    required this.onJoinChanged,
  });

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  late String _joinStatus = widget.joinStatus;
  String _selectedSection = '概览';
  final List<({String type, String title, String meta})> _localPosts = [];
  final List<({String type, String title, String meta})> _localQuestions = [];

  @override
  Widget build(BuildContext context) {
    final title = widget.circle['title']?.toString() ?? '未命名圈子';
    final subtitle = widget.circle['subtitle']?.toString().isNotEmpty == true
        ? widget.circle['subtitle'].toString()
        : widget.circle['category']?.toString() ?? 'Art Circle';
    final memberCount =
        widget.circle['member_count'] ?? (widget.index + 1) * 128;
    final discussions =
        int.tryParse(widget.circle['today_post_count']?.toString() ?? '') ??
            (8 + widget.index * 5);
    final tags = _circleTags(widget.circle, widget.index);

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.artC.ink,
        centerTitle: true,
        title: const Text('圈子'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('圈子链接已准备好，稍后开放分享')),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 19),
          ),
        ],
      ),
      bottomNavigationBar: _CircleDetailBottomBar(
        circle: widget.circle,
        index: widget.index,
        joinStatus: _joinStatus,
        onJoin: _handleAction,
        onPost: _openPostComposer,
        onAsk: _openAskQuestion,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.paddingOf(context).bottom + 104,
        ),
        children: [
          _CircleDetailHero(
            circle: widget.circle,
            index: widget.index,
            title: title,
            subtitle: subtitle,
            tags: tags,
            memberCount: memberCount,
            discussions: discussions,
            joinStatus: _joinStatus,
          ),
          const SizedBox(height: 12),
          _CircleJoinInsightCard(
            circle: widget.circle,
            index: widget.index,
            joinStatus: _joinStatus,
          ),
          const SizedBox(height: 14),
          _CircleAnnouncement(circle: widget.circle, index: widget.index),
          const SizedBox(height: 16),
          _CircleDetailTabs(
            selected: _selectedSection,
            onSelected: (value) => setState(() => _selectedSection = value),
          ),
          const SizedBox(height: 12),
          ..._buildSectionItems(),
        ],
      ),
    );
  }

  List<Widget> _buildSectionItems() {
    if (_selectedSection == '概览') {
      return [
        _CircleOverviewSection(
          circle: widget.circle,
          index: widget.index,
          joinStatus: _joinStatus,
        ),
      ];
    }
    final items = switch (_selectedSection) {
      '问答' => [
          ..._localQuestions,
          ..._circleQuestionItems(widget.circle, widget.index),
        ],
      '活动' => _circleEventItems(widget.circle, widget.index),
      _ => [..._localPosts, ..._circleFeedItems(widget.circle, widget.index)],
    };
    if (items.isEmpty) {
      return [
        _CommunityEmptyState(
          icon: Icons.forum_outlined,
          title: '还没有内容',
          subtitle: '发布第一条动态，或从圈子里发起一个问题。',
          actionLabel: '发动态',
          onRetry: _openPostComposer,
        ),
      ];
    }
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CircleFeedItem(item: item),
          ),
        )
        .toList();
  }

  Future<void> _handleAction() async {
    if (_joinStatus == 'joined') return;
    if (_joinStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请正在审核中')),
      );
      return;
    }
    final joinType = _circleJoinType(widget.circle, widget.index);
    if (joinType == 'private') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个圈子暂时不可加入')),
      );
      return;
    }
    if (!await ensureLoggedIn(context, message: '请先登录后加入圈子')) return;
    final id = widget.circle['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圈子缺少 ID，暂时无法加入')),
      );
      return;
    }
    try {
      final updated = await BackendApiService.joinCommunityCircle(id);
      if (!mounted) return;
      final nextStatus = updated['join_status']?.toString() ??
          (joinType == 'approval' ? 'pending' : 'joined');
      widget.circle.addAll(updated);
      setState(() => _joinStatus = nextStatus);
      widget.onJoinChanged(nextStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextStatus == 'pending'
              ? '申请已提交，审核通过后会通知你'
              : '已加入「${widget.circle['title'] ?? '艺术圈子'}」'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败：$e')),
      );
    }
  }

  Future<void> _openPostComposer() async {
    if (_joinStatus != 'joined') {
      await _handleAction();
      if (_joinStatus != 'joined') return;
    }
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PostComposerModal(),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final id = widget.circle['id']?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圈子缺少 ID，暂时无法发布')),
      );
      return;
    }
    try {
      await BackendApiService.createCommunityPost(
        title: text,
        body: text,
        metadata: {
          'kind': 'circle',
          'circle_id': id,
          'source_circle': widget.circle['title']?.toString() ?? '艺术圈子',
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedSection = '动态';
        _localPosts.insert(
          0,
          (type: '讨论', title: text, meta: '刚刚 · 0 回复'),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('动态已发布')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    }
  }

  Future<void> _openAskQuestion() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布问题')) return;
    final title = widget.circle['title']?.toString() ?? '艺术圈子';
    final createdTitle = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => AskQuestionScreen(
          initialCategory: _circleQuestionCategory(widget.circle, widget.index),
          initialSchool: _circleRelatedSchool(widget.circle, widget.index),
          sourceCircle: title,
        ),
      ),
    );
    if (createdTitle == null || !mounted) return;
    setState(() {
      _selectedSection = '问答';
      _localQuestions.insert(
        0,
        (type: '提问', title: createdTitle, meta: '刚刚 · 0 回答'),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问题已发布，也会进入问答流')),
    );
  }
}

class _CircleOverviewSection extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;

  const _CircleOverviewSection({
    required this.circle,
    required this.index,
    required this.joinStatus,
  });

  @override
  Widget build(BuildContext context) {
    final title = circle['title']?.toString() ?? '艺术圈子';
    final subtitle = circle['subtitle']?.toString().isNotEmpty == true
        ? circle['subtitle'].toString()
        : circle['category']?.toString() ?? '这个圈子的定位还在完善';
    final members = circle['member_count'] ?? (index + 1) * 128;
    final discussions =
        int.tryParse(circle['today_post_count']?.toString() ?? '') ??
            (8 + index * 5);
    final joinType = _circleJoinType(circle, index);
    final tags = _circleTags(circle, index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: context.artC.ink.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '圈子概览',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.52),
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CircleOverviewMetric(
                      label: '成员',
                      value: '$members',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CircleOverviewMetric(
                      label: '今日动态',
                      value: '$discussions',
                      icon: Icons.bolt_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CircleOverviewMetric(
                      label: '加入方式',
                      value: joinType == 'approval'
                          ? '审核'
                          : joinType == 'private'
                              ? '私密'
                              : '开放',
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 13),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => _MiniTag(label: tag)).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCobalt.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_outlined,
                    color: kCobalt,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '正在聊：${_circleHotTopic(circle, index)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kCobalt,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _circleAnnouncementText(circle, index),
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.56),
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.artC.silver.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                joinStatus == 'joined' ? '你可以在这里做什么' : '加入前可以先了解',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              _CircleOverviewLine(
                icon: Icons.chat_bubble_outline_rounded,
                text: '看圈内动态，了解$title最近的讨论方向。',
              ),
              _CircleOverviewLine(
                icon: Icons.help_outline,
                text: '把具体问题发到问答，方便同方向成员集中回答。',
              ),
              _CircleOverviewLine(
                icon: Icons.event_available_outlined,
                text: '关注活动、互评和资源交换，不错过重要节点。',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleOverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CircleOverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kCobalt, size: 17),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleOverviewLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CircleOverviewLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kCobalt, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.54),
                fontSize: 11.2,
                height: 1.38,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleDetailHero extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String title;
  final String subtitle;
  final List<String> tags;
  final Object memberCount;
  final int discussions;
  final String joinStatus;

  const _CircleDetailHero({
    required this.circle,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.memberCount,
    required this.discussions,
    required this.joinStatus,
  });

  @override
  Widget build(BuildContext context) {
    final hotTopic = _circleHotTopic(circle, index);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Icon(
                  _circleIcon(circle, index),
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _CircleDarkBadge(
                          label: _circleDetailStatusText(
                              circle, index, joinStatus),
                          strong: true,
                        ),
                        _CircleDarkBadge(
                          label:
                              circle['category']?.toString().isNotEmpty == true
                                  ? circle['category'].toString()
                                  : 'Art Circle',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Noto Serif SC',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              height: 1.45,
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
                  .map((tag) => _CircleDarkBadge(label: tag))
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CircleHeroMetric(
                  label: '成员',
                  value: '$memberCount',
                  icon: Icons.people_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CircleHeroMetric(
                  label: '今日动态',
                  value: '$discussions',
                  icon: Icons.bolt_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CircleHeroMetric(
                  label: '加入方式',
                  value: _circleJoinType(circle, index) == 'approval'
                      ? '审核'
                      : _circleJoinType(circle, index) == 'private'
                          ? '私密'
                          : '开放',
                  icon: Icons.verified_user_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '正在聊：$hotTopic',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
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

class _CircleDarkBadge extends StatelessWidget {
  final String label;
  final bool strong;

  const _CircleDarkBadge({
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? kCobalt : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: strong ? 1 : 0.72),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CircleHeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CircleHeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.72), size: 16),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String _circleDetailStatusText(
  Map<String, dynamic> circle,
  int index,
  String status,
) {
  if (status == 'joined') return '已加入';
  if (status == 'pending') return '审核中';
  final joinType = _circleJoinType(circle, index);
  if (joinType == 'private') return '私密圈子';
  if (joinType == 'approval') return '需审核';
  return '开放加入';
}

({String title, String body, IconData icon, Color color})
    _circleJoinInsightCopy(
  String status,
  String joinType,
) {
  if (status == 'joined') {
    return (
      title: '你已加入这个圈子',
      body: '可以发布动态、发起问题，也可以跟进圈内作品集反馈、活动和资源更新。',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF16A34A),
    );
  }
  if (status == 'pending') {
    return (
      title: '申请正在审核中',
      body: '审核通过后会通知你。通过前可以先浏览圈子公告和公开动态。',
      icon: Icons.hourglass_top_rounded,
      color: const Color(0xFFEA580C),
    );
  }
  if (joinType == 'private') {
    return (
      title: '暂不开放加入',
      body: '这个圈子当前为私密状态，可以先浏览其他推荐圈子或关注后续开放。',
      icon: Icons.lock_outline,
      color: const Color(0xFF64748B),
    );
  }
  if (joinType == 'approval') {
    return (
      title: '需要审核后加入',
      body: '提交申请后由圈子管理员确认。适合认证校友、研究小组或项目协作圈。',
      icon: Icons.verified_user_outlined,
      color: kCobalt,
    );
  }
  return (
    title: '开放加入',
    body: '加入后即可发布动态、提问题、参与作品互评，并接收圈内新活动提醒。',
    icon: Icons.group_add_outlined,
    color: kCobalt,
  );
}

class _CircleJoinInsightCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;

  const _CircleJoinInsightCard({
    required this.circle,
    required this.index,
    required this.joinStatus,
  });

  @override
  Widget build(BuildContext context) {
    final joinType = _circleJoinType(circle, index);
    final copy = _circleJoinInsightCopy(joinStatus, joinType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: copy.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(copy.icon, color: copy.color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  copy.body,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.52),
                    fontSize: 11,
                    height: 1.45,
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

class _CircleDetailBottomBar extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;
  final VoidCallback onJoin;
  final VoidCallback onPost;
  final VoidCallback onAsk;

  const _CircleDetailBottomBar({
    required this.circle,
    required this.index,
    required this.joinStatus,
    required this.onJoin,
    required this.onPost,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final action = _circleActionStyle(context, circle, index, joinStatus);
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: joinStatus == 'joined'
            ? Row(
                children: [
                  Expanded(
                    child: _CircleBottomAction(
                      label: '提问题',
                      icon: Icons.help_outline,
                      dark: false,
                      onTap: onAsk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CircleBottomAction(
                      label: '发动态',
                      icon: Icons.edit_square,
                      dark: true,
                      onTap: onPost,
                    ),
                  ),
                ],
              )
            : _CircleBottomAction(
                label: action.label,
                icon: _circleJoinType(circle, index) == 'approval'
                    ? Icons.verified_user_outlined
                    : Icons.group_add_outlined,
                dark: action.borderColor == null,
                background: action.background,
                foreground: action.foreground,
                borderColor: action.borderColor,
                onTap: onJoin,
              ),
      ),
    );
  }
}

class _CircleBottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final VoidCallback onTap;

  const _CircleBottomAction({
    required this.label,
    required this.icon,
    required this.dark,
    required this.onTap,
    this.background,
    this.foreground,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (dark ? context.artC.ink : context.artC.silver.withValues(alpha: 0.22));
    final fg = foreground ?? (dark ? Colors.white : context.artC.ink);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(17),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: fg,
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

class _CircleAnnouncement extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;

  const _CircleAnnouncement({required this.circle, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '圈子公告',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _circleAnnouncementText(circle, index),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 11,
                    height: 1.45,
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

class _CircleDetailTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CircleDetailTabs({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const values = ['概览', '动态', '问答', '活动'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.artC.silver.withOpacity(0.32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: values
            .map(
              (value) => Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(value),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected == value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: selected == value
                            ? kCobalt
                            : context.artC.ink.withOpacity(0.42),
                        fontSize: 12,
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

class _CircleFeedItem extends StatelessWidget {
  final ({String type, String title, String meta}) item;

  const _CircleFeedItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.artC.silver.withOpacity(0.36)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.artC.silver.withOpacity(0.24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_feedIcon(item.type), color: kCobalt, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[${item.type}] ${item.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.meta,
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.38),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

class _CircleActionStyle {
  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  const _CircleActionStyle({
    required this.label,
    required this.background,
    required this.foreground,
    this.borderColor,
  });
}

String _circleJoinType(Map<String, dynamic> circle, int index) {
  final raw = circle['join_type']?.toString();
  if (raw == 'open' || raw == 'approval' || raw == 'private') return raw!;
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('认证') || text.contains('研究') || index % 3 == 0) {
    return 'approval';
  }
  return 'open';
}

_CircleActionStyle _circleActionStyle(
  BuildContext context,
  Map<String, dynamic> circle,
  int index,
  String status,
) {
  final joinType = _circleJoinType(circle, index);
  if (status == 'joined') {
    return _CircleActionStyle(
      label: '进入',
      background: context.artC.silver.withOpacity(0.28),
      foreground: context.artC.ink,
    );
  }
  if (status == 'pending') {
    return _CircleActionStyle(
      label: '审核中',
      background: context.artC.silver.withOpacity(0.48),
      foreground: context.artC.ink.withOpacity(0.42),
    );
  }
  if (joinType == 'private') {
    return _CircleActionStyle(
      label: '暂不可加入',
      background: context.artC.silver.withOpacity(0.4),
      foreground: context.artC.ink.withOpacity(0.36),
    );
  }
  if (joinType == 'approval') {
    return _CircleActionStyle(
      label: '申请加入',
      background: context.artC.ink,
      foreground: Colors.white,
    );
  }
  return const _CircleActionStyle(
    label: '加入',
    background: kCobalt,
    foreground: Colors.white,
  );
}

List<String> _circleTags(Map<String, dynamic> circle, int index) {
  final metadata = circle['metadata'];
  if (metadata is Map) {
    final tags = metadata['tags'];
    if (tags is List && tags.isNotEmpty) {
      return tags.map((tag) => tag.toString()).take(3).toList();
    }
    final directions = metadata['directions'];
    if (directions is List && directions.isNotEmpty) {
      return directions.map((item) => '#${item.toString()}').take(3).toList();
    }
  }
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('ual') ||
      text.contains('rca') ||
      text.contains('留学') ||
      text.contains('申请')) {
    return const ['#UAL', '#RCA', '#申请'];
  }
  if (text.contains('建筑') || text.contains('空间')) {
    return const ['#建筑', '#空间'];
  }
  if (text.contains('媒介') || text.contains('新媒体')) {
    return const ['#媒介艺术', '#作品集'];
  }
  if (text.contains('就业') || text.contains('实习') || text.contains('career')) {
    return const ['#实习', '#职业发展'];
  }
  if (text.contains('市场') || text.contains('收藏') || text.contains('画廊')) {
    return const ['#展览', '#收藏'];
  }
  if (index % 4 == 1) return const ['#作品集', '#诊断'];
  if (index % 4 == 2) return const ['#同城', '#活动'];
  return const ['#作品集', '#留学'];
}

String _circleHotTopic(Map<String, dynamic> circle, int index) {
  final raw = circle['hot_topic']?.toString();
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  final metadata = circle['metadata'];
  if (metadata is Map) {
    final metaRaw = metadata['hot_topic']?.toString();
    if (metaRaw != null && metaRaw.trim().isNotEmpty) return metaRaw.trim();
  }
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('建筑') || text.contains('空间')) return '新中式空间叙事怎么做？';
  if (text.contains('ual') || text.contains('rca') || text.contains('留学')) {
    return 'RCA / UAL 面试作品集怎么讲？';
  }
  if (text.contains('媒介') || text.contains('新媒体')) {
    return '作品集主题如何从材料实验展开？';
  }
  if (text.contains('就业') || text.contains('实习')) return '艺术生第一份实习怎么找？';
  if (text.contains('市场') || text.contains('收藏')) return '年轻艺术家如何进入展览体系？';
  return [
    '作品集主题如何从材料实验展开？',
    '申请季目标院校怎么分层？',
    '项目叙事太散怎么收束？',
  ][index % 3];
}

String _circleAnnouncementText(Map<String, dynamic> circle, int index) {
  final metadata = circle['metadata'];
  if (metadata is Map) {
    final raw = metadata['announcement']?.toString();
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  }
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('ual') || text.contains('rca') || text.contains('留学')) {
    return '本圈用于交流 RCA / UAL 申请、作品集准备、面试经验和材料时间线。';
  }
  if (text.contains('建筑') || text.contains('空间')) {
    return '这里聚合空间叙事、建筑作品集和文旅场景案例，欢迎分享项目过程。';
  }
  return '这里用于交流专业方向、作品集反馈、资源分享和同频创作者机会。';
}

IconData _circleIcon(Map<String, dynamic> circle, int index) {
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (_circleJoinType(circle, index) == 'approval') {
    return Icons.verified_user_outlined;
  }
  if (text.contains('伦敦') || text.contains('上海') || text.contains('同城')) {
    return Icons.location_on_outlined;
  }
  if (text.contains('ual') || text.contains('rca') || text.contains('院校')) {
    return Icons.school_outlined;
  }
  if (text.contains('就业') || text.contains('实习')) {
    return Icons.work_outline;
  }
  return Icons.groups_outlined;
}

List<({String type, String title, String meta})> _circleFeedItems(
  Map<String, dynamic> circle,
  int index,
) {
  final hotTopic = _circleHotTopic(circle, index);
  return [
    (
      type: '讨论',
      title: hotTopic,
      meta: '18 分钟前 · 12 个回复',
    ),
    (
      type: '作品集反馈',
      title: '我的第 3 个项目叙事太散，求建议',
      meta: '今天 14:20 · 6 张参考图',
    ),
    (
      type: '资源',
      title: 'UAL 申请材料 checklist',
      meta: '昨天 · 42 人收藏',
    ),
    (
      type: '活动',
      title: '本周六线上作品集诊断',
      meta: '06.08 20:00 · 可预约',
    ),
  ];
}

List<({String type, String title, String meta})> _circleQuestionItems(
  Map<String, dynamic> circle,
  int index,
) {
  final hotTopic = _circleHotTopic(circle, index);
  return [
    (
      type: '问答',
      title: hotTopic,
      meta: '8 回答 · 2 个认证回答',
    ),
    (
      type: '问答',
      title: '这个方向适合申请哪些院校作为主申？',
      meta: '5 回答 · 240 浏览',
    ),
    (
      type: '问答',
      title: '作品集里过程页和最终页比例怎么把握？',
      meta: '12 回答 · 1 个认证回答',
    ),
  ];
}

List<({String type, String title, String meta})> _circleEventItems(
  Map<String, dynamic> circle,
  int index,
) {
  return [
    (
      type: '活动',
      title: '线上作品集诊断小组',
      meta: '06.08 20:00 · 剩余 6 席',
    ),
    (
      type: '活动',
      title: '校友申请经验分享会',
      meta: '06.15 19:30 · 可预约',
    ),
    (
      type: '活动',
      title: '圈子成员作品互评夜',
      meta: '每周三 · 线上',
    ),
  ];
}

String _circleQuestionCategory(Map<String, dynamic> circle, int index) {
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('市场') || text.contains('收藏') || text.contains('画廊')) {
    return '艺术市场';
  }
  if (text.contains('就业') || text.contains('实习') || text.contains('career')) {
    return '行业就业';
  }
  if (text.contains('作品集') || text.contains('媒介') || text.contains('建筑')) {
    return '作品集';
  }
  return '艺术留学';
}

String? _circleRelatedSchool(Map<String, dynamic> circle, int index) {
  final text =
      '${circle['title'] ?? ''} ${circle['subtitle'] ?? ''} ${circle['category'] ?? ''}'
          .toLowerCase();
  if (text.contains('ual')) return 'UAL';
  if (text.contains('rca') || text.contains('皇艺')) return 'RCA';
  if (text.contains('risd')) return 'RISD';
  return null;
}

IconData _feedIcon(String type) => switch (type) {
      '作品集反馈' => Icons.image_search_outlined,
      '问答' => Icons.help_outline,
      '资源' => Icons.bookmark_border,
      '活动' => Icons.event_available_outlined,
      _ => Icons.forum_outlined,
    };

class _SalonCard extends StatelessWidget {
  final Map<String, dynamic> salon;
  final int index;
  final bool reserved;
  final VoidCallback onOpen;
  final VoidCallback onApply;

  const _SalonCard({
    required this.salon,
    required this.index,
    required this.reserved,
    required this.onOpen,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = _salonTypeLabel(salon, index);
    final statusLabel = reserved ? '已预约' : _salonStatusLabel(salon, index);
    final seatsLeft = _salonSeatsLeft(salon, index);
    final guest = _salonGuestLine(salon, index);
    final benefit = _salonBenefitLine(salon, index);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.artC.silver.withOpacity(0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.55,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    salon['cover_url']?.toString().isNotEmpty == true
                        ? Image.network(
                            salon['cover_url'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: context.artC.silver.withOpacity(0.3),
                              child: Icon(
                                Icons.image_outlined,
                                size: 50,
                                color: context.artC.ink.withOpacity(0.2),
                              ),
                            ),
                          )
                        : Container(
                            color: context.artC.silver.withOpacity(0.3),
                            child: Icon(
                              Icons.event_outlined,
                              size: 50,
                              color: context.artC.ink.withOpacity(0.2),
                            ),
                          ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.artC.ink.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _salonStatusColor(statusLabel, context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel == '可预约' && seatsLeft <= 6
                              ? '剩余 $seatsLeft 席'
                              : statusLabel,
                          style: TextStyle(
                            color: statusLabel == '已结束' || statusLabel == '回放'
                                ? context.artC.ink
                                : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
                  Text(
                    salon['title']?.toString() ?? '未命名沙龙',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    salon['summary']?.toString().isNotEmpty == true
                        ? salon['summary'].toString()
                        : salon['description']?.toString() ?? '艺术沙龙与线下交流活动。',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.42,
                      color: context.artC.ink.withOpacity(0.44),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(icon: Icons.person_outline, text: '嘉宾：$guest'),
                  const SizedBox(height: 7),
                  _InfoLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatForumDate(salon['start_time']),
                  ),
                  const SizedBox(height: 7),
                  _InfoLine(
                    icon: Icons.location_on_outlined,
                    text: salon['venue']?.toString().isNotEmpty == true
                        ? salon['venue'].toString()
                        : salon['city']?.toString() ?? '地点待定',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatSalonFeeWithSeats(salon, index),
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.artC.ink.withOpacity(0.34),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: statusLabel == '已结束' || statusLabel == '回放'
                        ? onOpen
                        : reserved
                            ? null
                            : onApply,
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: reserved
                            ? context.artC.silver.withOpacity(0.35)
                            : context.artC.ink,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        reserved
                            ? '已预约'
                            : statusLabel == '已结束' || statusLabel == '回放'
                                ? '看回放'
                                : '立即预约 →',
                        style: TextStyle(
                          color: reserved
                              ? context.artC.ink.withOpacity(0.5)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
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
}

class SalonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> salon;
  final int index;
  final bool reserved;
  final Future<bool> Function() onReserve;

  const SalonDetailScreen({
    super.key,
    required this.salon,
    required this.index,
    required this.reserved,
    required this.onReserve,
  });

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  late bool _reserved = widget.reserved;
  bool _submitting = false;

  Future<void> _handleReserve() async {
    if (_submitting || _reserved) return;
    setState(() => _submitting = true);
    final reserved = await widget.onReserve();
    if (!mounted) return;
    setState(() {
      _reserved = reserved;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status =
        _reserved ? '已预约' : _salonStatusLabel(widget.salon, widget.index);
    final type = _salonTypeLabel(widget.salon, widget.index);
    final seats = _salonSeatsLeft(widget.salon, widget.index);
    final guest = _salonGuestLine(widget.salon, widget.index);
    final benefit = _salonBenefitLine(widget.salon, widget.index);
    final title = widget.salon['title']?.toString() ?? '未命名沙龙';
    final summary = widget.salon['summary']?.toString().isNotEmpty == true
        ? widget.salon['summary'].toString()
        : widget.salon['description']?.toString() ?? '艺术沙龙与线下交流活动。';
    final venue = _salonVenue(widget.salon);
    final canReserve =
        !_reserved && !_submitting && status != '已结束' && status != '回放';
    final bottom = MediaQuery.paddingOf(context).bottom;

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
          '沙龙详情',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded,
                color: context.artC.ink, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('沙龙分享功能稍后开放')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _SalonDetailBottomBar(
        status: status,
        reserved: _reserved,
        submitting: _submitting,
        canReserve: canReserve,
        feeLine: _formatSalonFeeWithSeats(widget.salon, widget.index),
        onReserve: _handleReserve,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 120),
        children: [
          _SalonDetailHero(
            salon: widget.salon,
            title: title,
            summary: summary,
            type: type,
            status: status,
            seats: seats,
            venue: venue,
            dateLine: _formatForumDate(widget.salon['start_time']),
          ),
          const SizedBox(height: 14),
          _SalonBookingSnapshot(
            status: status,
            seats: seats,
            fee: _formatSalonFeeWithSeats(widget.salon, widget.index),
          ),
          const SizedBox(height: 14),
          _SalonInvitationCard(summary: summary),
          const SizedBox(height: 14),
          _SalonHostCard(
            guest: guest,
            benefit: benefit,
            type: type,
          ),
          const SizedBox(height: 14),
          _SalonHighlightGrid(
            items: _salonHighlights(widget.salon, widget.index),
          ),
          const SizedBox(height: 18),
          const _CommunitySectionHeader(title: '活动流程', action: 'PLAN'),
          const SizedBox(height: 10),
          _SalonItineraryCard(
            items: _salonItinerary(widget.salon, widget.index),
          ),
          const SizedBox(height: 18),
          const _CommunitySectionHeader(title: '适合人群', action: 'MATCH'),
          const SizedBox(height: 10),
          _SalonAudienceCard(
            items: _salonAudience(widget.salon, widget.index),
          ),
        ],
      ),
    );
  }
}

class _SalonDetailHero extends StatelessWidget {
  final Map<String, dynamic> salon;
  final String title;
  final String summary;
  final String type;
  final String status;
  final int seats;
  final String venue;
  final String dateLine;

  const _SalonDetailHero({
    required this.salon,
    required this.title,
    required this.summary,
    required this.type,
    required this.status,
    required this.seats,
    required this.venue,
    required this.dateLine,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = salon['cover_url']?.toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        height: 380,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _SalonHeroFallback(),
              )
            else
              _SalonHeroFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.artC.ink.withValues(alpha: 0.05),
                    context.artC.ink.withValues(alpha: 0.42),
                    context.artC.ink.withValues(alpha: 0.92),
                  ],
                  stops: const [0.08, 0.46, 1],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SalonGlassBadge(label: type, strong: true),
                  _SalonGlassBadge(
                    label:
                        status == '可预约' && seats <= 6 ? '剩余 $seats 席' : status,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SalonHeroInfoLine(
                    icon: Icons.calendar_today_outlined,
                    text: dateLine,
                  ),
                  const SizedBox(height: 8),
                  _SalonHeroInfoLine(
                    icon: Icons.location_on_outlined,
                    text: venue,
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

class _SalonHeroFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.artC.ink,
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white.withValues(alpha: 0.24),
          size: 72,
        ),
      ),
    );
  }
}

class _SalonGlassBadge extends StatelessWidget {
  final String label;
  final bool strong;

  const _SalonGlassBadge({
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: strong ? kCobalt : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: strong ? 1 : 0.82),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SalonHeroInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SalonHeroInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kCobalt, size: 16),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalonBookingSnapshot extends StatelessWidget {
  final String status;
  final int seats;
  final String fee;

  const _SalonBookingSnapshot({
    required this.status,
    required this.seats,
    required this.fee,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SalonSnapshotTile(
            icon: Icons.event_available_outlined,
            label: '状态',
            value: status == '可预约' ? '开放预约' : status,
            color: _salonStatusAccent(status),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SalonSnapshotTile(
            icon: Icons.event_seat_outlined,
            label: '席位',
            value: '$seats 席',
            color: kCobalt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SalonSnapshotTile(
            icon: Icons.payments_outlined,
            label: '费用',
            value: fee.split('/').first.trim(),
            color: context.artC.ink,
          ),
        ),
      ],
    );
  }
}

class _SalonSnapshotTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SalonSnapshotTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
          Icon(icon, color: color, size: 17),
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

class _SalonInvitationCard extends StatelessWidget {
  final String summary;

  const _SalonInvitationCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_activity_outlined,
                  color: kCobalt,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  '本场邀请',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Noto Serif SC',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.58),
              fontSize: 12,
              height: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonHostCard extends StatelessWidget {
  final String guest;
  final String benefit;
  final String type;

  const _SalonHostCard({
    required this.guest,
    required this.benefit,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  guest,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Noto Serif SC',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  benefit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    height: 1.45,
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

class _SalonHighlightGrid extends StatelessWidget {
  final List<({IconData icon, String title, String body})> items;

  const _SalonHighlightGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.artC.silver.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: kCobalt, size: 18),
              ),
              const SizedBox(height: 9),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.46),
                  fontSize: 10,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalonItineraryCard extends StatelessWidget {
  final List<({String time, String title, String body})> items;

  const _SalonItineraryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .map(
              (entry) => _SalonTimelineRow(
                item: entry.value,
                last: entry.key == items.length - 1,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SalonTimelineRow extends StatelessWidget {
  final ({String time, String title, String body}) item;
  final bool last;

  const _SalonTimelineRow({
    required this.item,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            item.time,
            style: const TextStyle(
              color: kCobalt,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: kCobalt,
                shape: BoxShape.circle,
              ),
            ),
            if (!last)
              Container(
                width: 1,
                height: 52,
                color: context.artC.silver.withValues(alpha: 0.46),
              ),
          ],
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.46),
                    fontSize: 11,
                    height: 1.4,
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

class _SalonAudienceCard extends StatelessWidget {
  final List<String> items;

  const _SalonAudienceCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
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
                        item,
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

class _SalonDetailBottomBar extends StatelessWidget {
  final String status;
  final bool reserved;
  final bool submitting;
  final bool canReserve;
  final String feeLine;
  final Future<void> Function() onReserve;

  const _SalonDetailBottomBar({
    required this.status,
    required this.reserved,
    required this.submitting,
    required this.canReserve,
    required this.feeLine,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final label = reserved
        ? '已预约'
        : submitting
            ? '提交中'
            : status == '回放'
                ? '看回放'
                : status == '已结束'
                    ? '已结束'
                    : '立即预约';
    final enabled = canReserve;
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feeLine,
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
                    reserved ? '活动通知会进入私信' : '预约后可在私信查看通知',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              onTap: enabled ? onReserve : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled
                      ? context.artC.ink
                      : context.artC.silver.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(17),
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

class _ReservationSheet extends StatelessWidget {
  final List<MapEntry<int, Map<String, dynamic>>> reserved;

  const _ReservationSheet({required this.reserved});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
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
              '我的预约',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const SizedBox(height: 12),
            if (reserved.isEmpty)
              _CommunityEmptyState(
                icon: Icons.event_available_outlined,
                title: '暂无预约',
                subtitle: '预约沙龙后会显示在这里，活动通知也会进入私信。',
                actionLabel: '去看沙龙',
                onRetry: () => Navigator.of(context).pop(),
              )
            else
              ...reserved.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReservationRow(salon: entry.value, index: entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReservationRow extends StatelessWidget {
  final Map<String, dynamic> salon;
  final int index;

  const _ReservationRow({required this.salon, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.artC.silver.withOpacity(0.36)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: kCobalt, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salon['title']?.toString() ?? '未命名沙龙',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatForumDate(salon['start_time']),
                  style: TextStyle(
                    color: context.artC.ink.withOpacity(0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '已预约',
            style: TextStyle(
              color: kCobalt,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _salonVenue(Map<String, dynamic> salon) {
  final venue = salon['venue']?.toString();
  if (venue != null && venue.trim().isNotEmpty) return venue.trim();
  final city = salon['city']?.toString();
  if (city != null && city.trim().isNotEmpty) return city.trim();
  return '地点待定';
}

Color _salonStatusAccent(String status) {
  if (status == '已预约') return const Color(0xFF16A34A);
  if (status == '名额紧张' || status == '即将开始') {
    return const Color(0xFFEA580C);
  }
  if (status == '回放' || status == '已结束') return const Color(0xFF64748B);
  return kCobalt;
}

List<({IconData icon, String title, String body})> _salonHighlights(
  Map<String, dynamic> salon,
  int index,
) {
  final type = _salonTypeLabel(salon, index);
  if (type == 'PORTFOLIO REVIEW') {
    return const [
      (
        icon: Icons.image_search_outlined,
        title: '作品集点评',
        body: '聚焦项目叙事、过程页和最终呈现'
      ),
      (
        icon: Icons.question_answer_outlined,
        title: '现场 Q&A',
        body: '把申请和创作卡点当场拆开'
      ),
      (icon: Icons.groups_outlined, title: '小班交流', body: '控制人数，保留充分互动时间'),
      (
        icon: Icons.mark_chat_unread_outlined,
        title: '通知跟进',
        body: '预约后活动信息进入私信'
      ),
    ];
  }
  if (type == 'CAREER SALON') {
    return const [
      (icon: Icons.work_outline, title: '行业路径', body: '拆解岗位、能力和第一份实习'),
      (icon: Icons.badge_outlined, title: '简历建议', body: '把作品集转成可投递表达'),
      (icon: Icons.groups_outlined, title: '从业者交流', body: '听真实招聘和团队协作反馈'),
      (icon: Icons.timeline_outlined, title: '行动清单', body: '带走下一步求职准备方向'),
    ];
  }
  if (type == 'ART MARKET') {
    return const [
      (icon: Icons.storefront_outlined, title: '画廊视角', body: '理解展览、收藏和销售链路'),
      (icon: Icons.trending_up_outlined, title: '市场判断', body: '看年轻艺术家的定价与曝光'),
      (icon: Icons.handshake_outlined, title: '合作机会', body: '连接策展、空间和藏家资源'),
      (icon: Icons.verified_outlined, title: '规则意识', body: '聊授权、合同和商业边界'),
    ];
  }
  return const [
    (icon: Icons.school_outlined, title: '校友经验', body: '围绕院校申请和学习体验展开'),
    (icon: Icons.auto_awesome, title: '主题分享', body: '从一个清晰议题进入深聊'),
    (icon: Icons.groups_outlined, title: '同频社交', body: '认识同方向申请者与创作者'),
    (icon: Icons.bookmark_border, title: '资料沉淀', body: '会后可继续跟进重点资源'),
  ];
}

List<({String time, String title, String body})> _salonItinerary(
  Map<String, dynamic> salon,
  int index,
) {
  final type = _salonTypeLabel(salon, index);
  if (type == 'PORTFOLIO REVIEW') {
    return const [
      (time: '00:00', title: '签到与破冰', body: '确认作品集方向和本场点评重点。'),
      (time: '00:15', title: '主题方法分享', body: '讲解项目叙事、页面结构和面试表达。'),
      (time: '00:45', title: '作品集诊断', body: '选取典型案例做拆解式反馈。'),
      (time: '01:20', title: '开放问答', body: '集中处理申请节奏、材料和院校选择问题。'),
    ];
  }
  if (type == 'CAREER SALON') {
    return const [
      (time: '00:00', title: '入场与自我介绍', body: '快速同步专业方向和目标岗位。'),
      (time: '00:15', title: '行业路径拆解', body: '讲清岗位差异、作品要求和招聘节奏。'),
      (time: '00:50', title: '案例复盘', body: '用真实作品或简历看可优化点。'),
      (time: '01:20', title: '行动计划', body: '形成后续投递、改稿和交流清单。'),
    ];
  }
  return const [
    (time: '00:00', title: '签到入场', body: '确认预约信息，进入主题社交场。'),
    (time: '00:15', title: '主理人分享', body: '围绕本场主题做一次高密度导入。'),
    (time: '00:50', title: '圆桌讨论', body: '嘉宾与参与者围绕核心问题展开交流。'),
    (time: '01:20', title: '自由交流', body: '留下合作、申请或作品反馈线索。'),
  ];
}

class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final int index;
  final VoidCallback onTap;

  const _ChatCard({
    required this.conversation,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final peer = conversation['peer_profile'];
    final latest = conversation['latest_message'];
    final peerProfile = peer is Map<String, dynamic> ? peer : null;
    final latestMessage = latest is Map<String, dynamic> ? latest : null;
    final isOrg = _conversationIsOrganization(conversation);
    final title = conversation['title']?.toString().isNotEmpty == true
        ? conversation['title'].toString()
        : peerProfile?['nickname']?.toString().isNotEmpty == true
            ? peerProfile!['nickname'].toString()
            : isOrg
                ? '机构会话'
                : 'Artsee 用户';
    final body = latestMessage?['body']?.toString() ?? '暂无消息内容';
    final time = _formatForumChatTime(
      latestMessage?['created_at'] ?? conversation['updated_at'],
    );
    final unread = conversation['unread_count'] is int
        ? conversation['unread_count'] as int
        : int.tryParse(conversation['unread_count']?.toString() ?? '') ?? 0;
    final avatarUrl = peerProfile?['avatar_url']?.toString();
    final identity = isOrg
        ? _conversationOrganizationIdentity(conversation)
        : _conversationPersonIdentityLabel(conversation);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE9EDEF), width: 0.8),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ChatAvatarFallback(seed: index, org: isOrg),
                          )
                        : _ChatAvatarFallback(seed: index, org: isOrg),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: kCobalt,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                            color: const Color(0xFF111B21),
                            fontSize: 16,
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: unread > 0 ? _whatsAppAccent : _whatsAppMuted,
                          fontSize: 12,
                          fontWeight:
                              unread > 0 ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _ChatIdentityTag(label: identity, org: isOrg),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _whatsAppMuted,
                            fontSize: 13.5,
                            fontWeight:
                                unread > 0 ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _whatsAppAccent,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
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

class _FriendShortcutFallback extends StatelessWidget {
  final String name;

  const _FriendShortcutFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCobalt.withValues(alpha: 0.09),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '艺' : name.characters.first,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatAvatarFallback extends StatelessWidget {
  final int seed;
  final bool org;

  const _ChatAvatarFallback({required this.seed, this.org = false});

  @override
  Widget build(BuildContext context) {
    final colors = [
      _whatsAppGreen,
      kCobaltMuted,
      const Color(0xFFE8EEF7),
      const Color(0xFFF2F5FA),
    ];
    final color = colors[seed % colors.length];
    final foreground =
        color == kCobalt ? Colors.white : kCobalt.withValues(alpha: 0.86);
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      color: color == kCobalt ? kCobalt : color,
      child: Icon(
        org ? Icons.storefront_outlined : Icons.person_outline,
        color: foreground,
        size: 24,
      ),
    );
  }
}

class _ChatIdentityTag extends StatelessWidget {
  final String label;
  final bool org;

  const _ChatIdentityTag({required this.label, required this.org});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (org ? _whatsAppGreen : _whatsAppGreenLight)
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: org ? _whatsAppGreen : _whatsAppGreenLight,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CommunitySectionHeader extends StatelessWidget {
  final String title;
  final String? action;

  const _CommunitySectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final actionText = action;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
              letterSpacing: 0,
            ),
          ),
        ),
        if (actionText != null && actionText.isNotEmpty) ...[
          Text(
            actionText,
            style: const TextStyle(
              color: kCobalt,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const Icon(Icons.chevron_right, color: kCobalt, size: 14),
        ],
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool dark;

  const _SmallButton({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? context.artC.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: dark ? context.artC.ink : context.artC.silver),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : context.artC.ink.withOpacity(0.46),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kCobalt),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: context.artC.ink.withOpacity(0.42),
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onRetry;

  const _CommunityEmptyState({
    this.icon = Icons.forum_outlined,
    required this.title,
    required this.subtitle,
    this.actionLabel = '刷新',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.artC.silver.withOpacity(0.32)),
      ),
      child: Column(
        children: [
          Icon(icon, color: kCobalt.withOpacity(0.7), size: 34),
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: _SmallButton(label: actionLabel, dark: true),
          ),
        ],
      ),
    );
  }
}

String _formatForumDate(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  if (date == null) return '时间待定';
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatForumChatTime(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

bool _matchesSearch(String text, String keyword) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) return true;
  return text.toLowerCase().contains(query);
}

String _groupSceneIdentity(String scene) => switch (scene) {
      '院校申请' => '院校申请群',
      '作品集互助' => '作品集互助群',
      '活动临时群' => '活动群',
      '合作项目' => '合作项目群',
      _ => '群聊',
    };

String? _friendId(Map<String, dynamic> friend) {
  final friendId = friend['friend_id']?.toString();
  if (friendId != null && friendId.isNotEmpty) return friendId;
  final profileId = _stringMap(friend['profile'])?['id']?.toString();
  if (profileId != null && profileId.isNotEmpty) return profileId;
  final id = friend['id']?.toString();
  if (id != null && id.isNotEmpty) return id;
  return null;
}

Map<String, dynamic> _friendProfile(Map<String, dynamic> friend) {
  return _stringMap(friend['profile']) ?? friend;
}

String _friendName(Map<String, dynamic> friend) {
  final profile = _friendProfile(friend);
  final nickname = profile['nickname']?.toString().trim();
  if (nickname != null && nickname.isNotEmpty) return nickname;
  final id = _friendId(friend);
  if (id != null && id.length >= 8) return '用户 ${id.substring(0, 8)}';
  return 'Artsee 好友';
}

String _friendAvatarUrl(Map<String, dynamic> friend) {
  final profile = _friendProfile(friend);
  return profile['avatar_url']?.toString().trim() ?? '';
}

String _friendRoleLabel(Map<String, dynamic> friend) {
  final profile = _friendProfile(friend);
  return _candidateRoleLabel(profile);
}

String _groupPlazaJoinStatus(Map<String, dynamic> circle) {
  final raw = circle['join_status']?.toString().trim();
  if (raw != null && raw.isNotEmpty) return raw;
  final metadata = _stringMap(circle['metadata']);
  final metaRaw = metadata?['join_status']?.toString().trim();
  if (metaRaw != null && metaRaw.isNotEmpty) return metaRaw;
  return 'none';
}

bool _matchesGroupPlazaFilter(
  Map<String, dynamic> circle,
  int index,
  String filter,
) {
  if (filter == '推荐') return true;
  final text = _groupPlazaSearchText(circle, index).toLowerCase();
  return switch (filter) {
    '院校' =>
      ['院校', '申请', '留学', 'rca', 'ual', 'risd', 'bu', 'neu'].any(text.contains),
    '城市' => ['城市', '同城', '伦敦', '纽约', '波士顿', '上海', '北京'].any(text.contains),
    '专业' => ['专业', '设计', '插画', '建筑', '空间', '摄影', '策展', '交互'].any(text.contains),
    '作品集' => ['作品集', 'portfolio', '项目', '排版', '诊断'].any(text.contains),
    '活动' => ['活动', '展览', '沙龙', '讲座', '工作坊', '开放日'].any(text.contains),
    '合作' => ['合作', '机会', '招募', '征集', '共创', '委托', '艺术家'].any(text.contains),
    _ => true,
  };
}

String _groupPlazaSearchText(Map<String, dynamic> circle, int index) {
  final metadata = _stringMap(circle['metadata']);
  final tags = _circleTags(circle, index).join(' ');
  return [
    circle['title'],
    circle['subtitle'],
    circle['category'],
    circle['hot_topic'],
    tags,
    metadata?['scene'],
    metadata?['related_target'],
    metadata?['announcement'],
  ].whereType<Object>().join(' ');
}

String _groupPlazaSubtitle(Map<String, dynamic> circle, int index) {
  final text = _groupPlazaSearchText(circle, index).toLowerCase();
  if (['合作', '机会', '招募', '共创'].any(text.contains)) {
    return '合作机会、项目招募和共创沟通';
  }
  if (['活动', '展览', '沙龙', '开放日'].any(text.contains)) {
    return '活动同行、现场交流和资料同步';
  }
  if (['作品集', 'portfolio', '诊断'].any(text.contains)) {
    return '作品集进度、反馈和项目复盘';
  }
  if (['城市', '同城', '伦敦', '纽约', '波士顿'].any(text.contains)) {
    return '同城生活、租房、活动和院校信息';
  }
  return '院校申请、专业方向和经验互助';
}

Color _groupPlazaColor(int index) {
  const colors = [
    kCobalt,
    Color(0xFF0F9F7A),
    Color(0xFF7C3AED),
    Color(0xFFE11D48),
    Color(0xFFEA580C),
  ];
  return colors[index % colors.length];
}

IconData _groupPlazaIcon(Map<String, dynamic> circle, int index) {
  final text = _groupPlazaSearchText(circle, index).toLowerCase();
  if (['合作', '机会', '招募', '共创'].any(text.contains)) {
    return Icons.handshake_outlined;
  }
  if (['活动', '展览', '沙龙', '开放日'].any(text.contains)) {
    return Icons.event_available_outlined;
  }
  if (['作品集', 'portfolio', '诊断'].any(text.contains)) {
    return Icons.collections_bookmark_outlined;
  }
  if (['城市', '同城'].any(text.contains)) return Icons.location_city_outlined;
  return Icons.school_outlined;
}

String _groupPlazaActionLabel(
  Map<String, dynamic> circle,
  int index,
  String status,
) {
  if (status == 'joined') return '进入';
  if (status == 'pending') return '审核中';
  final joinType = _circleJoinType(circle, index);
  if (joinType == 'approval') return '申请';
  if (joinType == 'private') return '私密';
  return '加入';
}

String _conversationSearchText(Map<String, dynamic> conversation) {
  final peer = _stringMap(conversation['peer_profile']);
  final latest = _stringMap(conversation['latest_message']);
  final metadata = _stringMap(conversation['metadata']);
  return [
    conversation['title'],
    conversation['type'],
    latest?['body'],
    peer?['nickname'],
    peer?['user_role'],
    peer?['user_type'],
    metadata?['organization_name'],
    metadata?['identity_label'],
  ].whereType<Object>().join(' ');
}

String _candidateRoleLabel(Map<String, dynamic> candidate) {
  final role =
      candidate['user_role']?.toString() ?? candidate['user_type']?.toString();
  return switch (role) {
    'artist' => '艺术家',
    'mentor' => '导师',
    'student' => '学生',
    'personal' => '个人用户',
    'business' => '机构',
    'institution' => '机构',
    'official_association' => '官方协会',
    'school_official' => '院校官方',
    'official_partner' => '官方合作组织',
    'study_abroad_agency' => '留学服务（已下线）',
    _ => '可添加用户',
  };
}

Map<String, dynamic>? _stringMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

String _salonTypeLabel(Map<String, dynamic> salon, int index) {
  final metadata = salon['metadata'];
  if (metadata is Map) {
    final salonType = metadata['salon_type']?.toString();
    if (salonType == '留学答疑') return 'ADMISSION Q&A';
    if (salonType == '作品集诊断') return 'PORTFOLIO REVIEW';
    if (salonType == '校友分享') return 'ALUMNI TALK';
    if (salonType == '行业就业') return 'CAREER SALON';
    if (salonType == '艺术市场') return 'ART MARKET';
  }
  final raw =
      '${salon['summary'] ?? ''} ${salon['title'] ?? ''} ${salon['description'] ?? ''}'
          .toLowerCase();
  if (raw.contains('portfolio') || raw.contains('作品集')) {
    return 'PORTFOLIO REVIEW';
  }
  if (raw.contains('校友') || raw.contains('alumni')) return 'ALUMNI TALK';
  if (raw.contains('就业') || raw.contains('career')) return 'CAREER SALON';
  if (raw.contains('市场') || raw.contains('market')) return 'ART MARKET';
  if (raw.contains('申请') || raw.contains('admission')) return 'ADMISSION Q&A';
  const fallback = [
    'ALUMNI TALK',
    'PORTFOLIO REVIEW',
    'ADMISSION Q&A',
    'CAREER SALON',
  ];
  return fallback[index % fallback.length];
}

bool _matchesSalonFilter(Map<String, dynamic> salon, int index, String filter) {
  if (filter == '全部') return true;
  final raw =
      '${salon['summary'] ?? ''} ${salon['title'] ?? ''} ${salon['description'] ?? ''} ${_salonTypeLabel(salon, index)}'
          .toLowerCase();
  return switch (filter) {
    '留学' => ['admission', '申请', '留学', '院校'].any(raw.contains),
    '作品集' => ['portfolio', '作品集', '诊断', '评审'].any(raw.contains),
    '校友' => ['alumni', '校友', 'risd', 'rca', 'ual'].any(raw.contains),
    '就业' => ['career', '就业', '职业', '实习'].any(raw.contains),
    '市场' => ['market', '市场', '画廊', '收藏', '展览'].any(raw.contains),
    _ => true,
  };
}

String _salonFilterTitle(String filter) => switch (filter) {
      '留学' => '留学答疑',
      '作品集' => '作品集诊断',
      '校友' => '校友分享',
      '就业' => '行业就业',
      '市场' => '艺术市场',
      _ => '全部沙龙',
    };

String _salonFilterSubtitle(String filter) => switch (filter) {
      '留学' => '申请、院校和材料准备相关活动',
      '作品集' => '作品集评审、诊断和项目叙事',
      '校友' => '海外艺术院校校友经验分享',
      '就业' => '职业发展、实习和行业路径',
      '市场' => '展览、收藏和艺术市场观察',
      _ => '根据你的申请方向和关注学校推荐',
    };

String _salonStatusLabel(Map<String, dynamic> salon, int index) {
  final start = DateTime.tryParse(salon['start_time']?.toString() ?? '');
  if (start != null) {
    final now = DateTime.now();
    if (start.isBefore(now)) return '回放';
    if (start.difference(now).inHours <= 2) return '即将开始';
  }
  if (index % 5 == 4) return '已结束';
  if (_salonSeatsLeft(salon, index) <= 6) return '名额紧张';
  return '可预约';
}

Color _salonStatusColor(String status, BuildContext context) {
  if (status == '已预约') return const Color(0xFF16A34A);
  if (status == '名额紧张') return const Color(0xFFEA580C);
  if (status == '已结束' || status == '回放') return Colors.white.withOpacity(0.82);
  return kCobalt;
}

int _salonSeatsLeft(Map<String, dynamic> salon, int index) {
  final raw = int.tryParse(salon['seats_left']?.toString() ?? '');
  if (raw != null) return raw;
  final metadata = salon['metadata'];
  if (metadata is Map) {
    final metaRaw = int.tryParse(metadata['seats_left']?.toString() ?? '');
    if (metaRaw != null) return metaRaw;
  }
  final quota = int.tryParse(salon['quota']?.toString() ?? '');
  if (quota != null) return quota;
  return 6 + (index % 5) * 2;
}

String _salonGuestLine(Map<String, dynamic> salon, int index) {
  final raw = salon['guest']?.toString();
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  final metadata = salon['metadata'];
  if (metadata is Map) {
    final metaRaw = metadata['guest']?.toString();
    if (metaRaw != null && metaRaw.trim().isNotEmpty) return metaRaw.trim();
  }
  final type = _salonTypeLabel(salon, index);
  if (type == 'PORTFOLIO REVIEW') return 'RCA 校友 / 作品集导师';
  if (type == 'CAREER SALON') return '艺术行业从业者 · 创意招聘顾问';
  if (type == 'ART MARKET') return '画廊策展人 · 艺术市场顾问';
  if (type == 'ADMISSION Q&A') return '艺术留学顾问 · 申请规划师';
  return 'RISD 工业设计校友 · Google UX Designer';
}

String _salonBenefitLine(Map<String, dynamic> salon, int index) {
  final metadata = salon['metadata'];
  if (metadata is Map) {
    final raw = metadata['benefit']?.toString();
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  }
  final type = _salonTypeLabel(salon, index);
  if (_formatForumFee(salon['fee_amount']) == '免费') return '线上分享 · 可回放';
  if (type == 'PORTFOLIO REVIEW') return '含作品集点评 · 现场 Q&A';
  if (type == 'ALUMNI TALK') return '含校友交流 · 申请经验';
  return '含主题分享 · 现场交流';
}

List<String> _salonAudience(Map<String, dynamic> salon, int index) {
  final type = _salonTypeLabel(salon, index);
  if (type == 'PORTFOLIO REVIEW') {
    return const [
      '正在准备作品集项目的学生',
      '需要梳理项目叙事和视觉排版的人',
      '准备申请 RCA / UAL / RISD 的申请者',
    ];
  }
  if (type == 'CAREER SALON') {
    return const ['想了解艺术行业职业路径的人', '正在找实习或第一份工作的学生'];
  }
  return const ['准备艺术留学申请的学生', '想了解海外院校学习体验的人', '希望和校友交流的人'];
}

bool _conversationIsOrganization(Map<String, dynamic> conversation) {
  final peer = conversation['peer_profile'];
  final peerProfile = peer is Map<String, dynamic> ? peer : null;
  final metadataRaw = conversation['metadata'];
  final metadata =
      metadataRaw is Map ? Map<String, dynamic>.from(metadataRaw) : {};
  final type = conversation['type']?.toString() ?? 'direct';
  final userType = peerProfile?['user_type']?.toString() ??
      metadata['peer_type']?.toString() ??
      metadata['target_type']?.toString();
  return userType == 'business' ||
      userType == 'institution' ||
      type == 'organization' ||
      type == 'cooperation' ||
      metadata['organization_name'] != null;
}

bool _conversationIsCooperation(Map<String, dynamic> conversation) {
  if (_conversationIsOrganization(conversation)) return true;
  final text = _conversationSearchText(conversation).toLowerCase();
  return [
    'cooperation',
    'opportunity',
    'application',
    'apply',
    'offer',
    'artist',
    '合作',
    '机会',
    '申请',
    '邀约',
    '招募',
    '艺术家',
    '机构',
  ].any(text.contains);
}

bool _conversationIsCircle(Map<String, dynamic> conversation) {
  final metadata = _stringMap(conversation['metadata']);
  final type = conversation['type']?.toString().toLowerCase() ?? '';
  if (type == 'group' || type == 'circle' || type == 'community') return true;
  final source = metadata?['source']?.toString().toLowerCase() ?? '';
  if (source.contains('circle') || source.contains('community')) return true;
  final text = _conversationSearchText(conversation).toLowerCase();
  return [
    'circle',
    'community',
    'group',
    '圈子',
    '群聊',
    '问答',
    '评论',
    '@',
    '院校圈',
    '作品集',
  ].any(text.contains);
}

String _conversationPersonIdentityLabel(Map<String, dynamic> conversation) {
  final peer = conversation['peer_profile'];
  final peerProfile = peer is Map<String, dynamic> ? peer : null;
  final metadataRaw = conversation['metadata'];
  final metadata =
      metadataRaw is Map ? Map<String, dynamic>.from(metadataRaw) : {};
  final role = peerProfile?['user_role']?.toString() ??
      metadata['user_role']?.toString() ??
      metadata['peer_role']?.toString();
  return switch (role) {
    'artist' => '认证艺术家',
    'mentor' => '导师',
    'student' => '学生',
    _ => metadata['identity_label']?.toString() ?? '用户',
  };
}

String _conversationOrganizationIdentity(Map<String, dynamic> conversation) {
  final metadataRaw = conversation['metadata'];
  final metadata =
      metadataRaw is Map ? Map<String, dynamic>.from(metadataRaw) : {};
  final serviceStatus = metadata['service_status']?.toString();
  final responseTime = metadata['response_time']?.toString();
  if (serviceStatus?.isNotEmpty == true && responseTime?.isNotEmpty == true) {
    return '机构认证 · $serviceStatus · $responseTime';
  }
  if (serviceStatus?.isNotEmpty == true) return '机构认证 · $serviceStatus';
  return '机构认证 · 服务中';
}

String _formatForumFee(dynamic raw) {
  final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (value == null || value <= 0) return '免费/邀请制';
  return '¥$value';
}

String _formatSalonFeeWithSeats(Map<String, dynamic> salon, int index) {
  final metadata = salon['metadata'];
  String? feeMode;
  if (metadata is Map) {
    feeMode = metadata['fee_mode']?.toString();
  }
  final quota = salon['quota'];
  final quotaNum = quota is int ? quota : int.tryParse(quota?.toString() ?? '');
  final seatsText = quotaNum != null && quotaNum > 0 ? '$quotaNum 人小班' : '小班';

  if (feeMode == 'free') {
    return '免费 / 预约制';
  } else if (feeMode == 'invite') {
    return '邀请制 / $seatsText';
  } else if (feeMode == 'paid') {
    final fee = _formatForumFee(salon['fee_amount']);
    return '$fee / $seatsText';
  }

  final fee = _formatForumFee(salon['fee_amount']);
  if (fee == '免费/邀请制') {
    return '免费 / 预约制';
  }
  return '$fee / $seatsText';
}

class _PostComposerModal extends StatefulWidget {
  const _PostComposerModal();

  @override
  State<_PostComposerModal> createState() => _PostComposerModalState();
}

class _PostComposerModalState extends State<_PostComposerModal> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发动态',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '分享资源、讨论、作品集进展或活动信息...',
                filled: true,
                fillColor: context.artC.silver.withOpacity(0.22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = _controller.text.trim();
                  if (value.isNotEmpty) Navigator.of(context).pop(value);
                },
                child: const Text('发布动态'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
