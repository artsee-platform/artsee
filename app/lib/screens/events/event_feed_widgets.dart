import 'package:flutter/material.dart';

import '../../theme/artsee_ui_colors.dart';
import '../../widgets/common.dart';

class ArtseeEventDayGroup {
  final DateTime? day;
  final List<Map<String, dynamic>> events;

  const ArtseeEventDayGroup({
    required this.day,
    required this.events,
  });
}

List<ArtseeEventDayGroup> groupArtseeEventsByDay(
  List<Map<String, dynamic>> events,
) {
  final sorted = [...events]..sort(compareArtseeEventsByStart);
  final groups = <String, ArtseeEventDayGroup>{};
  for (final event in sorted) {
    final start = artseeEventStartDate(event);
    final day =
        start == null ? null : DateTime(start.year, start.month, start.day);
    final key = day == null
        ? 'none'
        : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final current = groups[key];
    if (current == null) {
      groups[key] = ArtseeEventDayGroup(day: day, events: [event]);
    } else {
      current.events.add(event);
    }
  }
  return groups.values.toList();
}

Map<String, dynamic>? artseeEventFromApplication(
  Map<String, dynamic> application,
) {
  final raw = application['events'];
  final event = raw is Map<String, dynamic>
      ? raw
      : raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
  if (event == null || event.isEmpty) return null;
  return {
    ...event,
    'application_status': application['status'],
    'ticket_code': application['ticket_code'],
  };
}

DateTime? artseeEventStartDate(Map<String, dynamic> event) {
  final raw = event['start_time'] ??
      event['startTime'] ??
      event['event_start_at'] ??
      event['scheduled_at'] ??
      event['date'];
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw?.toString() ?? '');
}

int compareArtseeEventsByStart(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aStart = artseeEventStartDate(a);
  final bStart = artseeEventStartDate(b);
  if (aStart == null && bStart == null) {
    return (a['title']?.toString() ?? '').compareTo(
      b['title']?.toString() ?? '',
    );
  }
  if (aStart == null) return 1;
  if (bStart == null) return -1;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final aDay = DateTime(aStart.year, aStart.month, aStart.day);
  final bDay = DateTime(bStart.year, bStart.month, bStart.day);
  final aPast = aDay.isBefore(today);
  final bPast = bDay.isBefore(today);
  if (aPast != bPast) return aPast ? 1 : -1;
  if (aPast && bPast) return bStart.compareTo(aStart);
  return aStart.compareTo(bStart);
}

class ArtseeActivityPersonalSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback? onOpenAll;

  const ArtseeActivityPersonalSection({
    super.key,
    required this.events,
    required this.onOpen,
    this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible = [...events]..sort(compareArtseeEventsByStart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '你的活动',
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.artC.ink.withValues(alpha: 0.22),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: context.artC.cardIconBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.artC.ink.withValues(alpha: 0.035),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  color: context.artC.ink.withValues(alpha: 0.22),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '你暂时没有任何活动安排。浏览下方的活动，或点击 + 创建一个。',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.4),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: visible
                .take(2)
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PersonalEventRow(
                      event: event,
                      onTap: () => onOpen(event),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class ArtseeActivityRecommendationHeader extends StatelessWidget {
  final String filterLabel;
  final String selectedFilter;
  final List<String> filters;
  final ValueChanged<String> onSelected;

  const ArtseeActivityRecommendationHeader({
    super.key,
    required this.filterLabel,
    required this.selectedFilter,
    required this.filters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '为你推荐',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          initialValue: selectedFilter,
          onSelected: onSelected,
          color: context.artC.cardIconBg,
          surfaceTintColor: Colors.transparent,
          itemBuilder: (context) => filters
              .map(
                (filter) => PopupMenuItem<String>(
                  value: filter,
                  child: Text(filter == '全部' ? '附近' : filter),
                ),
              )
              .toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filterLabel,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.38),
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                color: context.artC.ink.withValues(alpha: 0.22),
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ArtseeActivitySponsoredSlot extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onOpen;

  const ArtseeActivitySponsoredSlot({
    super.key,
    required this.event,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(event['title']) ?? '精选艺术活动';
    final location = _eventLocationLabel(event);
    final type = _eventTypeLabel(event);
    final start = artseeEventStartDate(event);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.artC.silver.withValues(alpha: 0.26),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityCover(event: event, title: title, size: 64),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '合作推荐 · $type',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_timeLabel(start)} · $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.46),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.26),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtseeActivityDateSection extends StatelessWidget {
  final ArtseeEventDayGroup group;
  final Set<String> appliedIds;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const ArtseeActivityDateSection({
    super.key,
    required this.group,
    required this.appliedIds,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateHeading(group.day),
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...group.events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ArtseeActivityFeedTile(
                event: event,
                applied: appliedIds.contains(event['id']?.toString()),
                onTap: () => onOpen(event),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ArtseeActivityFeedTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool applied;
  final VoidCallback onTap;

  const ArtseeActivityFeedTile({
    super.key,
    required this.event,
    required this.applied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(event['title']) ?? '未命名活动';
    final host = _eventHostLabel(event);
    final start = artseeEventStartDate(event);
    final time = _timeLabel(start);
    final location = _eventLocationLabel(event);
    final price = _priceLabel(event);

    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = constraints.maxWidth < 360 ? 68.0 : 76.0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityCover(
                    event: event,
                    title: title,
                    size: coverSize,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _ActivityHostLine(label: host)),
                            if (applied || price != null) ...[
                              const SizedBox(width: 5),
                              _ActivityStatusPill(
                                label: applied ? '已报名' : price!,
                                applied: applied,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 15,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _ActivityMeta(icon: Icons.schedule, text: time),
                            _ActivityMeta(
                              icon: Icons.location_on_outlined,
                              text: location,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ArtseeActivityFeedEmpty extends StatelessWidget {
  final String title;
  final String subtitle;

  const ArtseeActivityFeedEmpty({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: context.artC.ink.withValues(alpha: 0.18),
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.34),
              fontSize: 11,
              height: 1.45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _PersonalEventRow({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(event['title']) ?? '未命名活动';
    final start = artseeEventStartDate(event);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            _ActivityCover(event: event, title: title, size: 44),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dateHeading(start == null ? null : DateTime(start.year, start.month, start.day))}  ${_timeLabel(start)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.42),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ActivityCover extends StatelessWidget {
  final Map<String, dynamic> event;
  final String title;
  final double size;

  const _ActivityCover({
    required this.event,
    required this.title,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = _eventCoverUrl(event);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: coverUrl == null || coverUrl.isEmpty
            ? _NetworkFallbackCover(seed: title, title: title)
            : Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _NetworkFallbackCover(seed: title, title: title),
              ),
      ),
    );
  }
}

class _NetworkFallbackCover extends StatelessWidget {
  final String seed;
  final String title;

  const _NetworkFallbackCover({
    required this.seed,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(seed);
    return Image.network(
      'https://picsum.photos/seed/artsee_event_$encoded/360/360',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _ColorFallbackCover(title: title),
    );
  }
}

class _ColorFallbackCover extends StatelessWidget {
  final String title;

  const _ColorFallbackCover({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: context.artC.silver.withValues(alpha: 0.18),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.7),
          fontSize: 10,
          height: 1.18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivityHostLine extends StatelessWidget {
  final String label;

  const _ActivityHostLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: kCobalt.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: kCobalt,
            size: 10,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ActivityMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: context.artC.ink.withValues(alpha: 0.22),
          size: 16,
        ),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.46),
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityStatusPill extends StatelessWidget {
  final String label;
  final bool applied;

  const _ActivityStatusPill({
    required this.label,
    required this.applied,
  });

  @override
  Widget build(BuildContext context) {
    final color = applied ? kCobalt : const Color(0xFF3DAA57);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _eventTypeLabel(Map<String, dynamic> event) {
  final raw = event.entries
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

String _eventHostLabel(Map<String, dynamic> event) {
  final metadata = event['metadata'] is Map
      ? (event['metadata'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final showOrganization = metadata['show_organization'] != false;
  final organization = _stringValue(metadata['organization']);
  if (showOrganization && organization != null) return organization;
  return _stringValue(event['organizer_name']) ??
      _stringValue(event['host_name']) ??
      _stringValue(event['hotel_name']) ??
      _stringValue(event['city']) ??
      _eventTypeLabel(event);
}

String _eventLocationLabel(Map<String, dynamic> event) {
  final city = _stringValue(event['city']);
  final venue = _stringValue(event['venue']);
  final location = [
    if (city != null) city,
    if (venue != null) venue,
  ].join(' · ');
  return location.isEmpty ? '地点待定' : location;
}

String? _eventCoverUrl(Map<String, dynamic> event) {
  return _stringValue(event['cover_url']) ??
      _stringValue(event['image_url']) ??
      _stringValue(event['poster_url']) ??
      _stringValue(event['thumbnail_url']);
}

String _timeLabel(DateTime? date) {
  if (date == null) return '时间待定';
  final period = date.hour < 12 ? '上午' : '下午';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$period $hour:$minute';
}

String? _priceLabel(Map<String, dynamic> event) {
  final raw = event['fee_amount'];
  final value = raw is num ? raw.round() : int.tryParse(raw?.toString() ?? '');
  if (value == null || value <= 0) return null;
  final currency = _stringValue(event['currency'])?.toLowerCase();
  final symbol = switch (currency) {
    'usd' || 'dollar' => r'$',
    'gbp' => '£',
    'eur' => '€',
    _ => '¥',
  };
  return '$symbol$value';
}

String _dateHeading(DateTime? day) {
  if (day == null) return '日期待定';
  return '${day.month}月${day.day}日 / ${_weekdayLongCn(day.weekday)}';
}

String _weekdayLongCn(int weekday) {
  const labels = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  final index = weekday.clamp(1, 7) - 1;
  return labels[index];
}
