import 'package:flutter/material.dart';
import '../../config/dev_test_account.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../programs/program_detail_screen.dart';
import '../schools/school_detail_enhanced_screen.dart';
import 'orders_screen.dart';
import 'profile_edit_screen.dart';
import 'package:artsee_app/theme/artsee_theme_controller.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// 我的页 — 完全对齐 _artist_ref ProfileView，接入真实用户数据
/// ═══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

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
    List<Map<String, dynamic>> orders = [];
    try {
      orders = await BackendApiService.fetchMyOrders(limit: 20);
    } catch (_) {
      orders = [];
    }
    if (mounted) {
      setState(() {
        _profile = p;
        _orders = orders;
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

  String get _bio {
    final b = _profile?['bio'] as String?;
    if (b != null && b.isNotEmpty) return b;
    return '完善简介，让更多人了解你';
  }

  String get _avatarUrl => _profile?['avatar_url'] as String? ?? '';

  bool get _isVerified => _profile?['is_verified'] == true;

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
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) ...[
                _buildProfileBackButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
              ],
              _buildProfileHeader(),
              const SizedBox(height: 28),
              _buildStatsCards(),
              const SizedBox(height: 28),
              _buildMenuList(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBackButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: context.artC.ink,
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: context.artC.porcelain, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: context.artC.ink.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _avatarUrl.isNotEmpty
                    ? Image.network(
                        _avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
            ),
            if (_isVerified)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kCobalt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.artC.porcelain, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: context.artC.ink.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.verified, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nickname,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _bio,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.artC.ink.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final refreshed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditScreen(
                            initialProfile: _profile,
                          ),
                        ),
                      );
                      if (refreshed == true) _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: kCobalt,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: kCobalt.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text(
                        '编辑资料',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ListenableBuilder(
                    listenable: ArtseeThemeController.instance,
                    builder: (context, _) {
                      final dark = ArtseeThemeController.instance.isDark;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => ArtseeThemeController.instance.toggle(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  context.artC.silver.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              dark
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nightlight_round,
                              size: 20,
                              color: context.artC.ink.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.share_outlined,
                        size: 20,
                        color: context.artC.ink.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() {
    final ch = _nickname.isNotEmpty ? _nickname.substring(0, 1) : '艺';
    return Center(
      child: Text(
        ch,
        style: const TextStyle(
            fontSize: 40, fontWeight: FontWeight.w700, color: kCobalt),
      ),
    );
  }

  Widget _buildStatsCards() {
    final exposure = (_profile?['exposure'] as String?) ?? '48.2k';
    final activeInvitations =
        (_profile?['active_invitations'] ?? 12).toString();
    final paidTotalCents = _orders
        .where((order) => order['status'] == 'paid')
        .fold<int>(
            0,
            (sum, order) =>
                sum + ((order['amount_total'] as num?)?.toInt() ?? 0));
    final paidText = paidTotalCents > 0
        ? '¥${(paidTotalCents / 100).toStringAsFixed(2)}'
        : '${_orders.length} 笔';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openOrders,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: context.artC.deepPanel,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: kInk.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '数据看板 (Exposure)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exposure,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: kCobaltMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '累计曝光',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeInvitations,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: kCobaltMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '活跃邀约',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border:
                  Border.all(color: context.artC.silver.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支付中心 (Orders)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.4),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paidText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paidTotalCents > 0 ? '已支付订单' : '近期订单',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: context.artC.ink.withValues(alpha: 0.3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '订单',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kCobalt.withValues(alpha: 0.9),
                        decoration: TextDecoration.underline,
                        decorationColor: kCobalt.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList() {
    final items = [
      (label: '我的订单', icon: Icons.receipt_long_outlined, onTap: _openOrders),
      (label: '作品管理', icon: Icons.layers_outlined, onTap: null),
      (label: '合作邀约管理', icon: Icons.business_center_outlined, onTap: null),
      (label: '展览报名记录', icon: Icons.calendar_today_outlined, onTap: null),
      (label: '版权备案', icon: Icons.emoji_events_outlined, onTap: null),
      (label: '认证中心', icon: Icons.verified_outlined, onTap: null),
    ];

    return Column(
      children: [
        ...items.map((item) {
          return GestureDetector(
            onTap: item.onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.artC.cardIconBg,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: context.artC.ink.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(item.icon,
                            size: 20,
                            color: context.artC.ink.withValues(alpha: 0.35)),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.artC.ink.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right,
                      size: 22, color: context.artC.ink.withValues(alpha: 0.2)),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: _signOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: context.artC.silver.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.artC.cardIconBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: context.artC.ink.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(Icons.logout,
                          size: 20, color: Colors.red.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      '退出登录',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right,
                    size: 22, color: context.artC.ink.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
        if (devLoginShortcutsEnabled) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCobalt.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开发调试',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kCobalt.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDevButton(
                        '学校详情页',
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SchoolDetailEnhancedScreen(
                                id: '3485e258-d84b-4067-b093-62a3d468ac62'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDevButton(
                        '专业详情页',
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProgramDetailScreen(
                                id: '001f9862-a2c5-4d37-9b7a-720ceeef163e'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDevButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kCobalt.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kCobalt.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
    );
  }
}
