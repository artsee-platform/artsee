import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import '../profile/content_submissions_screen.dart';
import '../publish/publish_exhibition_screen.dart';
import '../publish/publish_opportunity_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class GeneralBusinessWorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const GeneralBusinessWorkspaceScreen({super.key, this.profile});

  @override
  State<GeneralBusinessWorkspaceScreen> createState() =>
      _GeneralBusinessWorkspaceScreenState();
}

class _GeneralBusinessWorkspaceScreenState
    extends State<GeneralBusinessWorkspaceScreen> {
  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GeneralBusinessWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?['id'] != widget.profile?['id']) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizations = await BackendApiService.fetchMyOrganizations();
      final submissions =
          await BackendApiService.fetchMyContentSubmissions(limit: 20);
      if (!mounted) return;
      setState(() {
        _organizations = organizations.data;
        _submissions = submissions.data;
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

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) _load();
  }

  int _typeCount(String type) {
    return _submissions
        .where((item) => item['type']?.toString() == type)
        .length;
  }

  int _reviewingCount() {
    return _submissions
        .where((item) => item['status']?.toString() == 'reviewing')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kCobalt,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _BusinessHero(profile: widget.profile),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _WorkspaceError(error: _error!, onRetry: _load),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MetricGrid(
                    metrics: [
                      _MetricData(
                        icon: Icons.business_center_outlined,
                        label: '合作机会',
                        value: '${_typeCount('opportunities')}',
                      ),
                      _MetricData(
                        icon: Icons.event_outlined,
                        label: '活动发布',
                        value: '${_typeCount('events')}',
                      ),
                      _MetricData(
                        icon: Icons.hourglass_top_outlined,
                        label: '审核中',
                        value: '${_reviewingCount()}',
                      ),
                      _MetricData(
                        icon: Icons.storefront_outlined,
                        label: '机构档案',
                        value: '${_organizations.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ActionList(
                    actions: [
                      _BusinessAction(
                        icon: Icons.add_business_outlined,
                        title: '发布合作机会',
                        subtitle: '招募艺术家、设计师或内容合作方',
                        onTap: () => _push(const PublishOpportunityScreen()),
                      ),
                      _BusinessAction(
                        icon: Icons.event_available_outlined,
                        title: '发布活动',
                        subtitle: '品牌活动、沙龙、文旅空间计划',
                        onTap: () => _push(const PublishExhibitionScreen()),
                      ),
                      _BusinessAction(
                        icon: Icons.history_outlined,
                        title: '发布记录',
                        subtitle: '查看审核进度与补充资料',
                        onTap: () => _push(const ContentSubmissionsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BusinessOrgPanel(organizations: _organizations),
                  const SizedBox(height: 16),
                  _BusinessSubmissionPanel(submissions: _submissions),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessHero extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const _BusinessHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final role = _roleLabel(profile?['user_role']?.toString());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work_outline_rounded, color: kCobalt),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$role工作台',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '管理合作机会、活动发布、品牌主页与审核进度',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessOrgPanel extends StatelessWidget {
  final List<Map<String, dynamic>> organizations;

  const _BusinessOrgPanel({required this.organizations});

  @override
  Widget build(BuildContext context) {
    final membership = organizations.isEmpty ? null : organizations.first;
    final org = _map(membership?['organization']) ?? const <String, dynamic>{};
    final name = _text(org['name'], fallback: '暂无机构档案');
    final subscriptionStatus =
        _text(org['subscription_status'], fallback: 'inactive');
    return _WorkspacePanel(
      title: '品牌主页',
      icon: Icons.storefront_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallTag(label: organizations.isEmpty ? '待创建' : '已创建'),
              _SmallTag(
                label: subscriptionStatus == 'active' ? '入驻有效' : '未开通年费',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessSubmissionPanel extends StatelessWidget {
  final List<Map<String, dynamic>> submissions;

  const _BusinessSubmissionPanel({required this.submissions});

  @override
  Widget build(BuildContext context) {
    final recent = submissions.take(4).toList();
    return _WorkspacePanel(
      title: '近期事项',
      icon: Icons.task_alt_outlined,
      child: recent.isEmpty
          ? Text(
              '还没有合作机会或活动发布记录。',
              style: TextStyle(
                fontSize: 12,
                color: context.artC.ink.withValues(alpha: 0.52),
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: [
                for (final item in recent)
                  _RecentSubmissionRow(
                    title: _text(item['title'], fallback: '未命名内容'),
                    status: _statusLabel(_text(item['status'])),
                    type: _typeLabel(_text(item['type'])),
                  ),
              ],
            ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.65,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics.map((metric) => _MetricCard(metric: metric)).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, color: kCobalt, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final String value;

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ActionList extends StatelessWidget {
  final List<_BusinessAction> actions;

  const _ActionList({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final action in actions) ...[
          _ActionTile(action: action),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final _BusinessAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: action.onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(action.icon, color: kCobalt, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.32)),
          ],
        ),
      ),
    );
  }
}

class _BusinessAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BusinessAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _WorkspacePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _WorkspacePanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kCobalt),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RecentSubmissionRow extends StatelessWidget {
  final String title;
  final String status;
  final String type;

  const _RecentSubmissionRow({
    required this.title,
    required this.status,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.artC.ink.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SmallTag(label: status),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;

  const _SmallTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _WorkspaceError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 42, color: context.artC.ink.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.58),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _roleLabel(String? role) {
  return switch (role) {
    'official_association' => '官方协会',
    'school_official' => '院校官方',
    'official_partner' => '官方合作组织',
    'event_organizer' => '活动机构',
    'hotel_culture_space' => '文旅空间',
    'brand_partner' => '品牌合作方',
    'art_media_community' => '艺术媒体',
    'other_service' => '商业机构',
    _ => '商业机构',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'published' => '已发布',
    'reviewing' => '审核中',
    'rejected' => '未通过',
    'draft' => '草稿',
    _ => status.isEmpty ? '未知' : status,
  };
}

String _typeLabel(String type) {
  return switch (type) {
    'events' => '活动',
    'opportunities' => '合作机会',
    'artists' => '艺术家',
    'artworks' => '作品',
    _ => type.isEmpty ? '内容' : type,
  };
}
