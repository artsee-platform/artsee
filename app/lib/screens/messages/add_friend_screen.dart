import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/common.dart';
import '../profile/public_user_profile_screen.dart';

class AddFriendScreen extends StatefulWidget {
  final VoidCallback? onFriendAdded;

  const AddFriendScreen({super.key, this.onFriendAdded});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _candidates = const [];
  final Set<String> _busyIds = <String>{};
  final Set<String> _addedIds = <String>{};
  final Set<String> _hiddenIds = <String>{};
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _qrCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BackendApiService.fetchAuthProfile(),
        BackendApiService.fetchFriendCandidates(limit: 30),
        BackendApiService.createMyQrCode(
          metadata: {'surface': 'add_friend_screen'},
        ).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final profileResult = results[0] as Map<String, dynamic>;
      final candidates = results[1] as List<Map<String, dynamic>>;
      final qrCode = results[2] as Map<String, dynamic>;
      setState(() {
        _profile = _profileFromResponse(profileResult);
        _qrCode = qrCode;
        _candidates = candidates;
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

  List<Map<String, dynamic>> get _visibleCandidates {
    final keyword = _searchController.text.trim().toLowerCase();
    return _candidates.where((candidate) {
      final id = _candidateId(candidate);
      if (id == null || _hiddenIds.contains(id)) return false;
      if (keyword.isEmpty) return true;
      return _candidateSearchText(candidate).toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _addFriend(Map<String, dynamic> candidate) async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后添加好友');
    if (!mounted || !loggedIn) return;
    final id = _candidateId(candidate);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户资料还没有完成同步')),
      );
      return;
    }
    if (_busyIds.contains(id) || _addedIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await BackendApiService.addFriend(
        targetUserId: id,
        message: _candidateAddMessage(candidate),
      );
      if (!mounted) return;
      setState(() {
        _busyIds.remove(id);
        _addedIds.add(id);
      });
      widget.onFriendAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${_candidateName(candidate)} 为好友')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加好友失败：$e')),
      );
    }
  }

  void _openProfile(Map<String, dynamic> candidate) {
    final id = _candidateId(candidate);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfileScreen(
          userId: id,
          name: _candidateName(candidate),
          handle: _candidateHandle(candidate),
          avatarUrl: _candidateAvatarUrl(candidate),
          roleLabel: _candidateRoleLabel(candidate),
          bio: _candidateReason(candidate),
          kind: _candidateKind(candidate),
        ),
      ),
    );
  }

  void _dismissCandidate(Map<String, dynamic> candidate) {
    final id = _candidateId(candidate);
    if (id == null) return;
    setState(() => _hiddenIds.add(id));
  }

  Future<void> _copyCardText(String channel) async {
    final name = _profileName(_profile);
    final artseeId = _profileArtseeId(_profile);
    final qrUrl = _profileQrUrl(_qrCode);
    await Clipboard.setData(
      ClipboardData(
        text: qrUrl.isEmpty
            ? '我在 Artsee 艺见心：$name（$artseeId）'
            : '我在 Artsee 艺见心：$name（$artseeId）\n$qrUrl',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('个人名片已复制，可粘贴分享给$channel好友')),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFriendOptionSheet(
        title: '扫一扫',
        options: [
          _AddFriendOption(
            icon: Icons.badge_outlined,
            title: '扫个人名片',
            subtitle: '添加好友并查看作品主页',
          ),
          _AddFriendOption(
            icon: Icons.groups_2_outlined,
            title: '扫群邀请',
            subtitle: '加入院校、作品集或合作群',
          ),
          _AddFriendOption(
            icon: Icons.event_available_outlined,
            title: '活动签到',
            subtitle: '展览、沙龙、开放日现场签到',
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFriendSearchSheet(
        initialQuery: _searchController.text,
        candidates: _candidates,
        addedIds: _addedIds,
        busyIds: _busyIds,
        hiddenIds: _hiddenIds,
        onQueryChanged: _setSearchKeyword,
        onOpenProfile: _openProfile,
        onAddFriend: _addFriend,
        onDismiss: _dismissCandidate,
      ),
    );
  }

  void _setSearchKeyword(String value) {
    final trimmed = value.trim();
    if (_searchController.text != trimmed) {
      _searchController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    setState(() {});
  }

  void _showDirectoryHint() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFriendOptionSheet(
        title: '通讯录好友',
        options: [
          _AddFriendOption(
            icon: Icons.assignment_ind_outlined,
            title: '匹配通讯录',
            subtitle: '授权后识别已经在 Artsee 的联系人',
          ),
          _AddFriendOption(
            icon: Icons.verified_user_outlined,
            title: '隐私保护',
            subtitle: '通讯录只用于匹配，不会公开给其他用户',
          ),
          _AddFriendOption(
            icon: Icons.person_search_outlined,
            title: '手动搜索',
            subtitle: '也可以通过 Artsee ID、学校、专业或城市寻找',
          ),
        ],
      ),
    );
  }

  void _showShareSheet(String channel) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFriendShareSheet(
        channel: channel,
        profile: _profile,
        qrCode: _qrCode,
        onCopy: () => _copyCardText(channel),
      ),
    );
  }

  void _showPrivacyHint() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFriendOptionSheet(
        title: '添加设置',
        options: [
          _AddFriendOption(
            icon: Icons.visibility_outlined,
            title: '允许通过 Artsee ID 找到我',
            subtitle: '适合线下活动和同学互加',
          ),
          _AddFriendOption(
            icon: Icons.school_outlined,
            title: '显示学校和专业匹配理由',
            subtitle: '帮助同校、同专业的人更自然地认识你',
          ),
          _AddFriendOption(
            icon: Icons.verified_user_outlined,
            title: '好友申请需要验证',
            subtitle: '后续会接入申请理由和来源审核',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.artC.ink,
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '添加好友',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: context.artC.ink.withValues(alpha: 0.26),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '添加设置',
            onPressed: _showPrivacyHint,
            icon: Icon(
              Icons.settings_outlined,
              size: 24,
              color: context.artC.ink.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: kCobalt,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    _MyArtseeCard(
                      profile: _profile,
                      qrCode: _qrCode,
                      loading: _loading && _profile == null,
                    ),
                    const SizedBox(height: 28),
                    _AddFriendActionRow(
                      icon: Icons.qr_code_scanner_rounded,
                      title: '扫一扫',
                      onTap: _showScanOptions,
                    ),
                    _AddFriendActionRow(
                      icon: Icons.search_rounded,
                      title: '搜索 Artsee ID',
                      trailing: '学校 / 专业 / 城市',
                      onTap: _showSearchSheet,
                    ),
                    _AddFriendActionRow(
                      icon: Icons.assignment_ind_outlined,
                      title: '通讯录好友',
                      trailing: '匹配已在 Artsee 的联系人',
                      onTap: _showDirectoryHint,
                    ),
                    _AddFriendActionRow(
                      icon: Icons.wechat_rounded,
                      title: '微信好友',
                      trailing: '分享个人名片至微信',
                      onTap: () => _showShareSheet('微信'),
                    ),
                    _AddFriendActionRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'QQ 好友',
                      trailing: '分享个人名片至 QQ',
                      onTap: () => _showShareSheet('QQ'),
                    ),
                    const SizedBox(height: 30),
                    _RecommendationHeader(onRefresh: _load),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 26),
                        child: LoadingIndicator(),
                      )
                    else if (_error != null)
                      _AddFriendEmptyState(
                        icon: Icons.person_search_outlined,
                        title: '推荐加载失败',
                        subtitle: _error!,
                        actionLabel: '重试',
                        onTap: _load,
                      )
                    else if (_visibleCandidates.isEmpty)
                      _AddFriendEmptyState(
                        icon: Icons.person_search_outlined,
                        title: _searchController.text.trim().isEmpty
                            ? '暂无推荐用户'
                            : '没有匹配的人',
                        subtitle: _searchController.text.trim().isEmpty
                            ? '之后会根据学校、专业、圈子、活动和合作记录推荐更合适的人。'
                            : '换个昵称、学校、专业或城市关键词试试。',
                        actionLabel: '刷新',
                        onTap: _load,
                      )
                    else
                      ..._visibleCandidates.map(
                        (candidate) {
                          final id = _candidateId(candidate);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _SuggestedFriendTile(
                              candidate: candidate,
                              added: id != null && _addedIds.contains(id),
                              busy: id != null && _busyIds.contains(id),
                              onTap: () => _openProfile(candidate),
                              onAdd: () => _addFriend(candidate),
                              onDismiss: () => _dismissCandidate(candidate),
                            ),
                          );
                        },
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
}

class _MyArtseeCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? qrCode;
  final bool loading;

  const _MyArtseeCard({
    required this.profile,
    required this.qrCode,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final name = _profileName(profile);
    final artseeId = _profileArtseeId(profile);
    final avatarUrl = _profileAvatarUrl(profile);
    final qrUrl = _profileQrUrl(qrCode);
    return Column(
      children: [
        _ArtseeQrCard(
          seed: qrUrl.isEmpty ? artseeId : qrUrl,
          avatarUrl: avatarUrl,
          name: name,
          loading: loading,
        ),
        const SizedBox(height: 18),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: qrUrl.isEmpty ? artseeId : qrUrl),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(qrUrl.isEmpty ? 'Artsee ID 已复制' : '名片链接已复制')),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                qrUrl.isEmpty ? 'Artsee ID：$artseeId' : '名片码已同步 · $artseeId',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.42),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.copy_rounded,
                size: 15,
                color: context.artC.ink.withValues(alpha: 0.36),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtseeQrCard extends StatelessWidget {
  final String seed;
  final String avatarUrl;
  final String name;
  final bool loading;

  const _ArtseeQrCard({
    required this.seed,
    required this.avatarUrl,
    required this.name,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 184,
      height: 184,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.62)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Padding(
              padding: const EdgeInsets.all(4),
              child: QrImageView(
                data: seed.isEmpty ? 'https://artiqore.com' : seed,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                gapless: false,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: context.artC.ink,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: context.artC.ink,
                ),
              ),
            ),
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _AddFriendAvatarFallback(name: name),
                    )
                  : _AddFriendAvatarFallback(name: name),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _AddFriendActionRow({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.artC.silver.withValues(alpha: 0.34),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: context.artC.ink.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: MediaQuery.sizeOf(context).width >= 380 ? 178 : 138,
              child: trailing == null
                  ? const SizedBox.shrink()
                  : Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC8C8C8),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _AddFriendSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 13, right: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: context.artC.ink.withValues(alpha: 0.32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: kCobalt,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: '搜索昵称、Artsee ID、学校、专业、城市',
                hintStyle: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.32),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          IconButton(
            tooltip: '清空',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              controller.clear();
              onChanged('');
            },
            icon: Icon(
              Icons.close_rounded,
              color: context.artC.ink.withValues(alpha: 0.38),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendSearchSheet extends StatefulWidget {
  final String initialQuery;
  final List<Map<String, dynamic>> candidates;
  final Set<String> addedIds;
  final Set<String> busyIds;
  final Set<String> hiddenIds;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Map<String, dynamic>> onOpenProfile;
  final Future<void> Function(Map<String, dynamic>) onAddFriend;
  final ValueChanged<Map<String, dynamic>> onDismiss;

  const _AddFriendSearchSheet({
    required this.initialQuery,
    required this.candidates,
    required this.addedIds,
    required this.busyIds,
    required this.hiddenIds,
    required this.onQueryChanged,
    required this.onOpenProfile,
    required this.onAddFriend,
    required this.onDismiss,
  });

  @override
  State<_AddFriendSearchSheet> createState() => _AddFriendSearchSheetState();
}

class _AddFriendSearchSheetState extends State<_AddFriendSearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _results {
    final keyword = _controller.text.trim().toLowerCase();
    return widget.candidates.where((candidate) {
      final id = _candidateId(candidate);
      if (id == null || widget.hiddenIds.contains(id)) return false;
      if (keyword.isEmpty) return true;
      return _candidateSearchText(candidate).toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.76;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
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
                      '搜索 Artsee ID',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _AddFriendSearchField(
                controller: _controller,
                onChanged: (value) {
                  widget.onQueryChanged(value);
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? _AddFriendEmptyState(
                      icon: Icons.person_search_outlined,
                      title: '没有匹配的人',
                      subtitle: '换个昵称、Artsee ID、学校、专业或城市关键词试试。',
                      actionLabel: '清空搜索',
                      onTap: () {
                        _controller.clear();
                        widget.onQueryChanged('');
                        setState(() {});
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, index) {
                        final candidate = _results[index];
                        final id = _candidateId(candidate);
                        return _SuggestedFriendTile(
                          candidate: candidate,
                          added: id != null && widget.addedIds.contains(id),
                          busy: id != null && widget.busyIds.contains(id),
                          onTap: () => widget.onOpenProfile(candidate),
                          onAdd: () async {
                            await widget.onAddFriend(candidate);
                            if (mounted) setState(() {});
                          },
                          onDismiss: () {
                            widget.onDismiss(candidate);
                            setState(() {});
                          },
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

class _RecommendationHeader extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _RecommendationHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '你可能感兴趣的人',
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        GestureDetector(
          onTap: onRefresh,
          behavior: HitTestBehavior.opaque,
          child: Icon(
            Icons.refresh_rounded,
            size: 19,
            color: context.artC.ink.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class _SuggestedFriendTile extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final bool added;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _SuggestedFriendTile({
    required this.candidate,
    required this.added,
    required this.busy,
    required this.onTap,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final name = _candidateName(candidate);
    final avatarUrl = _candidateAvatarUrl(candidate);
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              width: 60,
              height: 60,
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _AddFriendAvatarFallback(name: name),
                    )
                  : _AddFriendAvatarFallback(name: name),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _candidateSubtitle(candidate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _candidateReason(candidate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.34),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 74,
          height: 36,
          child: OutlinedButton(
            onPressed: added || busy ? null : onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  added ? context.artC.ink.withValues(alpha: 0.38) : kCobalt,
              side: BorderSide(
                color: added
                    ? context.artC.silver.withValues(alpha: 0.42)
                    : kCobalt.withValues(alpha: 0.52),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: EdgeInsets.zero,
            ),
            child: busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kCobalt,
                    ),
                  )
                : Text(
                    added ? '已添加' : '加好友',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Icon(
            Icons.close_rounded,
            color: context.artC.ink.withValues(alpha: 0.38),
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _AddFriendAvatarFallback extends StatelessWidget {
  final String name;

  const _AddFriendAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCobalt.withValues(alpha: 0.09),
      alignment: Alignment.center,
      child: Text(
        name.trim().isEmpty ? '艺' : name.characters.first,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AddFriendEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _AddFriendEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Icon(icon, size: 30, color: context.artC.ink.withValues(alpha: 0.28)),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.44),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _AddFriendOption {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AddFriendOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _AddFriendShareSheet extends StatelessWidget {
  final String channel;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? qrCode;
  final Future<void> Function() onCopy;

  const _AddFriendShareSheet({
    required this.channel,
    required this.profile,
    required this.qrCode,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final name = _profileName(profile);
    final artseeId = _profileArtseeId(profile);
    final qrUrl = _profileQrUrl(qrCode);
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.artC.silver.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '分享给$channel好友',
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
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: QrImageView(
                        data: qrUrl.isEmpty ? artseeId : qrUrl,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        padding: EdgeInsets.zero,
                        gapless: false,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: context.artC.ink,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            qrUrl.isEmpty ? artseeId : '名片链接已同步',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.42),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '复制后可粘贴到$channel，也可以后续接入系统分享面板。',
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.36),
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () async {
                    await onCopy();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('复制名片链接'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCobalt,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

class _AddFriendOptionSheet extends StatelessWidget {
  final String title;
  final List<_AddFriendOption> options;

  const _AddFriendOptionSheet({
    required this.title,
    required this.options,
  });

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
                      title,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                children: options
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AddFriendSheetOptionTile(option: option),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendSheetOptionTile extends StatelessWidget {
  final _AddFriendOption option;

  const _AddFriendSheetOptionTile({required this.option});

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
          Icon(option.icon, color: kCobalt, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  option.subtitle,
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
    );
  }
}

Map<String, dynamic>? _profileFromResponse(Map<String, dynamic> response) {
  final profile = _stringMap(response['profile']) ??
      _stringMap(response['user_profile']) ??
      _stringMap(response['user']);
  return profile ?? response;
}

String _profileName(Map<String, dynamic>? profile) {
  final raw = profile?['nickname']?.toString().trim() ??
      profile?['name']?.toString().trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return SupabaseService.currentUser?.email?.split('@').first ?? 'Artsee 用户';
}

String _profileArtseeId(Map<String, dynamic>? profile) {
  final raw = profile?['handle']?.toString().trim() ??
      profile?['username']?.toString().trim() ??
      profile?['artsee_id']?.toString().trim();
  if (raw != null && raw.isNotEmpty) {
    return raw.startsWith('@') ? raw : '@$raw';
  }
  final id =
      profile?['id']?.toString() ?? SupabaseService.currentUser?.id ?? '';
  if (id.length >= 8) return '@artsee_${id.substring(0, 8)}';
  return '@artsee';
}

String _profileAvatarUrl(Map<String, dynamic>? profile) {
  return profile?['avatar_url']?.toString().trim() ?? '';
}

String _profileQrUrl(Map<String, dynamic>? qrCode) {
  final raw = qrCode?['qr_url']?.toString().trim();
  return raw == null || raw.isEmpty ? '' : raw;
}

String? _candidateId(Map<String, dynamic> candidate) {
  final id = candidate['id']?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}

String _candidateName(Map<String, dynamic> candidate) {
  final name = candidate['nickname']?.toString().trim() ??
      candidate['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final id = _candidateId(candidate);
  if (id != null && id.length >= 8) return '用户 ${id.substring(0, 8)}';
  return 'Artsee 用户';
}

String _candidateHandle(Map<String, dynamic> candidate) {
  final handle = candidate['handle']?.toString().trim() ??
      candidate['username']?.toString().trim();
  if (handle != null && handle.isNotEmpty) {
    return handle.startsWith('@') ? handle : '@$handle';
  }
  final id = _candidateId(candidate);
  if (id != null && id.length >= 8) return '@artsee_${id.substring(0, 8)}';
  return '@artsee_user';
}

String _candidateAvatarUrl(Map<String, dynamic> candidate) {
  return candidate['avatar_url']?.toString().trim() ?? '';
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
    'study_abroad_agency' => '艺术留学机构',
    _ => 'Artsee 用户',
  };
}

String _candidateSubtitle(Map<String, dynamic> candidate) {
  final parts = [
    _candidateRoleLabel(candidate),
    candidate['school']?.toString(),
    candidate['major']?.toString(),
    candidate['city']?.toString() ?? candidate['location']?.toString(),
  ]
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(3)
      .toList();
  return parts.isEmpty ? '作品、申请和艺术社区动态' : parts.join(' · ');
}

String _candidateReason(Map<String, dynamic> candidate) {
  final role = candidate['user_role']?.toString();
  final type = candidate['user_type']?.toString();
  if (role == 'student') return '可能和你有相近的院校、专业或作品集方向';
  if (role == 'artist') return '可关注作品、展览和合作动态';
  if (role == 'mentor') return '可交流作品集、申请路径和行业经验';
  if (type == 'business' || type == 'institution') {
    return '可能发布活动、合作或艺术留学服务信息';
  }
  return '来自 Artsee 社区推荐';
}

String _candidateAddMessage(Map<String, dynamic> candidate) {
  final reason = _candidateReason(candidate);
  return '你好，我在 Artsee 艺见心看到你的主页，$reason，想加个好友交流。';
}

String _candidateSearchText(Map<String, dynamic> candidate) {
  return [
    _candidateName(candidate),
    _candidateHandle(candidate),
    _candidateSubtitle(candidate),
    _candidateReason(candidate),
    candidate['user_role'],
    candidate['user_type'],
  ].whereType<Object>().join(' ');
}

PublicUserProfileKind _candidateKind(Map<String, dynamic> candidate) {
  final role = candidate['user_role']?.toString();
  return switch (role) {
    'artist' => PublicUserProfileKind.artist,
    'mentor' => PublicUserProfileKind.mentor,
    'student' => PublicUserProfileKind.student,
    _ => PublicUserProfileKind.user,
  };
}

Map<String, dynamic>? _stringMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}
