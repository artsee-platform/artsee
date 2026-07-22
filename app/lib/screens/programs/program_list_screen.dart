import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import 'program_detail_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 专业列表 — 分页查询
class ProgramListScreen extends StatefulWidget {
  const ProgramListScreen({super.key});

  @override
  State<ProgramListScreen> createState() => _ProgramListScreenState();
}

class _ProgramListScreenState extends State<ProgramListScreen> {
  final List<AppProgram> _items = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDegree;
  bool? _requiresPortfolio;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await BackendApiService.fetchProgramsPaginated(
        limit: _limit,
        offset: _offset,
        keyword: _searchController.text.trim(),
        degreeType: _selectedDegree,
        requiresPortfolio: _requiresPortfolio,
      );
      final newItems = result.data;
      final total = result.count;
      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _offset += newItems.length;
          _hasMore = total == null || _offset < total;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  void _setDegree(String? degree) {
    setState(() => _selectedDegree = degree);
    _refresh();
  }

  void _setPortfolio(bool? value) {
    setState(() => _requiresPortfolio = value);
    _refresh();
  }

  void _clearFilters() {
    setState(() {
      _selectedDegree = null;
      _requiresPortfolio = null;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kCobalt,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _ProgramHeader(),
          const SizedBox(height: 18),
          _ProgramSearchBar(
            controller: _searchController,
            onSubmitted: (_) => _refresh(),
            onClear: () {
              if (_searchController.text.isEmpty) return;
              _searchController.clear();
              _refresh();
            },
          ),
          const SizedBox(height: 14),
          _ProgramFilterBar(
            selectedDegree: _selectedDegree,
            requiresPortfolio: _requiresPortfolio,
            onDegreeChanged: _setDegree,
            onPortfolioChanged: _setPortfolio,
            onClear: _clearFilters,
          ),
          const SizedBox(height: 14),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: Text(
                '共 ${_items.length}${_hasMore ? '+' : ''} 个专业项目',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.38),
                ),
              ),
            ),
          if (_items.isEmpty && _loading)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_items.isEmpty && _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 96),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('加载失败: $_error',
                      style: TextStyle(color: context.artC.ink)),
                  const SizedBox(height: 12),
                  _ProgramPressable(
                    onTap: _refresh,
                    pressedScale: 0.95,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kCobalt,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: kCobalt.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text(
                        '重试',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(
                child: Text(
                  '暂无匹配专业',
                  style: TextStyle(color: context.artC.ink),
                ),
              ),
            )
          else ...[
            for (final item in _items) ...[
              _ProgramCard(
                program: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProgramDetailScreen(id: item.id),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_hasMore)
            Builder(
              builder: (context) {
                if (_items.isNotEmpty && !_loading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) _loadMore();
                  });
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: kCobalt,
                              strokeWidth: 2,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ProgramPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _ProgramPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_ProgramPressable> createState() => _ProgramPressableState();
}

class _ProgramPressableState extends State<_ProgramPressable> {
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

class _ProgramHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 44, height: 1, color: kCobalt),
            const SizedBox(width: 12),
            Text(
              'PROGRAM PATHWAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                color: kCobalt.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '艺术专业项目库',
          style: TextStyle(
            fontSize: 32,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: context.artC.ink,
            fontFamily: 'Noto Serif SC',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '按学位、作品集要求和关键词快速筛选，找到最适合的申请方向。',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: context.artC.ink.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class _ProgramSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _ProgramSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: 8,
      color: context.artC.cardIconBg.withValues(alpha: 0.82),
      child: Row(
        children: [
          Icon(Icons.search,
              size: 20, color: context.artC.ink.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索专业名称',
                border: InputBorder.none,
                hintStyle:
                    TextStyle(color: context.artC.ink.withValues(alpha: 0.3)),
              ),
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(
              Icons.close,
              size: 18,
              color: context.artC.ink.withValues(alpha: 0.35),
            ),
            tooltip: '清空',
          ),
        ],
      ),
    );
  }
}

class _ProgramFilterBar extends StatelessWidget {
  final String? selectedDegree;
  final bool? requiresPortfolio;
  final ValueChanged<String?> onDegreeChanged;
  final ValueChanged<bool?> onPortfolioChanged;
  final VoidCallback onClear;

  const _ProgramFilterBar({
    required this.selectedDegree,
    required this.requiresPortfolio,
    required this.onDegreeChanged,
    required this.onPortfolioChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = selectedDegree != null || requiresPortfolio != null;
    return ArtseeSurface(
      padding: const EdgeInsets.all(16),
      radius: 8,
      color: context.artC.cardIconBg.withValues(alpha: 0.82),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.school_outlined, color: kCobalt, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '专业筛选',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DEGREE / PORTFOLIO',
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.28),
                        fontSize: 9,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgramPressable(
                onTap: hasFilters ? onClear : null,
                pressedScale: 0.96,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.artC.porcelain.withValues(
                      alpha: hasFilters ? 0.72 : 0.38,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.artC.silver.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close,
                        size: 14,
                        color: context.artC.ink.withValues(
                          alpha: hasFilters ? 0.45 : 0.18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '清除筛选',
                        style: TextStyle(
                          color: context.artC.ink.withValues(
                            alpha: hasFilters ? 0.45 : 0.18,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipButton(
                text: '全部学位',
                selected: selectedDegree == null,
                onTap: () => onDegreeChanged(null),
              ),
              for (final degree in const ['BA', 'MA', 'MFA', 'BFA', 'PhD'])
                _FilterChipButton(
                  text: degree,
                  selected: selectedDegree == degree,
                  onTap: () => onDegreeChanged(degree),
                ),
              _FilterChipButton(
                text: '不限作品集',
                selected: requiresPortfolio == null,
                onTap: () => onPortfolioChanged(null),
              ),
              _FilterChipButton(
                text: '需作品集',
                selected: requiresPortfolio == true,
                onTap: () => onPortfolioChanged(true),
              ),
              _FilterChipButton(
                text: '无需作品集',
                selected: requiresPortfolio == false,
                onTap: () => onPortfolioChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ProgramPressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kCobalt.withValues(alpha: 0.08)
              : context.artC.porcelain.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? kCobalt.withValues(alpha: 0.28)
                : context.artC.silver.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color:
                selected ? kCobalt : context.artC.ink.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final AppProgram program;
  final VoidCallback? onTap;

  const _ProgramCard({required this.program, this.onTap});

  @override
  Widget build(BuildContext context) {
    final schoolName = program.schoolNameZh ?? '—';

    return _ProgramPressable(
      onTap: onTap,
      pressedScale: 0.985,
      child: ArtseeSurface(
        padding: const EdgeInsets.all(16),
        radius: 8,
        color: context.artC.cardIconBg.withValues(alpha: 0.84),
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (program.coverImageUrl != null &&
                program.coverImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.network(
                    program.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.artC.silver.withValues(alpha: 0.22),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: context.artC.ink.withValues(alpha: 0.26),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.programName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: context.artC.ink.withValues(alpha: 0.25)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.artC.silver.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    schoolName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.artC.ink.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (program.degreeType != null &&
                    program.degreeType!.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      program.degreeType!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kCobalt.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
                if (program.requiresPortfolio)
                  const _Pill('需作品集', highlighted: true),
                if (program.requiresInterview) const _Pill('需面试'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ProgramStat(
                    label: 'IELTS',
                    value: program.ieltsOverall?.toString() ?? '---',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                Expanded(
                  child: _ProgramStat(
                    label: '学制',
                    value: program.durationText ?? '---',
                    icon: Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _ProgramStat(
                    label: '学费',
                    value: _formatTuition(
                      program.internationalTuitionFee,
                      program.currencyCode,
                    ),
                    icon: Icons.payments_outlined,
                  ),
                ),
                Expanded(
                  child: _ProgramStat(
                    label: '截止',
                    value: _shortDate(program.regularDeadline),
                    icon: Icons.event_available_outlined,
                  ),
                ),
              ],
            ),
            if (program.programOverview != null &&
                program.programOverview!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                program.programOverview!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: context.artC.ink.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _Pill(this.text, {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? kCobalt.withValues(alpha: 0.08)
            : context.artC.silver.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: highlighted
              ? kCobalt.withValues(alpha: 0.9)
              : context.artC.ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _ProgramStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProgramStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: kCobalt.withValues(alpha: 0.72)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: context.artC.ink.withValues(alpha: 0.32),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(String? value) {
  if (value == null || value.isEmpty) return '滚动';
  if (value.length >= 10) return value.substring(5, 10);
  return value;
}

String _formatTuition(int? value, String? currency) {
  if (value == null || value <= 0) return '---';
  final symbol = switch ((currency ?? '').toUpperCase()) {
    'GBP' => '£',
    'USD' => '\$',
    'EUR' => '€',
    'CNY' => '¥',
    _ => currency ?? '',
  };
  if (value >= 1000) return '$symbol${(value / 1000).round()}k';
  return '$symbol$value';
}
