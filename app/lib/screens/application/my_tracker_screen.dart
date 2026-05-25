import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class MyTrackerScreen extends StatefulWidget {
  const MyTrackerScreen({super.key});

  @override
  State<MyTrackerScreen> createState() => _MyTrackerScreenState();
}

class _MyTrackerScreenState extends State<MyTrackerScreen> {
  List<ApplicationTrackerItem> _items = const [];
  bool _loading = true;
  bool _analyzing = false;
  bool _generatingTimeline = false;
  String? _error;

  static const _tierLabels = {
    'reach': '冲刺',
    'match': '匹配',
    'safety': '保底',
  };

  static const _statusLabels = {
    'planning': '规划中',
    'preparing': '准备材料',
    'submitted': '已提交',
    'admitted': '已录取',
    'rejected': '未录取',
  };

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
      final items = await BackendApiService.fetchMyTracker();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _updateItem(
    ApplicationTrackerItem item, {
    String? tier,
    String? status,
  }) async {
    final oldItems = _items;
    setState(() {
      _items = _items
          .map((current) => current.id == item.id
              ? ApplicationTrackerItem(
                  id: current.id,
                  schoolId: current.schoolId,
                  programId: current.programId,
                  schoolName: current.schoolName,
                  programName: current.programName,
                  tier: tier ?? current.tier,
                  status: status ?? current.status,
                  deadline: current.deadline,
                  notes: current.notes,
                  createdAt: current.createdAt,
                  updatedAt: current.updatedAt,
                )
              : current)
          .toList();
    });
    try {
      final updated = await BackendApiService.updateTrackerItem(
        item.id,
        tier: tier,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((current) => current.id == item.id ? updated : current)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = oldItems);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _deleteItem(ApplicationTrackerItem item) async {
    final oldItems = _items;
    setState(() =>
        _items = _items.where((current) => current.id != item.id).toList());
    try {
      await BackendApiService.deleteTrackerItem(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = oldItems);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  Future<void> _openAddSheet() async {
    final created = await showModalBottomSheet<ApplicationTrackerItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTrackerSheet(),
    );
    if (created == null || !mounted) return;
    setState(() => _items = [created, ..._items]);
  }

  Future<void> _analyzeAndSuggestTiers() async {
    final analyzable = _items
        .where((item) => item.schoolId != null && item.schoolId!.isNotEmpty)
        .toList();
    if (analyzable.isEmpty || _analyzing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清单里还没有可分析的院校 ID')),
      );
      return;
    }
    setState(() => _analyzing = true);
    try {
      final result = await BackendApiService.aiAnalyzeSchools(
        analyzable.map((item) => item.schoolId!).toList(),
      );
      final analyses = _TrackerAnalysis.listFromResult(result);
      if (!mounted) return;
      setState(() => _analyzing = false);
      _showAnalysisSheet(analyses);
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败：$e')),
      );
    }
  }

  void _showAnalysisSheet(List<_TrackerAnalysis> analyses) {
    if (analyses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时没有生成可用分析')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalysisSheet(
        analyses: analyses,
        onApply: () async {
          Navigator.of(context).pop();
          await _applyTierSuggestions(analyses);
        },
      ),
    );
  }

  Future<void> _applyTierSuggestions(List<_TrackerAnalysis> analyses) async {
    final bySchoolId = {for (final item in analyses) item.schoolId: item};
    for (final item in _items) {
      final analysis = bySchoolId[item.schoolId];
      if (analysis == null || analysis.suggestedTier == item.tier) continue;
      await _updateItem(item, tier: analysis.suggestedTier);
    }
  }

  Future<void> _generateTimeline() async {
    if (_generatingTimeline) return;
    setState(() => _generatingTimeline = true);
    try {
      final tasks = await BackendApiService.fetchTrackerTimeline();
      if (!mounted) return;
      setState(() => _generatingTimeline = false);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TimelineSheet(tasks: tasks),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingTimeline = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingIndicator());
    }
    if (_error != null) {
      return _TrackerError(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      color: kCobalt,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
              child: _TrackerSummary(
                items: _items,
                onAdd: _openAddSheet,
                onAnalyze: _analyzeAndSuggestTiers,
                onTimeline: _generateTimeline,
                analyzing: _analyzing,
                generatingTimeline: _generatingTimeline,
              ),
            ),
          ),
          if (_items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                emoji: '🗂',
                message: '还没有申请清单',
              ),
            )
          else
            ..._tierLabels.entries.map((entry) {
              final tierItems =
                  _items.where((item) => item.tier == entry.key).toList();
              return SliverToBoxAdapter(
                child: _TierSection(
                  title: entry.value,
                  items: tierItems,
                  tierLabels: _tierLabels,
                  statusLabels: _statusLabels,
                  onTierChanged: (item, tier) => _updateItem(item, tier: tier),
                  onStatusChanged: (item, status) =>
                      _updateItem(item, status: status),
                  onDelete: _deleteItem,
                ),
              );
            }),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _TrackerSummary extends StatelessWidget {
  final List<ApplicationTrackerItem> items;
  final VoidCallback onAdd;
  final VoidCallback onAnalyze;
  final VoidCallback onTimeline;
  final bool analyzing;
  final bool generatingTimeline;

  const _TrackerSummary({
    required this.items,
    required this.onAdd,
    required this.onAnalyze,
    required this.onTimeline,
    required this.analyzing,
    required this.generatingTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = items
        .where(
            (item) => item.status == 'submitted' || item.status == 'admitted')
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [kShadowCard],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryStat(label: '清单', value: '${items.length}'),
              _SummaryStat(label: '已提交', value: '$submitted'),
              _SummaryStat(
                label: '录取',
                value:
                    '${items.where((item) => item.status == 'admitted').length}',
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryAction(
                  label: analyzing ? '分析中...' : 'AI 分析分层',
                  icon: Icons.auto_graph_rounded,
                  onTap: analyzing ? null : onAnalyze,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryAction(
                  label: generatingTimeline ? '生成中...' : '生成时间线',
                  icon: Icons.timeline_rounded,
                  onTap: generatingTimeline ? null : onTimeline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SummaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.86)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 12,
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

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  final String title;
  final List<ApplicationTrackerItem> items;
  final Map<String, String> tierLabels;
  final Map<String, String> statusLabels;
  final void Function(ApplicationTrackerItem item, String tier) onTierChanged;
  final void Function(ApplicationTrackerItem item, String status)
      onStatusChanged;
  final ValueChanged<ApplicationTrackerItem> onDelete;

  const _TierSection({
    required this.title,
    required this.items,
    required this.tierLabels,
    required this.statusLabels,
    required this.onTierChanged,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.68),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => _TrackerCard(
              item: item,
              tierLabels: tierLabels,
              statusLabels: statusLabels,
              onTierChanged: (tier) => onTierChanged(item, tier),
              onStatusChanged: (status) => onStatusChanged(item, status),
              onDelete: () => onDelete(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerCard extends StatefulWidget {
  final ApplicationTrackerItem item;
  final Map<String, String> tierLabels;
  final Map<String, String> statusLabels;
  final ValueChanged<String> onTierChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  const _TrackerCard({
    required this.item,
    required this.tierLabels,
    required this.statusLabels,
    required this.onTierChanged,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  State<_TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<_TrackerCard> {
  List<AppCase>? _relatedCases;
  bool _loadingCases = false;
  bool _showCases = false;

  Future<void> _loadRelatedCases() async {
    if (_relatedCases != null || _loadingCases) return;
    setState(() => _loadingCases = true);
    try {
      final cases = await BackendApiService.fetchCases(
        result: 'admitted',
        limit: 3,
      );
      if (!mounted) return;
      setState(() {
        _relatedCases = cases;
        _loadingCases = false;
        _showCases = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCases = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                    Text(
                      item.schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.programName != null &&
                        item.programName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.programName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.44),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.close_rounded),
                color: context.artC.ink.withValues(alpha: 0.32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactDropdown(
                  value: item.tier,
                  labels: widget.tierLabels,
                  onChanged: widget.onTierChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactDropdown(
                  value: item.status,
                  labels: widget.statusLabels,
                  onChanged: widget.onStatusChanged,
                ),
              ),
            ],
          ),
          if (item.deadline != null && item.deadline!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '截止日期 ${item.deadline}',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.48),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _loadingCases ? null : _loadRelatedCases,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 14,
                    color: kCobalt.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _loadingCases ? '加载中...' : '查看相关案例',
                    style: TextStyle(
                      color: kCobalt.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showCases && _relatedCases != null && _relatedCases!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._relatedCases!.take(2).map(
              (caseItem) => _RelatedCaseCard(caseItem: caseItem),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => labels.entries
          .map(
            (entry) => PopupMenuItem(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.artC.porcelain,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labels[value] ?? value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.artC.ink.withValues(alpha: 0.38),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerAnalysis {
  final String schoolId;
  final String schoolName;
  final int? matchScore;
  final List<String> strengths;
  final List<String> recommendations;

  const _TrackerAnalysis({
    required this.schoolId,
    required this.schoolName,
    this.matchScore,
    this.strengths = const [],
    this.recommendations = const [],
  });

  String get suggestedTier {
    final score = matchScore ?? 0;
    if (score >= 80) return 'match';
    if (score >= 60) return 'reach';
    return 'safety';
  }

  factory _TrackerAnalysis.fromJson(Map<String, dynamic> json) {
    return _TrackerAnalysis(
      schoolId: json['schoolId']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '院校分析',
      matchScore: (json['matchScore'] as num?)?.toInt(),
      strengths: _stringList(json['strengths']),
      recommendations: _stringList(json['recommendations']),
    );
  }

  static List<_TrackerAnalysis> listFromResult(Map<String, dynamic> result) {
    final raw = result['analyses'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_TrackerAnalysis.fromJson)
        .where((item) => item.schoolId.isNotEmpty)
        .toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _AnalysisSheet extends StatelessWidget {
  final List<_TrackerAnalysis> analyses;
  final VoidCallback onApply;

  const _AnalysisSheet({required this.analyses, required this.onApply});

  @override
  Widget build(BuildContext context) {
    const tierLabels = {
      'reach': '冲刺',
      'match': '匹配',
      'safety': '保底',
    };
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [kShadowCard],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'AI 分层建议',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton(onPressed: onApply, child: const Text('应用建议')),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: analyses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = analyses[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.artC.porcelain,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.schoolName,
                                style: TextStyle(
                                  color: context.artC.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _MiniPill(
                              label:
                                  '${item.matchScore ?? '--'} / ${tierLabels[item.suggestedTier]}',
                            ),
                          ],
                        ),
                        if (item.strengths.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.strengths.take(2).join(' · '),
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.58),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _TimelineSheet extends StatelessWidget {
  final List<ApplicationTimelineTask> tasks;

  const _TimelineSheet({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [kShadowCard],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '申请时间线',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    '暂无可生成的时间线',
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.46),
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 78,
                          child: Text(
                            task.date,
                            style: const TextStyle(
                              color: kCobalt,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: context.artC.porcelain,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.task,
                                  style: TextStyle(
                                    color: context.artC.ink,
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _MiniPill(label: task.schoolName),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AddTrackerSheet extends StatefulWidget {
  const _AddTrackerSheet();

  @override
  State<_AddTrackerSheet> createState() => _AddTrackerSheetState();
}

class _AddTrackerSheetState extends State<_AddTrackerSheet> {
  final _schoolCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  String _tier = 'match';
  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _schoolResults = [];
  Map<String, dynamic>? _selectedSchool;

  static const _tierLabels = {
    'reach': '冲刺',
    'match': '匹配',
    'safety': '保底',
  };

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchSchools(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _schoolResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await BackendApiService.fetchSchools(
        keyword: query,
        limit: 5,
      );
      if (!mounted) return;
      setState(() {
        _schoolResults = result.data;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _selectSchool(Map<String, dynamic> school) {
    setState(() {
      _selectedSchool = school;
      _schoolCtrl.text = school['name_zh']?.toString() ?? school['name_en']?.toString() ?? '';
      _schoolResults = [];
    });
  }

  Future<void> _submit() async {
    final schoolName = _schoolCtrl.text.trim();
    final programName = _programCtrl.text.trim();
    if (schoolName.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final item = await BackendApiService.addToTracker(
        schoolId: _selectedSchool?['id']?.toString(),
        schoolName: schoolName,
        programName: programName.isEmpty ? null : programName,
        tier: _tier,
      );
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [kShadowCard],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '添加申请项',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _schoolCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '搜索院校名称',
                suffixIcon: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _selectedSchool != null
                        ? const Icon(Icons.check_circle, color: kCobalt)
                        : null,
              ),
              onChanged: (value) {
                setState(() => _selectedSchool = null);
                _searchSchools(value);
              },
            ),
            if (_schoolResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: context.artC.porcelain,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _schoolResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.artC.silver.withValues(alpha: 0.28),
                  ),
                  itemBuilder: (context, index) {
                    final school = _schoolResults[index];
                    final nameZh = school['name_zh']?.toString() ?? '';
                    final nameEn = school['name_en']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(
                        nameZh.isNotEmpty ? nameZh : nameEn,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: nameZh.isNotEmpty && nameEn.isNotEmpty
                          ? Text(
                              nameEn,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.artC.ink.withValues(alpha: 0.48),
                              ),
                            )
                          : null,
                      onTap: () => _selectSchool(school),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _programCtrl,
              decoration: const InputDecoration(hintText: '专业名称（可选）'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: _tierLabels.entries.map((entry) {
                final selected = _tier == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _tier = entry.key),
                  selectedColor: kCobalt,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : context.artC.ink,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed:
                    _schoolCtrl.text.trim().isEmpty || _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('加入申请清单'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TrackerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '申请清单加载失败',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.48),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _RelatedCaseCard extends StatelessWidget {
  final AppCase caseItem;

  const _RelatedCaseCard({required this.caseItem});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (caseItem.targetSchool != null) caseItem.targetSchool!,
      if (caseItem.year != null) caseItem.year!,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_outlined, color: kCobalt, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.42),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: context.artC.ink.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}
