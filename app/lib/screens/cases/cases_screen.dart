import 'package:artsee_app/theme/artsee_ui_colors.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'case_detail_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  static const _filters = <({String label, String? value})>[
    (label: '全部', value: null),
    (label: '录取', value: 'admitted'),
    (label: '候补', value: 'waitlisted'),
    (label: '未录取', value: 'rejected'),
  ];

  List<AppCase> _cases = const [];
  bool _loading = true;
  String? _error;
  String? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rows = await BackendApiService.fetchCases(
        limit: 40,
        result: _result,
      );
      if (!mounted) return;
      setState(() {
        _cases = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _selectResult(String? value) {
    if (_result == value) return;
    setState(() {
      _result = value;
      _cases = const [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: kCobalt,
          onRefresh: () => _load(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ResultFilters(
                  filters: _filters,
                  selected: _result,
                  onSelected: _selectResult,
                ),
              ),
              if (_loading && _cases.isEmpty)
                const SliverFillRemaining(child: LoadingIndicator())
              else if (_error != null && _cases.isEmpty)
                SliverFillRemaining(
                  child: _CasesError(message: _error!, onRetry: _load),
                )
              else if (_cases.isEmpty)
                const SliverFillRemaining(child: _CasesEmpty())
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    mainTabBottomInset(context),
                  ),
                  sliver: SliverList.separated(
                    itemCount: _cases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _CaseCard(item: _cases[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultFilters extends StatelessWidget {
  final List<({String label, String? value})> filters;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _ResultFilters({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final active = selected == f.value;
          return _CaseFilterChip(
            label: f.label,
            active: active,
            onTap: () => onSelected(f.value),
          );
        },
      ),
    );
  }
}

class _CaseFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CaseFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 34,
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                active ? kCobalt : context.artC.silver.withValues(alpha: 0.56),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kCobalt.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active
                ? Colors.white
                : context.artC.ink.withValues(alpha: 0.46),
            fontWeight: active ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final AppCase item;

  const _CaseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final excerpt = (item.excerpt ?? item.content ?? '').trim();
    final targetText =
        '${item.targetSchool ?? '目标院校待补'} · ${item.targetProgram ?? '专业待补'}';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CaseDetailScreen(caseId: item.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.34)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 4),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: resultGradient(item.result),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    resultLabel(item.result).substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kCobalt.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              resultLabel(item.result),
                              style: const TextStyle(
                                color: kCobalt,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.year ?? timeAgo(item.createdAt),
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.34),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        targetText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.34),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.artC.ink.withValues(alpha: 0.16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniFact(
                    label: '本科背景',
                    value: item.undergrad ?? '未填写',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _MiniFact(
                    label: 'GPA',
                    value: item.gpa ?? '未填写',
                  ),
                ),
              ],
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: context.artC.ink.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags.take(5).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.artC.ink.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _Meta(icon: Icons.favorite_border, value: item.likeCount),
                const SizedBox(width: 14),
                _Meta(
                  icon: Icons.chat_bubble_outline,
                  value: item.commentCount,
                ),
                const SizedBox(width: 14),
                _Meta(
                  icon: Icons.bookmark_border,
                  value: item.saveCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.32),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.artC.ink.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final int value;

  const _Meta({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.artC.ink.withValues(alpha: 0.32)),
        const SizedBox(width: 4),
        Text(
          _shortCount(value),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.artC.ink.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _CasesEmpty extends StatelessWidget {
  const _CasesEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 46,
            color: context.artC.ink.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          Text(
            '暂时没有匹配案例',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '换一个申请结果筛选，或稍后补充更多真实案例数据。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.artC.ink.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CasesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CasesError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 46,
            color: context.artC.ink.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          Text(
            '案例数据暂时加载失败',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.artC.ink.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 16),
          CobaltButton(label: '重试', onTap: onRetry),
        ],
      ),
    );
  }
}

String _shortCount(int value) {
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceAll('.0', '')}万';
  }
  return '$value';
}
