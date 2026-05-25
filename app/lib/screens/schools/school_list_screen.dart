import 'package:flutter/material.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'school_detail_enhanced_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 院校列表 — 分页查询
class SchoolListScreen extends StatefulWidget {
  static final schoolListKey = GlobalKey<SchoolListScreenState>();

  final ValueChanged<bool>? onSearchToolsVisibilityChanged;

  const SchoolListScreen({
    super.key,
    this.onSearchToolsVisibilityChanged,
  });

  @override
  State<SchoolListScreen> createState() => SchoolListScreenState();
}

class SchoolListScreenState extends State<SchoolListScreen> {
  final List<Map<String, dynamic>> _items = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCountry;
  String? _selectedRegionTag;
  String? _selectedSchoolType;
  String? _selectedAdvantageSubject;
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
      final result = await BackendApiService.fetchSchools(
        limit: _limit,
        offset: _offset,
        keyword: _searchController.text.trim(),
        country: _selectedCountry,
        regionTag: _selectedRegionTag,
        schoolType: _selectedSchoolType,
        advantageSubject: _selectedAdvantageSubject,
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

  void _setCountry(String? country) {
    setState(() => _selectedCountry = country);
    _refresh();
  }

  void _setRegionTag(String? value) {
    setState(() => _selectedRegionTag = value);
    _refresh();
  }

  void _setSchoolType(String? value) {
    setState(() => _selectedSchoolType = value);
    _refresh();
  }

  void _setAdvantageSubject(String? value) {
    setState(() => _selectedAdvantageSubject = value);
    _refresh();
  }

  void _clearFilters() {
    setState(() {
      _selectedCountry = null;
      _selectedRegionTag = null;
      _selectedSchoolType = null;
      _selectedAdvantageSubject = null;
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
    final hasFilters = _selectedCountry != null ||
        _selectedRegionTag != null ||
        _selectedSchoolType != null ||
        _selectedAdvantageSubject != null ||
        _searchController.text.trim().isNotEmpty;
    final toolsSpacerHeight =
        !_toolsVisible ? 0.0 : (_filtersExpanded ? 500.0 : 178.0);

    final toolsPanel = _SchoolToolsPanel(
      searchBar: _SearchBar(
        controller: _searchController,
        onSubmitted: (_) => _refresh(),
        onClear: () {
          if (_searchController.text.isEmpty) return;
          _searchController.clear();
          _refresh();
        },
      ),
      countryTabs: _CountryTabs(
        selectedCountry: _selectedCountry,
        onSelected: _setCountry,
      ),
      filtersExpanded: _filtersExpanded,
      hasFilters: hasFilters,
      onToggleFilters: _toggleFilters,
      onClose: _closeTools,
      filterPanel: _FilterPanel(
        selectedRegionTag: _selectedRegionTag,
        selectedSchoolType: _selectedSchoolType,
        selectedAdvantageSubject: _selectedAdvantageSubject,
        onRegionTagChanged: _setRegionTag,
        onSchoolTypeChanged: _setSchoolType,
        onAdvantageSubjectChanged: _setAdvantageSubject,
        onClear: _clearFilters,
      ),
    );

    return Stack(
      children: [
        RefreshIndicator(
          color: kCobalt,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 156),
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: toolsSpacerHeight,
              ),
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Text(
                    '共 ${_items.length}${_hasMore ? '+' : ''} 所院校',
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
                      Text(
                        '加载失败: $_error',
                        style: TextStyle(color: context.artC.ink),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refresh,
                        style:
                            ElevatedButton.styleFrom(backgroundColor: kCobalt),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      '暂无匹配院校',
                      style: TextStyle(color: context.artC.ink),
                    ),
                  ),
                )
              else ...[
                for (var index = 0; index < _items.length; index++) ...[
                  _SchoolCard(
                    data: _items[index],
                    onTap: () {
                      final id = _items[index]['id']?.toString();
                      if (id != null && id.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SchoolDetailEnhancedScreen(id: id),
                          ),
                        );
                      }
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
        ),
        if (_toolsVisible)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: const ValueKey('school-tools-floating'),
                child: toolsPanel,
              ),
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLarge),
        boxShadow: [kShadowCard],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: context.artC.ink.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索院校名称',
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

class _SchoolToolsPanel extends StatelessWidget {
  final Widget searchBar;
  final Widget countryTabs;
  final Widget filterPanel;
  final bool filtersExpanded;
  final bool hasFilters;
  final VoidCallback onToggleFilters;
  final VoidCallback onClose;

  const _SchoolToolsPanel({
    required this.searchBar,
    required this.countryTabs,
    required this.filterPanel,
    required this.filtersExpanded,
    required this.hasFilters,
    required this.onToggleFilters,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: countryTabs),
              const SizedBox(width: 10),
              _ToolPillButton(
                icon: Icons.tune,
                label: '筛选',
                active: filtersExpanded || hasFilters,
                onTap: onToggleFilters,
              ),
              const SizedBox(width: 8),
              _ToolIconButton(
                icon: Icons.close,
                onTap: onClose,
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: filtersExpanded
                ? Padding(
                    key: const ValueKey('filter-panel-open'),
                    padding: const EdgeInsets.only(top: 14),
                    child: filterPanel,
                  )
                : const SizedBox.shrink(key: ValueKey('filter-panel-closed')),
          ),
        ],
      ),
    );
  }
}

class _ToolPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolPillButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                active ? kCobalt : context.artC.silver.withValues(alpha: 0.65),
          ),
          boxShadow: active ? [kShadowCard] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active
                  ? Colors.white
                  : context.artC.ink.withValues(alpha: 0.58),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : context.artC.ink.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.65)),
        ),
        child: Icon(icon,
            size: 18, color: context.artC.ink.withValues(alpha: 0.42)),
      ),
    );
  }
}

class _CountryTabs extends StatelessWidget {
  final String? selectedCountry;
  final ValueChanged<String?> onSelected;

  const _CountryTabs({
    required this.selectedCountry,
    required this.onSelected,
  });

  static const countries = <String>[
    '中西部旗舰',
    '意大利',
    '英国',
    '其他南美国家',
    '墨西哥',
    '德国',
    '韩国',
    '南方与西南',
    '中国',
    '美国',
    '新加坡',
    '埃及',
    '新西兰',
    '加州旗舰',
    '东北强校',
    '尼日利亚',
    '南非',
    '刚果（金）',
    '加拿大',
    '其他非洲国家',
    '其他欧洲国家',
    '日本',
    '法国',
    '澳大利亚',
    '北欧',
    '荷兰',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: countries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final country = index == 0 ? null : countries[index - 1];
          final selected = selectedCountry == country;
          return ChoiceChip(
            selected: selected,
            label: Text(country ?? '全部国家'),
            onSelected: (_) => onSelected(country),
            selectedColor: kCobalt,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : context.artC.ink.withValues(alpha: 0.55),
            ),
            side: BorderSide(
              color: selected
                  ? kCobalt
                  : context.artC.silver.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String? selectedRegionTag;
  final String? selectedSchoolType;
  final String? selectedAdvantageSubject;
  final ValueChanged<String?> onRegionTagChanged;
  final ValueChanged<String?> onSchoolTypeChanged;
  final ValueChanged<String?> onAdvantageSubjectChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.selectedRegionTag,
    required this.selectedSchoolType,
    required this.selectedAdvantageSubject,
    required this.onRegionTagChanged,
    required this.onSchoolTypeChanged,
    required this.onAdvantageSubjectChanged,
    required this.onClear,
  });

  static const regionTags = <_FilterOption>[
    _FilterOption('us_midwest_flagship', '中西部旗舰'),
    _FilterOption('us_california_flagship', '加州旗舰'),
    _FilterOption('us_northeast_top', '东北强校'),
    _FilterOption('us_south_southwest', '南方与西南'),
    _FilterOption('nordics', '北欧'),
    _FilterOption('other_europe', '其他欧洲国家'),
    _FilterOption('other_africa', '其他非洲国家'),
    _FilterOption('other_south_america', '其他南美国家'),
  ];

  static const schoolTypes = <_FilterOption>[
    _FilterOption('art_academy', '艺术学院'),
    _FilterOption('design_school', '设计学院'),
    _FilterOption('university_art_dept', '大学艺术院系'),
    _FilterOption('architecture_school', '建筑学院'),
    _FilterOption('film_school', '电影学院'),
    _FilterOption('performing_arts', '表演艺术'),
    _FilterOption('multi_disciplinary', '综合类'),
  ];

  static const advantageSubjects = <String>[
    'Fine Art',
    'Design',
    'Visual Arts',
    'Architecture',
    'Animation',
    'Photography',
    'Illustration',
    'Film',
    'Fashion Design',
    'Graphic Design',
    'Art History',
    'Sculpture',
    'Painting',
  ];

  @override
  Widget build(BuildContext context) {
    final hasFilters = selectedRegionTag != null ||
        selectedSchoolType != null ||
        selectedAdvantageSubject != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLarge),
        boxShadow: [kShadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune, color: kCobalt, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '院校筛选',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'REGION TAG / TYPE / STRENGTHS',
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.28),
                        fontSize: 9,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: hasFilters ? onClear : null,
                icon: const Icon(Icons.close, size: 14),
                label: const Text('清除筛选'),
                style: TextButton.styleFrom(
                  foregroundColor: context.artC.ink.withValues(alpha: 0.45),
                  disabledForegroundColor:
                      context.artC.ink.withValues(alpha: 0.18),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FilterDropdown(
            label: '区域标签',
            value: selectedRegionTag,
            hint: '全部区域标签',
            items: regionTags
                .map((item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ))
                .toList(),
            onChanged: onRegionTagChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: '院校类型',
            value: selectedSchoolType,
            hint: '全部院校类型',
            items: schoolTypes
                .map((item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ))
                .toList(),
            onChanged: onSchoolTypeChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown(
            label: '优势学科',
            value: selectedAdvantageSubject,
            hint: '全部优势学科',
            items: advantageSubjects
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: onAdvantageSubjectChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.38),
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.artC.porcelain.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: context.artC.silver.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: context.artC.silver.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kCobalt),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.artC.ink,
          ),
        ),
      ],
    );
  }
}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption(this.value, this.label);
}

class _SchoolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const _SchoolCard({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final nameZh = data['name_zh'] as String? ?? '—';
    final nameEn = data['name_en'] as String?;
    final country = data['country'] as String?;
    final city = data['city'] as String?;
    final schoolType = data['school_type'] as String?;
    final qsRank = data['qs_art_rank'] as int?;
    final logoUrl = data['logo_url'] as String?;

    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.artC.porcelain.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _SchoolCardLogoFallback(nameZh),
                        ),
                      )
                    : Center(
                        child: Text(
                          nameZh.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: kCobalt,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameZh,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nameEn != null && nameEn.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      nameEn,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.artC.ink.withValues(alpha: 0.34),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (country != null) _MetaChip(country),
                      if (city != null) _MetaChip(city),
                      if (schoolType != null && schoolType.isNotEmpty)
                        _MetaChip(schoolType),
                      if (qsRank != null)
                        _MetaChip('QS #$qsRank', highlighted: true),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.artC.ink.withValues(alpha: 0.16),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolCardLogoFallback extends StatelessWidget {
  final String name;

  const _SchoolCardLogoFallback(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.substring(0, 1),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: kCobalt,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _MetaChip(this.text, {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEAF1FF) : const Color(0xFFF4F5F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color:
              highlighted ? kCobalt : context.artC.ink.withValues(alpha: 0.48),
        ),
      ),
    );
  }
}
