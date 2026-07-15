import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class DiscoverSearchScreen extends StatefulWidget {
  final String initialKeyword;
  final int initialTabIndex;

  const DiscoverSearchScreen({
    super.key,
    this.initialKeyword = '',
    this.initialTabIndex = 0,
  });

  @override
  State<DiscoverSearchScreen> createState() => _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends State<DiscoverSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<_DiscoverSearchItem> _opportunities = const [];
  List<_DiscoverSearchItem> _artists = const [];
  List<_DiscoverSearchItem> _events = const [];
  List<_DiscoverSearchItem> _circles = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  static const _quickKeywords = [
    '展览',
    '沙龙',
    '圈子',
    '驻留',
    '伦敦',
    '策展',
    '插画',
    '作品投稿',
    '品牌委托',
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
      final opportunitiesFuture = BackendApiService.fetchOpportunities(
        limit: 12,
        keyword: keyword,
      );
      final artistsFuture = BackendApiService.fetchArtists(
        limit: 12,
        keyword: keyword,
      );
      final eventsFuture = BackendApiService.fetchEvents(limit: 20);
      final salonsFuture = BackendApiService.fetchEvents(
        limit: 20,
        type: 'salon',
      );
      final circlesFuture = BackendApiService.fetchCommunityCircles(
        limit: 12,
        keyword: keyword,
      );

      final opportunitiesResult = await opportunitiesFuture;
      final artistsResult = await artistsFuture;
      final eventsResult = await eventsFuture;
      final salonsResult = await salonsFuture;
      final circlesResult = await circlesFuture;
      if (!mounted) return;

      final mergedEvents = _mergeEventLists([
        eventsResult.data,
        salonsResult.data,
      ]);
      setState(() {
        _opportunities = opportunitiesResult.data
            .where((item) => _matchesKeyword(item, keyword))
            .map(_opportunityItem)
            .toList();
        _artists = artistsResult.data
            .where((item) => _matchesKeyword(item, keyword))
            .map(_artistItem)
            .toList();
        _events = mergedEvents
            .where((item) => _matchesKeyword(item, keyword))
            .map(_eventItem)
            .toList();
        _circles = circlesResult.data
            .where((item) => _matchesKeyword(item, keyword))
            .map(_circleItem)
            .toList();
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
    Navigator.of(context).pop(_controller.text.trim());
  }

  void _clearKeyword() {
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: Column(
          children: [
            _DiscoverSearchHeader(
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
            '搜索合作、活动、艺术家、圈子',
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '可以搜机会、展览、沙龙、圈子、城市、艺术方向或合作类型。',
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _quickKeywords
                .map(
                  (keyword) => _DiscoverQuickChip(
                    label: keyword,
                    onTap: () {
                      _controller.text = keyword;
                      _runSearch(keyword);
                    },
                  ),
                )
                .toList(),
          ),
          if (widget.initialKeyword.trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _clearKeyword,
              child: const Text('清空发现页筛选'),
            ),
          ],
        ],
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return _DiscoverSearchStateView(
        icon: Icons.cloud_off_outlined,
        title: '搜索失败',
        body: _error!,
        actionLabel: '重试',
        onAction: _runSearch,
      );
    }

    final totalCount = _opportunities.length +
        _artists.length +
        _events.length +
        _circles.length;
    if (totalCount == 0) {
      return _DiscoverSearchStateView(
        icon: Icons.search_off_rounded,
        title: '没有找到相关内容',
        body: '换一个城市、合作类型、活动类型或艺术方向试试。',
        actionLabel: '重新搜索',
        onAction: () => _focusNode.requestFocus(),
      );
    }

    final sections = switch (widget.initialTabIndex) {
      1 => [
          _DiscoverSearchSectionData('活动', _events),
          _DiscoverSearchSectionData('机会', _opportunities),
          _DiscoverSearchSectionData('艺术家', _artists),
          _DiscoverSearchSectionData('圈子', _circles),
        ],
      2 => [
          _DiscoverSearchSectionData('圈子', _circles),
          _DiscoverSearchSectionData('机会', _opportunities),
          _DiscoverSearchSectionData('艺术家', _artists),
          _DiscoverSearchSectionData('活动', _events),
        ],
      _ => [
          _DiscoverSearchSectionData('机会', _opportunities),
          _DiscoverSearchSectionData('艺术家', _artists),
          _DiscoverSearchSectionData('活动', _events),
          _DiscoverSearchSectionData('圈子', _circles),
        ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '找到 $totalCount 条发现内容',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.58),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearKeyword,
              style: TextButton.styleFrom(
                foregroundColor: context.artC.ink.withValues(alpha: 0.46),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                '清空',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: _applyKeyword,
              style: TextButton.styleFrom(
                foregroundColor: kCobalt,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                '应用到发现页',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final section in sections)
          if (section.items.isNotEmpty) ...[
            _DiscoverResultSection(title: section.title, items: section.items),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _DiscoverSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;

  const _DiscoverSearchHeader({
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
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmit,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: '搜索合作、活动、艺术家、圈子',
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

class _DiscoverResultSection extends StatelessWidget {
  final String title;
  final List<_DiscoverSearchItem> items;

  const _DiscoverResultSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · ${items.length}',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DiscoverResultCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _DiscoverResultCard extends StatelessWidget {
  final _DiscoverSearchItem item;

  const _DiscoverResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DiscoverTypeBadge(
                        label: item.typeLabel, color: item.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 15,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.meta.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.48),
                      fontSize: 11.5,
                      height: 1.42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DiscoverTypeBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DiscoverQuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DiscoverQuickChip({
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

class _DiscoverSearchStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _DiscoverSearchStateView({
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
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kCobalt, size: 36),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.48),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverSearchSectionData {
  final String title;
  final List<_DiscoverSearchItem> items;

  const _DiscoverSearchSectionData(this.title, this.items);
}

class _DiscoverSearchItem {
  final String typeLabel;
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final Color color;

  const _DiscoverSearchItem({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.color,
  });
}

_DiscoverSearchItem _opportunityItem(Map<String, dynamic> item) {
  final title = _stringValue(item['title']) ?? '未命名机会';
  final type = _opportunityTypeLabel(_stringValue(item['type']));
  final city = _stringValue(item['city']);
  final deadline = _formatDateValue(item['deadline']);
  final requirements = _stringValue(item['requirements']);
  final metadata = item['metadata'] is Map
      ? (item['metadata'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final organization = _stringValue(metadata['organization']);
  return _DiscoverSearchItem(
    typeLabel: '机会',
    title: title,
    subtitle: [
      type,
      if (city != null) city,
      if (deadline != null) '$deadline 截止',
    ].join(' · '),
    meta: [
      if (organization != null) organization,
      if (requirements != null) requirements,
    ].join(' · '),
    icon: Icons.business_center_outlined,
    color: kCobalt,
  );
}

_DiscoverSearchItem _artistItem(Map<String, dynamic> item) {
  final name = _stringValue(item['display_name']) ?? '未命名艺术家';
  final city = _stringValue(item['city']);
  final fields = _stringList(item['fields']);
  final intent = _stringValue(item['cooperation_intent']) ??
      _stringValue(item['bio']) ??
      '开放合作与作品交流';
  return _DiscoverSearchItem(
    typeLabel: '艺术家',
    title: name,
    subtitle: [
      if (fields.isNotEmpty) fields.join(' / '),
      if (city != null) city,
    ].join(' · ').trim().isEmpty
        ? '认证艺术家'
        : [
            if (fields.isNotEmpty) fields.join(' / '),
            if (city != null) city,
          ].join(' · '),
    meta: intent,
    icon: Icons.palette_outlined,
    color: const Color(0xFFE64565),
  );
}

_DiscoverSearchItem _eventItem(Map<String, dynamic> item) {
  final title = _stringValue(item['title']) ?? '未命名活动';
  final city = _stringValue(item['city']);
  final venue = _stringValue(item['venue']);
  final date = _formatDateValue(item['start_time']);
  final summary = _stringValue(item['summary']) ??
      _stringValue(item['description']) ??
      '展览、沙龙、讲座或工作坊活动';
  return _DiscoverSearchItem(
    typeLabel: _eventTypeLabel(item),
    title: title,
    subtitle: [
      if (date != null) date,
      if (city != null) city,
      if (venue != null) venue,
    ].join(' · '),
    meta: summary,
    icon: Icons.event_available_outlined,
    color: const Color(0xFF1F9D8A),
  );
}

_DiscoverSearchItem _circleItem(Map<String, dynamic> item) {
  final title = _stringValue(item['title']) ?? '未命名圈子';
  final category = _stringValue(item['category']) ?? '艺术圈子';
  final city = _stringValue(item['city']);
  final subtitle = _stringValue(item['subtitle']) ??
      _stringValue(item['hot_topic']) ??
      '圈内讨论、问答和经验交流';
  final memberCount = int.tryParse(item['member_count']?.toString() ?? '');
  return _DiscoverSearchItem(
    typeLabel: '圈子',
    title: title,
    subtitle: [
      category,
      if (city != null) city,
      if (memberCount != null) '$memberCount 人',
    ].join(' · '),
    meta: subtitle,
    icon: Icons.groups_outlined,
    color: const Color(0xFF8B5CF6),
  );
}

List<Map<String, dynamic>> _mergeEventLists(
  Iterable<List<Map<String, dynamic>>> groups,
) {
  final seen = <String>{};
  final merged = <Map<String, dynamic>>[];
  for (final item in groups.expand((items) => items)) {
    final id = item['id']?.toString();
    final key = id != null && id.isNotEmpty
        ? id
        : '${item['type'] ?? ''}|${item['title'] ?? ''}|${item['start_time'] ?? ''}';
    if (seen.add(key)) merged.add(item);
  }
  return merged;
}

bool _matchesKeyword(Map<String, dynamic> item, String keyword) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) return true;
  final text = item.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' ')
      .toLowerCase();
  return text.contains(query);
}

String _opportunityTypeLabel(String? raw) {
  return switch (raw) {
    'residency' => '驻留',
    'exhibition' => '展览征集',
    'commission' => '委托',
    'internship' => '实习',
    'open_call' => '公开征集',
    _ => '合作',
  };
}

String _eventTypeLabel(Map<String, dynamic> item) {
  final raw = item.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' ')
      .toLowerCase();
  if (raw.contains('salon') || raw.contains('沙龙')) return '沙龙';
  if (raw.contains('lecture') || raw.contains('talk') || raw.contains('讲座')) {
    return '讲座';
  }
  if (raw.contains('workshop') || raw.contains('工作坊')) return '工作坊';
  if (raw.contains('open day') ||
      raw.contains('open_day') ||
      raw.contains('开放日')) {
    return '开放日';
  }
  if (raw.contains('info session') ||
      raw.contains('briefing') ||
      raw.contains('application') ||
      raw.contains('说明会')) {
    return '说明会';
  }
  if (raw.contains('exhibition') ||
      raw.contains('展览') ||
      raw.contains('gallery')) {
    return '展览';
  }
  return '活动';
}

String? _formatDateValue(dynamic raw) {
  if (raw == null) return null;
  final date = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
  if (date == null) return null;
  return '${date.month}.${date.day}';
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return const [];
  return text
      .split(RegExp(r'[,，/、]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
