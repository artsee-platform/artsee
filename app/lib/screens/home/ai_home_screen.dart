import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';
import '../cases/case_detail_screen.dart';
import '../schools/school_detail_enhanced_screen.dart';

class AiHomeScreen extends StatefulWidget {
  final bool navigationRevealed;
  final VoidCallback onRevealNavigation;
  final VoidCallback onHideNavigation;
  final int? sidebarRequestToken;

  const AiHomeScreen({
    super.key,
    required this.navigationRevealed,
    required this.onRevealNavigation,
    required this.onHideNavigation,
    this.sidebarRequestToken,
  });

  @override
  State<AiHomeScreen> createState() => AiHomeScreenState();
}

class AiHomeScreenState extends State<AiHomeScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_AiConversation> _conversations = [_AiConversation.seed()];
  String _activeConversationId = 'seed';
  Map<String, dynamic>? _profile;
  bool _sending = false;
  double _gestureDy = 0;

  List<String> get _quickPrompts => _buildQuickPrompts(_profile);

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _loadProfile();
    _loadPersistedConversations();
  }

  @override
  void didUpdateWidget(covariant AiHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = widget.sidebarRequestToken;
    if (token != null && token != oldWidget.sidebarRequestToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConversationSidebar();
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _loadPersistedConversations() async {
    final rows = await SupabaseService.fetchAiConversations();
    if (!mounted || rows.isEmpty) return;
    final conversations = rows
        .map(_AiConversation.fromPersisted)
        .where((item) => item.messages.isNotEmpty)
        .toList();
    if (conversations.isEmpty) return;
    setState(() {
      _conversations
        ..clear()
        ..addAll(conversations);
      _activeConversationId = conversations.first.id;
    });
  }

  List<String> _buildQuickPrompts(Map<String, dynamic>? profile) {
    final countries = _profileList(profile, 'target_countries');
    final majors = _profileList(profile, 'target_majors');
    final degree = profile?['target_degree']?.toString().trim() ?? '';
    final portfolio = profile?['portfolio_status']?.toString().trim() ?? '';
    final budget = profile?['total_budget_range']?.toString().trim() ?? '';

    final prompts = <String>[];
    if (countries.isEmpty) {
      prompts.add('帮我选择目标国家');
    }
    if (majors.isEmpty) {
      prompts.add('帮我确定适合的专业方向');
    }
    if (degree.isEmpty) {
      prompts.add('BA / MA / MFA 我该怎么选？');
    }
    if (countries.isNotEmpty && majors.isNotEmpty) {
      prompts.add('根据我的画像推荐 5 所学校');
    }
    prompts.add(
      portfolio.isEmpty ? '帮我规划作品集时间线' : '根据我的作品集进度安排申请时间线',
    );
    if (budget.isEmpty) {
      prompts.add('我的预算适合哪些国家？');
    }
    prompts.add('用案例判断我的申请档位');

    return prompts.toSet().take(4).toList();
  }

  List<String> _profileList(Map<String, dynamic>? profile, String key) {
    final raw = profile?[key];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final conversation = _activeConversation;
    late _AiMessage assistantMessage;
    setState(() {
      if (conversation.title == '新的咨询') {
        conversation.title =
            text.length > 18 ? '${text.substring(0, 18)}…' : text;
      }
      conversation.messages.add(_AiMessage(role: 'user', text: text));
      assistantMessage = _AiMessage(role: 'assistant', text: '');
      conversation.messages.add(assistantMessage);
      _sending = true;
    });
    _input.clear();
    _scrollBottom();

    Map<String, dynamic>? streamMeta;
    try {
      final payload = _conversationPayload(conversation);
      await for (final event in BackendApiService.aiChatStream(payload)) {
        if (!mounted) return;
        if (event.meta != null) {
          streamMeta = event.meta;
          continue;
        }
        if (event.text != null && event.text!.isNotEmpty) {
          setState(() {
            assistantMessage.text += event.text!;
            conversation.updatedAt = DateTime.now();
          });
          _scrollBottom();
        }
        if (event.done) break;
      }
      streamMeta ??= {
        'sources': const [],
        'schoolData': null,
      };
      final schoolCards = await _extractSchoolCards(streamMeta);
      final recommendations = await _buildRecommendations(
        schoolCards,
        intent: streamMeta['intent']?.toString(),
      );
      final actions = _extractActions(streamMeta, schoolCards);
      if (!mounted) return;
      setState(() {
        assistantMessage.schoolCards = schoolCards;
        assistantMessage.recommendations = recommendations;
        assistantMessage.actions = actions;
        conversation.updatedAt = DateTime.now();
        _sending = false;
      });
    } catch (e) {
      try {
        final response = await BackendApiService.aiConsult(text);
        final schoolCards = await _extractSchoolCards(response);
        final recommendations = await _buildRecommendations(schoolCards);
        final actions = _extractActions(response, schoolCards);
        if (!mounted) return;
        setState(() {
          assistantMessage.text = _formatConsultReply(response);
          assistantMessage.schoolCards = schoolCards;
          assistantMessage.recommendations = recommendations;
          assistantMessage.actions = actions;
          conversation.updatedAt = DateTime.now();
          _sending = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          assistantMessage.text =
              '我暂时连不上完整 AI 服务，但可以先按你的画像给出基础建议。你可以继续补充目标国家、专业、预算、语言成绩和作品集阶段。';
          conversation.updatedAt = DateTime.now();
          _sending = false;
        });
      }
    }
    _persistConversation(conversation);
    _scrollBottom();
  }

  List<Map<String, String>> _conversationPayload(_AiConversation conversation) {
    return conversation.messages
        .where((message) => message.text.trim().isNotEmpty)
        .map((message) => {
              'role': message.role,
              'content': message.text,
            })
        .toList();
  }

  Future<_AiRecommendations?> _buildRecommendations(
    List<_AiSchoolCardData> schools, {
    String? intent,
  }) async {
    final shouldRecommend = schools.isNotEmpty ||
        const {
          'recommendation',
          'application_advice',
          'school_fit_analysis',
        }.contains(intent);
    if (!shouldRecommend) return null;
    final casesFuture = BackendApiService.fetchCases(
      limit: intent == 'school_fit_analysis' ? 4 : 3,
      result: 'admitted',
    ).catchError((_) => <AppCase>[]);
    final analysesFuture = schools.isEmpty
        ? Future.value(<_AiSchoolAnalysisData>[])
        : BackendApiService.aiAnalyzeSchools(schools.map((s) => s.id).toList())
            .then(_AiSchoolAnalysisData.listFromResult)
            .catchError((_) => <_AiSchoolAnalysisData>[]);
    final results = await Future.wait([casesFuture, analysesFuture]);
    final cases = results[0] as List<AppCase>;
    final analyses = results[1] as List<_AiSchoolAnalysisData>;
    if (cases.isEmpty && analyses.isEmpty) return null;
    return _AiRecommendations(cases: cases, analyses: analyses);
  }

  void _persistConversation(_AiConversation conversation) {
    SupabaseService.saveAiConversation(
      id: conversation.id,
      title: conversation.title,
      messages:
          conversation.messages.map((message) => message.toJson()).toList(),
    );
  }

  Future<List<_AiSchoolCardData>> _extractSchoolCards(
    Map<String, dynamic> response,
  ) async {
    final candidates = <({String? id, String? name})>[];
    final sources = response['sources'];
    if (sources is List) {
      for (final source in sources) {
        if (source is! Map) continue;
        final id = source['schoolId']?.toString().trim();
        final name = source['schoolName']?.toString().trim();
        if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
          continue;
        }
        candidates.add((id: id?.isEmpty == true ? null : id, name: name));
      }
    }

    final schoolData = response['schoolData'];
    if (schoolData is Map) {
      final id = schoolData['id']?.toString().trim();
      final name =
          (schoolData['name_zh'] ?? schoolData['name_en'])?.toString().trim();
      if ((id != null && id.isNotEmpty) || (name != null && name.isNotEmpty)) {
        candidates.insert(0, (id: id, name: name));
      }
    }

    final cards = <_AiSchoolCardData>[];
    final seenIds = <String>{};
    final seenNames = <String>{};
    for (final candidate in candidates) {
      if (cards.length >= 3) break;
      Map<String, dynamic>? school;
      final id = candidate.id;
      if (id != null && id.isNotEmpty && !seenIds.contains(id)) {
        try {
          school = await BackendApiService.fetchSchool(id);
        } catch (_) {
          school = null;
        }
      }
      final name = candidate.name;
      if (school == null && name != null && name.isNotEmpty) {
        final nameKey = name.toLowerCase();
        if (seenNames.contains(nameKey)) continue;
        try {
          final result = await BackendApiService.fetchSchools(
            keyword: name,
            limit: 1,
          );
          if (result.data.isNotEmpty) school = result.data.first;
        } catch (_) {
          school = null;
        }
      }
      if (school == null) continue;
      final card = _AiSchoolCardData.fromJson(school);
      if (seenIds.add(card.id)) {
        seenNames.add(card.nameZh.toLowerCase());
        cards.add(card);
      }
    }
    return cards;
  }

  List<_AiAction> _extractActions(
    Map<String, dynamic> response,
    List<_AiSchoolCardData> schoolCards,
  ) {
    final actions = <_AiAction>[];
    final rawActions = response['actions'];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map<String, dynamic>) {
          actions.add(_AiAction.fromJson(item));
        }
      }
    }
    if (actions.isEmpty && schoolCards.isNotEmpty) {
      for (final school in schoolCards.take(3)) {
        actions.add(_AiAction(
          type: 'add_to_tracker',
          schoolId: school.id,
          schoolName: school.nameZh,
          tier: 'match',
        ));
      }
    }
    return actions;
  }

  _AiConversation get _activeConversation {
    return _conversations.firstWhere(
      (c) => c.id == _activeConversationId,
      orElse: () => _conversations.first,
    );
  }

  String _formatConsultReply(Map<String, dynamic> response) {
    final lines = <String>[];
    final answer = response['answer']?.toString().trim();
    if (answer != null && answer.isNotEmpty) lines.add(answer);

    final sources = response['sources'];
    if (sources is List && sources.isNotEmpty) {
      final sourceLines = sources
          .take(3)
          .map((source) {
            if (source is! Map) return null;
            final school = source['schoolName']?.toString();
            final heading = source['heading']?.toString();
            return [school, heading]
                .where((v) => v != null && v.isNotEmpty)
                .join(' · ');
          })
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toList();
      if (sourceLines.isNotEmpty) {
        lines.add('参考来源：\n${sourceLines.map((s) => '· $s').join('\n')}');
      }
    }
    return lines.isEmpty ? '我已经收到你的问题，但暂时没有结构化建议。' : lines.join('\n\n');
  }

  void _newConversation() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _conversations.insert(0, _AiConversation(id: id));
      _activeConversationId = id;
    });
  }

  void _openConversationSidebar() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '最近聊天',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _AiConversationSidebar(
            conversations: _conversations,
            activeId: _activeConversationId,
            onNew: () {
              Navigator.of(ctx).pop();
              _newConversation();
            },
            onSelect: (id) {
              Navigator.of(ctx).pop();
              setState(() => _activeConversationId = id);
            },
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildConversationList(BuildContext context) {
    final messages = _activeConversation.messages;
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      children: [
        _AiHero(
          profile: _profile,
          onOpenHistory: _openConversationSidebar,
          onNewChat: _newConversation,
        ),
        const SizedBox(height: 16),
        _QuickPromptGrid(
          prompts: _quickPrompts,
          onTap: _send,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              _activeConversation.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.artC.ink,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openConversationSidebar,
              icon: const Icon(Icons.history, size: 17),
              label: const Text('最近聊天'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...messages.map((msg) => _MessageBubble(message: msg)),
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              'Artiqore AI 正在思考…',
              style: TextStyle(
                fontSize: 12,
                color: context.artC.ink.withValues(alpha: 0.42),
              ),
            ),
          ),
        SizedBox(
            height:
                widget.navigationRevealed ? mainTabBottomInset(context) : 16),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: _AiConversationSidebar(
            conversations: _conversations,
            activeId: _activeConversationId,
            embedded: true,
            onNew: _newConversation,
            onSelect: (id) => setState(() => _activeConversationId = id),
          ),
        ),
        Expanded(child: _buildConversationList(context)),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return _buildConversationList(context);
  }

  bool get _isWide {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 820;
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 96,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: Listener(
        onPointerMove: (event) {
          _gestureDy += event.delta.dy;
          if (_gestureDy >= 18) {
            widget.onRevealNavigation();
            _gestureDy = 0;
          } else if (_gestureDy <= -18) {
            widget.onHideNavigation();
            _gestureDy = 0;
          }
        },
        onPointerUp: (_) => _gestureDy = 0,
        onPointerCancel: (_) => _gestureDy = 0,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _isWide
                    ? _buildDesktopLayout(context)
                    : _buildMobileLayout(context),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: widget.navigationRevealed
                    ? const SizedBox.shrink()
                    : _AiInputBar(
                        key: const ValueKey('ai-input-bar'),
                        controller: _input,
                        sending: _sending,
                        onSend: () => _send(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiConversation {
  final String id;
  String title;
  DateTime updatedAt;
  final List<_AiMessage> messages;

  _AiConversation({
    required this.id,
    this.title = '新的咨询',
    DateTime? updatedAt,
    List<_AiMessage>? messages,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ??
            [
              _AiMessage(
                role: 'assistant',
                text:
                    '你好，我是 Artiqore AI。告诉我你的目标国家、专业方向、预算或作品集进度，我可以帮你拆选校、时间线和案例参考。',
              ),
            ];

  factory _AiConversation.seed() {
    return _AiConversation(
      id: 'seed',
      title: '申请规划咨询',
    );
  }

  factory _AiConversation.fromPersisted(Map<String, dynamic> json) {
    final rawMessages = (json['ai_messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
            (b['position'] as num?)?.toInt() ?? 0,
          ));
    return _AiConversation(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '新的咨询',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      messages: rawMessages.map(_AiMessage.fromPersisted).toList(),
    );
  }
}

class _AiMessage {
  final String role;
  String text;
  List<_AiSchoolCardData>? schoolCards;
  _AiRecommendations? recommendations;
  List<_AiAction>? actions;

  _AiMessage({
    required this.role,
    required this.text,
    this.schoolCards,
    this.recommendations,
    this.actions,
  });

  factory _AiMessage.fromPersisted(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    return _AiMessage(
      role: json['role']?.toString() ?? 'assistant',
      text: json['content']?.toString() ?? '',
      schoolCards: (metadata['school_cards'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(_AiSchoolCardData.fromJson)
          .toList(),
      recommendations: metadata['recommendations'] is Map<String, dynamic>
          ? _AiRecommendations.fromJson(
              metadata['recommendations'] as Map<String, dynamic>,
            )
          : null,
      actions: (metadata['actions'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(_AiAction.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': text,
      'metadata': {
        if (schoolCards != null)
          'school_cards': schoolCards!.map((item) => item.toJson()).toList(),
        if (recommendations != null)
          'recommendations': recommendations!.toJson(),
        if (actions != null)
          'actions': actions!.map((item) => item.toJson()).toList(),
      },
    };
  }
}

class _AiAction {
  final String type;
  final String? schoolId;
  final String? schoolName;
  final String? programId;
  final String? programName;
  final String? tier;

  const _AiAction({
    required this.type,
    this.schoolId,
    this.schoolName,
    this.programId,
    this.programName,
    this.tier,
  });

  factory _AiAction.fromJson(Map<String, dynamic> json) {
    return _AiAction(
      type: json['type']?.toString() ?? 'add_to_tracker',
      schoolId: json['schoolId']?.toString(),
      schoolName: json['schoolName']?.toString(),
      programId: json['programId']?.toString(),
      programName: json['programName']?.toString(),
      tier: json['tier']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (schoolId != null) 'schoolId': schoolId,
      if (schoolName != null) 'schoolName': schoolName,
      if (programId != null) 'programId': programId,
      if (programName != null) 'programName': programName,
      if (tier != null) 'tier': tier,
    };
  }
}

class _AiSchoolCardData {
  final String id;
  final String nameZh;
  final String? nameEn;
  final String? country;
  final String? city;
  final int? rank;
  final String? logoUrl;
  final int programCount;

  const _AiSchoolCardData({
    required this.id,
    required this.nameZh,
    this.nameEn,
    this.country,
    this.city,
    this.rank,
    this.logoUrl,
    this.programCount = 0,
  });

  factory _AiSchoolCardData.fromJson(Map<String, dynamic> json) {
    final programs = json['programs'];
    final metrics = json['metrics'];
    final metricProgramCount =
        metrics is Map ? (metrics['total_programs'] as num?)?.toInt() : null;
    return _AiSchoolCardData(
      id: json['id'].toString(),
      nameZh:
          json['name_zh']?.toString() ?? json['name_en']?.toString() ?? '未命名院校',
      nameEn: json['name_en']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      rank: (json['qs_art_design_rank'] as num?)?.toInt() ??
          (json['qs_art_rank'] as num?)?.toInt(),
      logoUrl: json['logo_url']?.toString(),
      programCount:
          metricProgramCount ?? (programs is List ? programs.length : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_zh': nameZh,
      'name_en': nameEn,
      'country': country,
      'city': city,
      'qs_art_design_rank': rank,
      'logo_url': logoUrl,
      'metrics': {'total_programs': programCount},
    };
  }
}

class _AiSchoolAnalysisData {
  final String schoolId;
  final String schoolName;
  final int? matchScore;
  final List<String> strengths;
  final List<String> recommendations;

  const _AiSchoolAnalysisData({
    required this.schoolId,
    required this.schoolName,
    this.matchScore,
    this.strengths = const [],
    this.recommendations = const [],
  });

  factory _AiSchoolAnalysisData.fromJson(Map<String, dynamic> json) {
    return _AiSchoolAnalysisData(
      schoolId: json['schoolId']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '院校分析',
      matchScore: (json['matchScore'] as num?)?.toInt(),
      strengths: _stringList(json['strengths']),
      recommendations: _stringList(json['recommendations']),
    );
  }

  static List<_AiSchoolAnalysisData> listFromResult(
    Map<String, dynamic> result,
  ) {
    final raw = result['analyses'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_AiSchoolAnalysisData.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'schoolId': schoolId,
      'schoolName': schoolName,
      'matchScore': matchScore,
      'strengths': strengths,
      'recommendations': recommendations,
    };
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _AiRecommendations {
  final List<AppCase> cases;
  final List<_AiSchoolAnalysisData> analyses;

  const _AiRecommendations({
    this.cases = const [],
    this.analyses = const [],
  });

  factory _AiRecommendations.fromJson(Map<String, dynamic> json) {
    return _AiRecommendations(
      cases: (json['cases'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(_caseFromJson)
              .toList() ??
          const [],
      analyses: (json['analyses'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(_AiSchoolAnalysisData.fromJson)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cases': cases.map(_caseToJson).toList(),
      'analyses': analyses.map((item) => item.toJson()).toList(),
    };
  }

  static AppCase _caseFromJson(Map<String, dynamic> json) {
    return AppCase.fromJson({
      'id': json['id'],
      'title': json['title'],
      'undergrad': json['undergrad'],
      'gpa': json['gpa'],
      'target_school': json['target_school'],
      'target_program': json['target_program'],
      'result': json['result'],
      'content': json['content'],
      'excerpt': json['excerpt'],
      'cover_gradient': json['cover_gradient'],
      'is_anonymous': json['is_anonymous'],
      'tags': json['tags'],
      'year': json['year'],
      'like_count': json['like_count'],
      'comment_count': json['comment_count'],
      'save_count': json['save_count'],
      'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  static Map<String, dynamic> _caseToJson(AppCase item) {
    return {
      'id': item.id,
      'title': item.title,
      'undergrad': item.undergrad,
      'gpa': item.gpa,
      'target_school': item.targetSchool,
      'target_program': item.targetProgram,
      'result': item.result,
      'content': item.content,
      'excerpt': item.excerpt,
      'cover_gradient': item.coverGradient,
      'is_anonymous': item.isAnonymous,
      'tags': item.tags,
      'year': item.year,
      'like_count': item.likeCount,
      'comment_count': item.commentCount,
      'save_count': item.saveCount,
      'created_at': item.createdAt,
    };
  }
}

class _AiConversationSidebar extends StatelessWidget {
  final List<_AiConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final bool embedded;

  const _AiConversationSidebar({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onNew,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width:
          embedded ? double.infinity : MediaQuery.sizeOf(context).width * 0.78,
      height: double.infinity,
      color: context.artC.porcelain,
      padding: EdgeInsets.fromLTRB(16, embedded ? 20 : 56, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '最近聊天',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onNew,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: kCobalt,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kCobalt.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.add_comment_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    '新对话',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = conversations[index];
                final active = item.id == activeId;
                return GestureDetector(
                  onTap: () => onSelect(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: active
                          ? kCobalt.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active
                            ? kCobalt
                            : context.artC.silver.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: active
                              ? kCobalt
                              : context.artC.ink.withValues(alpha: 0.42),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active ? kCobalt : context.artC.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.messages.length} 条消息',
                                style: TextStyle(
                                  color:
                                      context.artC.ink.withValues(alpha: 0.38),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (embedded) return panel;
    return Material(color: Colors.transparent, child: panel);
  }
}

class _AiHero extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onOpenHistory;
  final VoidCallback onNewChat;

  const _AiHero({
    required this.profile,
    required this.onOpenHistory,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final countries = (profile?['target_countries'] as List?)?.join(' / ');
    final majors = (profile?['target_majors'] as List?)?.join(' / ');
    final summary = [
      if (profile?['target_degree'] != null) profile!['target_degree'],
      if (majors != null && majors.isNotEmpty) majors,
      if (countries != null && countries.isNotEmpty) countries,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [kShadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: kCobalt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 26),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenHistory,
                icon: const Icon(Icons.history),
                color: Colors.white,
                tooltip: '最近聊天',
              ),
              IconButton(
                onPressed: onNewChat,
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.white,
                tooltip: '新聊天',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'AI 申请工作台',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary.isEmpty ? '先问一个关于选校、作品集、预算或案例的问题。' : '你的方向：$summary',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptGrid extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;

  const _QuickPromptGrid({required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: prompts.map((prompt) {
        return GestureDetector(
          onTap: () => onTap(prompt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.65)),
            ),
            child: Text(
              prompt,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _AiMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final schoolCards = message.schoolCards ?? const <_AiSchoolCardData>[];
    final recommendations = message.recommendations;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: isUser ? null : const Radius.circular(4),
          ),
          border: isUser
              ? null
              : Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : context.artC.ink.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isUser && schoolCards.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...schoolCards.map((school) => _AiSchoolCard(school: school)),
            ],
            if (!isUser && recommendations != null) ...[
              const SizedBox(height: 12),
              _AiRecommendationsPanel(recommendations: recommendations),
            ],
            if (!isUser && message.actions != null && message.actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...message.actions!.map((action) => _AiActionButton(action: action)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiSchoolCard extends StatelessWidget {
  final _AiSchoolCardData school;

  const _AiSchoolCard({required this.school});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (school.city != null && school.city!.isNotEmpty) school.city!,
      if (school.country != null && school.country!.isNotEmpty) school.country!,
      if (school.programCount > 0) '${school.programCount} 个项目',
    ].join(' · ');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SchoolDetailEnhancedScreen(id: school.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.artC.porcelain,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          children: [
            _AiSchoolLogo(school: school),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.nameZh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (school.nameEn != null && school.nameEn!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      school.nameEn!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.48),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (school.rank != null)
                        _AiSchoolMetaChip(label: 'QS #${school.rank}'),
                      if (meta.isNotEmpty) _AiSchoolMetaChip(label: meta),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: context.artC.ink.withValues(alpha: 0.32),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSchoolLogo extends StatelessWidget {
  final _AiSchoolCardData school;

  const _AiSchoolLogo({required this.school});

  @override
  Widget build(BuildContext context) {
    final logoUrl = school.logoUrl;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.42),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _AiSchoolLogoFallback(school),
            )
          : _AiSchoolLogoFallback(school),
    );
  }
}

class _AiSchoolLogoFallback extends StatelessWidget {
  final _AiSchoolCardData school;

  const _AiSchoolLogoFallback(this.school);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        school.nameZh.isEmpty ? 'A' : school.nameZh.substring(0, 1),
        style: const TextStyle(
          color: kCobalt,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AiSchoolMetaChip extends StatelessWidget {
  final String label;

  const _AiSchoolMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.58),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AiRecommendationsPanel extends StatelessWidget {
  final _AiRecommendations recommendations;

  const _AiRecommendationsPanel({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCobalt.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '下一步推荐',
            style: TextStyle(
              color: kCobalt,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (recommendations.analyses.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...recommendations.analyses
                .take(2)
                .map((analysis) => _AiAnalysisTile(analysis: analysis)),
          ],
          if (recommendations.cases.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...recommendations.cases
                .take(2)
                .map((item) => _AiCaseTile(item: item)),
          ],
        ],
      ),
    );
  }
}

class _AiAnalysisTile extends StatelessWidget {
  final _AiSchoolAnalysisData analysis;

  const _AiAnalysisTile({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final line = [
      if (analysis.matchScore != null) '匹配度 ${analysis.matchScore}',
      if (analysis.strengths.isNotEmpty) analysis.strengths.first,
      if (analysis.recommendations.isNotEmpty) analysis.recommendations.first,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_graph_rounded, size: 16, color: kCobalt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${analysis.schoolName}${line.isEmpty ? '' : '\n$line'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.72),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCaseTile extends StatelessWidget {
  final AppCase item;

  const _AiCaseTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.targetSchool != null) item.targetSchool!,
      if (item.targetProgram != null) item.targetProgram!,
      if (item.year != null) item.year!,
    ].join(' · ');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseId: item.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kCobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.verified_outlined, color: kCobalt, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.46),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: context.artC.ink.withValues(alpha: 0.28)),
          ],
        ),
      ),
    );
  }
}

class _AiActionButton extends StatefulWidget {
  final _AiAction action;

  const _AiActionButton({required this.action});

  @override
  State<_AiActionButton> createState() => _AiActionButtonState();
}

class _AiActionButtonState extends State<_AiActionButton> {
  bool _adding = false;

  Future<void> _handleAction() async {
    if (_adding) return;
    final action = widget.action;
    if (action.type == 'add_to_tracker') {
      final schoolId = action.schoolId;
      final schoolName = action.schoolName;
      if (schoolId == null || schoolName == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缺少院校信息，无法添加')),
        );
        return;
      }
      setState(() => _adding = true);
      try {
        await BackendApiService.addToTracker(
          schoolId: schoolId,
          schoolName: schoolName,
          programId: action.programId,
          programName: action.programName,
          tier: action.tier ?? 'match',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加「$schoolName」到申请清单')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败：$e')),
        );
      } finally {
        if (mounted) setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    String label = '添加到申请清单';
    IconData icon = Icons.playlist_add;
    if (action.type == 'view_cases') {
      label = '查看相关案例';
      icon = Icons.verified_outlined;
    }
    return GestureDetector(
      onTap: _adding ? null : _handleAction,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kCobalt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              _adding ? '添加中…' : label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _AiInputBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.42)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: context.artC.ink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.56)),
              boxShadow: [
                BoxShadow(
                  color: context.artC.ink.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '问问 AI：选校、专业、作品集、案例…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: context.artC.ink.withValues(alpha: 0.32),
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.fromLTRB(
                        18,
                        14,
                        10,
                        14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: sending ? null : onSend,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sending
                            ? context.artC.ink.withValues(alpha: 0.16)
                            : kCobalt,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
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
