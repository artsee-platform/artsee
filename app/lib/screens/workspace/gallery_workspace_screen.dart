import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/deep_sea_ui.dart';
import '../profile/content_submissions_screen.dart';
import '../publish/publish_artist_screen.dart';
import '../publish/publish_exhibition_screen.dart';
import '../publish/publish_opportunity_screen.dart';

class GalleryWorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const GalleryWorkspaceScreen({super.key, this.profile});

  @override
  State<GalleryWorkspaceScreen> createState() => _GalleryWorkspaceScreenState();
}

class _GalleryWorkspaceScreenState extends State<GalleryWorkspaceScreen> {
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
  void didUpdateWidget(covariant GalleryWorkspaceScreen oldWidget) {
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

  int _countStatus(String status) {
    return _submissions
        .where((item) => item['status']?.toString() == status)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return DeepSeaBackdrop(
      child: RefreshIndicator(
        color: kDeepSeaGlow,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _GalleryHero(profile: widget.profile),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: kDeepSeaGlow,
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
                    const _GalleryArtworkGrid(),
                    const SizedBox(height: 16),
                    _MetricGrid(
                      metrics: [
                        _MetricData(
                          icon: Icons.storefront_outlined,
                          label: '机构档案',
                          value: '${_organizations.length}',
                        ),
                        _MetricData(
                          icon: Icons.event_available_outlined,
                          label: '发布记录',
                          value: '${_submissions.length}',
                        ),
                        _MetricData(
                          icon: Icons.hourglass_top_outlined,
                          label: '审核中',
                          value: '${_countStatus('reviewing')}',
                        ),
                        _MetricData(
                          icon: Icons.verified_outlined,
                          label: '已发布',
                          value: '${_countStatus('published')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ActionGrid(
                      actions: [
                        _WorkspaceAction(
                          icon: Icons.event_outlined,
                          title: '发布展览活动',
                          subtitle: '展览、沙龙、导览与报名',
                          onTap: () => _push(const PublishExhibitionScreen()),
                        ),
                        _WorkspaceAction(
                          icon: Icons.palette_outlined,
                          title: '发布艺术家档案',
                          subtitle: '合作艺术家与作品资源',
                          onTap: () => _push(const PublishArtistScreen()),
                        ),
                        _WorkspaceAction(
                          icon: Icons.handshake_outlined,
                          title: '发布合作邀约',
                          subtitle: '品牌联名、展览合作、商业委托',
                          onTap: () => _push(const PublishOpportunityScreen()),
                        ),
                        _WorkspaceAction(
                          icon: Icons.history_outlined,
                          title: '发布记录',
                          subtitle: '查看审核进度与修改补充材料',
                          onTap: () => _push(const ContentSubmissionsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _OrganizationCard(organizations: _organizations),
                    const SizedBox(height: 16),
                    _GalleryPipelineCard(submissions: _submissions),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryHero extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const _GalleryHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile?['nickname']?.toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: deepSeaGlassDecoration(radius: 28, opacity: 0.72, glow: true),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kDeepSeaGlow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.museum_outlined, color: kDeepSeaGlow),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? '画廊展览工作台' : '$name 的画廊工作台',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kDeepSeaTextStyle.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: kDeepSeaInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '管理展览活动、合作艺术家、报名线索与商业邀约',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kDeepSeaTextStyle.copyWith(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kDeepSeaMuted.withValues(alpha: 0.84),
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

class _GalleryArtworkGrid extends StatelessWidget {
  const _GalleryArtworkGrid();

  static const _works = [
    (
      seed: 'artsee_gallery_blue_room',
      title: 'Silent Room',
      subtitle: 'Mixed Media',
      height: 184.0,
    ),
    (
      seed: 'artsee_gallery_glass_body',
      title: 'Glass Body',
      subtitle: 'Sculpture',
      height: 136.0,
    ),
    (
      seed: 'artsee_gallery_tide_print',
      title: 'Tide Print',
      subtitle: 'Photography',
      height: 144.0,
    ),
    (
      seed: 'artsee_gallery_night_archive',
      title: 'Night Archive',
      subtitle: 'Installation',
      height: 196.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final left = [_works[0], _works[2]];
    final right = [_works[1], _works[3]];
    return DeepSeaGlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 30,
      opacity: 0.58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Gallery Grid',
                style: kDeepSeaTextStyle.copyWith(
                  color: kDeepSeaInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              const _SmallTag(label: '策展视图'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ArtworkColumn(items: left)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _ArtworkColumn(items: right),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtworkColumn extends StatelessWidget {
  final List<({double height, String seed, String subtitle, String title})>
      items;

  const _ArtworkColumn({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          _ArtworkTile(item: item),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  final ({double height, String seed, String subtitle, String title}) item;

  const _ArtworkTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: item.height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: kDeepSeaMetal.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: kDeepSeaMidnight.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                'https://picsum.photos/seed/${item.seed}/540/720',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: kDeepSeaPanel,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    color: kDeepSeaGlow.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: kDeepSeaMidnight.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.16)),
              ),
              child: Text(
                '${item.title} · ${item.subtitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kDeepSeaTextStyle.copyWith(
                  color: kDeepSeaInk.withValues(alpha: 0.86),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPipelineCard extends StatelessWidget {
  final List<Map<String, dynamic>> submissions;

  const _GalleryPipelineCard({required this.submissions});

  @override
  Widget build(BuildContext context) {
    final recent = submissions.take(3).toList();
    return _WorkspacePanel(
      title: '近期发布',
      icon: Icons.timeline_outlined,
      child: recent.isEmpty
          ? Text(
              '还没有展览、艺术家或合作发布记录。',
              style: TextStyle(
                fontSize: 12,
                color: kDeepSeaMuted.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Text',
                fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC'],
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

class _OrganizationCard extends StatelessWidget {
  final List<Map<String, dynamic>> organizations;

  const _OrganizationCard({required this.organizations});

  @override
  Widget build(BuildContext context) {
    final first = organizations.isEmpty
        ? null
        : _map(organizations.first['organization']);
    final org = first?.isNotEmpty == true ? first! : const <String, dynamic>{};
    final name =
        _text(org['name'], fallback: organizations.isEmpty ? '暂无机构档案' : '机构档案');
    final status = _text(org['subscription_status'], fallback: 'inactive');
    return _WorkspacePanel(
      title: '机构入驻',
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kDeepSeaInk,
              fontFamily: 'SF Pro Text',
              fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallTag(label: organizations.isEmpty ? '待创建' : '已创建'),
              _SmallTag(label: status == 'active' ? '入驻有效' : '未开通年费'),
            ],
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
      decoration: deepSeaGlassDecoration(radius: 24, opacity: 0.64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, color: kDeepSeaGlow, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kDeepSeaInk,
                  fontFamily: 'SF Pro Display',
                  fontFamilyFallback: ['SF Pro Text', 'Noto Sans SC'],
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
                  color: kDeepSeaMuted.withValues(alpha: 0.82),
                  fontFamily: 'SF Pro Text',
                  fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC'],
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

class _ActionGrid extends StatelessWidget {
  final List<_WorkspaceAction> actions;

  const _ActionGrid({required this.actions});

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
  final _WorkspaceAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: action.onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: deepSeaGlassDecoration(radius: 24, opacity: 0.62),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kDeepSeaGlow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.18)),
              ),
              child: Icon(action.icon, color: kDeepSeaGlow, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: kDeepSeaInk,
                      fontFamily: 'SF Pro Text',
                      fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
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
                      color: kDeepSeaMuted.withValues(alpha: 0.8),
                      fontFamily: 'SF Pro Text',
                      fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC'],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: kDeepSeaGlow.withValues(alpha: 0.54),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WorkspaceAction({
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
      decoration: deepSeaGlassDecoration(radius: 26, opacity: 0.66),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kDeepSeaGlow),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: kDeepSeaInk,
                  fontFamily: 'SF Pro Text',
                  fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kDeepSeaInk,
                    fontFamily: 'SF Pro Text',
                    fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    color: kDeepSeaMuted.withValues(alpha: 0.74),
                    fontFamily: 'SF Pro Text',
                    fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC'],
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
        color: kDeepSeaGlow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kDeepSeaGlow,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'SF Pro Text',
          fontFamilyFallback: ['PingFang SC', 'Noto Sans SC'],
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
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: kDeepSeaGlow.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kDeepSeaMuted.withValues(alpha: 0.86),
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
    'events' => '展览活动',
    'artists' => '艺术家档案',
    'artworks' => '作品',
    'opportunities' => '合作机会',
    _ => type.isEmpty ? '内容' : type,
  };
}
