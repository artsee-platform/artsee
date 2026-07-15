import 'package:flutter/material.dart';
import '../../widgets/common.dart';
import '../../services/backend_api_service.dart';
import '../../utils/auth_gate.dart';
import 'event_feed_widgets.dart';
import 'my_events_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _myEvents = [];
  final Set<String> _appliedIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final result = await BackendApiService.fetchEvents(limit: 30);
      var myEvents = <Map<String, dynamic>>[];
      try {
        final applications =
            await BackendApiService.fetchMyEventApplications(limit: 30);
        myEvents = applications.data
            .map(artseeEventFromApplication)
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        myEvents = const [];
      }
      final appliedIds = myEvents
          .map((event) => event['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final events = _mergeEventLists([myEvents, result.data]);
      if (mounted) {
        setState(() {
          _events = events;
          _myEvents = myEvents;
          _appliedIds
            ..clear()
            ..addAll(appliedIds);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMyEvents() async {
    if (!await ensureLoggedIn(context, message: '请先登录后查看你的活动')) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MyEventsScreen()),
    );
  }

  void _openEvent(Map<String, dynamic> event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(event['title']?.toString() ?? '活动详情')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = mainTabBottomInset(context);
    final groups = groupArtseeEventsByDay(_events);
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadEvents,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, bottom + 24),
                  children: [
                    ArtseeActivityPersonalSection(
                      events: _myEvents,
                      onOpen: _openEvent,
                      onOpenAll: _openMyEvents,
                    ),
                    const SizedBox(height: 22),
                    ArtseeActivityRecommendationHeader(
                      filterLabel: '附近',
                      selectedFilter: '全部',
                      filters: const ['全部'],
                      onSelected: (_) {},
                    ),
                    const SizedBox(height: 16),
                    if (_events.isEmpty)
                      const ArtseeActivityFeedEmpty(
                        title: '暂无展览活动',
                        subtitle: '点击右下角 + 发布展览、沙龙或工作坊。',
                      )
                    else ...[
                      ArtseeActivitySponsoredSlot(
                        event: _events.first,
                        onOpen: () => _openEvent(_events.first),
                      ),
                      const SizedBox(height: 18),
                      ...groups.map(
                        (group) => ArtseeActivityDateSection(
                          group: group,
                          appliedIds: _appliedIds,
                          onOpen: _openEvent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

List<Map<String, dynamic>> _mergeEventLists(
  Iterable<List<Map<String, dynamic>>> lists,
) {
  final byId = <String, Map<String, dynamic>>{};
  final fallback = <Map<String, dynamic>>[];
  for (final list in lists) {
    for (final item in list) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        fallback.add(item);
      } else {
        byId[id] = {...?byId[id], ...item};
      }
    }
  }
  return [...byId.values, ...fallback]..sort(compareArtseeEventsByStart);
}
