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
    (label: '全部案例', value: null),
    (label: '已录取', value: 'admitted'),
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
        child: RefreshIndicator(
          color: kCobalt,
          onRefresh: () => _load(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _CasesHeader()),
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

class _CasePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _CasePressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_CasePressable> createState() => _CasePressableState();
}

class _CasePressableState extends State<_CasePressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _CasesHeader extends StatelessWidget {
  const _CasesHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '录取案例库',
            style: TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
              fontFamily: kAppFontFamily,
              fontFamilyFallback: kAppFontFallback,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '从真实申请结果里查看院校、专业、背景和作品集准备路径。',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: context.artC.ink.withValues(alpha: 0.42),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final active = selected == f.value;
          return TagChip(
            label: f.label,
            active: active,
            onTap: () => onSelected(f.value),
          );
        },
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
    return _CasePressable(
      pressedScale: 0.985,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CaseDetailScreen(caseId: item.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.artC.cardIconBg.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.02),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: resultGradient(item.result),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          resultLabel(item.result),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.year ?? timeAgo(item.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      fontFamily: kAppFontFamily,
                      fontFamilyFallback: kAppFontFallback,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.targetSchool ?? '目标院校待补'} · ${item.targetProgram ?? '专业待补'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniFact(
                          label: '本科背景',
                          value: item.undergrad ?? '未填写',
                        ),
                      ),
                      const SizedBox(width: 10),
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
                        color: context.artC.ink.withValues(alpha: 0.52),
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
                            color: kCobalt.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              color: kCobalt,
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
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 13,
                        color: context.artC.ink.withValues(alpha: 0.28),
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

class _MiniFact extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
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
