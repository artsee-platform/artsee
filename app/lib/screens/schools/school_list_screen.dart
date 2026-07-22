import 'package:flutter/material.dart';
import '../../data/school_display_aliases.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../consultation/organization_list_screen.dart';
import 'school_detail_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 院校列表 — 分页查询
class SchoolListScreen extends StatefulWidget {
  final VoidCallback? onOpenCompare;
  final VoidCallback? onOpenCompareTab;

  const SchoolListScreen({
    super.key,
    this.onOpenCompare,
    @Deprecated('Use onOpenCompare instead') this.onOpenCompareTab,
  });

  VoidCallback? get resolvedOpenCompare => onOpenCompare ?? onOpenCompareTab;

  @override
  State<SchoolListScreen> createState() => SchoolListScreenState();
}

enum _SchoolSortKey {
  recommended,
  qs,
  heat,
  difficultyLow,
  value,
  updated,
}

class SchoolListScreenState extends State<SchoolListScreen>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _items = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRegionTag;
  String? _selectedCountry;
  String? _selectedSchoolType;
  String? _selectedAdvantageSubject;
  _SchoolSortKey _sortKey = _SchoolSortKey.recommended;
  int? _maxRank;
  bool _searchPanelExpanded = false;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _loadGeneration = 0;
  final int _limit = 20;
  final Set<String> _savedSchoolIds = {};
  final Set<String> _savingSchoolIds = {};

  @override
  void initState() {
    super.initState();
    _loadMore();
    _loadSavedSchools();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void toggleFilterPanel({bool? expand}) {
    final shouldExpand = expand ?? !_searchPanelExpanded;
    setState(() => _searchPanelExpanded = shouldExpand);
  }

  Future<void> openDecisionFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SchoolDecisionFilterSheet(
        sortKey: _sortKey,
        maxRank: _maxRank,
        selectedCountry: _selectedCountry,
        selectedRegionTag: _selectedRegionTag,
        selectedSchoolType: _selectedSchoolType,
        selectedAdvantageSubject: _selectedAdvantageSubject,
        onSortChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setSortKey(value);
        },
        onRankChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setRankRange(value);
        },
        onCountryChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setCountry(value);
        },
        onRegionTagChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setRegionTag(value);
        },
        onSchoolTypeChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setSchoolType(value);
        },
        onAdvantageSubjectChanged: (value) {
          Navigator.of(sheetContext).pop();
          _setAdvantageSubject(value);
        },
        onClear: () {
          Navigator.of(sheetContext).pop();
          _clearFilters();
        },
      ),
    );
  }

  /// 外部调用：设置搜索关键词并刷新
  void setSearchKeyword(String keyword) {
    _searchController.text = keyword;
    _refresh();
  }

  /// 获取当前搜索关键词
  String get searchKeyword => _searchController.text;

  Future<void> _loadMore({int? generation}) async {
    if (_loading || !_hasMore) return;
    final requestGeneration = generation ?? _loadGeneration;
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
        maxRank: _maxRank,
      );
      final newItems = _sortSchools(result.data);
      final total = result.count;
      if (!mounted || requestGeneration != _loadGeneration) return;
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
      if (mounted && requestGeneration == _loadGeneration) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    _loadGeneration += 1;
    final generation = _loadGeneration;
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadMore(generation: generation);
    _loadSavedSchools();
  }

  Future<void> _loadSavedSchools() async {
    try {
      final saved = await BackendApiService.fetchSavedSchools(limit: 100);
      if (!mounted) return;
      setState(() {
        _savedSchoolIds
          ..clear()
          ..addAll(
            saved.data
                .map((item) => (item['id'] ?? item['school_id'])?.toString())
                .whereType<String>(),
          );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedSchoolIds.clear());
    }
  }

  String? _schoolActionId(Map<String, dynamic> school) {
    final remoteId = school['remote_school_id']?.toString();
    if (remoteId != null && remoteId.isNotEmpty) return remoteId;

    final id = school['id']?.toString();
    if (id == null || id.isEmpty) return null;
    if (school['is_auxiliary_display'] == true) return null;
    return id;
  }

  Future<void> _toggleSavedSchool(Map<String, dynamic> school) async {
    final id = _schoolActionId(school);
    if (id == null || id.isEmpty || _savingSchoolIds.contains(id)) return;
    if (!SupabaseService.isLoggedIn) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      if (!mounted || !SupabaseService.isLoggedIn) return;
    }
    final wasSaved = _savedSchoolIds.contains(id);
    setState(() => _savingSchoolIds.add(id));
    try {
      if (wasSaved) {
        await BackendApiService.removeSavedSchool(id);
      } else {
        await BackendApiService.saveSchool(id);
      }
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedSchoolIds.remove(id);
        } else {
          _savedSchoolIds.add(id);
        }
      });
      final onOpenCompare = widget.resolvedOpenCompare;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasSaved ? '已移出目标院校池' : '已加入目标院校池，可去对比'),
          action: !wasSaved && onOpenCompare != null
              ? SnackBarAction(
                  label: '去对比',
                  onPressed: onOpenCompare,
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _savingSchoolIds.remove(id));
    }
  }

  void _setRegionTag(String? value) {
    setState(() => _selectedRegionTag = value);
    _refresh();
  }

  void _setCountry(String? value) {
    setState(() => _selectedCountry = value);
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

  void _setSortKey(_SchoolSortKey value) {
    setState(() => _sortKey = value);
    _refresh();
  }

  void _setRankRange(int? value) {
    setState(() => _maxRank = value);
    _refresh();
  }

  void _clearFilters() {
    setState(() {
      _selectedRegionTag = null;
      _selectedCountry = null;
      _selectedSchoolType = null;
      _selectedAdvantageSubject = null;
      _sortKey = _SchoolSortKey.recommended;
      _maxRank = null;
    });
    _refresh();
  }

  List<Map<String, dynamic>> _sortSchools(List<Map<String, dynamic>> rows) {
    final sorted = [...rows];
    final keyword = _searchController.text.trim();
    int rankOf(Map<String, dynamic> item) =>
        (item['qs_art_rank'] as int?) ?? 99999;
    int disciplineCount(Map<String, dynamic> item) =>
        _stringList(item['strength_disciplines']).length;
    int tagCount(Map<String, dynamic> item) =>
        _stringList(item['feature_tags']).length;
    int heatScore(Map<String, dynamic> item) =>
        ((item['saved_count'] as num?)?.toInt() ?? 0) * 3 +
        ((item['consultation_count'] as num?)?.toInt() ?? 0) * 4 +
        disciplineCount(item) +
        tagCount(item);
    int valueScore(Map<String, dynamic> item) =>
        (rankOf(item) == 99999 ? 0 : (120 - rankOf(item)).clamp(0, 120)) +
        disciplineCount(item) * 8 +
        tagCount(item) * 4;
    int searchPriority(Map<String, dynamic> item) {
      if (keyword.isEmpty) return 0;
      if (_rowHasExactAliasMatch(item, keyword)) return 0;
      if (_rowHasNamePrefixMatch(item, keyword)) return 10;
      if (_rowHasAliasFamilyMatch(item, keyword)) return 20;
      return 50;
    }

    int compareSearchPriority(Map<String, dynamic> a, Map<String, dynamic> b) {
      return searchPriority(a).compareTo(searchPriority(b));
    }

    switch (_sortKey) {
      case _SchoolSortKey.qs:
        sorted.sort((a, b) {
          final searchCompare = compareSearchPriority(a, b);
          if (searchCompare != 0) return searchCompare;
          return rankOf(a).compareTo(rankOf(b));
        });
      case _SchoolSortKey.heat:
        sorted.sort((a, b) {
          final searchCompare = compareSearchPriority(a, b);
          if (searchCompare != 0) return searchCompare;
          return heatScore(b).compareTo(heatScore(a));
        });
      case _SchoolSortKey.difficultyLow:
        sorted.sort((a, b) {
          final searchCompare = compareSearchPriority(a, b);
          if (searchCompare != 0) return searchCompare;
          return rankOf(b).compareTo(rankOf(a));
        });
      case _SchoolSortKey.value:
        sorted.sort((a, b) {
          final searchCompare = compareSearchPriority(a, b);
          if (searchCompare != 0) return searchCompare;
          return valueScore(b).compareTo(valueScore(a));
        });
      case _SchoolSortKey.updated:
        sorted.sort(
          (a, b) {
            final searchCompare = compareSearchPriority(a, b);
            if (searchCompare != 0) return searchCompare;
            return (b['updated_at']?.toString() ?? '')
                .compareTo(a['updated_at']?.toString() ?? '');
          },
        );
      case _SchoolSortKey.recommended:
        sorted.sort((a, b) {
          final searchCompare = compareSearchPriority(a, b);
          if (searchCompare != 0) return searchCompare;
          final rankCompare = rankOf(a).compareTo(rankOf(b));
          if (rankCompare != 0) return rankCompare;
          return heatScore(b).compareTo(heatScore(a));
        });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: RefreshIndicator(
        color: kCobalt,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 164),
          children: [
            _SchoolSortBar(
              sortKey: _sortKey,
              maxRank: _maxRank,
              count: _items.length,
              hasMore: _hasMore,
              onOpen: openDecisionFilterSheet,
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _searchPanelExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 12),
                      child: _FilterPanel(
                        selectedCountry: _selectedCountry,
                        selectedRegionTag: _selectedRegionTag,
                        selectedSchoolType: _selectedSchoolType,
                        selectedAdvantageSubject: _selectedAdvantageSubject,
                        onCountryChanged: _setCountry,
                        onRegionTagChanged: _setRegionTag,
                        onSchoolTypeChanged: _setSchoolType,
                        onAdvantageSubjectChanged: _setAdvantageSubject,
                        onClear: _clearFilters,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _ConsultationEntryCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OrganizationListScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
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
                      style: ElevatedButton.styleFrom(backgroundColor: kCobalt),
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
                Builder(builder: (context) {
                  final school = _items[index];
                  final actionId = _schoolActionId(school);
                  return _SchoolCard(
                    data: school,
                    isSaved:
                        actionId != null && _savedSchoolIds.contains(actionId),
                    isSaving:
                        actionId != null && _savingSchoolIds.contains(actionId),
                    onSaveTap: actionId == null
                        ? null
                        : () => _toggleSavedSchool(school),
                    onTap: () {
                      final id = school['id']?.toString();
                      if (id != null && id.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SchoolDetailScreen(
                              id: id,
                              onOpenCompare: widget.resolvedOpenCompare,
                            ),
                          ),
                        );
                      }
                    },
                  );
                }),
                const SizedBox(height: 28),
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
    );
  }
}

class _ConsultationEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ConsultationEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '咨询官方组织',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.62),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.artC.ink.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolSortBar extends StatelessWidget {
  final _SchoolSortKey sortKey;
  final int? maxRank;
  final int count;
  final bool hasMore;
  final VoidCallback onOpen;

  const _SchoolSortBar({
    required this.sortKey,
    required this.maxRank,
    required this.count,
    required this.hasMore,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Row(
                children: [
                  Text(
                    '${_sortLabel(sortKey)} ▼',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      [
                        '共 $count${hasMore ? '+' : ''} 所院校',
                        if (maxRank != null) _rankRangeLabel(maxRank),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.artC.ink.withValues(alpha: 0.36),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onOpen,
            icon: const Icon(Icons.tune_rounded, size: 18),
            color: context.artC.ink.withValues(alpha: 0.66),
            tooltip: '筛选与排序',
          ),
        ],
      ),
    );
  }
}

class _SchoolDecisionFilterSheet extends StatelessWidget {
  final _SchoolSortKey sortKey;
  final int? maxRank;
  final String? selectedCountry;
  final String? selectedRegionTag;
  final String? selectedSchoolType;
  final String? selectedAdvantageSubject;
  final ValueChanged<_SchoolSortKey> onSortChanged;
  final ValueChanged<int?> onRankChanged;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onRegionTagChanged;
  final ValueChanged<String?> onSchoolTypeChanged;
  final ValueChanged<String?> onAdvantageSubjectChanged;
  final VoidCallback onClear;

  const _SchoolDecisionFilterSheet({
    required this.sortKey,
    required this.maxRank,
    required this.selectedCountry,
    required this.selectedRegionTag,
    required this.selectedSchoolType,
    required this.selectedAdvantageSubject,
    required this.onSortChanged,
    required this.onRankChanged,
    required this.onCountryChanged,
    required this.onRegionTagChanged,
    required this.onSchoolTypeChanged,
    required this.onAdvantageSubjectChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final sortOptions = <({String label, _SchoolSortKey value})>[
      (label: '默认排序', value: _SchoolSortKey.recommended),
      (label: 'QS 艺术排名优先', value: _SchoolSortKey.qs),
      (label: '平台热度优先', value: _SchoolSortKey.heat),
      (label: '申请难度从低到高', value: _SchoolSortKey.difficultyLow),
      (label: '性价比优先', value: _SchoolSortKey.value),
      (label: '最新更新', value: _SchoolSortKey.updated),
    ];
    final rankOptions = <({String label, int? value})>[
      (label: '不限', value: null),
      (label: 'Top 10', value: 10),
      (label: 'Top 30', value: 30),
      (label: 'Top 50', value: 50),
      (label: 'Top 100', value: 100),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: context.artC.porcelain,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.artC.silver.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '筛选与排序',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                        fontFamily: 'Noto Serif SC',
                      ),
                    ),
                  ),
                  TextButton(onPressed: onClear, child: const Text('重置')),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _SheetSection(
                      title: '排序方式',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortOptions.map((item) {
                          return _SheetChoiceChip(
                            label: item.label,
                            selected: sortKey == item.value,
                            onTap: () => onSortChanged(item.value),
                          );
                        }).toList(),
                      ),
                    ),
                    _SheetSection(
                      title: 'QS 艺术排名',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rankOptions.map((item) {
                          return _SheetChoiceChip(
                            label: item.label,
                            selected: maxRank == item.value,
                            onTap: () => onRankChanged(item.value),
                          );
                        }).toList(),
                      ),
                    ),
                    _SheetSection(
                      title: '平台热度',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const ['热门申请', '收藏多', '近期咨询多']
                            .map(
                              (item) => _SheetChoiceChip(
                                label: item,
                                selected: sortKey == _SchoolSortKey.heat,
                                onTap: () => onSortChanged(_SchoolSortKey.heat),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    _SheetSection(
                      title: '专业细分榜',
                      child: _InlineFilterChoices(
                        items: _FilterPanel.advantageSubjects,
                        selectedValue: selectedAdvantageSubject,
                        onChanged: onAdvantageSubjectChanged,
                      ),
                    ),
                    _SheetSection(
                      title: '国家 / 地区',
                      child: _InlineFilterChoices(
                        items: _FilterPanel.countryTags,
                        selectedValue: selectedCountry,
                        onChanged: onCountryChanged,
                      ),
                    ),
                    _SheetSection(
                      title: '院校类型',
                      child: _InlineFilterChoices(
                        items: _FilterPanel.schoolTypes,
                        selectedValue: selectedSchoolType,
                        onChanged: onSchoolTypeChanged,
                      ),
                    ),
                    _SheetSection(
                      title: '区域标签',
                      child: _InlineFilterChoices(
                        items: _FilterPanel.regionTags,
                        selectedValue: selectedRegionTag,
                        onChanged: onRegionTagChanged,
                      ),
                    ),
                    _SheetSection(
                      title: '申请难度',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SheetChoiceChip(
                            label: '保底 / 难度低',
                            selected: sortKey == _SchoolSortKey.difficultyLow,
                            onTap: () =>
                                onSortChanged(_SchoolSortKey.difficultyLow),
                          ),
                          _SheetChoiceChip(
                            label: '匹配',
                            selected: sortKey == _SchoolSortKey.recommended,
                            onTap: () =>
                                onSortChanged(_SchoolSortKey.recommended),
                          ),
                          _SheetChoiceChip(
                            label: '冲刺',
                            selected: maxRank == 30,
                            onTap: () => onRankChanged(30),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '预算和语言要求将在接入真实学费、生活费、语言门槛字段后开放精确筛选。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.34),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: context.artC.ink.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _InlineFilterChoices extends StatelessWidget {
  final List<_FilterOption> items;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _InlineFilterChoices({
    required this.items,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SheetChoiceChip(
          label: '不限',
          selected: selectedValue == null,
          onTap: () => onChanged(null),
        ),
        ...items.map(
          (item) => _SheetChoiceChip(
            label: item.label,
            selected: selectedValue == item.value,
            onTap: () => onChanged(item.value),
          ),
        ),
      ],
    );
  }
}

class _SheetChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? kCobalt.withValues(alpha: 0.08)
              : context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? kCobalt.withValues(alpha: 0.28)
                : context.artC.silver.withValues(alpha: 0.36),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color:
                selected ? kCobalt : context.artC.ink.withValues(alpha: 0.68),
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String? selectedCountry;
  final String? selectedRegionTag;
  final String? selectedSchoolType;
  final String? selectedAdvantageSubject;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onRegionTagChanged;
  final ValueChanged<String?> onSchoolTypeChanged;
  final ValueChanged<String?> onAdvantageSubjectChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.selectedCountry,
    required this.selectedRegionTag,
    required this.selectedSchoolType,
    required this.selectedAdvantageSubject,
    required this.onCountryChanged,
    required this.onRegionTagChanged,
    required this.onSchoolTypeChanged,
    required this.onAdvantageSubjectChanged,
    required this.onClear,
  });

  static const countryTags = <_FilterOption>[
    _FilterOption('英国', '英国'),
    _FilterOption('美国', '美国'),
  ];

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

  static const advantageSubjects = <_FilterOption>[
    _FilterOption('纯艺', '纯艺强'),
    _FilterOption('交互设计', '交互设计'),
    _FilterOption('插画', '插画'),
    _FilterOption('工业设计', '工业设计'),
    _FilterOption('建筑', '建筑'),
    _FilterOption('时尚', '时尚'),
  ];

  @override
  Widget build(BuildContext context) {
    final hasFilters = selectedRegionTag != null ||
        selectedCountry != null ||
        selectedSchoolType != null ||
        selectedAdvantageSubject != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: kCobalt,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '清除',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (hasFilters) const SizedBox(height: 8),
          _FilterSection(
            label: '快捷筛选',
            items: countryTags,
            selectedValue: selectedCountry,
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: 10),
          _FilterSection(
            label: '院校类型',
            items: schoolTypes,
            selectedValue: selectedSchoolType,
            onChanged: onSchoolTypeChanged,
          ),
          const SizedBox(height: 10),
          _FilterSection(
            label: '优势方向',
            items: advantageSubjects,
            selectedValue: selectedAdvantageSubject,
            onChanged: onAdvantageSubjectChanged,
          ),
          const SizedBox(height: 10),
          _FilterSection(
            label: '区域标签',
            items: regionTags,
            selectedValue: selectedRegionTag,
            onChanged: onRegionTagChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final List<_FilterOption> items;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _FilterSection({
    required this.label,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: '全部',
                value: null,
                isSelected: selectedValue == null,
              ),
              const SizedBox(width: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      context,
                      label: item.label,
                      value: item.value,
                      isSelected: selectedValue == item.value,
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required String? value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? kCobalt.withValues(alpha: 0.08)
              : context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? kCobalt.withValues(alpha: 0.28)
                : context.artC.silver.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color:
                isSelected ? kCobalt : context.artC.ink.withValues(alpha: 0.7),
          ),
        ),
      ),
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
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool isSaving;

  const _SchoolCard({
    required this.data,
    this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameZh = data['name_zh'] as String? ?? '—';
    final nameEn = data['name_en'] as String?;
    final country = data['country'] as String?;
    final city = data['city'] as String?;
    final schoolType = data['school_type'] as String?;
    final qsRank = data['qs_art_rank'] as int?;
    final logoUrl = data['logo_url'] as String?;
    final disciplines = _stringList(data['strength_disciplines']);
    final featureTags = _stringList(data['feature_tags']);
    final schoolTypeLabel = _schoolTypeLabel(schoolType);
    final fitText = _fitSummary(
      schoolType: schoolType,
      disciplines: disciplines,
      city: city,
    );
    final locationLine = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
      schoolTypeLabel,
      if (qsRank != null) 'QS 艺术 #$qsRank',
    ].join(' · ');
    final directionLine = [
      if (disciplines.isNotEmpty)
        ...disciplines.take(3).map((item) => _displayLabel(item)),
      if (disciplines.isEmpty && featureTags.isNotEmpty)
        ...featureTags.take(2).map((item) => _displayLabel(item)),
    ].where((item) => item.trim().isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: context.artC.ink.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _SchoolCardLogoFallback(nameZh),
                          )
                        : Center(
                            child: Text(
                              nameZh.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: kCobalt,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameZh,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: context.artC.ink,
                          letterSpacing: 0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nameEn != null && nameEn.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          nameEn,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: context.artC.ink.withValues(alpha: 0.38),
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        locationLine,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                          color: context.artC.ink.withValues(alpha: 0.44),
                          letterSpacing: 0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (directionLine.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          directionLine,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.32,
                            fontWeight: FontWeight.w600,
                            color: context.artC.ink.withValues(alpha: 0.30),
                            letterSpacing: 0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onSaveTap != null)
                  GestureDetector(
                    onTap: onSaveTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      child: isSaving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                color: kCobalt,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              children: [
                                Icon(
                                  isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_add_outlined,
                                  size: 17,
                                  color: isSaved
                                      ? kCobalt
                                      : context.artC.ink
                                          .withValues(alpha: 0.32),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 1,
                    color: context.artC.ink.withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fitText.replaceFirst('适合：', ''),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.42,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: context.artC.ink.withValues(alpha: 0.48),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
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
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String _schoolTypeLabel(String? value) {
  return switch (value) {
    'art_academy' => '专业艺术学院',
    'art_college' => '艺术学院',
    'design_school' => '设计学院',
    'university_art_dept' => '大学艺术院系',
    'comprehensive_university' => '综合大学艺术方向',
    'architecture_school' => '建筑学院',
    'film_school' => '电影学院',
    'performing_arts' => '表演艺术院校',
    'multi_disciplinary' => '综合艺术设计院校',
    'private_art_school' => '私立艺术院校',
    'public_university' => '公立大学艺术方向',
    null || '' => '艺术与设计院校',
    _ => _displayLabel(value),
  };
}

String _displayLabel(String value) {
  final normalized = value.trim();
  final key =
      normalized.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  return switch (key) {
    'fine_art' || 'fine_arts' => '纯艺',
    'painting' => '绘画',
    'sculpture' => '雕塑',
    'design' => '设计',
    'graphic_design' || 'communication_design' => '平面设计',
    'visual_communication' || 'visual_communications' => '视觉传达',
    'interaction_design' || 'interactive_design' => '交互设计',
    'service_design' => '服务设计',
    'industrial_design' || 'product_design' => '工业设计',
    'architecture' || 'architectural_design' => '建筑',
    'interior_design' => '室内设计',
    'fashion' || 'fashion_design' => '时尚',
    'illustration' => '插画',
    'animation' => '动画',
    'film' || 'film_video' => '电影影像',
    'photography' => '摄影',
    'curating' || 'curatorial_studies' => '策展',
    'art_history' => '艺术史',
    'multi_disciplinary' => '跨学科',
    'portfolio_friendly' => '作品集友好',
    _ => normalized.contains('_')
        ? normalized
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ')
        : normalized,
  };
}

String _fitSummary({
  required String? schoolType,
  required List<String> disciplines,
  required String? city,
}) {
  final direction = disciplines.isNotEmpty
      ? disciplines.take(2).map(_displayLabel).join(' / ')
      : '艺术与设计';
  if (schoolType == 'design_school') {
    return '适合：希望围绕 $direction 做作品集和专业匹配的设计方向申请者。';
  }
  if (schoolType == 'art_academy') {
    return '适合：重视作品表达、创作脉络和 studio 训练的艺术申请者。';
  }
  if (schoolType == 'university_art_dept') {
    return '适合：想兼顾综合大学资源和 $direction 方向深造的申请者。';
  }
  if (city != null && city.isNotEmpty) {
    return '适合：希望利用 $city 城市艺术资源，并继续比较预算和作品集难度的申请者。';
  }
  return '适合：正在建立目标院校池，需要继续比较排名、方向、预算和申请难度的申请者。';
}

String _sortLabel(_SchoolSortKey key) {
  return switch (key) {
    _SchoolSortKey.recommended => '综合推荐',
    _SchoolSortKey.qs => 'QS 排名',
    _SchoolSortKey.heat => '平台热度',
    _SchoolSortKey.difficultyLow => '难度低',
    _SchoolSortKey.value => '性价比',
    _SchoolSortKey.updated => '最新更新',
  };
}

String _rankRangeLabel(int? maxRank) {
  if (maxRank == null) return '不限排名';
  return 'QS Top $maxRank';
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,，、\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

bool _rowHasExactAliasMatch(Map<String, dynamic> row, String query) {
  final exactValues = [
    row['name_zh'],
    row['name_en'],
    row['slug'],
    ..._stringList(row['aliases']),
  ].whereType<String>();
  return exactValues.any((value) {
    final normalizedValue = normalizeSchoolAliasText(value);
    final normalizedQuery = normalizeSchoolAliasText(query);
    return normalizedValue == normalizedQuery ||
        schoolAliasMatches(query, value);
  });
}

bool _rowHasNamePrefixMatch(Map<String, dynamic> row, String query) {
  final normalizedQuery = normalizeSchoolAliasText(query);
  if (normalizedQuery.isEmpty) return false;
  return [
    row['name_zh'],
    row['name_en'],
  ].whereType<String>().any(
        (value) => normalizeSchoolAliasText(value).startsWith(normalizedQuery),
      );
}

bool _rowHasAliasFamilyMatch(Map<String, dynamic> row, String query) {
  final matchedAliases = kSchoolDisplayAliases.where(
    (alias) => alias.aliases.any((value) => schoolAliasMatches(query, value)),
  );
  return matchedAliases.any((alias) => _rowMatchesDisplayAlias(row, alias));
}

bool _rowMatchesDisplayAlias(
  Map<String, dynamic> row,
  SchoolDisplayAlias alias,
) {
  if (row['slug'] == alias.slug) return true;
  final text = [
    row['name_zh'],
    row['name_en'],
    row['description'],
    row['slug'],
    ..._stringList(row['aliases']),
  ].whereType<String>().join(' ');
  if (text.contains(alias.nameZh) || text.contains(alias.nameEn)) return true;
  return alias.aliases.any((value) => schoolAliasMatches(text, value));
}
