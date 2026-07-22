import 'package:artsee_app/theme/artsee_ui_colors.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  AppCase? _case;
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
      final c = await BackendApiService.fetchCaseDetail(widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingIndicator());
    if (_error != null) {
      return Scaffold(
        backgroundColor: context.artC.porcelain,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: _CaseDetailError(message: _error!, onRetry: _load),
      );
    }
    if (_case == null) {
      return const Scaffold(body: EmptyState(emoji: '❌', message: '找不到该案例'));
    }

    final c = _case!;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: resultGradient(c.result)),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(resultLabel(c.result),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 6),
                        Text(c.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Applicant card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: ArtseeSurface(
                padding: const EdgeInsets.all(14),
                radius: 8,
                color: context.artC.cardIconBg.withValues(alpha: 0.84),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kCobalt,
                          child: Text(
                              c.isAnonymous
                                  ? '匿'
                                  : (c.authorNickname?.substring(0, 1) ?? '?'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                c.isAnonymous
                                    ? '匿名用户'
                                    : (c.authorNickname ?? '用户'),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: context.artC.ink)),
                            const SizedBox(height: 2),
                            Text(
                                '${c.undergrad ?? '背景待补'} · GPA ${c.gpa ?? '—'}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.artC.ink
                                        .withValues(alpha: 0.42))),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _CaseInfoTile(
                            label: '目标院校', value: c.targetSchool ?? '—'),
                        const SizedBox(width: 8),
                        _CaseInfoTile(
                            label: '申请专业', value: c.targetProgram ?? '—'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tags
          if (c.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: c.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kCobalt.withValues(alpha: 0.07),
                              border: Border.all(
                                  color: kCobalt.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('#$t',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: kCobalt.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                )),
                          ))
                      .toList(),
                ),
              ),
            ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ArtseeSurface(
                padding: const EdgeInsets.all(16),
                radius: 8,
                color: context.artC.cardIconBg.withValues(alpha: 0.84),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('申请心得',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.artC.ink)),
                    const SizedBox(height: 8),
                    Text(c.content ?? c.excerpt ?? '暂无内容',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.artC.ink.withValues(alpha: 0.66),
                            height: 1.7)),
                  ],
                ),
              ),
            ),
          ),

          // Interaction bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  _ActionBtn(
                      icon: Icons.favorite_border, label: '${c.likeCount} 赞'),
                  const SizedBox(width: 8),
                  _ActionBtn(
                      icon: Icons.bookmark_border, label: '${c.saveCount} 收藏'),
                  const SizedBox(width: 8),
                  _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      label: '${c.commentCount} 评论'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _CaseInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: context.artC.silver.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.32)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kCobalt.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.artC.ink.withValues(alpha: 0.38),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseDetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CaseDetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: context.artC.ink.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              '案例详情加载失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.artC.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.artC.ink.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 16),
            CobaltButton(label: '重试', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: kCobalt.withValues(alpha: 0.72)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.artC.ink.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}
