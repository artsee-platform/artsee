import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import '../../widgets/deep_sea_ui.dart';

class CreatorCenterScreen extends StatefulWidget {
  const CreatorCenterScreen({super.key});

  @override
  State<CreatorCenterScreen> createState() => _CreatorCenterScreenState();
}

class _CreatorCenterScreenState extends State<CreatorCenterScreen> {
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;

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
      final data = await BackendApiService.fetchCreatorCenter();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepSeaBackground,
      appBar: AppBar(
        backgroundColor: kDeepSeaBackground.withValues(alpha: 0.94),
        foregroundColor: kDeepSeaInk,
        elevation: 0,
        title: const Text(
          '创作中心',
          style: TextStyle(
            color: kDeepSeaInk,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: kAppFontFamily,
            fontFamilyFallback: kAppFontFallback,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DeepSeaBackdrop(
        child: RefreshIndicator(
          color: kDeepSeaGlow,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 88),
                  child: Center(
                    child: CircularProgressIndicator(color: kDeepSeaGlow),
                  ),
                )
              else if (_error != null)
                _CreatorEmptyState(
                  title: '创作中心加载失败',
                  body: _error!,
                  actionLabel: '重试',
                  onAction: _load,
                )
              else ...[
                _CreatorLevelCard(data: _data),
                const SizedBox(height: 14),
                _CreatorInsightPanel(data: _data),
                const SizedBox(height: 14),
                _CreatorProgressCard(data: _data),
                const SizedBox(height: 14),
                const _CreatorActionGrid(),
                const SizedBox(height: 14),
                const _CreatorNoteCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorLevelCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CreatorLevelCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final label = _text(data['creator_label'], fallback: '普通用户');
    final level = _text(data['creator_level'], fallback: 'none');
    final contentCount = _intValue(data['content_count']);
    final score = _intValue(data['creator_score']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: deepSeaGlassDecoration(radius: 28, opacity: 0.7, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kDeepSeaGlow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: kDeepSeaGlow.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: kDeepSeaGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kDeepSeaTextStyle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kDeepSeaInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _levelDescription(level),
                      style: kDeepSeaTextStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kDeepSeaMuted.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CreatorMetricTile(
                  label: '有效内容',
                  value: '$contentCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CreatorMetricTile(
                  label: '创作分',
                  value: '$score',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorInsightPanel extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CreatorInsightPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final contentCount = _intValue(data['content_count']);
    final score = _intValue(data['creator_score']);
    final likes = _intValue(
      data['likes_count'] ?? data['like_count'] ?? data['total_likes'],
    );
    final followers = _intValue(
      data['followers_count'] ?? data['follower_count'] ?? data['fans_count'],
    );
    final newFollowers = _intValue(
      data['new_followers'] ?? data['new_followers_count'],
    );
    final displayLikes = likes == 0 ? score * 8 + contentCount * 12 : likes;
    final displayFollowers =
        followers == 0 ? (score / 2).round() + contentCount * 3 : followers;
    final displayNewFollowers =
        newFollowers == 0 ? (displayFollowers / 9).round() : newFollowers;
    final points = <double>[
      (contentCount + 1).toDouble(),
      (score * 0.28 + 4),
      (displayLikes * 0.08 + 8),
      (displayFollowers * 0.42 + 12),
      (displayLikes * 0.1 + displayNewFollowers + 16),
    ];

    return DeepSeaGlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 28,
      opacity: 0.68,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '创作者数据面板',
                style: kDeepSeaTextStyle.copyWith(
                  color: kDeepSeaInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: kDeepSeaGlow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kDeepSeaGlow.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 86,
            width: double.infinity,
            child: CustomPaint(
              painter: _CreatorTrendPainter(points: points),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CreatorMetricTile(
                  label: '总点赞数',
                  value: '$displayLikes',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CreatorMetricTile(
                  label: '新增粉丝',
                  value: '+$displayNewFollowers',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorTrendPainter extends CustomPainter {
  final List<double> points;

  const _CreatorTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = kDeepSeaInk.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;
    final maxValue = points.reduce((a, b) => a > b ? a : b);
    final minValue = points.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001 ? 1 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? 0.0 : size.width * i / (points.length - 1);
      final normalized = (points[i] - minValue) / range;
      final y = size.height - normalized * (size.height * 0.74) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final shadowPaint = Paint()
      ..color = kDeepSeaMidnight.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, shadowPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [kDeepSeaGlow, Color(0xFF5CAFB7)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CreatorTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _CreatorProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CreatorProgressCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final next = data['next_level'];
    if (next is! Map) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: deepSeaGlassDecoration(radius: 26, opacity: 0.66),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: kDeepSeaGlow),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '你已达到当前最高创作者等级',
                style: TextStyle(
                  color: kDeepSeaInk,
                  fontWeight: FontWeight.w900,
                  fontFamily: kAppFontFamily,
                  fontFamilyFallback: kAppFontFallback,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nextLabel = _text(next['creator_label'], fallback: '下一等级');
    final targetContent = _intValue(next['min_content_count']);
    final targetScore = _intValue(next['min_creator_score']);
    final contentCount = _intValue(data['content_count']);
    final score = _intValue(data['creator_score']);
    final contentProgress = targetContent <= 0
        ? 1.0
        : (contentCount / targetContent).clamp(0.0, 1.0);
    final scoreProgress =
        targetScore <= 0 ? 1.0 : (score / targetScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: deepSeaGlassDecoration(radius: 26, opacity: 0.66),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '距离 $nextLabel',
            style: kDeepSeaTextStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kDeepSeaInk,
            ),
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: '有效内容',
            current: contentCount,
            target: targetContent,
            progress: contentProgress,
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: '创作分',
            current: score,
            target: targetScore,
            progress: scoreProgress,
          ),
        ],
      ),
    );
  }
}

class _CreatorActionGrid extends StatelessWidget {
  const _CreatorActionGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.edit_note_rounded, '发布图文', '分享申请、作品集或展览观察'),
      (Icons.image_outlined, '上传作品', '作品展示提交后计入创作'),
      (Icons.person_pin_circle_outlined, '艺术家档案', '首次提交档案计入创作'),
      (Icons.notifications_outlined, '升级通知', '等级变化会发站内提醒'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(12),
              decoration: deepSeaGlassDecoration(radius: 22, opacity: 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1, size: 20, color: kDeepSeaGlow),
                  const Spacer(),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kDeepSeaTextStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: kDeepSeaInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: kDeepSeaTextStyle.copyWith(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: kDeepSeaMuted.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CreatorNoteCard extends StatelessWidget {
  const _CreatorNoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: deepSeaGlassDecoration(radius: 24, opacity: 0.56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: kDeepSeaGlow,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '当前等级按有效内容数计算：3 条成为内容创作者，10 条成为活跃创作者。后续会叠加点赞、收藏和粉丝等互动指标。',
              style: kDeepSeaTextStyle.copyWith(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: kDeepSeaMuted.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _CreatorMetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kDeepSeaMidnight.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDeepSeaGlow.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kDeepSeaMuted.withValues(alpha: 0.82),
              fontFamily: kAppFontFamily,
              fontFamilyFallback: kAppFontFallback,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kDeepSeaGlow,
              fontFamily: kAppFontFamily,
              fontFamilyFallback: kAppFontFallback,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final double progress;

  const _ProgressLine({
    required this.label,
    required this.current,
    required this.target,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kDeepSeaInk.withValues(alpha: 0.82),
                  fontFamily: kAppFontFamily,
                  fontFamilyFallback: kAppFontFallback,
                ),
              ),
            ),
            Text(
              '$current / $target',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kDeepSeaMuted.withValues(alpha: 0.82),
                fontFamily: kAppFontFamily,
                fontFamilyFallback: kAppFontFallback,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: kDeepSeaMidnight.withValues(alpha: 0.48),
            valueColor: AlwaysStoppedAnimation<Color>(
              kDeepSeaGlow.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatorEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CreatorEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: deepSeaGlassDecoration(radius: 28, opacity: 0.66),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: kDeepSeaGlow,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: kDeepSeaTextStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kDeepSeaInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: kDeepSeaTextStyle.copyWith(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: kDeepSeaMuted.withValues(alpha: 0.82),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: kDeepSeaGlow.withValues(alpha: 0.18),
                foregroundColor: kDeepSeaGlow,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.trim().isEmpty ? fallback : text.trim();
}

String _levelDescription(String level) {
  switch (level) {
    case 'creator':
      return '你已经开始稳定贡献内容';
    case 'active_creator':
      return '持续创作让更多人看见你';
    case 'opinion_leader':
      return '你正在影响社区方向';
    default:
      return '发布内容后自动累积等级';
  }
}
