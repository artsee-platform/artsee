import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class SchoolDetailEnhancedScreen extends StatefulWidget {
  final String id;

  const SchoolDetailEnhancedScreen({super.key, required this.id});

  @override
  State<SchoolDetailEnhancedScreen> createState() =>
      _SchoolDetailEnhancedScreenState();
}

class _SchoolDetailEnhancedScreenState
    extends State<SchoolDetailEnhancedScreen> {
  SchoolDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await BackendApiService.fetchSchool(widget.id);
      if (mounted) {
        setState(() {
          _detail = SchoolDetail.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: kCobalt,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: context.artC.ink.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text('加载失败',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.artC.ink)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(
                              fontSize: 13,
                              color: context.artC.ink.withAlpha(150))),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;
    return CustomScrollView(
      slivers: [
        _buildHeader(detail),
        _buildBasicInfo(detail),
        if (detail.programs.isNotEmpty) _buildProgramsList(detail.programs),
        if (detail.documents.isNotEmpty) _buildDocuments(detail.documents),
        _buildMetrics(detail.metrics),
        _buildActionButtons(detail),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHeader(SchoolDetail detail) {
    final imageUrl = detail.bannerUrl ?? _fallbackSchoolHeroUrl(detail);
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: false,
      backgroundColor: context.artC.ink,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.artC.ink.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.artC.ink,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF6D7D92)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.46, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SchoolLogoMark(detail: detail, size: 74),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detail.nameZh,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 25,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (detail.nameEn != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              detail.nameEn!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildBasicInfo(SchoolDetail detail) {
    final location = [
      if (detail.country != null && detail.country!.trim().isNotEmpty)
        detail.country!.trim(),
      if (detail.city != null && detail.city!.trim().isNotEmpty)
        detail.city!.trim(),
    ].join(' · ');
    final schoolType = _prettyTag(detail.schoolType);
    final website = _cleanWebsite(detail.officialWebsite);
    final descriptionParts = _descriptionParagraphs(detail.description);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.artC.silver.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.045),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SchoolStatsGrid(
              rank: detail.qsArtDesignRank ?? detail.qsArtRank,
              location: location.isEmpty ? null : location,
              type: schoolType,
            ),
            if (website != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openUrl(website),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kCobalt.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kCobalt.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          size: 18, color: kCobalt),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '访问官方网站',
                          style: TextStyle(
                            color: kCobalt,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _websiteLabel(website),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new_rounded,
                          size: 15, color: kCobalt),
                    ],
                  ),
                ),
              ),
            ],
            if (descriptionParts.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                '学校介绍',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 12),
              ...descriptionParts.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    paragraph,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: context.artC.ink.withValues(alpha: 0.64),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsList(List<ProgramInfo> programs) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('开设专业 (${programs.length})',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink)),
            const SizedBox(height: 12),
            ...programs.map((program) => _ProgramCard(program: program)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocuments(List<SchoolDocument> documents) {
    final requirements =
        documents.where((d) => d.documentType == 'requirements').toList();
    final faqs = documents.where((d) => d.documentType == 'faq').toList();

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requirements.isNotEmpty) ...[
              Text('申请要求',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink)),
              const SizedBox(height: 8),
              ...requirements.map((doc) => _DocumentCard(document: doc)),
            ],
            if (faqs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('常见问题',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink)),
              const SizedBox(height: 8),
              ...faqs.map((doc) => _DocumentCard(document: doc)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(SchoolMetrics metrics) {
    if (metrics.totalPrograms == 0 && metrics.totalDocuments == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCobalt.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (metrics.totalPrograms > 0)
              _MetricItem(label: '专业数', value: '${metrics.totalPrograms}'),
            if (metrics.totalDocuments > 0)
              _MetricItem(label: '文档数', value: '${metrics.totalDocuments}'),
            if (metrics.acceptanceRate != null)
              _MetricItem(
                  label: '录取率',
                  value:
                      '${(metrics.acceptanceRate! * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SchoolDetail detail) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('添加到申请清单功能即将上线')),
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('添加到申请清单'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('查看录取案例功能即将上线')),
                  );
                },
                icon: const Icon(Icons.cases_outlined, size: 20),
                label: const Text('查看案例'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCobalt,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kCobalt),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolLogoMark extends StatelessWidget {
  final SchoolDetail detail;
  final double size;

  const _SchoolLogoMark({
    required this.detail,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = detail.logoUrl;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: logoUrl != null && logoUrl.trim().isNotEmpty
            ? Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _LogoInitial(detail.nameZh),
              )
            : _LogoInitial(detail.nameZh),
      ),
    );
  }
}

class _LogoInitial extends StatelessWidget {
  final String name;

  const _LogoInitial(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : 'A',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: kCobalt,
        ),
      ),
    );
  }
}

class _SchoolStatsGrid extends StatelessWidget {
  final int? rank;
  final String? location;
  final String? type;

  const _SchoolStatsGrid({
    required this.rank,
    required this.location,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 340 ? 8.0 : 10.0;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: _StatTile(
                  icon: Icons.emoji_events_rounded,
                  label: 'QS 艺术设计',
                  value: rank != null ? '#$rank' : '—',
                  highlighted: true,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 9,
                child: Column(
                  children: [
                    _StatTile(
                      icon: Icons.location_on_rounded,
                      label: '城市',
                      value: location ?? '—',
                    ),
                    SizedBox(height: gap),
                    _StatTile(
                      icon: Icons.auto_awesome_mosaic_rounded,
                      label: '类型',
                      value: type ?? '艺术院校',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: EdgeInsets.all(highlighted ? 16 : 13),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF111827)
            : context.artC.porcelain.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.08)
              : context.artC.silver.withValues(alpha: 0.28),
        ),
      ),
      child: highlighted
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFFD8B866), size: 22),
                const SizedBox(height: 18),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 17, color: kCobalt),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.artC.ink.withValues(alpha: 0.34),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.artC.ink.withValues(alpha: 0.78),
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

class _ProgramCard extends StatelessWidget {
  final ProgramInfo program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(program.programName,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (program.degreeType != null)
                _Tag(text: program.degreeType!, color: kCobalt),
              if (program.durationMonths != null)
                _Tag(
                    text: '${program.durationMonths}个月',
                    color: context.artC.ink.withAlpha(150)),
              if (program.requiresPortfolio)
                const _Tag(text: '需作品集', color: Colors.orange),
              if (program.tuitionFee != null)
                _Tag(
                    text: '学费 ${program.tuitionFee!.toStringAsFixed(0)}',
                    color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final SchoolDocument document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.artC.silver.withAlpha(100)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(document.title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.artC.ink)),
          children: [
            if (document.content != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(document.content!,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.artC.ink.withAlpha(200))),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: kCobalt)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: context.artC.ink.withAlpha(150))),
      ],
    );
  }
}

String _fallbackSchoolHeroUrl(SchoolDetail detail) {
  final name = '${detail.nameZh} ${detail.nameEn ?? ''}'.toLowerCase();
  if (name.contains('royal college of art') || name.contains('皇家艺术学院')) {
    return 'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&q=82&w=1800';
  }
  return 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&q=82&w=1800';
}

String? _cleanWebsite(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null ||
      trimmed.isEmpty ||
      trimmed == '[object Object]' ||
      trimmed.toLowerCase() == 'null') {
    return null;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

String _websiteLabel(String url) {
  final host = Uri.tryParse(url)?.host;
  if (host == null || host.isEmpty) return url;
  return host.replaceFirst(RegExp(r'^www\.'), '');
}

String? _prettyTag(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final normalized = value.toLowerCase();
  const map = {
    'multi_disciplinary': '多学科综合',
    'art_academy': '艺术学院',
    'research_university': '研究型院校',
    'public': '公立',
    'private': '私立',
  };
  return map[normalized] ??
      value
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part.substring(0, 1).toUpperCase() + part.substring(1))
          .join(' ');
}

List<String> _descriptionParagraphs(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return const [];
  final fromNewlines = text
      .split(RegExp(r'\n+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (fromNewlines.length > 1) return fromNewlines;
  if (text.length < 520) return [text];

  final sentences = RegExp(r'[^.!?。！？]+[.!?。！？]?')
      .allMatches(text)
      .map((match) => match.group(0)!.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (sentences.length < 4) return [text];

  final midpoint = (sentences.length / 2).ceil();
  return [
    sentences.take(midpoint).join(' '),
    sentences.skip(midpoint).join(' '),
  ];
}
