import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';

class ProgramDetailScreen extends StatefulWidget {
  final int programId;
  const ProgramDetailScreen({super.key, required this.programId});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  AppProgram? _program;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SupabaseService.fetchProgram(widget.programId);
    if (mounted) setState(() { _program = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingIndicator());
    if (_program == null) return const Scaffold(body: EmptyState(emoji: '❌', message: '找不到该项目'));

    final p = _program!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: schoolGradient(p.schoolNameZh)),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(p.schoolNameZh ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(p.programName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (p.degreeType != null) _Badge(p.degreeType!),
                            if (p.durationText != null) ...[const SizedBox(width: 6), _Badge(p.durationText!)],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Key metrics
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (p.ieltsOverall != null) ...[InfoCard(label: '雅思要求', value: '${p.ieltsOverall}'), const SizedBox(width: 8)],
                  if (p.internationalTuitionFee != null) ...[InfoCard(label: '学费/年', value: '£${(p.internationalTuitionFee! / 1000).toStringAsFixed(0)}k'), const SizedBox(width: 8)],
                  if (p.regularDeadline != null) InfoCard(label: '截止日期', value: p.regularDeadline!.substring(0, 10)),
                ],
              ),
            ),
          ),

          // Overview
          if (p.programOverview != null)
            SliverToBoxAdapter(
              child: _Section(
                title: '项目简介',
                child: Text(p.programOverview!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6)),
              ),
            ),

          // Requirements
          SliverToBoxAdapter(
            child: _Section(
              title: '申请要求',
              child: Column(
                children: [
                  _ReqRow(icon: Icons.collections_outlined, label: '作品集', value: p.requiresPortfolio ? '需要' : '不需要', positive: p.requiresPortfolio),
                  _ReqRow(icon: Icons.record_voice_over_outlined, label: '面试', value: p.requiresInterview ? '需要' : '不需要', positive: p.requiresInterview),
                  if (p.ieltsOverall != null)
                    _ReqRow(icon: Icons.language_outlined, label: '雅思', value: '${p.ieltsOverall}', positive: true),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool positive;

  const _ReqRow({required this.icon, required this.label, required this.value, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: positive ? Colors.black87 : Colors.grey)),
        ],
      ),
    );
  }
}
