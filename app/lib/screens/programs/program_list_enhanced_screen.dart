import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ProgramListEnhancedScreen extends StatefulWidget {
  static final programListKey = GlobalKey<ProgramListEnhancedScreenState>();

  final ValueChanged<bool>? onSearchToolsVisibilityChanged;

  const ProgramListEnhancedScreen({
    super.key,
    this.onSearchToolsVisibilityChanged,
  });

  @override
  State<ProgramListEnhancedScreen> createState() =>
      ProgramListEnhancedScreenState();
}

class ProgramListEnhancedScreenState extends State<ProgramListEnhancedScreen> {
  final List<ProgramWithSchool> _items = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDegree;
  bool? _requiresPortfolio;
  bool _toolsVisible = false;
  bool _filtersExpanded = false;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;

  bool get searchToolsVisible => _toolsVisible;

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
      final result = await BackendApiService.fetchProgramsWithSchool(
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

  bool revealSearchTools() {
    setState(() {
      _toolsVisible = true;
      _filtersExpanded = true;
    });
    widget.onSearchToolsVisibilityChanged?.call(_toolsVisible);
    return _toolsVisible;
  }

  bool toggleSearchTools() {
    setState(() {
      _toolsVisible = !_toolsVisible;
      if (!_toolsVisible) _filtersExpanded = false;
    });
    widget.onSearchToolsVisibilityChanged?.call(_toolsVisible);
    return _toolsVisible;
  }

  void _toggleFilters() {
    setState(() {
      _toolsVisible = true;
      _filtersExpanded = !_filtersExpanded;
    });
  }

  void _closeTools() {
    setState(() {
      _toolsVisible = false;
      _filtersExpanded = false;
    });
    widget.onSearchToolsVisibilityChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _selectedDegree != null ||
        _requiresPortfolio != null ||
        _searchController.text.trim().isNotEmpty;
    final toolsSpacerHeight =
        !_toolsVisible ? 0.0 : (_filtersExpanded ? 350.0 : 178.0);

    final toolsPanel = _ProgramToolsPanel(
      searchBar: _SearchBar(
        controller: _searchController,
        onSubmitted: (_) => _refresh(),
        onClear: () {
          if (_searchController.text.isEmpty) return;
          _searchController.clear();
          _refresh();
        },
      ),
      filtersExpanded: _filtersExpanded,
      hasFilters: hasFilters,
      onToggleFilters: _toggleFilters,
      onClose: _closeTools,
      filterPanel: _FilterPanel(
        selectedDegree: _selectedDegree,
        requiresPortfolio: _requiresPortfolio,
        onDegreeChanged: _setDegree,
        onPortfolioChanged: _setPortfolio,
        onClear: _clearFilters,
      ),
    );

    return Stack(
      children: [
        RefreshIndicator(
          color: kCobalt,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: toolsSpacerHeight)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '专业列表',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _error != null
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Text('加载失败: $_error',
                              style: TextStyle(color: context.artC.ink)),
                        ),
                      )
                    : _items.isEmpty && !_loading
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Text('暂无专业',
                                  style: TextStyle(color: context.artC.ink)),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < _items.length) {
                                  return Column(
                                    children: [
                                      _ProgramCard(program: _items[index]),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                } else if (_hasMore) {
                                  _loadMore();
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: kCobalt,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  );
                                }
                                return null;
                              },
                              childCount: _items.length + (_hasMore ? 1 : 0),
                            ),
                          ),
              ),
            ],
          ),
        ),
        if (_toolsVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: toolsPanel,
          ),
      ],
    );
  }
}

class _ProgramToolsPanel extends StatelessWidget {
  final Widget searchBar;
  final bool filtersExpanded;
  final bool hasFilters;
  final VoidCallback onToggleFilters;
  final VoidCallback onClose;
  final Widget filterPanel;

  const _ProgramToolsPanel({
    required this.searchBar,
    required this.filtersExpanded,
    required this.hasFilters,
    required this.onToggleFilters,
    required this.onClose,
    required this.filterPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(child: searchBar),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: context.artC.silver.withAlpha(100)),
                      ),
                      child:
                          Icon(Icons.close, size: 20, color: context.artC.ink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: onToggleFilters,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasFilters ? kCobalt.withAlpha(25) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasFilters
                          ? kCobalt
                          : context.artC.silver.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: 18,
                          color: hasFilters ? kCobalt : context.artC.ink),
                      const SizedBox(width: 8),
                      Text(
                        '筛选条件',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasFilters ? kCobalt : context.artC.ink,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        filtersExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: hasFilters ? kCobalt : context.artC.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (filtersExpanded) filterPanel,
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.artC.silver.withAlpha(100)),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '搜索专业名称',
          hintStyle:
              TextStyle(fontSize: 13, color: context.artC.ink.withAlpha(100)),
          prefixIcon: Icon(Icons.search,
              size: 20, color: context.artC.ink.withAlpha(150)),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.clear,
                      size: 18, color: context.artC.ink.withAlpha(150)),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: TextStyle(fontSize: 13, color: context.artC.ink),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String? selectedDegree;
  final bool? requiresPortfolio;
  final ValueChanged<String?> onDegreeChanged;
  final ValueChanged<bool?> onPortfolioChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.selectedDegree,
    required this.requiresPortfolio,
    required this.onDegreeChanged,
    required this.onPortfolioChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('学位类型',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink)),
              const Spacer(),
              if (selectedDegree != null || requiresPortfolio != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Text('清除',
                      style: TextStyle(fontSize: 13, color: kCobalt)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '本科',
                selected: selectedDegree == 'bachelor',
                onTap: () => onDegreeChanged(
                    selectedDegree == 'bachelor' ? null : 'bachelor'),
              ),
              _FilterChip(
                label: '硕士',
                selected: selectedDegree == 'master',
                onTap: () => onDegreeChanged(
                    selectedDegree == 'master' ? null : 'master'),
              ),
              _FilterChip(
                label: '博士',
                selected: selectedDegree == 'phd',
                onTap: () =>
                    onDegreeChanged(selectedDegree == 'phd' ? null : 'phd'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('作品集要求',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: '需要作品集',
                selected: requiresPortfolio == true,
                onTap: () =>
                    onPortfolioChanged(requiresPortfolio == true ? null : true),
              ),
              _FilterChip(
                label: '不需要作品集',
                selected: requiresPortfolio == false,
                onTap: () => onPortfolioChanged(
                    requiresPortfolio == false ? null : false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kCobalt : context.artC.silver.withAlpha(100),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.artC.ink,
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final ProgramWithSchool program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (program.school != null) ...[
            Row(
              children: [
                if (program.school!.logoUrl != null)
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: context.artC.silver.withAlpha(50)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        program.school!.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.school,
                            size: 20, color: context.artC.ink.withAlpha(100)),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.school!.nameZh,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.artC.ink.withAlpha(150),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (program.school!.nameEn != null)
                        Text(
                          program.school!.nameEn!,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.artC.ink.withAlpha(100),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            program.programName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (program.degreeType != null)
                _Tag(text: program.degreeType!, color: kCobalt),
              if (program.durationMonths != null)
                _Tag(
                    text: '${program.durationMonths}个月',
                    color: context.artC.ink.withAlpha(150)),
              if (program.requiresPortfolio)
                const _Tag(text: '需作品集', color: Colors.orange),
              if (program.tuitionFee != null)
                _Tag(
                    text: '学费 ${program.tuitionFee!.toStringAsFixed(0)}',
                    color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
