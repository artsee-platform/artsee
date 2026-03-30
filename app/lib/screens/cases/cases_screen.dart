import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'case_detail_screen.dart';
import 'new_case_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppCase> _cases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await SupabaseService.fetchCases();
    if (mounted) setState(() { _cases = data; _loading = false; });
  }

  List<AppCase> get _filtered {
    if (_tabController.index == 1) return _cases.where((c) => c.result == 'admitted').toList();
    if (_tabController.index == 2) return _cases.where((c) => c.result == 'waitlisted').toList();
    return _cases;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('申请案例', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kPrimary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewCaseScreen())).then((_) => _load()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '全部案例'), Tab(text: '录取'), Tab(text: '等候')],
        ),
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _load,
        child: _loading
          ? const LoadingIndicator()
          : _filtered.isEmpty
            ? const EmptyState(emoji: '📝', message: '暂无案例，来第一个分享吧！')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) => _CaseCard(
                  c: _filtered[i],
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => CaseDetailScreen(caseId: _filtered[i].id),
                  )),
                ),
              ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final AppCase c;
  final VoidCallback onTap;

  const _CaseCard({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: schoolGradient(c.targetSchool),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: resultBadgeColor(c.result).withOpacity(0.9), borderRadius: BorderRadius.circular(99)),
                    child: Text(resultLabel(c.result), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (c.targetSchool != null)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text(c.targetSchool!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.excerpt ?? c.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(radius: 9, backgroundColor: kPrimary,
                        child: Text(c.isAnonymous ? '匿' : (c.authorNickname?.substring(0, 1) ?? '?'), style: const TextStyle(color: Colors.white, fontSize: 8))),
                      const SizedBox(width: 4),
                      Text(c.isAnonymous ? '匿名' : (c.authorNickname ?? '用户'), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      if (c.gpa != null) ...[
                        Text(' · ', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        Text(c.gpa!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                      const Spacer(),
                      Icon(Icons.favorite_border, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${c.likeCount}', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
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
