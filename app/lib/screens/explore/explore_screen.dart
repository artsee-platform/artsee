import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'program_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<AppProgram> _programs = [];
  List<AppProgram> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _degreeFilter = '全部';
  String _majorFilter = '全部';

  final List<String> _degreeOptions = ['全部', 'MA', 'MFA', 'MArch', 'MSc'];
  final List<String> _majorOptions = ['全部', '纯艺', '建筑', '设计', '插画', 'IDE'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SupabaseService.fetchPrograms();
    if (mounted) {
      setState(() {
        _programs = data;
        _filter();
        _loading = false;
      });
    }
  }

  void _filter() {
    var list = _programs;
    if (_degreeFilter != '全部') {
      list = list.where((p) => p.degreeType?.contains(_degreeFilter) == true || p.programName.contains(_degreeFilter)).toList();
    }
    if (_majorFilter != '全部') {
      list = list.where((p) => p.programName.contains(_majorFilter)).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((p) =>
        p.programName.contains(_search) ||
        (p.schoolNameZh?.contains(_search) ?? false)
      ).toList();
    }
    _filtered = list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('探索院校', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            backgroundColor: Colors.white,
            floating: true,
            snap: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() { _search = v; _filter(); }),
                  decoration: InputDecoration(
                    hintText: '搜索学校或专业...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),

          // Degree filter
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _degreeOptions.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TagChip(
                    label: d,
                    active: _degreeFilter == d,
                    onTap: () => setState(() { _degreeFilter = d; _filter(); }),
                  ),
                )).toList(),
              ),
            ),
          ),

          // Major filter
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                children: _majorOptions.map((m) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TagChip(
                    label: m,
                    active: _majorFilter == m,
                    onTap: () => setState(() { _majorFilter = m; _filter(); }),
                  ),
                )).toList(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          if (_loading)
            const SliverFillRemaining(child: LoadingIndicator())
          else if (_filtered.isEmpty)
            const SliverFillRemaining(child: EmptyState(emoji: '🔍', message: '没有找到匹配的项目'))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ProgramCard(
                  program: _filtered[i],
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => ProgramDetailScreen(programId: _filtered[i].id),
                  )),
                ),
                childCount: _filtered.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final AppProgram program;
  final VoidCallback onTap;

  const _ProgramCard({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: schoolGradient(program.schoolNameZh),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(program.schoolNameZh ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(program.programName, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (program.qsArtRank != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('QS #${program.qsArtRank}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _MetaChip(icon: Icons.school_outlined, label: program.degreeType ?? 'MA'),
                  const SizedBox(width: 8),
                  if (program.ieltsOverall != null)
                    _MetaChip(icon: Icons.language_outlined, label: 'IELTS ${program.ieltsOverall}'),
                  const SizedBox(width: 8),
                  if (program.durationText != null)
                    _MetaChip(icon: Icons.schedule_outlined, label: program.durationText!),
                  const Spacer(),
                  if (program.requiresPortfolio)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6)),
                      child: const Text('需作品集', style: TextStyle(fontSize: 9, color: kPrimary, fontWeight: FontWeight.w600)),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
