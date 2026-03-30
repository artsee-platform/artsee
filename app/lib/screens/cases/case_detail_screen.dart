import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  AppCase? _case;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await SupabaseService.fetchCase(widget.caseId);
    if (mounted) setState(() { _case = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingIndicator());
    if (_case == null) return const Scaffold(body: EmptyState(emoji: '❌', message: '找不到该案例'));

    final c = _case!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: resultGradient(c.result)),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(99)),
                          child: Text(resultLabel(c.result), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 6),
                        Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Applicant card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: kPrimary,
                        child: Text(c.isAnonymous ? '匿' : (c.authorNickname?.substring(0, 1) ?? '?'),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.isAnonymous ? '匿名用户' : (c.authorNickname ?? '用户'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${c.undergrad ?? ''} · GPA ${c.gpa ?? '—'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InfoCard(label: '目标院校', value: c.targetSchool ?? '—'),
                      const SizedBox(width: 8),
                      InfoCard(label: '申请专业', value: c.targetProgram ?? '—'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tags
          if (c.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6, runSpacing: 4,
                  children: c.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      border: Border.all(color: kPrimary.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('#$t', style: const TextStyle(fontSize: 10, color: kPrimary)),
                  )).toList(),
                ),
              ),
            ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('申请心得', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(c.content ?? c.excerpt ?? '暂无内容', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.7)),
                ],
              ),
            ),
          ),

          // Interaction bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  _ActionBtn(icon: Icons.favorite_border, label: '${c.likeCount} 赞'),
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.bookmark_border, label: '${c.saveCount} 收藏'),
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.chat_bubble_outline, label: '${c.commentCount} 评论'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
