import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../community/community_post_detail_screen.dart';
import '../consultation/organization_list_screen.dart';
import '../forum/ask_question_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class SchoolDetailScreen extends StatefulWidget {
  final String id;
  final VoidCallback? onOpenCompare;
  final VoidCallback? onOpenCompareTab;

  const SchoolDetailScreen({
    super.key,
    required this.id,
    this.onOpenCompare,
    @Deprecated('Use onOpenCompare instead') this.onOpenCompareTab,
  });

  VoidCallback? get resolvedOpenCompare => onOpenCompare ?? onOpenCompareTab;

  @override
  State<SchoolDetailScreen> createState() => _SchoolDetailScreenState();
}

class _SchoolDetailScreenState extends State<SchoolDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saved = false;
  bool _saving = false;
  bool _questionsLoading = false;
  List<AppCommunityPost> _schoolQuestions = const [];
  String? _error;

  bool get _isAuxiliarySchool =>
      widget.id.startsWith('aux-') || _data?['is_auxiliary_display'] == true;

  String? get _schoolActionId {
    final remoteId = _data?['remote_school_id']?.toString();
    if (remoteId != null && remoteId.isNotEmpty) return remoteId;
    if (_isAuxiliarySchool) return null;
    return widget.id;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await BackendApiService.fetchSchool(widget.id);
      if (mounted) {
        setState(() {
          _data = r;
          _loading = false;
        });
      }
      _loadSchoolQuestions(r);
      final actionId = _schoolActionId;
      if (actionId != null) await _loadSavedState(actionId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSavedState(String schoolId) async {
    try {
      final saved = await BackendApiService.fetchSavedSchools(limit: 100);
      if (!mounted) return;
      setState(() {
        _saved = saved.data.any(
          (item) => (item['id'] ?? item['school_id'])?.toString() == schoolId,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _saved = false);
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (SupabaseService.isLoggedIn) return true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
    return mounted && SupabaseService.isLoggedIn;
  }

  Future<bool> _toggleSaved() async {
    if (_saving) return false;
    final actionId = _schoolActionId;
    if (actionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地补充院校暂不支持加入目标池')),
      );
      return false;
    }
    if (!await _ensureLoggedIn()) return false;
    setState(() => _saving = true);
    try {
      if (_saved) {
        await BackendApiService.removeSavedSchool(actionId);
      } else {
        await BackendApiService.saveSchool(actionId);
      }
      if (!mounted) return false;
      setState(() => _saved = !_saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saved ? '已加入目标院校池' : '已移出目标院校池')),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCompare() async {
    if (!_saved) {
      final saved = await _toggleSaved();
      if (!saved) return;
    }
    if (!mounted) return;
    final openCompare = widget.resolvedOpenCompare;
    if (openCompare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入目标池，可从院校页进入对比')),
      );
      return;
    }
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openCompare();
    });
  }

  Future<void> _openOrganizationConsultation(String targetName) async {
    final actionId = _schoolActionId;
    if (actionId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrganizationListScreen(
          schoolId: actionId,
          schoolName: targetName,
        ),
      ),
    );
  }

  Future<void> _openSchoolQuestion() async {
    final data = _data;
    if (data == null) return;
    if (!await _ensureLoggedIn()) return;
    if (!mounted) return;
    final schoolName = _schoolDisplayName(data);
    final createdTitle = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => AskQuestionScreen(
          initialTitle: '关于$schoolName，我想问：',
          initialCategory: '艺术留学',
          initialSchool: schoolName,
          initialSchoolId: _schoolActionId ?? widget.id,
        ),
      ),
    );
    if (!mounted || createdTitle == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问题已进入院校广场')),
    );
    _loadSchoolQuestions(data);
  }

  Future<void> _loadSchoolQuestions(Map<String, dynamic> school) async {
    if (_questionsLoading) return;
    setState(() => _questionsLoading = true);
    try {
      final posts = await BackendApiService.fetchPlazaPosts(
        limit: 50,
        kind: 'qa',
        sort: 'latest',
      );
      final matched = posts.where((post) {
        return _schoolQuestionMatches(
          post,
          school: school,
          fallbackSchoolId: _schoolActionId ?? widget.id,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _schoolQuestions = matched;
        _questionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _schoolQuestions = const [];
        _questionsLoading = false;
      });
    }
  }

  String _schoolDisplayName(Map<String, dynamic> school) {
    final nameZh = school['name_zh']?.toString().trim();
    if (nameZh != null && nameZh.isNotEmpty && nameZh != '—') return nameZh;
    final nameEn = school['name_en']?.toString().trim();
    if (nameEn != null && nameEn.isNotEmpty) return nameEn;
    return '这所学校';
  }

  bool _schoolQuestionMatches(
    AppCommunityPost post, {
    required Map<String, dynamic> school,
    required String fallbackSchoolId,
  }) {
    final schoolIds = <String>{
      fallbackSchoolId.trim(),
      widget.id.trim(),
      school['id']?.toString().trim() ?? '',
      school['remote_school_id']?.toString().trim() ?? '',
    }..removeWhere((value) => value.isEmpty);
    final schoolId = post.metadata['school_id']?.toString().trim();
    if (schoolId != null && schoolIds.contains(schoolId)) return true;

    final names = [
      school['name_zh']?.toString(),
      school['name_en']?.toString(),
      school['short_name']?.toString(),
      school['name']?.toString(),
    ]
        .map((value) => value?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty && value != '—')
        .toSet();
    final metadataSchool = post.metadata['school']?.toString() ?? '';
    final haystack = [
      metadataSchool,
      post.title,
      post.body ?? '',
    ].join(' ').toLowerCase();
    return names.any((name) => haystack.contains(name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2.5,
                ),
              )
            : _error != null
                ? Center(
                    child: Text(
                      '加载失败: $_error',
                      style: TextStyle(color: context.artC.ink),
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final canUseActions = _schoolActionId != null;
    final nameZh = d['name_zh'] as String? ?? '—';
    final nameEn = d['name_en'] as String?;
    final country = d['country'] as String?;
    final city = d['city'] as String?;
    final schoolType = d['school_type'] as String?;
    final qsRank = d['qs_art_rank'] as int?;
    final qsOverallRank = d['qs_overall_rank'] as int?;
    final description = d['description'] as String?;
    final featureTags = _stringList(d['feature_tags']);
    final disciplines = _stringList(d['strength_disciplines']);
    final alumni = _stringList(d['notable_alumni']);
    final campusImages = _stringList(d['campus_image_urls']);
    final rawWebsite = d['official_website'];
    final website = (rawWebsite is String &&
            rawWebsite.isNotEmpty &&
            rawWebsite != '[object Object]')
        ? rawWebsite
        : null;
    final logoUrl = d['logo_url'] as String?;
    final schoolTypeLabel = _schoolTypeLabel(schoolType);
    final fitItems =
        _fitItems(schoolType: schoolType, disciplines: disciplines, city: city);
    final cautionItems = _cautionItems(qsRank: qsRank, schoolType: schoolType);
    final summary = _schoolSummary(
      nameZh: nameZh,
      city: city,
      schoolTypeLabel: schoolTypeLabel,
      disciplines: disciplines,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _buildHeaderIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: '返回',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                _buildHeaderIconButton(
                  icon: Icons.add_comment_outlined,
                  tooltip: '问这所学校',
                  onTap: _openSchoolQuestion,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: context.artC.cardIconBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.artC.silver.withOpacity(0.48),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.artC.ink.withOpacity(0.035),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _SchoolLogoFallback(nameZh),
                              )
                            : Center(
                                child: Text(
                                  nameZh.substring(0, 1),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: kCobalt,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameZh,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: context.artC.ink,
                              height: 1.2,
                            ),
                          ),
                          if (nameEn != null && nameEn.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              nameEn,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.artC.ink.withOpacity(0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (qsRank != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kCobalt.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'QS 艺术 #$qsRank',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kCobalt.withOpacity(0.9),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _DetailChip(
                                icon: Icons.place_outlined,
                                label: [
                                  if (city != null) city,
                                  if (country != null) country,
                                ].join(' · '),
                              ),
                              _DetailChip(
                                icon: Icons.account_balance_outlined,
                                label: schoolTypeLabel,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canUseActions) ...[
                  const SizedBox(height: 18),
                  _PrimaryDecisionButton(
                    icon: _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    label: _saved ? '已在目标池' : '加入目标池',
                    loading: _saving,
                    onTap: _toggleSaved,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryDecisionButton(
                          icon: Icons.compare_arrows_rounded,
                          label: '加入对比',
                          outlined: true,
                          onTap: _openCompare,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PrimaryDecisionButton(
                          icon: Icons.support_agent_outlined,
                          label: '开始咨询',
                          outlined: true,
                          onTap: () => _openOrganizationConsultation(nameZh),
                        ),
                      ),
                    ],
                  ),
                ],
                if (campusImages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kRadiusLarge),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        campusImages.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: context.artC.silver.withOpacity(0.35),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: context.artC.ink.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _buildFitCard(fitItems, cautionItems),
                const SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('关键结论'),
                      const SizedBox(height: 12),
                      Text(
                        summary,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w700,
                          color: context.artC.ink.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSchoolQuestionsCard(
                  nameZh: nameZh,
                  nameEn: nameEn,
                ),
                const SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('基本信息'),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        '国家 / 城市',
                        [
                          if (country != null) country,
                          if (city != null) city,
                        ].join(' · '),
                      ),
                      if (schoolType != null && schoolType.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow('学校类型', schoolTypeLabel),
                      ],
                      if (disciplines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          '优势方向',
                          disciplines.take(4).map(_displayLabel).join(' / '),
                        ),
                      ],
                      if (qsRank != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow('QS 艺术排名', '#$qsRank'),
                      ],
                      if (website != null && website.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow('官方网站', website),
                      ],
                    ],
                  ),
                ),
                if (description != null && description.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('学校介绍'),
                        const SizedBox(height: 12),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: context.artC.ink.withOpacity(0.74),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.artC.porcelain.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            description.trim(),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: context.artC.ink.withOpacity(0.48),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (featureTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('院校标签'),
                        const SizedBox(height: 14),
                        _buildChips(featureTags),
                      ],
                    ),
                  ),
                ],
                if (disciplines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('优势方向'),
                        const SizedBox(height: 14),
                        _buildChips(disciplines),
                      ],
                    ),
                  ),
                ],
                if (alumni.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('知名校友'),
                        const SizedBox(height: 12),
                        ...alumni.take(8).map(
                              (name) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: kCobalt.withOpacity(0.75),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.45,
                                          fontWeight: FontWeight.w600,
                                          color: context.artC.ink.withOpacity(
                                            0.72,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                if (qsRank != null || qsOverallRank != null) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('数据概览'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (qsRank != null)
                              Expanded(
                                child: _buildStatItem(
                                  qsRank.toString(),
                                  'QS 艺术排名',
                                ),
                              ),
                            if (qsRank != null && qsOverallRank != null)
                              const SizedBox(width: 16),
                            if (qsOverallRank != null)
                              Expanded(
                                child: _buildStatItem(
                                  qsOverallRank.toString(),
                                  'QS 综合排名',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.artC.silver.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: context.artC.ink.withOpacity(0.62),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolQuestionsCard({
    required String nameZh,
    required String? nameEn,
  }) {
    final name = nameZh == '—' ? (nameEn ?? '这所学校') : nameZh;
    final suggestions = [
      '$name 作品集通常需要几个完整项目？',
      '$name 更看重概念推导还是最终视觉完成度？',
      '申请 $name 前需要提前准备哪些背景？',
    ];

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSectionTitle('关于这所学校，大家在问')),
              TextButton.icon(
                onPressed: _openSchoolQuestion,
                icon: const Icon(Icons.add_comment_outlined, size: 16),
                label: const Text('提问'),
                style: TextButton.styleFrom(
                  foregroundColor: kCobalt,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_questionsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: kCobalt,
              ),
            )
          else if (_schoolQuestions.isEmpty) ...[
            Text(
              '还没有沉淀到这所学校的问答。可以先把具体问题发到院校广场。',
              style: TextStyle(
                color: context.artC.ink.withOpacity(0.48),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in suggestions) _buildSuggestedQuestionRow(item),
          ] else
            ..._schoolQuestions.take(3).map(_buildQuestionTile),
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestionRow(String text) {
    return InkWell(
      onTap: _openSchoolQuestion,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, size: 17, color: kCobalt),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withOpacity(0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.artC.ink.withOpacity(0.28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTile(AppCommunityPost post) {
    final subtitle = post.body?.trim().isNotEmpty == true
        ? post.body!.trim()
        : post.commentCount > 0
            ? '${post.commentCount} 个回答正在讨论'
            : '还在等第一条有用回答';
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPostDetailScreen(
              postId: post.id,
              initialPost: post,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kCobalt.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '问',
                style: TextStyle(
                  color: kCobalt,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withOpacity(0.44),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${post.commentCount} 回答',
              style: TextStyle(
                color: context.artC.ink.withOpacity(0.36),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitCard(List<String> fitItems, List<String> cautionItems) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('适合你吗？'),
          const SizedBox(height: 14),
          _FitColumn(
            title: '适合',
            icon: Icons.check_circle_rounded,
            color: kCobalt,
            items: fitItems,
          ),
          const SizedBox(height: 14),
          _FitColumn(
            title: '谨慎',
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF9A6A00),
            items: cautionItems,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.026),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: context.artC.ink,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.artC.ink.withOpacity(0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.artC.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChips(List<String> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.take(12).map((value) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kCobalt.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kCobalt.withOpacity(0.08)),
          ),
          child: Text(
            _displayLabel(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kCobalt.withOpacity(0.9),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatItem(String value, String label, {bool dimmed = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: dimmed ? context.artC.ink.withOpacity(0.25) : kCobalt,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: context.artC.ink.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SchoolLogoFallback extends StatelessWidget {
  final String name;

  const _SchoolLogoFallback(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.substring(0, 1),
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: kCobalt,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.artC.silver.withOpacity(0.26),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.artC.ink.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.artC.ink.withOpacity(0.52)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.artC.ink.withOpacity(0.58),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryDecisionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool loading;

  const _PrimaryDecisionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? kCobalt : Colors.white;
    final bg = outlined ? context.artC.cardIconBg : kCobalt;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: outlined ? kCobalt.withOpacity(0.18) : kCobalt,
            ),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FitColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _FitColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withOpacity(0.68),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,，、\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

String _schoolTypeLabel(String? value) {
  switch (value) {
    case 'art_college':
      return '艺术学院';
    case 'art_academy':
      return '专业艺术学院';
    case 'design_school':
      return '设计学院';
    case 'university_art_dept':
      return '大学艺术院系';
    case 'comprehensive_university':
      return '综合大学艺术方向';
    case 'multi_disciplinary':
      return '综合艺术与设计院校';
    case 'private_art_school':
      return '私立艺术院校';
    case 'public_university':
      return '公立大学艺术方向';
    default:
      return value == null || value.isEmpty ? '艺术与设计院校' : _displayLabel(value);
  }
}

String _displayLabel(String value) {
  final normalized = value.trim();
  final key =
      normalized.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  return switch (key) {
    'fine_art' || 'fine_arts' => '纯艺',
    'painting' => '绘画',
    'sculpture' => '雕塑',
    'design' => '设计',
    'graphic_design' || 'communication_design' => '平面设计',
    'visual_communication' || 'visual_communications' => '视觉传达',
    'interaction_design' || 'interactive_design' => '交互设计',
    'service_design' => '服务设计',
    'industrial_design' || 'product_design' => '工业设计',
    'architecture' || 'architectural_design' => '建筑',
    'interior_design' => '室内设计',
    'fashion' || 'fashion_design' => '时尚',
    'illustration' => '插画',
    'animation' => '动画',
    'film' || 'film_video' => '电影影像',
    'photography' => '摄影',
    'curating' || 'curatorial_studies' => '策展',
    'art_history' => '艺术史',
    'multi_disciplinary' => '跨学科',
    'portfolio_friendly' => '作品集友好',
    _ => normalized.contains('_')
        ? normalized
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ')
        : normalized,
  };
}

List<String> _fitItems({
  required String? schoolType,
  required List<String> disciplines,
  required String? city,
}) {
  final primaryDirection = disciplines.isNotEmpty
      ? disciplines.take(2).map(_displayLabel).join(' / ')
      : '艺术与设计';
  return [
    if (schoolType == 'multi_disciplinary' ||
        schoolType == 'design_school' ||
        schoolType == 'art_college')
      '想在$primaryDirection方向做系统深造'
    else
      '希望把$primaryDirection纳入目标院校池',
    if (city != null && city.isNotEmpty) '看重$city的艺术资源与行业机会',
    '需要通过排名、方向和作品集要求做申请取舍',
  ];
}

List<String> _cautionItems({
  required int? qsRank,
  required String? schoolType,
}) {
  return [
    if (qsRank != null && qsRank <= 10) '热门高排名院校，作品集概念和完成度要求更高',
    if (schoolType == 'multi_disciplinary') '专业跨度较大，申请前要先锁定具体项目',
    '费用、语言、DDL 和作品集格式仍需以官网为准',
  ];
}

String _schoolSummary({
  required String nameZh,
  required String? city,
  required String schoolTypeLabel,
  required List<String> disciplines,
}) {
  final direction = disciplines.isNotEmpty
      ? disciplines.take(4).map(_displayLabel).join('、')
      : '艺术与设计';
  final location = city == null || city.isEmpty ? '' : '位于$city，';
  return '$nameZh$location是一所$schoolTypeLabel，适合关注$direction方向、希望把院校选择和作品集策略结合起来判断的申请者。建议把它放入目标池后，与同国家或同专业方向院校一起比较排名、预算、课程重点和申请要求。';
}
