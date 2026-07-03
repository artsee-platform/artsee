import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';
import 'school_detail_screen.dart';

class SchoolSearchScreen extends StatefulWidget {
  final String initialKeyword;

  const SchoolSearchScreen({
    super.key,
    this.initialKeyword = '',
  });

  @override
  State<SchoolSearchScreen> createState() => _SchoolSearchScreenState();
}

class _SchoolSearchScreenState extends State<SchoolSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  static const _quickKeywords = [
    'RCA',
    '罗德岛',
    '伦敦',
    '交互设计',
    '作品集友好',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKeyword.trim();
    _controller.text = initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initial.isEmpty) {
        _focusNode.requestFocus();
      } else {
        _runSearch(initial);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? rawKeyword]) async {
    final keyword = (rawKeyword ?? _controller.text).trim();
    if (keyword.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchSchools(
        limit: 30,
        offset: 0,
        keyword: keyword,
      );
      if (!mounted) return;
      setState(() {
        _results = result.data;
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

  void _applyKeyword() {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    Navigator.of(context).pop(keyword);
  }

  void _openSchool(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SchoolDetailScreen(id: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _controller,
              focusNode: _focusNode,
              loading: _loading,
              onBack: () => Navigator.of(context).maybePop(),
              onSubmit: _runSearch,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_searched) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            '搜索院校、城市、国家或专业方向',
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _quickKeywords
                .map(
                  (keyword) => _QuickKeywordChip(
                    label: keyword,
                    onTap: () {
                      _controller.text = keyword;
                      _runSearch(keyword);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return _SearchStateView(
        icon: Icons.cloud_off_outlined,
        title: '搜索失败',
        body: _error!,
        actionLabel: '重试',
        onAction: _runSearch,
      );
    }

    if (_results.isEmpty) {
      return _SearchStateView(
        icon: Icons.search_off_rounded,
        title: '未找到相关院校',
        body: '换一个学校简称、城市或专业方向试试。',
        actionLabel: '重新搜索',
        onAction: () => _focusNode.requestFocus(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '找到 ${_results.length} 所院校',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.58),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _applyKeyword,
              style: TextButton.styleFrom(
                foregroundColor: kCobalt,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                '应用到院校页',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._results.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SchoolSearchResultCard(
              item: item,
              onTap: () => _openSchool(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 10),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        border: Border(
          bottom: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.34),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: context.artC.ink,
            tooltip: '返回',
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 13, right: 4),
              decoration: BoxDecoration(
                color: context.artC.silver.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmit,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: '搜索院校名称、城市或专业',
                        hintStyle: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.32),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) {
                        return const SizedBox(width: 2);
                      }
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          controller.clear();
                          focusNode.requestFocus();
                        },
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.close_rounded,
                            color: context.artC.ink.withValues(alpha: 0.42),
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: loading ? null : () => onSubmit(controller.text),
            style: TextButton.styleFrom(
              foregroundColor: kCobalt,
              disabledForegroundColor: kCobalt.withValues(alpha: 0.36),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              loading ? '搜索中' : '搜索',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickKeywordChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickKeywordChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: context.artC.silver.withValues(alpha: 0.34),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolSearchResultCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _SchoolSearchResultCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nameZh = _stringValue(item['name_zh']) ?? '未命名院校';
    final nameEn = _stringValue(item['name_en']);
    final city = _stringValue(item['city']);
    final country = _stringValue(item['country']);
    final rank = item['qs_art_rank'] as int?;
    final schoolType = _schoolTypeLabel(_stringValue(item['school_type']));
    final initial = nameZh.isEmpty ? '?' : nameZh.substring(0, 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.artC.silver.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: context.artC.ink.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: kCobalt,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameZh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (nameEn != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      [
                        if (city != null) city,
                        if (country != null) country,
                        schoolType,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.48),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rank == null ? 'QS -' : 'QS #$rank',
                    style: const TextStyle(
                      color: kCobalt,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.artC.ink.withValues(alpha: 0.28),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _SearchStateView({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 42, color: context.artC.ink.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.48),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: kCobalt),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
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
    _ => value.replaceAll('_', ' '),
  };
}
