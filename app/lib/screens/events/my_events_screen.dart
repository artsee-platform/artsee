import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../widgets/common.dart';
import 'event_feed_widgets.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  var _selected = _MyEventsTab.upcoming;
  var _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];

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
      final result =
          await BackendApiService.fetchMyEventApplications(limit: 80);
      final events = result.data
          .map(artseeEventFromApplication)
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(compareArtseeEventsByStart);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredEvents;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
              child: _MyEventsHeader(
                selected: _selected,
                onBack: () => Navigator.of(context).maybePop(),
                onSelected: (tab) => setState(() => _selected = tab),
                onMenu: _showMenu,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: kCobalt,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _error != null
                        ? _MyEventsError(message: _error!, onRetry: _load)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: visible.isEmpty
                                ? _MyEventsEmpty(tab: _selected)
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      20,
                                      22,
                                      120,
                                    ),
                                    children: groupArtseeEventsByDay(visible)
                                        .map(
                                          (group) => ArtseeActivityDateSection(
                                            group: group,
                                            appliedIds: visible
                                                .map(
                                                  (event) =>
                                                      event['id']?.toString() ??
                                                      '',
                                                )
                                                .where((id) => id.isNotEmpty)
                                                .toSet(),
                                            onOpen: (_) {},
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events.where((event) {
      final start = artseeEventStartDate(event);
      if (start == null) return _selected == _MyEventsTab.upcoming;
      final day = DateTime(start.year, start.month, start.day);
      final isPast = day.isBefore(today);
      return _selected == _MyEventsTab.history ? isPast : !isPast;
    }).toList();
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: BoxDecoration(
              color: context.artC.cardIconBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MyEventsMenuItem(
                  icon: Icons.refresh_rounded,
                  label: '刷新活动',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _load();
                  },
                ),
                _MyEventsMenuItem(
                  icon: Icons.help_outline_rounded,
                  label: '活动通知会进入私信/预约记录',
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyEventsHeader extends StatelessWidget {
  final _MyEventsTab selected;
  final VoidCallback onBack;
  final ValueChanged<_MyEventsTab> onSelected;
  final VoidCallback onMenu;

  const _MyEventsHeader({
    required this.selected,
    required this.onBack,
    required this.onSelected,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.chevron_left_rounded,
          label: '返回',
          onTap: onBack,
        ),
        const Spacer(),
        _MyEventsSegmentedControl(
          selected: selected,
          onSelected: onSelected,
        ),
        const Spacer(),
        _RoundIconButton(
          icon: Icons.menu_rounded,
          label: '菜单',
          onTap: onMenu,
        ),
      ],
    );
  }
}

class _MyEventsSegmentedControl extends StatelessWidget {
  final _MyEventsTab selected;
  final ValueChanged<_MyEventsTab> onSelected;

  const _MyEventsSegmentedControl({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _MyEventsSegment(
            label: '即将举办',
            selected: selected == _MyEventsTab.upcoming,
            onTap: () => onSelected(_MyEventsTab.upcoming),
          ),
          _MyEventsSegment(
            label: '历史',
            selected: selected == _MyEventsTab.history,
            onTap: () => onSelected(_MyEventsTab.history),
          ),
        ],
      ),
    );
  }
}

class _MyEventsSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MyEventsSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? context.artC.silver.withValues(alpha: 0.36)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: selected ? 0.92 : 0.74),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.artC.cardIconBg.withValues(alpha: 0.88),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.artC.ink.withValues(alpha: 0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: context.artC.ink, size: 32),
          ),
        ),
      ),
    );
  }
}

class _MyEventsEmpty extends StatelessWidget {
  final _MyEventsTab tab;

  const _MyEventsEmpty({required this.tab});

  @override
  Widget build(BuildContext context) {
    final title = tab == _MyEventsTab.upcoming ? '暂无即将举办的活动' : '暂无历史活动';
    final subtitle =
        tab == _MyEventsTab.upcoming ? '你目前没有即将举办的活动。' : '你过去参加或报名的活动会显示在这里。';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        SizedBox(
          height: 430,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: _FadedEventSkeleton()),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: context.artC.ink.withValues(alpha: 0.2),
                    size: 64,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.52),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.46),
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FadedEventSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Opacity(
        opacity: 0.17,
        child: Column(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(widthFactor: 0.78),
                        SizedBox(height: 12),
                        _SkeletonLine(widthFactor: 0.96),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _SkeletonLine(widthFactor: 0.42)),
                            SizedBox(width: 14),
                            Expanded(child: _SkeletonLine(widthFactor: 0.52)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;

  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: context.artC.silver.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MyEventsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MyEventsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 120),
      children: [
        Icon(
          Icons.event_busy_outlined,
          color: context.artC.ink.withValues(alpha: 0.28),
          size: 42,
        ),
        const SizedBox(height: 14),
        Text(
          '活动加载失败',
          textAlign: TextAlign.center,
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
            color: context.artC.ink.withValues(alpha: 0.45),
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: TextButton(onPressed: onRetry, child: const Text('重试'))),
      ],
    );
  }
}

class _MyEventsMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MyEventsMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: context.artC.ink.withValues(alpha: 0.7)),
      title: Text(
        label,
        style: TextStyle(
          color: context.artC.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _MyEventsTab { upcoming, history }
