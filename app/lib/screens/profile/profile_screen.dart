import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../cases/case_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<AppCase> _myCases = [];
  bool _loading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen for auth state changes
    SupabaseService.isLoggedIn ? _load() : null;
  }

  Future<void> _load() async {
    if (!SupabaseService.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([
      SupabaseService.fetchProfile(),
      SupabaseService.fetchMyCases(),
    ]);
    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _myCases = results[1] as List<AppCase>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return _NotLoggedInView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(child: _buildHeader()),

            // Stats
            SliverToBoxAdapter(child: _buildStats()),

            // Quick actions
            SliverToBoxAdapter(child: _buildQuickActions()),

            // Tab selector
            SliverToBoxAdapter(child: _buildTabs()),

            // Tab content
            if (_loading)
              const SliverFillRemaining(child: LoadingIndicator())
            else
              SliverToBoxAdapter(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 110,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [kPrimary, kPrimaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        Positioned(
          top: 8, right: 12,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () async {
                await SupabaseService.signOut();
                setState(() { _profile = null; _myCases = []; });
              },
            ),
          ),
        ),
        Positioned(
          bottom: -30, left: 16,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
            child: const Center(child: Text('🎨', style: TextStyle(fontSize: 28))),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    final nickname = _profile?['nickname'] as String? ?? '艺见用户';
    final bio = _profile?['bio'] as String? ?? '目标：英国艺术院校';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
              Text(bio, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('编辑资料'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final following = _profile?['following_count'] as int? ?? 0;
    final followers = _profile?['followers_count'] as int? ?? 0;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          _buildUserInfo(),
          const Divider(height: 1),
          Row(
            children: [
              _StatItem(label: '关注', value: '$following'),
              _StatItem(label: '粉丝', value: '$followers'),
              _StatItem(label: '案例', value: '${_myCases.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickAction(icon: Icons.school_outlined, label: '选校清单', color: const Color(0xFFEFF6FF), iconColor: const Color(0xFF3B82F6)),
          _QuickAction(icon: Icons.favorite_outline, label: '我的收藏', color: const Color(0xFFFFF1F2), iconColor: const Color(0xFFE11D48)),
          _QuickAction(icon: Icons.description_outlined, label: '文书草稿', color: const Color(0xFFF5F3FF), iconColor: const Color(0xFF7C3AED)),
          _QuickAction(icon: Icons.add, label: '分享案例', color: const Color(0xFFFFF7ED), iconColor: kPrimary),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['申请追踪', '我的案例'];
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(tabs.length, (i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _tabIndex == i ? kPrimary : Colors.transparent, width: 2)),
              ),
              child: Text(tabs[i], textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _tabIndex == i ? kPrimary : Colors.grey)),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_tabIndex == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: EmptyState(emoji: '📋', message: '暂无申请追踪\n前往探索页添加心仪院校'),
      );
    }
    if (_myCases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: EmptyState(emoji: '📝', message: '还没有分享过案例'),
      );
    }
    return Column(
      children: _myCases.map((c) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id))),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(gradient: resultGradient(c.result), borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(c.targetSchool ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              )),
              Text(resultLabel(c.result), style: TextStyle(fontSize: 10, color: resultBadgeColor(c.result), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _NotLoggedInView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎨', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('登录后解锁全部功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 6),
            Text('申请追踪 · 案例分享 · 论坛互动', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('登录 / 注册', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ]),
    ));
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
    ]);
  }
}
