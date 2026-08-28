import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../data/mock_compare_schools.dart';
import '../../models/models.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/common.dart';
import '../../widgets/deep_sea_ui.dart';
import '../../theme/artsee_ui_colors.dart';
import '../forum/forum_screen.dart' show CircleDetailScreen;
import '../main_scaffold.dart';
import '_emoji_picker.dart';

class _AiPromptItem {
  final IconData icon;
  final String text;

  const _AiPromptItem(this.icon, this.text);
}

class _AiHomeProfileConfig {
  final String profileKey;
  final String heroTitle;
  final String heroSubtitle;
  final String startButtonLabel;
  final String welcomeText;
  final String defaultPrompt;
  final String chatTitle;
  final String chatSubtitle;
  final String emptyConversationText;
  final String aiMode;
  final List<_AiPromptItem> promptCloudItems;
  final List<String> quickChips;
  final List<_AiPromptItem> emptyActions;

  const _AiHomeProfileConfig({
    required this.profileKey,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.startButtonLabel,
    required this.welcomeText,
    required this.defaultPrompt,
    required this.chatTitle,
    required this.chatSubtitle,
    required this.emptyConversationText,
    required this.aiMode,
    required this.promptCloudItems,
    required this.quickChips,
    required this.emptyActions,
  });

  static const general = _AiHomeProfileConfig(
    profileKey: 'general',
    heroTitle: '艺见心 AI 艺术助手',
    heroSubtitle: '帮你探索艺术学习、创作、展览、收藏与合作机会',
    startButtonLabel: '开始探索艺术',
    welcomeText:
        '你好，我是艺见心 AI 艺术助手。\n\n你可以告诉我你的身份、目标、城市和现在最想解决的问题。\n\n我会帮你梳理学习、创作、展览、收藏或合作机会，并给出下一步建议。',
    defaultPrompt: '我想探索艺术学习、创作、展览、收藏或合作机会，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 艺术助手',
    chatSubtitle: '学习 / 创作 / 展览 / 收藏',
    emptyConversationText: '开始一次 AI 艺术咨询后，我会帮你保存学习、创作、展览、收藏和合作讨论。',
    aiMode: 'general',
    promptCloudItems: [
      _AiPromptItem(Icons.auto_awesome_outlined, '先问我几个问题'),
      _AiPromptItem(Icons.palette_outlined, '帮我梳理艺术方向'),
      _AiPromptItem(Icons.event_available_outlined, '推荐艺术活动和机会'),
      _AiPromptItem(Icons.explore_outlined, '我适合从哪里开始？'),
    ],
    quickChips: ['先问我几个问题', '梳理艺术方向', '推荐艺术机会', '下一步怎么做'],
    emptyActions: [
      _AiPromptItem(Icons.auto_awesome_outlined, '先问我几个问题'),
      _AiPromptItem(Icons.palette_outlined, '梳理艺术方向'),
      _AiPromptItem(Icons.event_available_outlined, '推荐艺术机会'),
    ],
  );

  static const student = _AiHomeProfileConfig(
    profileKey: 'student',
    heroTitle: '艺见心 AI 申请顾问',
    heroSubtitle: '帮你选校、拆申请时间线、分析作品集与文书方向',
    startButtonLabel: '开始规划申请',
    welcomeText:
        '你好，我是艺见心 AI 申请顾问。\n\n你可以告诉我：目标国家、专业方向、预算、语言成绩、作品集进度。\n\n我会帮你拆成冲刺 / 匹配 / 保底院校建议、材料重点、作品集方向和下一步时间线。',
    defaultPrompt: '我想做艺术留学规划，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 申请顾问',
    chatSubtitle: '选校 / 作品集 / 时间线',
    emptyConversationText: '开始一次 AI 申请咨询后，我会帮你保存选校、作品集和时间线讨论。',
    aiMode: 'student',
    promptCloudItems: [
      _AiPromptItem(Icons.auto_awesome_outlined, '先问我几个问题'),
      _AiPromptItem(Icons.school_outlined, '帮我推荐院校'),
      _AiPromptItem(Icons.auto_fix_high_outlined, '分析我的作品集方向'),
      _AiPromptItem(Icons.calendar_today_outlined, '生成申请时间线'),
    ],
    quickChips: ['先问我几个问题', '帮我推荐院校', '分析我的作品集方向', '生成申请时间线'],
    emptyActions: [
      _AiPromptItem(Icons.calendar_today_outlined, '制定申请计划'),
      _AiPromptItem(Icons.auto_fix_high_outlined, '作品集诊断'),
      _AiPromptItem(Icons.compare_arrows_rounded, '院校对比'),
    ],
  );

  static const artist = _AiHomeProfileConfig(
    profileKey: 'artist',
    heroTitle: '艺见心 AI 艺术家助手',
    heroSubtitle: '帮你展示作品、匹配展览机会、对接品牌合作与收藏资源',
    startButtonLabel: '开始经营作品',
    welcomeText:
        '你好，我是艺见心 AI 艺术家助手。\n\n你可以告诉我你的艺术方向、作品系列、展览经历或合作目标。\n\n我可以帮你整理作品介绍、匹配展览机会、规划品牌合作路径。',
    defaultPrompt: '我想经营艺术作品和职业发展，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 艺术家助手',
    chatSubtitle: '展览 / 作品 / 合作',
    emptyConversationText: '开始一次 AI 艺术家咨询后，我会帮你保存作品表达、展览机会和合作路径讨论。',
    aiMode: 'artist',
    promptCloudItems: [
      _AiPromptItem(Icons.event_available_outlined, '怎么申请展览？'),
      _AiPromptItem(Icons.description_outlined, '帮我整理作品介绍'),
      _AiPromptItem(Icons.handshake_outlined, '品牌联名怎么谈？'),
      _AiPromptItem(Icons.sell_outlined, '我的作品怎么定价？'),
    ],
    quickChips: ['帮我诊断艺术家主页', '怎么申请展览？', '匹配品牌合作方向', '帮我写作品介绍'],
    emptyActions: [
      _AiPromptItem(Icons.event_available_outlined, '申请展览'),
      _AiPromptItem(Icons.description_outlined, '整理作品介绍'),
      _AiPromptItem(Icons.handshake_outlined, '品牌合作方向'),
    ],
  );

  static const collector = _AiHomeProfileConfig(
    profileKey: 'collector',
    heroTitle: '艺见心 AI 艺术顾问',
    heroSubtitle: '帮你发现展览、理解艺术市场、学习鉴赏与收藏',
    startButtonLabel: '开始探索艺术',
    welcomeText:
        '你好，我是艺见心 AI 艺术顾问。\n\n你可以告诉我你喜欢的艺术风格、预算、城市、想看的展览或想了解的艺术家。\n\n我会帮你推荐展览活动、解释作品价值、梳理收藏入门路径和艺术市场信息。',
    defaultPrompt: '我想了解展览、鉴赏和收藏入门，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 艺术顾问',
    chatSubtitle: '看展 / 鉴赏 / 收藏',
    emptyConversationText: '开始一次 AI 艺术顾问咨询后，我会帮你保存看展、鉴赏、收藏和艺术家背景讨论。',
    aiMode: 'collector',
    promptCloudItems: [
      _AiPromptItem(Icons.confirmation_number_outlined, '最近有什么值得看的展？'),
      _AiPromptItem(Icons.visibility_outlined, '如何看懂一件作品？'),
      _AiPromptItem(Icons.collections_bookmark_outlined, '新手怎么开始收藏？'),
      _AiPromptItem(Icons.person_search_outlined, '这个艺术家值得关注吗？'),
    ],
    quickChips: ['推荐适合我的展览', '教我看懂一件作品', '新手收藏怎么开始', '帮我了解艺术家背景'],
    emptyActions: [
      _AiPromptItem(Icons.confirmation_number_outlined, '推荐展览'),
      _AiPromptItem(Icons.visibility_outlined, '看懂作品'),
      _AiPromptItem(Icons.collections_bookmark_outlined, '收藏入门'),
    ],
  );

  static const parent = _AiHomeProfileConfig(
    profileKey: 'parent',
    heroTitle: '艺见心 AI 留学顾问',
    heroSubtitle: '帮你了解院校、费用、申请路径和作品集准备节奏',
    startButtonLabel: '了解申请路径',
    welcomeText:
        '你好，我是艺见心 AI 留学顾问。\n\n你可以告诉我孩子目前年级、艺术方向、目标国家、预算和作品集进度。\n\n我会帮你拆清楚申请路径、费用范围、时间节点、院校选择和需要提前准备的材料。',
    defaultPrompt: '我想了解孩子的艺术留学申请路径，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 留学顾问',
    chatSubtitle: '院校 / 费用 / 路径',
    emptyConversationText: '开始一次 AI 留学咨询后，我会帮你保存院校、费用、申请路径和准备节奏讨论。',
    aiMode: 'parent',
    promptCloudItems: [
      _AiPromptItem(Icons.route_outlined, '孩子适合学什么专业？'),
      _AiPromptItem(Icons.payments_outlined, '艺术留学大概要多少钱？'),
      _AiPromptItem(Icons.schedule_outlined, '什么时候开始准备作品集？'),
      _AiPromptItem(Icons.fact_check_outlined, '怎么判断官方信息是否可靠？'),
    ],
    quickChips: ['孩子适合学什么专业？', '艺术留学大概要多少钱？', '什么时候开始准备作品集？', '怎么核对官方信息？'],
    emptyActions: [
      _AiPromptItem(Icons.route_outlined, '专业选择'),
      _AiPromptItem(Icons.payments_outlined, '留学费用'),
      _AiPromptItem(Icons.schedule_outlined, '准备时间'),
    ],
  );

  static const business = _AiHomeProfileConfig(
    profileKey: 'business',
    heroTitle: '艺见心 AI 机构助手',
    heroSubtitle: '帮你完善机构资料、发布课程活动、提升曝光和对接用户',
    startButtonLabel: '完善机构主页',
    welcomeText:
        '你好，我是艺见心 AI 机构助手。\n\n你可以告诉我机构类型、服务内容、目标用户、活动 / 课程 / 合作需求。\n\n我会帮你整理主页介绍、优化展示文案、规划发布内容，并给出提升曝光的建议。',
    defaultPrompt: '我想完善机构主页、发布内容并提升曝光，请先问我几个关键问题。',
    chatTitle: '艺见心 AI 机构助手',
    chatSubtitle: '入驻 / 发布 / 曝光',
    emptyConversationText: '开始一次 AI 机构咨询后，我会帮你保存主页介绍、课程活动、曝光和用户咨询讨论。',
    aiMode: 'business',
    promptCloudItems: [
      _AiPromptItem(Icons.storefront_outlined, '怎么完善机构主页？'),
      _AiPromptItem(Icons.menu_book_outlined, '如何发布课程 / 服务？'),
      _AiPromptItem(Icons.event_outlined, '怎么发布展览或活动？'),
      _AiPromptItem(Icons.trending_up_outlined, '如何提升曝光和咨询？'),
    ],
    quickChips: ['帮我优化机构介绍', '怎么发布课程服务', '怎么发布展览活动', '如何提高咨询转化'],
    emptyActions: [
      _AiPromptItem(Icons.storefront_outlined, '完善主页'),
      _AiPromptItem(Icons.menu_book_outlined, '发布课程'),
      _AiPromptItem(Icons.trending_up_outlined, '提升曝光'),
    ],
  );

  static _AiHomeProfileConfig fromProfile(Map<String, dynamic>? profile) {
    final userType =
        (profile?['userType'] ?? profile?['user_type'])?.toString();
    final userRole =
        (profile?['userRole'] ?? profile?['user_role'])?.toString();

    if (userType == 'business') return business;
    return switch (userRole) {
      'student' => student,
      'artist' => artist,
      'collector' => collector,
      'parent' => parent,
      _ => general,
    };
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onReturnToMain;
  final bool showWorkbenchShortcut;
  final bool compactTopChrome;
  final bool institutionLeadMode;
  final bool inheritDeepSeaBackdrop;
  final int plazaRefreshSignal;

  const HomeScreen({
    super.key,
    this.onReturnToMain,
    this.showWorkbenchShortcut = false,
    this.compactTopChrome = false,
    this.institutionLeadMode = false,
    this.inheritDeepSeaBackdrop = false,
    this.plazaRefreshSignal = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_HomeDopamineFeedState> _feedKey =
      GlobalKey<_HomeDopamineFeedState>();
  final TextEditingController _queryCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _profile;
  _AiHomeProfileConfig _aiConfig = _AiHomeProfileConfig.general;
  String? _currentConversationId;
  bool _sending = false;
  bool _conversationStarted = false;
  bool _chatInputVisible = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _recordingStopPending = false;
  DateTime? _recordingStartedAt;
  String? _speechLocaleId;
  String? _lastSpeechError;

  _AiHomeProfileConfig get _activeAiConfig {
    if (!widget.compactTopChrome) return _aiConfig;
    return _aiConfig.profileKey == 'student'
        ? _AiHomeProfileConfig.student
        : _AiHomeProfileConfig.general;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadHomeBackendData();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          _lastSpeechError = error.errorMsg;
          if (mounted) {
            setState(() {
              _isRecording = false;
              _recordingStopPending = false;
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording && !_recordingStopPending) {
              _stopRecordingAndSend();
            }
          }
        },
      );
      if (_speechAvailable) {
        _speechLocaleId = await _resolveSpeechLocaleId();
      }
    } catch (e) {
      _speechAvailable = false;
    }
  }

  Future<String?> _resolveSpeechLocaleId() async {
    try {
      final locales = await _speech.locales();
      const preferredLocaleIds = [
        'zh_CN',
        'zh-Hans-CN',
        'zh_Hans_CN',
        'zh-Hans',
        'zh_TW',
        'zh-Hant-TW',
        'zh_HK',
        'cmn_Hans_CN',
      ];

      for (final preferred in preferredLocaleIds) {
        for (final locale in locales) {
          if (locale.localeId == preferred) {
            return locale.localeId;
          }
        }
      }

      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (normalized == 'zh' ||
            normalized.startsWith('zh-') ||
            normalized.startsWith('cmn-')) {
          return locale.localeId;
        }
      }

      final systemLocale = await _speech.systemLocale();
      return systemLocale?.localeId;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    MainScaffold.globalKey.currentState?.setHomeNavHidden(false);
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadHomeBackendData() async {
    List<Map<String, dynamic>> conversations = [];
    Map<String, dynamic>? profileData;

    if (SupabaseService.isLoggedIn) {
      try {
        conversations = await BackendApiService.getAiConversations();
      } catch (_) {}

      try {
        final profileResponse = await BackendApiService.fetchAuthProfile();
        profileData = profileResponse['profile'] is Map<String, dynamic>
            ? profileResponse['profile'] as Map<String, dynamic>
            : profileResponse.isEmpty
                ? null
                : profileResponse;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _conversations = conversations;
        _profile = profileData;
        _aiConfig = _AiHomeProfileConfig.fromProfile(profileData);
      });
    }
  }

  Map<String, dynamic> _welcomeMessage() {
    return <String, dynamic>{
      'role': 'assistant',
      'text': _activeAiConfig.welcomeText,
      'sources': <Map<String, dynamic>>[],
    };
  }

  void _normalizeMessagesForHotReload() {
    _messages = _messages
        .map(
          (message) => <String, dynamic>{
            'role': message['role']?.toString() ?? 'assistant',
            'text': message['text']?.toString() ?? '',
            'sources': (message['sources'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (source) => source.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
                .toList(),
          },
        )
        .toList();
  }

  void _startConversation() {
    if (_conversationStarted) {
      _showChatInput();
      return;
    }
    _normalizeMessagesForHotReload();
    setState(() {
      _conversationStarted = true;
      _chatInputVisible = true;
      _messages.add(_welcomeMessage());
    });
    MainScaffold.globalKey.currentState?.setHomeNavHidden(true);
    _scrollBottom();
  }

  bool _handleScroll(UserScrollNotification notification) {
    if (!_conversationStarted ||
        notification.direction == ScrollDirection.idle) {
      return false;
    }
    if (notification.direction == ScrollDirection.reverse) {
      _showMainNav();
    } else if (notification.direction == ScrollDirection.forward) {
      _showChatInput();
    }
    return false;
  }

  void _showChatInput() {
    if (mounted && !_chatInputVisible) {
      setState(() => _chatInputVisible = true);
    }
    MainScaffold.globalKey.currentState?.setHomeNavHidden(true);
  }

  void _showMainNav() {
    FocusScope.of(context).unfocus();
    if (mounted && (_chatInputVisible || _showEmojiPicker)) {
      setState(() {
        _chatInputVisible = false;
        _showEmojiPicker = false;
      });
    }
    MainScaffold.globalKey.currentState?.setHomeNavHidden(false);
  }

  void _returnToMainInterface() {
    FocusScope.of(context).unfocus();
    final customReturn = widget.onReturnToMain;
    if (customReturn != null) {
      customReturn();
      return;
    }
    MainScaffold.globalKey.currentState?.switchToTab(1);
  }

  void _openDebateForum() {
    FocusScope.of(context).unfocus();
    MainScaffold.globalKey.currentState?.switchToTab(3);
  }

  void _openExploreSurface() {
    FocusScope.of(context).unfocus();
    MainScaffold.globalKey.currentState?.switchToTab(2);
  }

  Future<void> _openAskQuestion({
    String? initialTitle,
    String? initialCategory,
  }) async {
    FocusScope.of(context).unfocus();
    final createdTitle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlazaQuestionSheet(
        initialTitle: initialTitle,
        initialCategory: initialCategory,
      ),
    );
    if (createdTitle == null || !mounted) return;
    _feedKey.currentState?._loadLegacyPlazaPosts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问题已进入广场')),
    );
  }

  void _handleChatDragEnd(DragEndDetails details) {
    if (!_conversationStarted) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -120) {
      _showMainNav();
    } else if (velocity > 120) {
      _showChatInput();
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final id = conversation['id']?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context).maybePop();
    try {
      final data = await BackendApiService.getAiConversation(id);
      final messages = data['messages'] as List<dynamic>? ?? [];
      if (!mounted) return;
      _normalizeMessagesForHotReload();
      setState(() {
        _conversationStarted = true;
        _chatInputVisible = true;
        _currentConversationId = id;
        _messages
          ..clear()
          ..addAll(messages.map((m) => <String, dynamic>{
                'role': m['role']?.toString() ?? 'assistant',
                'text': m['content']?.toString() ?? '',
                'sources': <Map<String, dynamic>>[],
              }));
      });
      MainScaffold.globalKey.currentState?.setHomeNavHidden(true);
      _scrollBottom();
    } catch (_) {}
  }

  Future<void> _runPrompt([String? preset]) async {
    final query = (preset ?? _queryCtrl.text).trim();
    final config = _activeAiConfig;
    final text = query.isEmpty ? config.defaultPrompt : query;
    if (_sending) return;
    _normalizeMessagesForHotReload();
    setState(() {
      _conversationStarted = true;
      _chatInputVisible = true;
      _messages.add(<String, dynamic>{
        'role': 'user',
        'text': text,
        'sources': <Map<String, dynamic>>[],
      });
      _sending = true;
    });
    MainScaffold.globalKey.currentState?.setHomeNavHidden(true);
    _queryCtrl.clear();
    _scrollBottom();

    await _ensureConversation(text);
    await _saveMessage(role: 'user', content: text);

    String reply;
    List<Map<String, dynamic>> sources = const [];
    try {
      final aiMessages = _messages
          .map((m) => <String, dynamic>{
                'role': m['role'] == 'assistant' ? 'assistant' : 'user',
                'content': (m['text'] ?? m['content'] ?? '').toString(),
              })
          .where((m) => (m['content'] as String).trim().isNotEmpty)
          .toList();
      final result = await BackendApiService.aiConsult(
        text,
        mode: config.aiMode,
        persona: config.profileKey,
        intent: 'home_${config.profileKey}_chat',
        context: {
          'surface': 'app_home_ai',
          'profileKey': config.profileKey,
        },
        messages: aiMessages,
        userProfile: {
          if (_profile != null) ..._profile!,
          'aiProfileKey': config.profileKey,
        },
      );
      reply = _formatConsultReply(result);
      sources = _extractSources(result);
    } catch (e) {
      reply = _buildFallbackReply(text, e);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(<String, dynamic>{
        'role': 'assistant',
        'text': reply,
        'sources': sources,
      });
      _sending = false;
    });
    _scrollBottom();
    await _saveMessage(role: 'assistant', content: reply);
  }

  Future<void> _ensureConversation(String firstMessage) async {
    if (!SupabaseService.isLoggedIn) return;
    if (_currentConversationId != null) return;
    try {
      final conversation = await BackendApiService.createAiConversation(
        title: firstMessage.length > 30
            ? '${firstMessage.substring(0, 30)}...'
            : firstMessage,
        aiProfileKey: _activeAiConfig.profileKey,
        userRoleSnapshot:
            (_profile?['userRole'] ?? _profile?['user_role'])?.toString(),
        userTypeSnapshot:
            (_profile?['userType'] ?? _profile?['user_type'])?.toString(),
      );
      _currentConversationId = conversation['id'] as String?;
      if (mounted) {
        setState(() {
          _conversations = [conversation, ..._conversations];
        });
      }
    } catch (_) {
      _currentConversationId = null;
    }
  }

  Future<void> _saveMessage({
    required String role,
    required String content,
  }) async {
    if (!SupabaseService.isLoggedIn) return;
    final conversationId = _currentConversationId;
    if (conversationId == null) return;
    try {
      await BackendApiService.saveAiMessage(
        conversationId: conversationId,
        role: role,
        content: content,
      );
    } catch (_) {}
  }

  String _formatConsultReply(Map<String, dynamic> response) {
    final answer = response['answer']?.toString().trim();
    if (answer != null && answer.isNotEmpty) return answer;
    final result = response['result'];
    if (result is Map<String, dynamic>) return _formatAiReply(response);
    return result?.toString() ?? '我已经收到你的问题，但暂时没有生成可展示的建议。';
  }

  List<Map<String, dynamic>> _extractSources(Map<String, dynamic> response) {
    final rawSources = response['sources'];
    if (rawSources is! List) return const [];
    return rawSources
        .whereType<Map>()
        .take(6)
        .map((source) => source.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }

  String _formatAiReply(Map<String, dynamic> response) {
    final result = response['result'];
    if (result is! Map<String, dynamic>) {
      return result?.toString() ?? '我已经收到你的问题，但暂时没有生成可展示的结构化建议。';
    }

    final lines = <String>[];
    final summary = result['summary']?.toString().trim();
    if (summary != null && summary.isNotEmpty) {
      lines.add(summary);
    }

    final recommendations = result['recommendations'];
    if (recommendations is List && recommendations.isNotEmpty) {
      lines.add('推荐方向：');
      for (final item in recommendations.take(4)) {
        if (item is Map) {
          final school = item['school']?.toString() ?? '目标院校';
          final reason = item['reason']?.toString() ?? '';
          lines.add('· $school：$reason');
        }
      }
    }

    final tips = result['tips'];
    if (tips is List && tips.isNotEmpty) {
      lines.add('下一步建议：');
      for (final tip in tips.take(3)) {
        lines.add('· ${tip.toString()}');
      }
    }

    return lines.isEmpty ? '我已经收到你的问题，但暂时没有生成可展示的结构化建议。' : lines.join('\n\n');
  }

  String _displayMessageText(String text) {
    return text
        .split('\n')
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
            return trimmed
                .split('|')
                .map((cell) => cell.trim())
                .where((cell) =>
                    cell.isNotEmpty && !RegExp(r'^:?-{2,}:?$').hasMatch(cell))
                .join('  /  ');
          }
          return line.replaceAll('|', ' | ');
        })
        .join('\n')
        .replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '· ')
        .replaceAll('*', '')
        .replaceAll(RegExp(r'\s*\[\d+\]'), '')
        .replaceAllMapped(
          RegExp(r'[A-Za-z0-9_./:#?=&%-]{24,}'),
          (match) => match.group(0)!.replaceAllMapped(
                RegExp(r'.{1,16}'),
                (part) => '${part.group(0)} ',
              ),
        );
  }

  String _buildFallbackReply(String question, Object error) {
    final config = _activeAiConfig;
    if (config.profileKey != 'student' && config.profileKey != 'parent') {
      return [
        '当前 AI 或后端环境还没完全配置好，我先按“${config.heroTitle}”的方向给你一个可执行判断。',
        '你可以补充身份、城市、目标、预算或当前阶段，我会先帮你整理问题结构和下一步行动。',
        '等 AI Key 与 Supabase Service Role 配好后，这里会自动切换成数据库 + AI 的真实回答。',
      ].join('\n\n');
    }
    final schools = _filterMockSchools(question).take(3).toList();
    final schoolLines = schools
        .map(
          (s) =>
              '· ${s.name}：${s.cityCountry}，${s.language}，参考学费 ${s.tuition}，适合作为${s.difficulty}档位继续核对。',
        )
        .join('\n');
    return [
      '当前 AI 或后端环境还没完全配置好，我先基于本地院校样例给你一个可执行判断。',
      if (schoolLines.isNotEmpty) schoolLines,
      '建议你下一步补充目标国家、专业方向、预算、语言成绩和作品集进度；等 OPENAI_API_KEY/MOONSHOT_API_KEY 与 Supabase Service Role 配好后，这里会自动切换成数据库 + AI 的真实回答。',
    ].join('\n\n');
  }

  List<CompareSchool> _filterMockSchools(String question) {
    final q = question.toLowerCase();
    final matched = kMockCompareSchools.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.enName.toLowerCase().contains(q) ||
          s.tags.any((tag) => q.contains(tag.toLowerCase())) ||
          q.contains(s.name.toLowerCase()) ||
          q.contains(s.enName.toLowerCase());
    }).toList();
    return matched.isEmpty ? kMockCompareSchools : matched;
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openPhotoPicker() async {
    if (!await ensureLoggedIn(context, message: '请先登录后上传图片分析')) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _sendImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _sendImage(XFile image) async {
    if (_sending) return;

    _normalizeMessagesForHotReload();
    setState(() {
      _conversationStarted = true;
      _chatInputVisible = true;
      _sending = true;
      _messages.add(<String, dynamic>{
        'role': 'user',
        'text': '[图片]',
        'sources': <Map<String, dynamic>>[],
      });
    });
    MainScaffold.globalKey.currentState?.setHomeNavHidden(true);
    _scrollBottom();

    await _ensureConversation('[图片]');

    String reply;
    try {
      final result = await BackendApiService.uploadImageAndAnalyze(
        bytes: await image.readAsBytes(),
        filename: image.name.isNotEmpty ? image.name : 'artsee-image.jpg',
        contentType: image.mimeType ?? 'image/jpeg',
        conversationId: _currentConversationId,
      );

      reply = result['answer']?.toString() ?? '图片已收到，正在分析中...';

      await _saveMessage(role: 'user', content: '[图片]');
    } catch (e) {
      reply = '图片上传失败: $e\n\n请稍后重试或尝试其他图片。';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(<String, dynamic>{
        'role': 'assistant',
        'text': reply,
        'sources': <Map<String, dynamic>>[],
      });
      _sending = false;
    });
    _scrollBottom();
    await _saveMessage(role: 'assistant', content: reply);
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _queryCtrl.text;
    final selection = _queryCtrl.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _queryCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording || _recordingStopPending) return;

    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          final permanentlyDenied = micStatus.isPermanentlyDenied;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permanentlyDenied
                    ? '麦克风权限已关闭，请到系统设置中允许后再使用语音输入'
                    : '需要麦克风权限才能使用语音输入',
              ),
              action: permanentlyDenied
                  ? const SnackBarAction(
                      label: '去设置',
                      onPressed: openAppSettings,
                    )
                  : null,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_speechUnavailableMessage()),
            action: kIsWeb
                ? null
                : const SnackBarAction(
                    label: '去设置',
                    onPressed: openAppSettings,
                  ),
          ),
        );
      }
      return;
    }

    if (kIsWeb && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在调用浏览器语音识别，请允许麦克风权限'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    _speechLocaleId ??= await _resolveSpeechLocaleId();

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
      _recordingStopPending = false;
      _recordingStartedAt = DateTime.now();
      _lastSpeechError = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognizedWords = result.recognizedWords.trim();
          if (recognizedWords.isEmpty) return;
          setState(() {
            _recognizedText = recognizedWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 3),
          localeId: _speechLocaleId,
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingStopPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_speechFailureMessage(e))),
        );
      }
    }
  }

  String _speechUnavailableMessage() {
    if (kIsWeb) {
      return '当前浏览器不支持语音识别。请使用 Chrome 或 Edge，并允许网页麦克风权限';
    }
    return '语音识别不可用。Android 请确认 Google/系统语音服务可用，iOS 请开启系统语音识别权限';
  }

  String _speechFailureMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('not-allowed') ||
        raw.contains('service-not-allowed') ||
        raw.contains('permission') ||
        raw.contains('denied')) {
      return kIsWeb
          ? '浏览器麦克风权限被拒绝，请在地址栏允许麦克风后重试'
          : '麦克风或语音识别权限被拒绝，请到系统设置中开启后重试';
    }
    if (raw.contains('no-speech') || raw.contains('no_match')) {
      return '没有听清语音内容，请靠近麦克风后重试';
    }
    if (raw.contains('audio-capture')) {
      return '没有检测到可用麦克风，请检查设备输入';
    }
    if (raw.contains('network')) {
      return '语音识别网络连接失败，请稍后重试';
    }
    return '系统语音识别失败: $error';
  }

  String _speechNoResultMessage() {
    if (_lastSpeechError == null) {
      return '没有听清语音内容，请按住说完后再松开';
    }
    return _speechFailureMessage(_lastSpeechError!);
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording || _recordingStopPending) return;

    setState(() => _recordingStopPending = true);

    final startedAt = _recordingStartedAt;
    if (startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      const minimumListenDuration = Duration(milliseconds: 900);
      if (elapsed < minimumListenDuration) {
        await Future.delayed(minimumListenDuration - elapsed);
      }
    }

    try {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 450));

      final recognizedText = _recognizedText.trim();
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _recordingStopPending = false;
        _recordingStartedAt = null;
      });

      if (recognizedText.isNotEmpty) {
        await _runPrompt(recognizedText);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_speechNoResultMessage())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingStopPending = false;
          _recordingStartedAt = null;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止识别失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      await BackendApiService.deleteAiConversation(conversationId);
      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c['id'] == conversationId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除对话')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _startNewChat() {
    _normalizeMessagesForHotReload();
    setState(() {
      _conversationStarted = true;
      _chatInputVisible = true;
      _sending = false;
      _showEmojiPicker = false;
      _isRecording = false;
      _currentConversationId = null;
      _queryCtrl.clear();
      _messages.clear();
      _messages.add(_welcomeMessage());
    });
    MainScaffold.globalKey.currentState?.setHomeNavHidden(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeConfig = _activeAiConfig;
    final deepSeaMode = widget.compactTopChrome;
    final tabInset = mainTabBottomInset(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const composerBottom = 0.0;
    final inputMode = _conversationStarted && _chatInputVisible;
    final bottomComposerSpace = inputMode ? 88.0 + safeBottom : tabInset + 32;
    final safeTop = MediaQuery.paddingOf(context).top > 0
        ? MediaQuery.paddingOf(context).top
        : 44.0;
    final feedTopPadding = widget.compactTopChrome ? 14.0 : safeTop + 60;

    final pageBody = NotificationListener<UserScrollNotification>(
      onNotification: _handleScroll,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: _handleChatDragEnd,
        child: Stack(
          children: [
            if (!widget.compactTopChrome)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopAura(),
              ),
            if (_conversationStarted) ...[
              _HomeChatView(
                messages: _messages,
                sending: _sending,
                scrollController: _scrollCtrl,
                bottomPadding: bottomComposerSpace,
                displayText: _displayMessageText,
                onQuickAction: _runPrompt,
                quickChips: activeConfig.quickChips,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ChatHeader(
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onActionTap: inputMode ? _showMainNav : _showChatInput,
                  onReturnTap: _returnToMainInterface,
                  showAppsIcon: inputMode,
                  title: activeConfig.chatTitle,
                  subtitle: activeConfig.chatSubtitle,
                ),
              ),
            ] else
              SingleChildScrollView(
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  20,
                  feedTopPadding,
                  20,
                  bottomComposerSpace,
                ),
                child: _HomeDopamineFeed(
                  key: _feedKey,
                  config: activeConfig,
                  simplified: widget.compactTopChrome,
                  institutionLeadMode:
                      widget.compactTopChrome && widget.institutionLeadMode,
                  refreshSignal: widget.plazaRefreshSignal,
                  onStartAi: _startConversation,
                  onPrompt: _runPrompt,
                  onOpenForum: _openDebateForum,
                  onOpenExplore: _openExploreSurface,
                  onOpenWorkbench: _returnToMainInterface,
                  onAskQuestion: _openAskQuestion,
                  showWorkbench: widget.showWorkbenchShortcut,
                ),
              ),
            if (!_conversationStarted && !widget.compactTopChrome) ...[
              Positioned(
                left: 8,
                top: safeTop + 4,
                child: _HeaderIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
            ],
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: inputMode ? composerBottom : -120,
              child: IgnorePointer(
                ignoring: !inputMode,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: inputMode ? 1 : 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showEmojiPicker)
                        EmojiPicker(onEmojiTap: _insertEmoji),
                      _BottomAskBar(
                        controller: _queryCtrl,
                        onSubmit: () => _runPrompt(),
                        onEmojiTap: _toggleEmojiPicker,
                        onPhotoTap: _openPhotoPicker,
                        onRecordStart: _startRecording,
                        onRecordEnd: _stopRecordingAndSend,
                        sending: _sending,
                        showEmojiPicker: _showEmojiPicker,
                        isRecording: _isRecording,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final homeBody = DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: kAppFontFamily,
        fontFamilyFallback: kAppFontFallback,
        letterSpacing: 0,
      ),
      child: pageBody,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: deepSeaMode
          ? widget.inheritDeepSeaBackdrop
              ? Colors.transparent
              : kDeepSeaBackground
          : Colors.white,
      onDrawerChanged: (isOpened) {
        final shouldHideNav =
            isOpened || (_conversationStarted && _chatInputVisible);
        MainScaffold.globalKey.currentState?.setHomeNavHidden(shouldHideNav);
      },
      drawer: _ConversationDrawer(
        conversations: _conversations,
        config: activeConfig,
        onConversationTap: _openConversation,
        onConversationDelete: _deleteConversation,
        onNewChat: _startNewChat,
      ),
      body: deepSeaMode && !widget.inheritDeepSeaBackdrop
          ? DeepSeaBackdrop(child: homeBody)
          : homeBody,
    );
  }
}

const _porcelainDeepBlue = Color(0xFF001D51);
const _porcelainNightBlue = Color(0xFF07111F);
const _inkWashBlue = Color(0xFF0A1833);
const _inkGlowBlue = Color(0xFF173A6A);
const _inkMistBlue = Color(0xFF8FA9C7);
const _debateCoral = Color(0xFFE85D3F);
const _debateGold = Color(0xFFC8A45D);
const _debateJade = Color(0xFF0E8F78);
const _debateLilac = Color(0xFF6F8FB7);
const _instaCanvas = Colors.white;
const _instaBorder = Color(0xFFE2DED5);
const _instaInk = Color(0xFF111111);
const _instaMuted = Color(0xFF737373);
const _instaRose = _porcelainDeepBlue;
const _instaOrange = _debateGold;
const _instaPurple = _inkWashBlue;
const _plazaInk = Color(0xFF171A1F);
const _plazaText = Color(0xFF3F4650);
const _plazaMuted = Color(0xFF6F7782);
const _plazaBorder = Color(0xFFE6EAF0);
const _plazaSoft = Color(0xFFF7F9FC);
const _inkWashGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_porcelainNightBlue, _inkWashBlue, _inkGlowBlue],
  stops: [0, 0.58, 1],
);

TextStyle _homeFeedTitleStyle({
  required Color color,
  double fontSize = 16,
  double height = 1.2,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: 0,
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
  );
}

TextStyle _homeFeedInfoStyle({
  required Color color,
  double fontSize = 12.8,
  double height = 1.32,
  FontWeight fontWeight = FontWeight.w500,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: 0,
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
  );
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _PressableScale({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (widget.onTap == null || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _InstaAvatar extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color iconColor;

  const _InstaAvatar({
    required this.icon,
    this.size = 38,
    this.iconColor = _instaInk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [_instaOrange, _instaRose, _instaPurple],
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(icon, size: size * 0.45, color: iconColor),
      ),
    );
  }
}

class _DebateTopic {
  final AppCommunityPost? leadPost;
  final String channel;
  final String track;
  final String category;
  final String status;
  final String timeLeft;
  final String title;
  final String lead;
  final String pro;
  final String con;
  final int proPercent;
  final String heat;
  final String comments;
  final String floor;
  final String hotComment;
  final String proComment;
  final String conComment;
  final String agentPersona;
  final String agentReply;
  final String askSeed;
  final List<String> tags;
  final IconData icon;
  final Color accent;

  const _DebateTopic({
    this.leadPost,
    required this.channel,
    required this.track,
    required this.category,
    required this.status,
    required this.timeLeft,
    required this.title,
    required this.lead,
    required this.pro,
    required this.con,
    required this.proPercent,
    required this.heat,
    required this.comments,
    required this.floor,
    required this.hotComment,
    required this.proComment,
    required this.conComment,
    required this.agentPersona,
    required this.agentReply,
    required this.askSeed,
    required this.tags,
    required this.icon,
    required this.accent,
  });
}

class _PlazaRatingItem {
  final AppCommunityPost? leadPost;
  final String collection;
  final String title;
  final String subtitle;
  final String quote;
  final String score;
  final String ratingCount;
  final String likes;
  final String comments;
  final String source;
  final String time;
  final String coverSeed;
  final Color accent;
  final List<_PlazaRatingReply> replies;

  const _PlazaRatingItem({
    this.leadPost,
    required this.collection,
    required this.title,
    required this.subtitle,
    required this.quote,
    required this.score,
    required this.ratingCount,
    required this.likes,
    required this.comments,
    required this.source,
    required this.time,
    required this.coverSeed,
    required this.accent,
    required this.replies,
  });
}

class _PlazaRatingReply {
  final String author;
  final String date;
  final String body;
  final int likes;
  final Color avatarColor;

  const _PlazaRatingReply({
    required this.author,
    required this.date,
    required this.body,
    required this.likes,
    required this.avatarColor,
  });
}

class _DebateLane {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _DebateLane({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

class _StorySignal {
  final String label;
  final String count;
  final IconData icon;
  final Color accent;

  const _StorySignal({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
  });
}

class _LiveComment {
  final String author;
  final String body;
  final String badge;
  final Color accent;

  const _LiveComment({
    required this.author,
    required this.body,
    required this.badge,
    required this.accent,
  });
}

class _DebateArenaRound {
  final String speaker;
  final String stance;
  final String body;
  final String counter;
  final IconData icon;
  final Color color;

  const _DebateArenaRound({
    required this.speaker,
    required this.stance,
    required this.body,
    required this.counter,
    required this.icon,
    required this.color,
  });
}

class _RhetoricalTitlePack {
  final String category;
  final String source;
  final String tension;
  final List<String> titles;
  final IconData icon;
  final Color color;

  const _RhetoricalTitlePack({
    required this.category,
    required this.source,
    required this.tension,
    required this.titles,
    required this.icon,
    required this.color,
  });
}

const _homeStories = [
  _StorySignal(
    label: 'AI 艺术?',
    count: '4.2k',
    icon: Icons.auto_awesome_outlined,
    accent: _debateLilac,
  ),
  _StorySignal(
    label: '60 万值吗',
    count: '8.7k',
    icon: Icons.payments_outlined,
    accent: _debateGold,
  ),
  _StorySignal(
    label: '过度解读',
    count: '3.6k',
    icon: Icons.theater_comedy_outlined,
    accent: _debateCoral,
  ),
  _StorySignal(
    label: '看展装懂',
    count: '2.9k',
    icon: Icons.visibility_outlined,
    accent: _debateJade,
  ),
  _StorySignal(
    label: '保底校',
    count: '3.4k',
    icon: Icons.people_alt_outlined,
    accent: _porcelainDeepBlue,
  ),
];

const _homeDebateTopics = [
  _DebateTopic(
    channel: '留学账本',
    track: '申请向',
    category: '艺术留学',
    status: '进行中',
    timeLeft: '剩 2 天',
    title: '花 60 万读艺术留学，真的买到未来了吗？',
    lead: '预算、城市、作品集和家庭期待被放在同一张桌上。',
    pro: '名校网络和海外经历很难用短期薪资衡量',
    con: '如果只是换一个更贵的焦虑场，不如先停下来算账',
    proPercent: 62,
    heat: '18.6k',
    comments: '742',
    floor: '38 楼',
    hotComment: '“最贵的不是学费，是不知道自己为什么出国。”',
    proComment: '城市资源和同行网络会改变一个人的长期半径。',
    conComment: '如果目标不清楚，贵学校只会放大原来的焦虑。',
    agentPersona: '现实派老学长',
    agentReply: '钱确实不是唯一答案，但你愿意把回报周期拉到几年？',
    askSeed: '花 60 万读艺术留学，怎样判断它到底值不值？',
    tags: ['预算', '回报', '家庭决策'],
    icon: Icons.account_balance_wallet_outlined,
    accent: _debateGold,
  ),
  _DebateTopic(
    channel: 'AI 作品集',
    track: '申请向',
    category: '作品集',
    status: '进行中',
    timeLeft: '剩 5 小时',
    title: 'AI 参与作品集，到底是新能力还是作弊？',
    lead: '工具边界、原创表达和院校审核规则正在互相追赶。',
    pro: '会用 AI 是未来创作能力的一部分',
    con: '只会生成结果，作品集会失去判断力',
    proPercent: 48,
    heat: '12.3k',
    comments: '516',
    floor: '21 楼',
    hotComment: '“AI 不可怕，可怕的是你说不清每一步为什么。”',
    proComment: 'AI 像摄影机一样，是新工具，不该天然被判作弊。',
    conComment: '作品集评的是判断力，不是把提示词包装成作者性。',
    agentPersona: '理想派策展人',
    agentReply: '我先同意工具无罪，但你能解释每张图为什么这样生成吗？',
    askSeed: 'AI 参与作品集时，哪些环节应该主动说明？',
    tags: ['AI', '原创性', '院校审核'],
    icon: Icons.auto_fix_high_outlined,
    accent: _debateLilac,
  ),
  _DebateTopic(
    channel: '官方信息辨别',
    track: '申请向',
    category: '申请信息',
    status: '进行中',
    timeLeft: '剩 1 天',
    title: '官方招生信息和经验帖冲突时，该信谁？',
    lead: '官网、协会通知、学长经验和社媒爆料之间，需要一套核对方法。',
    pro: '官方口径决定申请节点和硬性材料',
    con: '经验帖能补上流程细节和真实体感',
    proPercent: 55,
    heat: '9.4k',
    comments: '389',
    floor: '57 楼',
    hotComment: '“先看官网日期，再看经验帖适用年份。”',
    proComment: '政策和材料要求必须以官方页面为准。',
    conComment: '但经验帖能提醒你哪些环节最容易被忽略。',
    agentPersona: '信息核对员',
    agentReply: '先把官网、协会通知和经验帖按发布时间排一下。',
    askSeed: '当官方信息和经验帖冲突时，你会怎么核对？',
    tags: ['官方信息', '申请节点', '经验帖'],
    icon: Icons.forum_outlined,
    accent: _debateCoral,
  ),
  _DebateTopic(
    channel: 'AI 艺术审判',
    track: '文化向',
    category: '艺术讨论',
    status: '进行中',
    timeLeft: '剩 3 天',
    title: 'AI 生成的图，算不算艺术？',
    lead: '当创作从手艺变成选择，作者性还站得住吗？',
    pro: '艺术的核心是观念和选择，不是工具是否亲手完成',
    con: '没有身体经验和持续训练，图像再漂亮也只是结果',
    proPercent: 57,
    heat: '15.1k',
    comments: '681',
    floor: '9 楼',
    hotComment: '“摄影刚出现时也被骂过不像艺术。”',
    proComment: '如果杜尚能把现成品送进美术馆，AI 图也该被讨论。',
    conComment: '问题不是工具新，而是很多作品没有必要性。',
    agentPersona: '杠精策展人',
    agentReply: '我承认 AI 可以是艺术，但你能说清作者到底做了什么吗？',
    askSeed: 'AI 生成的图算艺术吗？判断标准应该是什么？',
    tags: ['AI 艺术', '作者性', '审美'],
    icon: Icons.auto_awesome_outlined,
    accent: _debateJade,
  ),
  _DebateTopic(
    channel: '展览现场',
    track: '文化向',
    category: '艺术讨论',
    status: '进行中',
    timeLeft: '剩 8 小时',
    title: '策展人的解读，是帮助理解还是过度包装？',
    lead: '墙上的文字、作品本身和观众直觉正在互相争夺解释权。',
    pro: '好的解读给观众入口，不是所有人都熟悉艺术史语境',
    con: '太多解释会替作品说话，把观看变成背答案',
    proPercent: 46,
    heat: '8.9k',
    comments: '304',
    floor: '31 楼',
    hotComment: '“门槛可以有，但别把门槛包装成优越感。”',
    proComment: '没有背景信息，很多作品会被误解成装置摆拍。',
    conComment: '如果离开小作文就不成立，作品本身可能不够有力。',
    agentPersona: '展厅嘴替',
    agentReply: '我先站反方一点：你看作品时真的需要先读完那块墙吗？',
    askSeed: '策展文字到底是在帮助观看，还是在替作品找借口？',
    tags: ['看展', '策展', '公共审美'],
    icon: Icons.visibility_outlined,
    accent: _porcelainDeepBlue,
  ),
  _DebateTopic(
    channel: '审美围观',
    track: '文化向',
    category: '艺术讨论',
    status: '已归档',
    timeLeft: '查看复盘',
    title: '丑东西火了，是审丑还是真的审美变了？',
    lead: '从丑萌、土酷到低保真视觉，年轻人的审美词典正在改写。',
    pro: '审美本来会反叛精致，丑感也是时代情绪',
    con: '很多所谓丑美学只是营销给平庸找台阶',
    proPercent: 64,
    heat: '10.7k',
    comments: '427',
    floor: '66 楼',
    hotComment: '“不是丑赢了，是标准答案失效了。”',
    proComment: '反精致也是一种表达，不能只用学院标准判断。',
    conComment: '如果所有粗糙都被叫真诚，审美就不用训练了。',
    agentPersona: '毒舌评论员',
    agentReply: '这题我差点被正方说服，但粗糙和有意为之仍然不同。',
    askSeed: '丑美学流行，是审美更新还是营销包装？',
    tags: ['审美', '青年文化', '视觉趋势'],
    icon: Icons.palette_outlined,
    accent: _debateCoral,
  ),
];

const _homeDebateLanes = [
  _DebateLane(
    label: '全站',
    title: '今日广场',
    subtitle: '申请向 / 文化向混排',
    icon: Icons.local_fire_department_rounded,
    accent: _debateCoral,
  ),
  _DebateLane(
    label: '申请',
    title: '申请向问题',
    subtitle: '预算 / 选校 / 作品集',
    icon: Icons.psychology_alt_outlined,
    accent: _porcelainDeepBlue,
  ),
  _DebateLane(
    label: '文化',
    title: '艺术爱好者',
    subtitle: '审美 / 展览 / AI 艺术',
    icon: Icons.people_alt_outlined,
    accent: _debateJade,
  ),
  _DebateLane(
    label: 'Agent',
    title: 'AI 正在下场',
    subtitle: '反驳 / 追问 / 认输',
    icon: Icons.auto_awesome_outlined,
    accent: _debateLilac,
  ),
];

const _liveComments = [
  _LiveComment(
    author: '小艺锐评',
    body: '我先接住你：AI 可以是工具，但你得说清作者性在哪里。',
    badge: 'Agent 反驳',
    accent: _debateLilac,
  ),
  _LiveComment(
    author: '伦敦看展人',
    body: '策展文字不是原罪，问题是它有没有真的帮我看见作品。',
    badge: '神评论',
    accent: _debateJade,
  ),
  _LiveComment(
    author: '作品集第 4 版',
    body: '好的机构应该让你更清醒，不是让你更依赖。',
    badge: '申请向',
    accent: _debateCoral,
  ),
  _LiveComment(
    author: '不申请也看展',
    body: '终于不是只聊 offer 了，AI 艺术这题我能吵一天。',
    badge: '文化向',
    accent: _debateGold,
  ),
];

const _debateArenaRounds = [
  _DebateArenaRound(
    speaker: '用户正方',
    stance: '先开题',
    body: 'AI 生成图当然可以算艺术，关键不是手有没有画，而是人有没有做选择。',
    counter: '如果选择就是创作，那随机抽 100 张再挑 1 张也算作者性吗？',
    icon: Icons.person_outline_rounded,
    color: _debateJade,
  ),
  _DebateArenaRound(
    speaker: '艾见Agent',
    stance: '反方追问',
    body: '我接住“选择”这点，但你还没说明：选择的标准来自作者，还是来自平台审美模板？',
    counter: '请给出一个能区分“会用工具”和“被工具带着走”的标准。',
    icon: Icons.auto_awesome_outlined,
    color: _debateGold,
  ),
  _DebateArenaRound(
    speaker: '围观补刀',
    stance: '第三方插话',
    body: '这题重点不是 AI 能不能创作，而是作品离开解释后还站不站得住。',
    counter: '如果作品必须靠很长的提示词过程说明才成立，它还够有力吗？',
    icon: Icons.forum_outlined,
    color: _debateCoral,
  ),
  _DebateArenaRound(
    speaker: 'AI 裁判',
    stance: '临时小结',
    body: '正方赢在扩大了创作定义，反方赢在逼问判断标准。下一轮应该吵“作者责任”。',
    counter: '你要站哪边补一刀？',
    icon: Icons.balance_outlined,
    color: _debateLilac,
  ),
];

const _rhetoricalTitlePacks = [
  _RhetoricalTitlePack(
    category: '作品集',
    source: 'AI 帮我做了 60% 作品集',
    tension: '工具效率 vs 原创边界',
    titles: [
      'AI 参与作品集，是新能力还是作弊？',
      '不会用 AI 的作品集，反而会显得落后吗？',
      '作品集里最该被说明的，是结果还是过程？',
    ],
    icon: Icons.auto_fix_high_outlined,
    color: _debateLilac,
  ),
  _RhetoricalTitlePack(
    category: '艺术留学',
    source: '家里觉得艺术留学太贵',
    tension: '长期回报 vs 当下焦虑',
    titles: [
      '花 60 万读艺术留学，真的买到未来了吗？',
      '艺术留学值不值，是看 offer 还是看十年后的自己？',
      '如果目标不清楚，名校会救你还是放大焦虑？',
    ],
    icon: Icons.account_balance_wallet_outlined,
    color: _debateGold,
  ),
  _RhetoricalTitlePack(
    category: '艺术讨论',
    source: '展览墙上的文字越写越玄',
    tension: '观看入口 vs 解释霸权',
    titles: [
      '策展人的解读，是帮助理解还是过度包装？',
      '看展必须读懂小作文，还是先相信自己的眼睛？',
      '离开文字就站不住的作品，还算好作品吗？',
    ],
    icon: Icons.visibility_outlined,
    color: _porcelainDeepBlue,
  ),
];

typedef _AskQuestionLauncher = Future<void> Function({
  String? initialTitle,
  String? initialCategory,
});

typedef _LeadPostAction = Future<bool> Function(AppCommunityPost post);
typedef _CommunityPostChanged = void Function(AppCommunityPost post);

enum _DebateSide { pro, con, watch }

enum _DebateCommentFilter { all, pro, con, agent, mine }

enum _TickerDisplayMode { aiDigest, liveRoll }

class _StanceSubmission {
  final _DebateSide side;
  final String body;

  const _StanceSubmission({
    required this.side,
    required this.body,
  });
}

class _DebateThreadComment {
  final String id;
  final _DebateSide side;
  final String author;
  final String body;
  final int likes;
  final int replies;
  final bool isAgent;
  final bool isMine;

  const _DebateThreadComment({
    required this.id,
    required this.side,
    required this.author,
    required this.body,
    required this.likes,
    required this.replies,
    this.isAgent = false,
    this.isMine = false,
  });
}

String _debateSideLabel(_DebateSide side) {
  return switch (side) {
    _DebateSide.pro => '正方',
    _DebateSide.con => '反方',
    _DebateSide.watch => '先围观',
  };
}

Color _debateSideColor(_DebateSide side) {
  return switch (side) {
    _DebateSide.pro => _debateJade,
    _DebateSide.con => _debateCoral,
    _DebateSide.watch => _porcelainDeepBlue,
  };
}

String _legacyMetaString(
  Map<String, dynamic> metadata,
  String key, [
  String fallback = '',
]) {
  final value = metadata[key]?.toString().trim();
  if (value == null || value.isEmpty || value == 'null') return fallback;
  return value;
}

int _legacyMetaInt(
  Map<String, dynamic> metadata,
  String key, [
  int fallback = 0,
]) {
  final value = metadata[key];
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _legacyMetaStringList(Map<String, dynamic> metadata, String key) {
  final value = metadata[key];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

int _legacyPostHeatScore(AppCommunityPost post) {
  return post.likeCount * 3 + post.commentCount * 6 + post.viewCount;
}

int _legacyPostTimeScore(AppCommunityPost post) {
  return DateTime.tryParse(post.createdAt)?.millisecondsSinceEpoch ?? 0;
}

String _legacyPostSourceLabel(AppCommunityPost post) {
  final metadata = post.metadata;
  return _legacyMetaString(
    metadata,
    'source_label',
    _legacyMetaString(metadata, 'channel', '广场'),
  );
}

Color _legacyColor(dynamic raw, Color fallback) {
  if (raw is int) return Color(raw);
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return fallback;
  final normalized = value.startsWith('#')
      ? 'FF${value.substring(1)}'
      : value.replaceFirst(RegExp(r'^0x'), '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

IconData _legacyDebateIcon(String value, IconData fallback) {
  return switch (value) {
    'wallet' => Icons.account_balance_wallet_outlined,
    'auto_fix' => Icons.auto_fix_high_outlined,
    'forum' => Icons.forum_outlined,
    'auto_awesome' => Icons.auto_awesome_outlined,
    'visibility' => Icons.visibility_outlined,
    'palette' => Icons.palette_outlined,
    _ => fallback,
  };
}

_DebateTopic? _debateTopicFromPlazaPost(AppCommunityPost post) {
  final metadata = post.metadata;
  final legacyType = _legacyMetaString(metadata, 'legacy_type');
  final kind = _legacyMetaString(metadata, 'kind');
  if (legacyType != 'debate_topic' && kind != 'debate') return null;

  return _DebateTopic(
    leadPost: post,
    channel: _legacyMetaString(metadata, 'channel', '广场'),
    track: _legacyMetaString(metadata, 'track', '文化向'),
    category: _legacyMetaString(metadata, 'category', '艺术讨论'),
    status: _legacyMetaString(metadata, 'status_label', '进行中'),
    timeLeft: _legacyMetaString(metadata, 'time_left', '查看讨论'),
    title: post.title.trim().isEmpty ? '广场讨论' : post.title,
    lead: _legacyMetaString(metadata, 'lead', post.body?.trim() ?? ''),
    pro: _legacyMetaString(metadata, 'pro'),
    con: _legacyMetaString(metadata, 'con'),
    proPercent: _legacyMetaInt(metadata, 'pro_percent', 50),
    heat: _legacyMetaString(metadata, 'heat_label', '${post.viewCount}'),
    comments: _legacyMetaString(
      metadata,
      'comments_label',
      '${post.commentCount}',
    ),
    floor: _legacyMetaString(metadata, 'floor', '1 楼'),
    hotComment: _legacyMetaString(metadata, 'hot_comment'),
    proComment: _legacyMetaString(metadata, 'pro_comment'),
    conComment: _legacyMetaString(metadata, 'con_comment'),
    agentPersona: _legacyMetaString(metadata, 'agent_persona', '艺见锐评员'),
    agentReply: _legacyMetaString(metadata, 'agent_reply'),
    askSeed: _legacyMetaString(metadata, 'ask_seed', post.title),
    tags: _legacyMetaStringList(metadata, 'tags'),
    icon: _legacyDebateIcon(
      _legacyMetaString(metadata, 'icon'),
      Icons.forum_outlined,
    ),
    accent: _legacyColor(metadata['accent'], _porcelainDeepBlue),
  );
}

_PlazaRatingItem? _ratingItemFromPlazaPost(AppCommunityPost post) {
  final metadata = post.metadata;
  final legacyType = _legacyMetaString(metadata, 'legacy_type');
  final kind = _legacyMetaString(metadata, 'kind');
  if (legacyType != 'rating_item' && kind != 'rating') return null;

  final replies = <_PlazaRatingReply>[];
  final rawReplies = metadata['replies'];
  if (rawReplies is List) {
    for (final rawReply in rawReplies) {
      if (rawReply is! Map) continue;
      final reply = Map<String, dynamic>.from(rawReply);
      replies.add(
        _PlazaRatingReply(
          author: _legacyMetaString(reply, 'author', '匿名用户'),
          date: _legacyMetaString(reply, 'date'),
          body: _legacyMetaString(reply, 'body'),
          likes: _legacyMetaInt(reply, 'likes'),
          avatarColor: _legacyColor(reply['avatar_color'], _debateJade),
        ),
      );
    }
  }

  return _PlazaRatingItem(
    leadPost: post,
    collection: _legacyMetaString(metadata, 'collection', '广场口碑'),
    title: post.title.trim().isEmpty ? '广场评分' : post.title,
    subtitle: _legacyMetaString(metadata, 'subtitle', post.body?.trim() ?? ''),
    quote: _legacyMetaString(metadata, 'quote'),
    score: _legacyMetaString(metadata, 'score', '0.0'),
    ratingCount: _legacyMetaString(
      metadata,
      'rating_count',
      '${post.commentCount}',
    ),
    likes: _legacyMetaString(metadata, 'likes_label', '${post.likeCount}'),
    comments: _legacyMetaString(
      metadata,
      'comments_label',
      '${post.commentCount}',
    ),
    source: _legacyMetaString(metadata, 'source_label', '广场'),
    time: _legacyMetaString(metadata, 'time_label'),
    coverSeed: _legacyMetaString(metadata, 'cover_seed', post.id),
    accent: _legacyColor(metadata['accent'], _debateJade),
    replies: replies,
  );
}

_PlazaRatingItem? _associatedRatingForTopic(_DebateTopic topic) {
  final haystack = '${topic.title} ${topic.channel} ${topic.category}';
  if (haystack.contains('侠') || haystack.contains('金庸')) {
    return const _PlazaRatingItem(
      collection: '金句口碑',
      title: '侠之大者，为国为民',
      subtitle: '这个问题正在被大家连续评分，大家更在意责任感还是文采。',
      quote: '多数人认为这句话的“责任感”比“武力值”更重要。',
      score: '9.9',
      ratingCount: '1160',
      likes: '557',
      comments: '3',
      source: '金句口碑圈子',
      time: '今天12:08',
      coverSeed: 'jingyong_xia',
      accent: _debateJade,
      replies: [
        _PlazaRatingReply(
          author: '小黑屋住户',
          date: '2026-07-06',
          body: '并不是成为大侠的人，就会被大家所认可，而是被大家所认可的人，才能成为大侠。',
          likes: 122,
          avatarColor: _debateGold,
        ),
        _PlazaRatingReply(
          author: 'CLANNADOR',
          date: '2026-07-06',
          body: '记得最早的时候是“为国为民，侠之大者”，不知道为什么换个顺序以后更像一种责任。',
          likes: 88,
          avatarColor: _debateJade,
        ),
      ],
    );
  }

  if (haystack.contains('AI')) {
    return _PlazaRatingItem(
      collection: '作品集口碑',
      title: 'AI 参与作品集边界',
      subtitle: '这个问题正在被大家评分，重点是透明说明、原创判断和创作责任。',
      quote: '大家最在意的不是用不用 AI，而是你能不能说清每一步为什么。',
      score: '8.6',
      ratingCount: '516',
      likes: '12.3k',
      comments: '5',
      source: 'AI 作品集圈子',
      time: '今天09:18',
      coverSeed: 'portfolio_ai_boundary',
      accent: _debateLilac,
      replies: [
        _PlazaRatingReply(
          author: '透明说明派',
          date: '今天',
          body: topic.proComment,
          likes: 64,
          avatarColor: _debateLilac,
        ),
        _PlazaRatingReply(
          author: '原创洁癖',
          date: '今天',
          body: topic.conComment,
          likes: 51,
          avatarColor: _debateCoral,
        ),
      ],
    );
  }

  if (haystack.contains('60') || haystack.contains('留学')) {
    return _PlazaRatingItem(
      collection: '留学账本',
      title: '艺术留学 60 万值不值',
      subtitle: '这个问题正在被大家评分，预算、城市、作品集和家庭期待都被放到桌面上。',
      quote: '多数人认为是否值得，取决于目标是否清楚，而不是学费本身。',
      score: '7.8',
      ratingCount: '742',
      likes: '18.6k',
      comments: '4',
      source: '留学账本圈子',
      time: '今天09:18',
      coverSeed: 'art_study_budget_value',
      accent: _debateGold,
      replies: [
        _PlazaRatingReply(
          author: '现实派老学长',
          date: '今天',
          body: topic.proComment,
          likes: 93,
          avatarColor: _debateGold,
        ),
        _PlazaRatingReply(
          author: '先算账再出发',
          date: '今天',
          body: topic.conComment,
          likes: 77,
          avatarColor: _debateCoral,
        ),
      ],
    );
  }

  return null;
}

Future<_StanceSubmission?> _showStanceCommentSheet(
  BuildContext context,
  _DebateTopic topic, {
  _DebateSide initialSide = _DebateSide.pro,
  String? initialDraft,
}) async {
  return showModalBottomSheet<_StanceSubmission>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _StanceCommentSheet(
      topic: topic,
      initialSide: initialSide,
      initialDraft: initialDraft,
    ),
  );
}

class _HomeDopamineFeed extends StatefulWidget {
  final _AiHomeProfileConfig config;
  final bool simplified;
  final bool institutionLeadMode;
  final int refreshSignal;
  final VoidCallback onStartAi;
  final ValueChanged<String> onPrompt;
  final VoidCallback onOpenForum;
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenWorkbench;
  final _AskQuestionLauncher onAskQuestion;
  final bool showWorkbench;

  const _HomeDopamineFeed({
    super.key,
    required this.config,
    required this.simplified,
    required this.institutionLeadMode,
    required this.refreshSignal,
    required this.onStartAi,
    required this.onPrompt,
    required this.onOpenForum,
    required this.onOpenExplore,
    required this.onOpenWorkbench,
    required this.onAskQuestion,
    required this.showWorkbench,
  });

  @override
  State<_HomeDopamineFeed> createState() => _HomeDopamineFeedState();
}

class _HomeDopamineFeedState extends State<_HomeDopamineFeed> {
  int _selectedLane = 0;
  int _selectedPlazaTab = 0;
  List<AppCommunityPost> _legacyPlazaPosts = const [];
  List<Map<String, dynamic>> _plazaCircles = const [];
  final Map<String, String> _plazaCircleJoinStatusOverrides = {};
  final Set<String> _leadActionBusyPostIds = {};
  final Set<String> _plazaLikeBusyPostIds = {};
  final Set<String> _plazaSaveBusyPostIds = {};
  bool _legacyPlazaLoading = false;
  bool _plazaCirclesLoading = false;
  String? _legacyPlazaError;
  String? _plazaCirclesError;

  @override
  void initState() {
    super.initState();
    if (widget.simplified) {
      _loadLegacyPlazaPosts();
      _loadPlazaCircles();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeDopamineFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.simplified &&
        !oldWidget.simplified &&
        _legacyPlazaPosts.isEmpty) {
      _loadLegacyPlazaPosts();
    }
    if (widget.simplified && !oldWidget.simplified && _plazaCircles.isEmpty) {
      _loadPlazaCircles();
    }
    if (widget.simplified && oldWidget.refreshSignal != widget.refreshSignal) {
      _loadLegacyPlazaPosts();
      _loadPlazaCircles();
    }
  }

  Future<void> _loadLegacyPlazaPosts() async {
    if (_legacyPlazaLoading) return;
    setState(() {
      _legacyPlazaLoading = true;
      _legacyPlazaError = null;
    });
    try {
      final qaPosts = await BackendApiService.fetchPlazaPosts(
        limit: 24,
        kind: 'qa',
        source: 'plaza_question',
        sort: 'latest',
      );
      final ratingPosts = await BackendApiService.fetchPlazaPosts(
        limit: 16,
        kind: 'rating',
        sort: 'latest',
      );
      final legacyPosts = await BackendApiService.fetchPlazaPosts(
        limit: 24,
        source: 'plaza_legacy',
        sort: 'latest',
      );
      final seen = <String>{};
      final posts = <AppCommunityPost>[];
      for (final post in [
        ...qaPosts,
        ...ratingPosts,
        ...legacyPosts,
      ]) {
        if (seen.add(post.id)) posts.add(post);
      }
      posts.sort(
        (a, b) => _legacyPostTimeScore(b).compareTo(_legacyPostTimeScore(a)),
      );
      if (!mounted) return;
      setState(() {
        _legacyPlazaPosts = posts;
        _legacyPlazaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _legacyPlazaError = e.toString();
        _legacyPlazaLoading = false;
      });
    }
  }

  Future<void> _loadPlazaCircles() async {
    if (_plazaCirclesLoading) return;
    setState(() {
      _plazaCirclesLoading = true;
      _plazaCirclesError = null;
    });
    try {
      final result = await BackendApiService.fetchCommunityCircles(limit: 24);
      if (!mounted) return;
      setState(() {
        _plazaCircles = result.data;
        _plazaCirclesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plazaCirclesError = e.toString();
        _plazaCirclesLoading = false;
      });
    }
  }

  void _selectPlazaTab(int index) {
    setState(() => _selectedPlazaTab = index);
    if (index == 4 && _plazaCircles.isEmpty && !_plazaCirclesLoading) {
      unawaited(_loadPlazaCircles());
    }
  }

  List<_DebateTopic> get _visibleTopics {
    return switch (_selectedLane) {
      1 => _homeDebateTopics.where((topic) => topic.track == '申请向').toList(),
      2 => _homeDebateTopics.where((topic) => topic.track == '文化向').toList(),
      3 => [
          ..._homeDebateTopics.where((topic) => topic.agentReply.isNotEmpty),
        ],
      _ => _homeDebateTopics,
    };
  }

  List<AppCommunityPost> get _visibleLegacyPlazaPosts {
    final posts = List<AppCommunityPost>.of(_legacyPlazaPosts);
    switch (_selectedPlazaTab) {
      case 1:
        posts.sort(
          (a, b) => _legacyPostSourceLabel(a).compareTo(
            _legacyPostSourceLabel(b),
          ),
        );
        return posts;
      case 2:
        posts.sort(
          (a, b) => _legacyPostHeatScore(b).compareTo(_legacyPostHeatScore(a)),
        );
        return posts;
      case 3:
        posts.sort(
          (a, b) => _legacyPostTimeScore(b).compareTo(_legacyPostTimeScore(a)),
        );
        return posts;
      case 4:
        posts.sort(
          (a, b) => _legacyPostSourceLabel(a).compareTo(
            _legacyPostSourceLabel(b),
          ),
        );
        return posts;
      default:
        posts.sort(
          (a, b) => _legacyPostHeatScore(b).compareTo(_legacyPostHeatScore(a)),
        );
        return posts;
    }
  }

  String get _sectionTitle {
    return switch (_selectedLane) {
      1 => '把申请焦虑拆成能被回答的问题',
      2 => '让艺术爱好者也能下场表达审美',
      3 => 'Agent 先接住你，再顶回来',
      _ => '广场不是瀑布流，是正在运转的辩论场',
    };
  }

  String get _askSeed {
    return switch (_selectedLane) {
      1 => '我现在最纠结的是预算、作品集还是选校？应该先问哪个问题？',
      2 => '最近看到一个艺术现象，我想知道大家会怎么站队：',
      3 => '请像真人辩论一样，先认可我一部分，再指出我的漏洞。',
      _ => '今天广场里，最值得被做成辩题的问题是什么？',
    };
  }

  AppCommunityPost _latestLegacyPost(AppCommunityPost post) {
    for (final current in _legacyPlazaPosts) {
      if (current.id == post.id) return current;
    }
    return post;
  }

  void _replaceLegacyPlazaPost(AppCommunityPost updated) {
    final index = _legacyPlazaPosts.indexWhere((post) => post.id == updated.id);
    if (index == -1) return;
    final next = List<AppCommunityPost>.of(_legacyPlazaPosts);
    next[index] = updated;
    setState(() => _legacyPlazaPosts = next);
  }

  Future<void> _togglePlazaPostLike(AppCommunityPost post) async {
    if (_plazaLikeBusyPostIds.contains(post.id)) return;
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后点赞');
    if (!mounted || !loggedIn) return;
    setState(() => _plazaLikeBusyPostIds.add(post.id));
    try {
      final current = _latestLegacyPost(post);
      final result = current.likedByMe
          ? await BackendApiService.unlikeCommunityPost(current.id)
          : await BackendApiService.likeCommunityPost(current.id);
      if (!mounted) return;
      final updated = _latestLegacyPost(post).copyWith(
        likedByMe: result.liked,
        likeCount: result.likeCount,
      );
      _replaceLegacyPlazaPost(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.liked ? '已点赞' : '已取消点赞')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('点赞失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _plazaLikeBusyPostIds.remove(post.id));
      }
    }
  }

  Future<void> _togglePlazaPostSave(AppCommunityPost post) async {
    if (_plazaSaveBusyPostIds.contains(post.id)) return;
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后收藏');
    if (!mounted || !loggedIn) return;
    setState(() => _plazaSaveBusyPostIds.add(post.id));
    try {
      final current = _latestLegacyPost(post);
      final result = current.savedByMe
          ? await BackendApiService.unsaveCommunityPost(current.id)
          : await BackendApiService.saveCommunityPost(current.id);
      if (!mounted) return;
      final updated = _latestLegacyPost(post).copyWith(
        savedByMe: result.saved,
        saveCount: result.saveCount,
      );
      _replaceLegacyPlazaPost(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.saved ? '已收藏' : '已取消收藏')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _plazaSaveBusyPostIds.remove(post.id));
      }
    }
  }

  Future<void> _openTopicDetail(
    _DebateTopic topic, {
    _StanceSubmission? initialSubmission,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _DebateTopicDetailScreen(
          topic: topic,
          onAskQuestion: widget.onAskQuestion,
          initialSubmission: initialSubmission,
          post: topic.leadPost,
          onPostChanged: _replaceLegacyPlazaPost,
          leadPost: widget.institutionLeadMode ? topic.leadPost : null,
          onToggleLeadSave:
              widget.institutionLeadMode ? _togglePlazaLeadSave : null,
          onConvertLead: widget.institutionLeadMode
              ? (post) => _openPlazaLeadReply(
                    post,
                    consultIntent: true,
                  )
              : null,
        ),
      ),
    );
  }

  Future<void> _openRatingDetail(_PlazaRatingItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PlazaRatingDetailScreen(
          item: item,
          leadPost: widget.institutionLeadMode ? item.leadPost : null,
          onToggleLeadSave:
              widget.institutionLeadMode ? _togglePlazaLeadSave : null,
          onConvertLead: widget.institutionLeadMode
              ? (post) => _openPlazaLeadReply(
                    post,
                    consultIntent: true,
                  )
              : null,
        ),
      ),
    );
  }

  Widget _plazaFeedCardSpacing({
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: child,
    );
  }

  Future<bool> _togglePlazaLeadSave(AppCommunityPost post) async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后收藏线索');
    if (!mounted || !loggedIn || _leadActionBusyPostIds.contains(post.id)) {
      return false;
    }
    setState(() => _leadActionBusyPostIds.add(post.id));
    try {
      if (post.savedByMe) {
        await BackendApiService.unsaveCommunityPost(post.id);
      } else {
        await BackendApiService.saveCommunityPost(post.id);
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(post.savedByMe ? '已取消收藏线索' : '已收藏为潜在线索'),
        ),
      );
      await _loadLegacyPlazaPosts();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _leadActionBusyPostIds.remove(post.id));
      }
    }
  }

  Future<bool> _openPlazaLeadReply(
    AppCommunityPost post, {
    bool consultIntent = false,
  }) async {
    final loggedIn = await ensureLoggedIn(
      context,
      message: consultIntent ? '请先登录后转咨询' : '请先登录后回应学生',
    );
    if (!mounted || !loggedIn || _leadActionBusyPostIds.contains(post.id)) {
      return false;
    }
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlazaLeadReplySheet(
        post: post,
        consultIntent: consultIntent,
      ),
    );
    if (!mounted || body == null) return false;
    setState(() => _leadActionBusyPostIds.add(post.id));
    try {
      await BackendApiService.createPlazaComment(
        postId: post.id,
        body: body,
        metadata: {
          'source': 'institution_plaza_lead',
          'intent': consultIntent ? 'consultation_invite' : 'public_reply',
        },
      );
      if (consultIntent && !post.savedByMe) {
        await BackendApiService.saveCommunityPost(post.id);
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(consultIntent ? '已公开回应并收藏线索' : '已发布回应'),
        ),
      );
      await _loadLegacyPlazaPosts();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('回应失败：$e')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _leadActionBusyPostIds.remove(post.id));
      }
    }
  }

  List<Widget> _buildBackendLegacyPlazaFeedItems() {
    final cards = <Widget>[];
    for (final post in _visibleLegacyPlazaPosts) {
      final topic = _debateTopicFromPlazaPost(post);
      if (topic != null) {
        cards.add(
          _plazaFeedCardSpacing(
            child: _DebateTopicCard(
              topic: topic,
              post: post,
              likeBusy: _plazaLikeBusyPostIds.contains(post.id),
              saveBusy: _plazaSaveBusyPostIds.contains(post.id),
              onLike: () => _togglePlazaPostLike(post),
              onSave: () => _togglePlazaPostSave(post),
              onTap: () => _openTopicDetail(topic),
            ),
          ),
        );
        continue;
      }

      final rating = _ratingItemFromPlazaPost(post);
      if (rating != null) {
        cards.add(
          _plazaFeedCardSpacing(
            child: _PlazaRatingCard(
              item: rating,
              post: post,
              likeBusy: _plazaLikeBusyPostIds.contains(post.id),
              saveBusy: _plazaSaveBusyPostIds.contains(post.id),
              onLike: () => _togglePlazaPostLike(post),
              onSave: () => _togglePlazaPostSave(post),
              onTap: () => _openRatingDetail(rating),
            ),
          ),
        );
      }
    }
    return cards;
  }

  List<Widget> _buildSimplifiedPlazaFeedItems() {
    if (_selectedPlazaTab == 4) {
      return _buildSimplifiedPlazaCircleItems();
    }
    final backendCards = _buildBackendLegacyPlazaFeedItems();
    if (backendCards.isNotEmpty) return backendCards;
    return [
      _PlazaDataStateCard(
        loading: _legacyPlazaLoading,
        hasError: _legacyPlazaError != null,
        onRetry: _loadLegacyPlazaPosts,
        onAskQuestion: () => widget.onAskQuestion(initialTitle: _askSeed),
      ),
    ];
  }

  List<Widget> _buildSimplifiedPlazaCircleItems() {
    final cards = <Widget>[];
    if (_plazaCirclesLoading && _plazaCircles.isEmpty) {
      cards.add(
        _PlazaCircleStateCard(
          loading: true,
          title: '正在读取圈子',
          subtitle: '正在整理院校、作品集、同城和行业方向的圈子。',
          onRetry: _loadPlazaCircles,
          onCreateCircle: _openCreateCircleSheet,
        ),
      );
      return cards;
    }
    if (_plazaCirclesError != null && _plazaCircles.isEmpty) {
      cards.add(
        _PlazaCircleStateCard(
          title: '圈子暂时没连上',
          subtitle: '可以重试，或先创建一个新的申请/作品集圈子。',
          onRetry: _loadPlazaCircles,
          onCreateCircle: _openCreateCircleSheet,
        ),
      );
      return cards;
    }
    if (_plazaCircles.isEmpty) {
      cards.add(
        _PlazaCircleStateCard(
          title: '还没有圈子',
          subtitle: '创建第一个圈子，把同学校、同专业或同城市的人聚到一起。',
          onRetry: _loadPlazaCircles,
          onCreateCircle: _openCreateCircleSheet,
        ),
      );
      return cards;
    }
    for (final entry in _plazaCircles.asMap().entries) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _PlazaCircleListCard(
            circle: entry.value,
            index: entry.key,
            joinStatus: _plazaCircleJoinStatus(entry.value, entry.key),
            onTap: () => _openPlazaCircleDetail(entry.value, entry.key),
          ),
        ),
      );
    }
    return cards;
  }

  Future<void> _openCreateCircleSheet() async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后创建圈子');
    if (!mounted || !loggedIn) return;
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const PlazaCreateCircleScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || created == null) return;
    final next = {
      ...created,
      'join_status': 'joined',
      'member_count': created['member_count'] ?? 1,
      'today_post_count': created['today_post_count'] ?? 0,
      'hot_topic': created['hot_topic'] ?? '发布第一条讨论，开启圈子交流',
    };
    setState(() {
      _selectedPlazaTab = 4;
      _plazaCircles = [next, ..._plazaCircles];
      _plazaCircleJoinStatusOverrides[_plazaCircleId(next, 0)] = 'joined';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('圈子已创建，你可以发布第一条动态或问题')),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPlazaCircleDetail(next, 0);
    });
  }

  void _openPlazaCircleDetail(Map<String, dynamic> circle, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CircleDetailScreen(
          circle: circle,
          index: index,
          joinStatus: _plazaCircleJoinStatus(circle, index),
          onJoinChanged: (status) {
            setState(() {
              _plazaCircleJoinStatusOverrides[_plazaCircleId(circle, index)] =
                  status;
              if (index >= 0 && index < _plazaCircles.length) {
                _plazaCircles[index] = {
                  ..._plazaCircles[index],
                  'join_status': status,
                };
              }
            });
          },
        ),
      ),
    );
  }

  String _plazaCircleJoinStatus(Map<String, dynamic> circle, int index) {
    final id = _plazaCircleId(circle, index);
    final override = _plazaCircleJoinStatusOverrides[id];
    if (override != null) return override;
    final raw = circle['join_status']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'none';
  }

  Widget _buildSimplifiedPlaza(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeepSeaGlassPanel(
              padding: const EdgeInsets.all(5),
              radius: 24,
              opacity: 0.56,
              airy: true,
              child: _PlazaFeedTabs(
                selectedIndex: _selectedPlazaTab,
                onSelected: _selectPlazaTab,
              ),
            ),
            const SizedBox(height: 18),
            ..._buildSimplifiedPlazaFeedItems(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.simplified) {
      return _buildSimplifiedPlaza(context);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeDebateHero(
              onOpenForum: widget.onOpenForum,
              onAskQuestion: () => widget.onAskQuestion(
                initialTitle: 'AI 作品集算作弊吗，还是新的创作基本功？',
                initialCategory: '作品集',
              ),
            ),
            const SizedBox(height: 14),
            const _WorldSimulationCard(),
            const SizedBox(height: 18),
            _DebateLaneStrip(
              lanes: _homeDebateLanes,
              selectedIndex: _selectedLane,
              onSelected: (index) => setState(() => _selectedLane = index),
            ),
            const SizedBox(height: 16),
            _StoryRail(stories: _homeStories, onTap: widget.onOpenForum),
            const SizedBox(height: 18),
            const _LiveCommentTicker(comments: _liveComments),
            const SizedBox(height: 14),
            _AgentDebateThreadCard(
              onChallengeAgent: () => widget.onAskQuestion(
                initialTitle: '我想反驳艾见Agent：AI 生成图像算不算艺术？',
                initialCategory: '艺术讨论',
              ),
              onStartAi: widget.onStartAi,
            ),
            const SizedBox(height: 14),
            _DebateArenaCard(
              onJoin: () => widget.onAskQuestion(
                initialTitle: '我想加入辩论：AI 生成图像算不算艺术？',
                initialCategory: '艺术讨论',
              ),
              onAskAgent: () => widget.onPrompt(
                '请像真人辩论一样，围绕“AI 生成图像算不算艺术”连续追问我三轮。',
              ),
            ),
            const SizedBox(height: 14),
            _NoiseControlPanel(onStartAi: widget.onStartAi),
            const SizedBox(height: 16),
            _RhetoricalTitleLabCard(
              onAskQuestion: widget.onAskQuestion,
              onPrompt: widget.onPrompt,
            ),
            const SizedBox(height: 16),
            _QuestionComposerCard(
              seed: _askSeed,
              onAskQuestion: widget.onAskQuestion,
              onStartAi: widget.onStartAi,
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              eyebrow: _homeDebateLanes[_selectedLane].title,
              title: _sectionTitle,
              actionLabel: '发问',
              onAction: () => widget.onAskQuestion(initialTitle: _askSeed),
            ),
            const SizedBox(height: 12),
            ..._visibleTopics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DebateTopicCard(
                  topic: topic,
                  onTap: () => _openTopicDetail(topic),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _AiDebateBrief(
              config: widget.config,
              onStartAi: widget.onStartAi,
              onPrompt: widget.onPrompt,
            ),
            const SizedBox(height: 18),
            _HomeActionDock(
              onOpenExplore: widget.onOpenExplore,
              onOpenWorkbench: widget.onOpenWorkbench,
              onOpenForum: widget.onOpenForum,
              showWorkbench: widget.showWorkbench,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebateLaneStrip extends StatelessWidget {
  final List<_DebateLane> lanes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DebateLaneStrip({
    required this.lanes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lanes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final lane = lanes[index];
          final selected = index == selectedIndex;
          return _PressableScale(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 150,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: selected
                    ? lane.accent.withValues(alpha: 0.14)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? lane.accent.withValues(alpha: 0.42)
                      : context.artC.silver.withValues(alpha: 0.54),
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? lane.accent.withValues(alpha: 0.12)
                        : context.artC.ink.withValues(alpha: 0.025),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(lane.icon, size: 18, color: lane.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lane.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? lane.accent : context.artC.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    lane.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.5),
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorldSimulationCard extends StatelessWidget {
  const _WorldSimulationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _porcelainDeepBlue.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: _porcelainNightBlue.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_porcelainNightBlue, _inkGlowBlue],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: _debateGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '广场世界正在运行',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Agent 负责出题、接话、策展，不只是生成内容',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.48),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _debateJade.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _debateJade.withValues(alpha: 0.10)),
                ),
                child: const Text(
                  '今日 09:20',
                  style: TextStyle(
                    color: _debateJade,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _WorldSignalChip(
                label: 'AI 艺术升温',
                value: '+246%',
                color: _debateLilac,
              ),
              _WorldSignalChip(
                label: '展览吐槽',
                value: '+89%',
                color: _debateJade,
              ),
              _WorldSignalChip(
                label: '放榜季焦虑',
                value: '+122%',
                color: _debateGold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _WorldLayerPill(
                  label: '日常动态',
                  body: '低门槛表达',
                  color: _debateJade,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _WorldLayerPill(
                  label: '话题讨论',
                  body: 'Agent 抛问题',
                  color: _porcelainDeepBlue,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _WorldLayerPill(
                  label: '辩题对战',
                  body: '站队和反驳',
                  color: _debateCoral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorldSignalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WorldSignalChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldLayerPill extends StatelessWidget {
  final String label;
  final String body;
  final Color color;

  const _WorldLayerPill({
    required this.label,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.48),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentDebateThreadCard extends StatelessWidget {
  final VoidCallback onChallengeAgent;
  final VoidCallback onStartAi;

  const _AgentDebateThreadCard({
    required this.onChallengeAgent,
    required this.onStartAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: _inkWashGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _porcelainDeepBlue.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.record_voice_over_outlined,
                  color: _debateGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '艾见Agent 下场中',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '先接住，再反驳，最后留一个问题',
                      style: TextStyle(
                        color: _inkMistBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const _AgentCanLoseBadge(),
            ],
          ),
          const SizedBox(height: 12),
          const _DebateMessageBubble(
            speaker: '用户',
            body: 'AI 生成的图不算艺术吧？没有手感，也没有训练痕迹。',
            color: _debateJade,
          ),
          const SizedBox(height: 8),
          const _DebateMessageBubble(
            speaker: '艾见Agent',
            body: '你说“训练痕迹”这点我认，但摄影刚出现时也被质疑过。问题是：作者在选择、删改和叙事里承担了多少判断？',
            color: _debateGold,
            strong: true,
          ),
          const SizedBox(height: 8),
          const _DebateMessageBubble(
            speaker: '围观补刀',
            body: '如果只靠提示词碰运气，那更像抽卡，不像创作。',
            color: _debateCoral,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineActionPill(
                icon: Icons.reply_all_outlined,
                label: '反驳 Agent',
                color: _debateGold,
                onTap: onChallengeAgent,
              ),
              _InlineActionPill(
                icon: Icons.swap_horiz_rounded,
                label: '让 AI 换立场',
                color: _debateLilac,
                onTap: onStartAi,
              ),
              _InlineActionPill(
                icon: Icons.how_to_vote_outlined,
                label: '站队',
                color: _debateJade,
                onTap: onChallengeAgent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebateArenaCard extends StatefulWidget {
  final VoidCallback onJoin;
  final VoidCallback onAskAgent;

  const _DebateArenaCard({
    required this.onJoin,
    required this.onAskAgent,
  });

  @override
  State<_DebateArenaCard> createState() => _DebateArenaCardState();
}

class _DebateArenaCardState extends State<_DebateArenaCard> {
  int _roundIndex = 0;
  _DebateSide _side = _DebateSide.watch;

  _DebateArenaRound get _round =>
      _debateArenaRounds[_roundIndex % _debateArenaRounds.length];

  void _nextRound() {
    setState(() => _roundIndex = (_roundIndex + 1) % _debateArenaRounds.length);
  }

  String get _sideHint {
    return switch (_side) {
      _DebateSide.pro => '你站正方，下一轮会优先收到反方追问。',
      _DebateSide.con => '你站反方，Agent 会逼你给出判断标准。',
      _DebateSide.watch => '先旁听，AI 会把双方漏洞折叠成小结。',
    };
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateLilac.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _porcelainNightBlue.withValues(alpha: 0.032),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_porcelainNightBlue, _inkGlowBlue],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: _debateGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '回合制辩论席',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '像真人一样接话、追问、让步和反击',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.46),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _ArenaRoundBadge(index: _roundIndex + 1),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ArenaSideButton(
                  label: '正方',
                  side: _DebateSide.pro,
                  selected: _side == _DebateSide.pro,
                  onTap: () => setState(() => _side = _DebateSide.pro),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ArenaSideButton(
                  label: '反方',
                  side: _DebateSide.con,
                  selected: _side == _DebateSide.con,
                  onTap: () => setState(() => _side = _DebateSide.con),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ArenaSideButton(
                  label: '旁听',
                  side: _DebateSide.watch,
                  selected: _side == _DebateSide.watch,
                  onTap: () => setState(() => _side = _DebateSide.watch),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _sideHint,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.5),
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 190),
            reverseDuration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.97, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: _ArenaRoundPanel(
              key: ValueKey(_roundIndex),
              round: round,
            ),
          ),
          const SizedBox(height: 11),
          _ArenaRoundDots(
            activeIndex: _roundIndex,
            onSelected: (index) => setState(() => _roundIndex = index),
          ),
          const SizedBox(height: 12),
          _ArenaJudgePanel(round: round, side: _side),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineActionPill(
                icon: Icons.skip_next_rounded,
                label: '下一回合',
                color: _porcelainDeepBlue,
                onTap: _nextRound,
              ),
              _InlineActionPill(
                icon: Icons.edit_note_rounded,
                label: '让我上场',
                color: _debateJade,
                onTap: widget.onJoin,
              ),
              _InlineActionPill(
                icon: Icons.auto_awesome_outlined,
                label: 'AI 连续追问',
                color: _debateLilac,
                onTap: widget.onAskAgent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArenaRoundBadge extends StatelessWidget {
  final int index;

  const _ArenaRoundBadge({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _debateLilac.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateLilac.withValues(alpha: 0.2)),
      ),
      child: Text(
        '第 $index 回合',
        style: const TextStyle(
          color: _debateLilac,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ArenaSideButton extends StatelessWidget {
  final String label;
  final _DebateSide side;
  final bool selected;
  final VoidCallback onTap;

  const _ArenaSideButton({
    required this.label,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _debateSideColor(side);
    return _PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: selected ? 1 : 0.16)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ArenaRoundPanel extends StatelessWidget {
  final _DebateArenaRound round;

  const _ArenaRoundPanel({
    super.key,
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _inkWashGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: round.color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: round.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(round.icon, color: round.color, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  round.speaker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: round.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  round.stance,
                  style: TextStyle(
                    color: round.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            round.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.42,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              '追问：${round.counter}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaRoundDots extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelected;

  const _ArenaRoundDots({
    required this.activeIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _debateArenaRounds.length; i++) ...[
          Expanded(
            child: _PressableScale(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 6,
                decoration: BoxDecoration(
                  color: i == activeIndex
                      ? _porcelainDeepBlue
                      : context.artC.silver.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          if (i != _debateArenaRounds.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _ArenaJudgePanel extends StatelessWidget {
  final _DebateArenaRound round;
  final _DebateSide side;

  const _ArenaJudgePanel({
    required this.round,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final sideLabel = _debateSideLabel(side);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _debateGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateGold.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.balance_outlined, size: 18, color: _debateGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI 裁判：$sideLabel视角下，这一轮要抓住“${round.counter}”继续追，不要只表态。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.68),
                fontSize: 12,
                height: 1.36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCanLoseBadge extends StatelessWidget {
  const _AgentCanLoseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _debateJade.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateJade.withValues(alpha: 0.34)),
      ),
      child: const Text(
        '可被说服',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DebateMessageBubble extends StatelessWidget {
  final String speaker;
  final String body;
  final Color color;
  final bool strong;

  const _DebateMessageBubble({
    required this.speaker,
    required this.body,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: strong ? Colors.white : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: strong ? 0.52 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            speaker,
            style: TextStyle(
              color: strong ? color : color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: strong
                  ? _porcelainNightBlue
                  : Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              height: 1.38,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoiseControlPanel extends StatelessWidget {
  final VoidCallback onStartAi;

  const _NoiseControlPanel({required this.onStartAi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _porcelainDeepBlue.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _porcelainDeepBlue.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _porcelainDeepBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '滚动评论不刷屏，AI 先做降噪',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                const Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _NoiseChip(label: '合并重复观点'),
                    _NoiseChip(label: '提取 3 个争点'),
                    _NoiseChip(label: '隐藏低质量吵架'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PressableScale(
            onTap: onStartAi,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _porcelainDeepBlue.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _porcelainDeepBlue.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: _porcelainDeepBlue,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoiseChip extends StatelessWidget {
  final String label;

  const _NoiseChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _porcelainDeepBlue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RhetoricalTitleLabCard extends StatefulWidget {
  final _AskQuestionLauncher onAskQuestion;
  final ValueChanged<String> onPrompt;

  const _RhetoricalTitleLabCard({
    required this.onAskQuestion,
    required this.onPrompt,
  });

  @override
  State<_RhetoricalTitleLabCard> createState() =>
      _RhetoricalTitleLabCardState();
}

class _RhetoricalTitleLabCardState extends State<_RhetoricalTitleLabCard> {
  int _packIndex = 0;
  int _titleIndex = 0;

  _RhetoricalTitlePack get _pack =>
      _rhetoricalTitlePacks[_packIndex % _rhetoricalTitlePacks.length];

  String get _selectedTitle =>
      _pack.titles[_titleIndex.clamp(0, _pack.titles.length - 1)];

  void _selectPack(int index) {
    setState(() {
      _packIndex = index;
      _titleIndex = 0;
    });
  }

  void _nextPack() {
    setState(() {
      _packIndex = (_packIndex + 1) % _rhetoricalTitlePacks.length;
      _titleIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pack.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _porcelainNightBlue.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pack.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(pack.icon, color: pack.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '反问标题实验室',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '把普通话题加工成能开吵的标题',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.46),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _PressableScale(
                onTap: _nextPack,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.artC.porcelain,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.artC.silver.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: _porcelainDeepBlue,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rhetoricalTitlePacks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final item = _rhetoricalTitlePacks[index];
                final selected = index == _packIndex;
                return _PressableScale(
                  onTap: () => _selectPack(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? item.color
                          : item.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            item.color.withValues(alpha: selected ? 1 : 0.16),
                      ),
                    ),
                    child: Text(
                      item.category,
                      style: TextStyle(
                        color: selected ? Colors.white : item.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: context.artC.porcelain,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleLabLine(
                  label: '原话题',
                  body: pack.source,
                  color: pack.color,
                ),
                const SizedBox(height: 7),
                _TitleLabLine(
                  label: '冲突点',
                  body: pack.tension,
                  color: _debateCoral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < pack.titles.length; i++) ...[
                _TitleOptionTile(
                  title: pack.titles[i],
                  selected: i == _titleIndex,
                  color: pack.color,
                  onTap: () => setState(() => _titleIndex = i),
                ),
                if (i != pack.titles.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineActionPill(
                icon: Icons.campaign_outlined,
                label: '发成辩题',
                color: pack.color,
                onTap: () => widget.onAskQuestion(
                  initialTitle: _selectedTitle,
                  initialCategory: pack.category,
                ),
              ),
              _InlineActionPill(
                icon: Icons.auto_awesome_outlined,
                label: 'AI加火药味',
                color: _debateLilac,
                onTap: () => widget.onPrompt(
                  '请把“${pack.source}”改写成更能激发讨论的反问句标题，并给出正反方切入点。',
                ),
              ),
              _InlineActionPill(
                icon: Icons.shuffle_rounded,
                label: '换一组',
                color: _porcelainDeepBlue,
                onTap: _nextPack,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleLabLine extends StatelessWidget {
  final String label;
  final String body;
  final Color color;

  const _TitleLabLine({
    required this.label,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            body,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.68),
              fontSize: 12,
              height: 1.34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TitleOptionTile({
    required this.title,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.42)
                : context.artC.silver.withValues(alpha: 0.48),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color:
                  selected ? color : context.artC.ink.withValues(alpha: 0.32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionComposerCard extends StatelessWidget {
  final String seed;
  final _AskQuestionLauncher onAskQuestion;
  final VoidCallback onStartAi;

  const _QuestionComposerCard({
    required this.seed,
    required this.onAskQuestion,
    required this.onStartAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateGold.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _debateGold.withValues(alpha: 0.075),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: _debateGold, size: 22),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '把围观变成一个好问题',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: context.artC.porcelain,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.38),
              ),
            ),
            child: Text(
              seed,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineActionPill(
                icon: Icons.question_answer_outlined,
                label: '用这句发问',
                color: _debateGold,
                onTap: () => onAskQuestion(initialTitle: seed),
              ),
              _InlineActionPill(
                icon: Icons.auto_awesome_outlined,
                label: '让 AI 改写',
                color: _debateLilac,
                onTap: onStartAi,
              ),
              _InlineActionPill(
                icon: Icons.forum_outlined,
                label: '看别人怎么问',
                color: _porcelainDeepBlue,
                onTap: () => onAskQuestion(
                  initialTitle: '这个话题我想换个角度问：',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlazaAskCard extends StatelessWidget {
  final String seed;
  final _AskQuestionLauncher onAskQuestion;

  const _PlazaAskCard({
    required this.seed,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _instaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _InstaAvatar(icon: Icons.edit_note_rounded, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '提出一个好问题',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _instaInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _instaCanvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _instaBorder),
            ),
            child: Text(
              seed,
              style: TextStyle(
                color: _instaInk.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _InlineActionPill(
            icon: Icons.question_answer_outlined,
            label: '用这句发问',
            color: _instaInk,
            onTap: () => onAskQuestion(initialTitle: seed),
          ),
        ],
      ),
    );
  }
}

class _InlineActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InlineActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.13)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDebateHero extends StatelessWidget {
  final VoidCallback onOpenForum;
  final VoidCallback onAskQuestion;

  const _HomeDebateHero({
    required this.onOpenForum,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: _inkWashGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _porcelainDeepBlue.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _InstaAvatar(icon: Icons.auto_awesome_rounded, size: 42),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '艺见心',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '艺术广场 · 热议社区',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _inkMistBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _LivePulseBadge(),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '今天广场想吵什么？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '申请者聊选择，艺术爱好者聊审美。先把问题说清楚，再看大家怎么站队。',
            style: TextStyle(
              color: _inkMistBlue.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroActionButton(
                icon: Icons.edit_note_rounded,
                label: '提出问题',
                color: _debateGold,
                textColor: _porcelainNightBlue,
                onTap: onAskQuestion,
              ),
              _HeroActionButton(
                icon: Icons.forum_outlined,
                label: '加入讨论',
                color: Colors.white.withValues(alpha: 0.1),
                textColor: Colors.white,
                onTap: onOpenForum,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePulseBadge extends StatelessWidget {
  const _LivePulseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 14, color: _debateGold),
          SizedBox(width: 3),
          Text(
            '热',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color == Colors.white
                ? _instaBorder
                : color.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: textColor == Colors.white
                  ? Colors.black.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRail extends StatelessWidget {
  final List<_StorySignal> stories;
  final VoidCallback onTap;

  const _StoryRail({
    required this.stories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          return _PressableScale(
            onTap: onTap,
            child: SizedBox(
              width: 74,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          story.accent,
                          _porcelainDeepBlue.withValues(alpha: 0.86),
                          _debateGold,
                          story.accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: story.accent.withValues(alpha: 0.11),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(story.icon, color: story.accent, size: 23),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    story.count,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink.withValues(alpha: 0.42),
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiveCommentTicker extends StatefulWidget {
  final List<_LiveComment> comments;

  const _LiveCommentTicker({required this.comments});

  @override
  State<_LiveCommentTicker> createState() => _LiveCommentTickerState();
}

class _LiveCommentTickerState extends State<_LiveCommentTicker> {
  Timer? _timer;
  int _index = 0;
  _TickerDisplayMode _mode = _TickerDisplayMode.aiDigest;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted || widget.comments.isEmpty) return;
      setState(() => _index = (_index + 1) % widget.comments.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<_LiveComment> get _rollingComments {
    final count = math.min(3, widget.comments.length);
    return List.generate(
      count,
      (offset) => widget.comments[(_index + offset) % widget.comments.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comments.isEmpty) return const SizedBox.shrink();
    final comment = widget.comments[_index % widget.comments.length];
    final isAiDigest = _mode == _TickerDisplayMode.aiDigest;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kCobalt.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: kCobalt.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _debateCoral,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '广场实时声浪',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TickerModeButton(
                label: 'AI精简',
                active: isAiDigest,
                onTap: () => setState(
                  () => _mode = _TickerDisplayMode.aiDigest,
                ),
              ),
              const SizedBox(width: 6),
              _TickerModeButton(
                label: '实时',
                active: !isAiDigest,
                onTap: () => setState(
                  () => _mode = _TickerDisplayMode.liveRoll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 190),
            reverseDuration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.97, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: isAiDigest
                ? _AiLiveDigest(
                    key: ValueKey('digest-$_index'),
                    comment: comment,
                    foldedCount: widget.comments.length * 7 + 18,
                  )
                : _LiveRollColumn(
                    key: ValueKey('roll-$_index'),
                    comments: _rollingComments,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TickerModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TickerModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _porcelainDeepBlue : context.artC.porcelain,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? _porcelainDeepBlue
                : context.artC.silver.withValues(alpha: 0.48),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : context.artC.ink.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AiLiveDigest extends StatelessWidget {
  final _LiveComment comment;
  final int foldedCount;

  const _AiLiveDigest({
    super.key,
    required this.comment,
    required this.foldedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _porcelainDeepBlue.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _porcelainDeepBlue.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _porcelainNightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: _debateGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'AI 已合并 $foldedCount 条重复观点',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: comment.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  comment.badge,
                  style: TextStyle(
                    color: comment.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '当前最有传播力的说法：${comment.body}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.38,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _DigestPointChip(label: '保留高赞反问'),
              _DigestPointChip(label: '折叠情绪重复'),
              _DigestPointChip(label: '推送给相关辩题'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveRollColumn extends StatelessWidget {
  final List<_LiveComment> comments;

  const _LiveRollColumn({
    super.key,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        for (var i = 0; i < comments.length; i++) ...[
          _LiveRollItem(
            comment: comments[i],
            dimmed: i == comments.length - 1,
          ),
          if (i != comments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LiveRollItem extends StatelessWidget {
  final _LiveComment comment;
  final bool dimmed;

  const _LiveRollItem({
    required this.comment,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.66 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: comment.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              comment.author.characters.first,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: comment.accent,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.34),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        comment.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: comment.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.34,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigestPointChip extends StatelessWidget {
  final String label;

  const _DigestPointChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.58),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                Text(
                  eyebrow!,
                  style: const TextStyle(
                    color: _porcelainDeepBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          _PressableScale(
            onTap: onAction,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: _porcelainDeepBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _porcelainDeepBlue.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: _porcelainDeepBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _porcelainDeepBlue,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _plazaFeedTabLabels = ['推荐', '关注', '热议', '最新', '圈子'];

class _PlazaFeedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PlazaFeedTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (var i = 0; i < _plazaFeedTabLabels.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 2,
                  right: i == _plazaFeedTabLabels.length - 1 ? 0 : 2,
                ),
                child: _PlazaFeedTab(
                  label: _plazaFeedTabLabels[i],
                  active: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlazaFeedTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PlazaFeedTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: TextStyle(
        color: active
            ? kGlassInk.withValues(alpha: 0.94)
            : kGlassInk.withValues(alpha: 0.58),
        fontSize: 12.8,
        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
        letterSpacing: 0,
        fontFamily: kAppFontFamily,
        fontFamilyFallback: kAppFontFallback,
      ),
    );
    return _PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? Border.all(color: Colors.white.withValues(alpha: 0.38))
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 8,
                    spreadRadius: -5,
                    offset: const Offset(0, -1),
                  ),
                ]
              : null,
        ),
        child: labelText,
      ),
    );
  }
}

class _PlazaDataStateCard extends StatelessWidget {
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onAskQuestion;

  const _PlazaDataStateCard({
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? '正在读取广场话题'
        : hasError
            ? '广场暂时没连上'
            : '还没有精选广场话题';
    final subtitle = loading
        ? '系统正在从问答里挑选适合公开讨论的话题。'
        : hasError
            ? '请稍后重试，或先发一个值得讨论的问题。'
            : '提问后，适合公开讨论的问题会进入这里。';
    return DeepSeaGlassPanel(
      padding: const EdgeInsets.all(18),
      radius: 26,
      glow: hasError,
      opacity: 0.68,
      airy: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: kGlassAccent,
                    ),
                  )
                : Icon(
                    hasError ? Icons.wifi_off_rounded : Icons.forum_outlined,
                    color: kGlassAccent,
                    size: 23,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _homeFeedTitleStyle(
                    color: kGlassInk,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: _homeFeedInfoStyle(
                    color: kGlassMuted,
                    fontSize: 13,
                    height: 1.42,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PlazaStateAction(
                        label: hasError ? '重试' : '去提问',
                        primary: true,
                        onTap: hasError ? onRetry : onAskQuestion,
                      ),
                      if (hasError)
                        _PlazaStateAction(
                          label: '去提问',
                          onTap: onAskQuestion,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlazaStateAction extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _PlazaStateAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? kGlassAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: primary
                ? kGlassAccent.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? kGlassAccent : kGlassInk.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            fontFamily: kAppFontFamily,
            fontFamilyFallback: kAppFontFallback,
          ),
        ),
      ),
    );
  }
}

class _PlazaLeadHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  const _PlazaLeadHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = active ? _plazaInk : _plazaText;
    return IconButton(
      onPressed: busy ? null : onTap,
      tooltip: tooltip,
      color: ink,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      visualDensity: VisualDensity.compact,
      icon: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(ink),
              ),
            )
          : Icon(icon, size: 20),
    );
  }
}

class _PlazaLeadMoreButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onConvertLead;

  const _PlazaLeadMoreButton({
    required this.busy,
    required this.onConvertLead,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const _PlazaLeadHeaderIcon(
        icon: Icons.more_horiz_rounded,
        tooltip: '更多',
        busy: true,
        onTap: null,
      );
    }
    return PopupMenuButton<String>(
      tooltip: '更多',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 128),
      icon: const Icon(Icons.more_horiz_rounded, size: 22),
      color: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => onConvertLead(),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'convert',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                '转咨询',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlazaLeadReplySheet extends StatefulWidget {
  final AppCommunityPost post;
  final bool consultIntent;

  const _PlazaLeadReplySheet({
    required this.post,
    required this.consultIntent,
  });

  @override
  State<_PlazaLeadReplySheet> createState() => _PlazaLeadReplySheetState();
}

class _PlazaLeadReplySheetState extends State<_PlazaLeadReplySheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialDraft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _initialDraft {
    final title = widget.post.title.trim();
    final topic = title.length > 20 ? '${title.substring(0, 20)}...' : title;
    if (widget.consultIntent) {
      return topic.isEmpty
          ? '你好，我们看到了你的申请问题。如果你愿意，可以补充目标国家、专业方向、预算和作品集阶段，我们会先给你一个公开的初步建议；需要进一步沟通时，也可以从官方组织主页发起咨询。'
          : '你好，我们看到了你关于“$topic”的问题。如果你愿意，可以补充目标国家、专业方向、预算和作品集阶段，我们会先给你一个公开的初步建议；需要进一步沟通时，也可以从官方组织主页发起咨询。';
    }
    return '你好，我先回应一个方向：';
  }

  void _submit() {
    final body = _controller.text.trim();
    if (body.length < 8) {
      setState(() => _error = '回应再具体一点，学生会更容易判断是否继续沟通');
      return;
    }
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + safeBottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: _plazaInk.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  widget.consultIntent
                      ? Icons.arrow_forward_rounded
                      : Icons.mode_comment_outlined,
                  size: 21,
                  color: _plazaInk,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.consultIntent ? '公开回应并引导咨询' : '公开回应学生动态',
                    style: const TextStyle(
                      color: _plazaInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _plazaMuted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              cursorColor: _plazaInk,
              decoration: InputDecoration(
                hintText: '写一段公开、克制、对学生有帮助的回应',
                errorText: _error,
                filled: true,
                fillColor: _plazaSoft,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _plazaInk.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _plazaInk.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _plazaInk.withValues(alpha: 0.26),
                  ),
                ),
              ),
              style: const TextStyle(
                color: _plazaInk,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: _plazaMuted,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  child: const Text('取消'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _plazaInk,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(98, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(widget.consultIntent ? '发布并收藏' : '发布回应'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlazaCircleStateCard extends StatelessWidget {
  final bool loading;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;
  final VoidCallback onCreateCircle;

  const _PlazaCircleStateCard({
    this.loading = false,
    required this.title,
    required this.subtitle,
    required this.onRetry,
    required this.onCreateCircle,
  });

  @override
  Widget build(BuildContext context) {
    return DeepSeaGlassPanel(
      padding: const EdgeInsets.all(18),
      radius: 26,
      opacity: 0.68,
      airy: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: kGlassAccent,
                    ),
                  )
                : const Icon(
                    Icons.groups_outlined,
                    color: kGlassAccent,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _homeFeedTitleStyle(
                    color: kGlassInk,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: _homeFeedInfoStyle(
                    color: kGlassMuted,
                    fontSize: 12.5,
                    height: 1.42,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PlazaStateAction(
                        label: '刷新',
                        onTap: onRetry,
                      ),
                      _PlazaStateAction(
                        label: '创建圈子',
                        primary: true,
                        onTap: onCreateCircle,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlazaCircleListCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final int index;
  final String joinStatus;
  final VoidCallback onTap;

  const _PlazaCircleListCard({
    required this.circle,
    required this.index,
    required this.joinStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _plazaCircleTitle(circle);
    final subtitle = _plazaCircleSubtitle(circle, index);
    final tags = _plazaCircleTags(circle, index);
    final members = _plazaCircleInt(circle['member_count']);
    final today = _plazaCircleInt(circle['today_post_count']);
    final hotTopic = _plazaCircleHotTopic(circle, index);
    final joinType = _plazaCircleJoinType(circle, index);
    return _PressableScale(
      onTap: onTap,
      pressedScale: 0.985,
      child: DeepSeaGlassPanel(
        padding: const EdgeInsets.all(14),
        radius: 26,
        opacity: 0.7,
        airy: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Icon(
                _plazaCircleIcon(circle, index),
                color: kGlassAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _homeFeedTitleStyle(
                            color: kGlassInk,
                            fontSize: 15.2,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PlazaCircleStatusPill(
                        label: _plazaCircleActionLabel(joinStatus, joinType),
                        active: joinStatus == 'joined',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _homeFeedInfoStyle(
                      color: kGlassInk.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '正在聊：$hotTopic',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _homeFeedInfoStyle(
                      color: kGlassMuted.withValues(alpha: 0.82),
                      fontSize: 11.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: tags
                              .take(3)
                              .map((tag) => _PlazaCircleMiniTag(label: tag))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PlazaMetaText(
                        '${members == 0 ? '--' : members}人 · 今日${today == 0 ? '--' : today}',
                      ),
                    ],
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

class _PlazaCircleStatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _PlazaCircleStatusPill({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? kGlassAccent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? kGlassAccent.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.48),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? kGlassAccent : kGlassInk.withValues(alpha: 0.68),
          fontSize: 10,
          fontWeight: active ? FontWeight.w800 : FontWeight.w700,
          letterSpacing: 0,
          fontFamily: kAppFontFamily,
          fontFamilyFallback: kAppFontFallback,
        ),
      ),
    );
  }
}

class _PlazaCircleMiniTag extends StatelessWidget {
  final String label;

  const _PlazaCircleMiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: kGlassMuted.withValues(alpha: 0.82),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          fontFamily: kAppFontFamily,
          fontFamilyFallback: kAppFontFallback,
        ),
      ),
    );
  }
}

class PlazaCreateCircleScreen extends StatefulWidget {
  const PlazaCreateCircleScreen({super.key});

  @override
  State<PlazaCreateCircleScreen> createState() =>
      _PlazaCreateCircleScreenState();
}

class _PlazaCreateCircleScreenState extends State<PlazaCreateCircleScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _placeCtrl = TextEditingController();
  final TextEditingController _introCtrl = TextEditingController();
  final Set<String> _directions = {'留学'};
  String _joinType = 'open';
  bool _submitting = false;
  String _error = '';

  static const _directionOptions = ['留学', '作品集', '同城', '就业', '市场'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _placeCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameCtrl.text.trim();
    final place = _placeCtrl.text.trim();
    final intro = _introCtrl.text.trim();
    if (name.length < 4 || name.length > 24) {
      setState(() => _error = '圈子名称需为 4-24 个字');
      return;
    }
    if (_directions.isEmpty) {
      setState(() => _error = '请选择至少一个方向');
      return;
    }
    if (_directions.contains('同城') && place.isEmpty) {
      setState(() => _error = '同城圈子需要填写城市或地区');
      return;
    }
    if (intro.length < 10) {
      setState(() => _error = '简介再具体一点，至少 10 个字');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    final directions = _directions.toList();
    final metadata = {
      'directions': directions,
      'join_type': _joinType,
      'tags': [
        ...directions.map((item) => '#$item'),
        if (place.isNotEmpty) '#$place',
      ],
      'hot_topic': '发布第一条讨论，开启圈子交流',
      'announcement': '欢迎来到$name。这里适合交流${directions.join('、')}相关经验、资源和机会。',
    };
    try {
      final created = await BackendApiService.createCommunityCircle({
        'title': name,
        'subtitle': intro,
        'category': directions.first,
        'city': place.isEmpty ? null : place,
        'metadata': metadata,
      });
      if (!mounted) return;
      final createdMetadata = _plazaCircleMetadata(created);
      Navigator.of(context).pop({
        ...created,
        'join_type': _joinType,
        'metadata': {
          ...metadata,
          ...createdMetadata,
        },
        'hot_topic': created['hot_topic'] ?? '发布第一条讨论，开启圈子交流',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '创建失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _plazaInk, size: 20),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          '创建圈子',
          style: TextStyle(
            color: _plazaInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: kCobalt,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: Text(_submitting ? '创建中' : '创建'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
          children: [
            const Text(
              '让同学校、同专业或同城市的人有一个固定讨论场。',
              style: TextStyle(
                color: _plazaText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 34),
            _PlazaCreateField(
              controller: _nameCtrl,
              label: '圈子名称',
              hint: '例如：RCA 作品集互助圈',
            ),
            const SizedBox(height: 28),
            const _PlazaCreateLabel('方向'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _directionOptions.map((item) {
                return _PlazaCreateChip(
                  label: item,
                  selected: _directions.contains(item),
                  onTap: () {
                    setState(() {
                      if (_directions.contains(item)) {
                        _directions.remove(item);
                      } else if (_directions.length < 2) {
                        _directions.add(item);
                      } else {
                        _directions
                          ..clear()
                          ..add(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const _PlazaCreateLabel('加入方式'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlazaCreateChip(
                  label: '开放加入',
                  selected: _joinType == 'open',
                  onTap: () => setState(() => _joinType = 'open'),
                ),
                _PlazaCreateChip(
                  label: '申请加入',
                  selected: _joinType == 'approval',
                  onTap: () => setState(() => _joinType = 'approval'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _PlazaCreateField(
              controller: _placeCtrl,
              label: '城市 / 学校（可选）',
              hint: '例如：伦敦、RCA、UAL',
            ),
            const SizedBox(height: 28),
            _PlazaCreateField(
              controller: _introCtrl,
              label: '圈子简介',
              hint: '这个圈子适合谁？大家可以交流什么？',
              maxLines: 5,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                _error,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlazaRatingTargetScreen extends StatefulWidget {
  const PlazaRatingTargetScreen({super.key});

  @override
  State<PlazaRatingTargetScreen> createState() =>
      _PlazaRatingTargetScreenState();
}

class _PlazaRatingTargetScreenState extends State<PlazaRatingTargetScreen> {
  static const _categories = [
    '艺术家',
    '作品',
    '展览',
    '活动',
  ];

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _quoteCtrl = TextEditingController();
  String _category = '艺术家';
  bool _submitting = false;
  String _error = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  String get _titleHint {
    return switch (_category) {
      '艺术家' => '例如：宫崎骏',
      '作品' => '例如：戴珍珠耳环的少女 / 某本画册 / 某部影像',
      '展览' => '例如：某某美术馆年度展',
      '活动' => '例如：某个工作坊、开放日或艺术节',
      _ => '输入想让大家打分的对象',
    };
  }

  String get _noteHint {
    return switch (_category) {
      '展览' => '展览地点、时间或你想让大家评价的角度',
      '活动' => '活动时间、城市、主办方或你想讨论的体验',
      _ => '补充身份、背景、代表作或你想让大家评价的点',
    };
  }

  String get _collectionLabel {
    return '$_category口碑';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!await ensureLoggedIn(context, message: '请先登录后发布评分')) {
      return;
    }
    if (!mounted) return;
    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final quote = _quoteCtrl.text.trim();
    if (title.length < 2) {
      setState(() => _error = '名称再具体一点，至少 2 个字');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await BackendApiService.createPlazaPost(
        title: title,
        body: note,
        kind: 'rating',
        group: _category,
        tags: [_category, _collectionLabel],
        metadata: {
          'kind': 'rating',
          'legacy_type': 'rating_item',
          'source': 'plaza_rating',
          'promote_to_plaza': true,
          'rating_category': _category,
          'target_name': title,
          'collection': _collectionLabel,
          'subtitle': note.isEmpty ? '由用户上传，等待大家打分和评论。' : note,
          'quote': quote.isEmpty ? '请给出你的判断和理由。' : quote,
          'score': '待评',
          'rating_count': '0',
          'likes_label': '0',
          'comments_label': '0',
          'source_label': '$_category评分',
          'cover_seed': '$_category-$title',
          'time_label': '刚刚',
          'replies': const [],
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop({
        'title': title,
        'category': _category,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '发布失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _plazaInk, size: 20),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          '发布评分',
          style: TextStyle(
            color: _plazaInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: kCobalt,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: Text(_submitting ? '发布中' : '发布'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
          children: [
            const Text(
              '上传艺术家、作品、展览或活动，让大家打分和讨论。',
              style: TextStyle(
                color: _plazaText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 34),
            const _PlazaCreateLabel('类型'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((item) {
                return _PlazaCreateChip(
                  label: item,
                  selected: _category == item,
                  onTap: () => setState(() => _category = item),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            _PlazaCreateField(
              controller: _titleCtrl,
              label: '打分对象',
              hint: _titleHint,
            ),
            const SizedBox(height: 28),
            _PlazaCreateField(
              controller: _noteCtrl,
              label: '补充说明',
              hint: _noteHint,
              maxLines: 4,
            ),
            const SizedBox(height: 28),
            _PlazaCreateField(
              controller: _quoteCtrl,
              label: '代表语句 / 评价切口（可选）',
              hint: '例如：为什么这个对象值得打高分或被争议？',
              maxLines: 4,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                _error,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlazaCreateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _PlazaCreateField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlazaCreateLabel(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          cursorColor: _plazaInk,
          maxLines: maxLines,
          style: const TextStyle(
            color: _plazaInk,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _plazaMuted,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 11),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _plazaBorder, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: _plazaInk.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlazaCreateLabel extends StatelessWidget {
  final String label;

  const _PlazaCreateLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _plazaInk,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _PlazaCreateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PlazaCreateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _plazaInk.withValues(alpha: 0.055)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? _plazaInk : _plazaInk.withValues(alpha: 0.28),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

String _plazaCircleId(Map<String, dynamic> circle, int index) {
  final id = circle['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  return '${_plazaCircleTitle(circle)}-$index';
}

Map<String, dynamic> _plazaCircleMetadata(Map<String, dynamic> circle) {
  final metadata = circle['metadata'];
  if (metadata is Map<String, dynamic>) return metadata;
  if (metadata is Map) return Map<String, dynamic>.from(metadata);
  return const {};
}

String _plazaCircleTitle(Map<String, dynamic> circle) {
  final title = circle['title']?.toString().trim();
  if (title != null && title.isNotEmpty) return title;
  return '未命名圈子';
}

String _plazaCircleSubtitle(Map<String, dynamic> circle, int index) {
  final subtitle = circle['subtitle']?.toString().trim();
  if (subtitle != null && subtitle.isNotEmpty) return subtitle;
  final category = circle['category']?.toString().trim();
  if (category != null && category.isNotEmpty) return '$category方向交流';
  return ['申请互助、资料共建和经验复盘', '作品集诊断、项目叙事和面试准备', '同城看展、沙龙和资源连接'][index % 3];
}

int _plazaCircleInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _plazaCircleJoinType(Map<String, dynamic> circle, int index) {
  final raw = circle['join_type']?.toString().trim();
  if (raw == 'open' || raw == 'approval' || raw == 'private') return raw!;
  final metadataRaw =
      _plazaCircleMetadata(circle)['join_type']?.toString().trim();
  if (metadataRaw == 'open' ||
      metadataRaw == 'approval' ||
      metadataRaw == 'private') {
    return metadataRaw!;
  }
  final text = [
    _plazaCircleTitle(circle),
    _plazaCircleSubtitle(circle, index),
    circle['category']?.toString() ?? '',
  ].join(' ');
  if (text.contains('认证') || text.contains('研究')) return 'approval';
  return 'open';
}

String _plazaCircleActionLabel(String status, String joinType) {
  if (status == 'joined') return '已加入';
  if (status == 'pending') return '待审核';
  if (joinType == 'private') return '私密';
  if (joinType == 'approval') return '申请加入';
  return '可加入';
}

String _plazaCircleHotTopic(Map<String, dynamic> circle, int index) {
  final direct = circle['hot_topic']?.toString().trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final metadata = _plazaCircleMetadata(circle);
  final meta = metadata['hot_topic']?.toString().trim();
  if (meta != null && meta.isNotEmpty) return meta;
  final title = _plazaCircleTitle(circle);
  if (title.toLowerCase().contains('rca') || title.contains('院校')) {
    return '作品集叙事和选校优先级怎么排';
  }
  if (title.contains('同城')) return '本周有哪些值得一起去的展览';
  if (title.contains('就业')) return '第一份艺术行业实习怎么准备';
  return '新成员自我介绍和资源互助';
}

List<String> _plazaCircleTags(Map<String, dynamic> circle, int index) {
  final tags = <String>[];
  void addTag(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return;
    final cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
    if (cleaned.isEmpty) return;
    final tag = '#$cleaned';
    if (!tags.contains(tag)) tags.add(tag);
  }

  final metadata = _plazaCircleMetadata(circle);
  final metaTags = metadata['tags'];
  if (metaTags is Iterable) {
    for (final tag in metaTags) {
      addTag(tag);
    }
  } else if (metaTags is String) {
    for (final tag in metaTags.split(RegExp(r'[,，\s]+'))) {
      addTag(tag);
    }
  }
  final directions = metadata['directions'];
  if (directions is Iterable) {
    for (final direction in directions) {
      addTag(direction);
    }
  }
  addTag(circle['category']);
  addTag(circle['city']);
  if (tags.isEmpty) {
    const fallback = ['#留学', '#作品集', '#同城', '#就业', '#市场'];
    tags.add(fallback[index % fallback.length]);
  }
  return tags;
}

IconData _plazaCircleIcon(Map<String, dynamic> circle, int index) {
  final text = [
    _plazaCircleTitle(circle),
    _plazaCircleSubtitle(circle, index),
    circle['category']?.toString() ?? '',
    ..._plazaCircleTags(circle, index),
  ].join(' ').toLowerCase();
  if (text.contains('作品') || text.contains('portfolio')) {
    return Icons.image_search_outlined;
  }
  if (text.contains('同城') || text.contains('city')) {
    return Icons.location_city_outlined;
  }
  if (text.contains('就业') || text.contains('career') || text.contains('实习')) {
    return Icons.work_outline_rounded;
  }
  if (text.contains('市场') || text.contains('展览') || text.contains('收藏')) {
    return Icons.storefront_outlined;
  }
  return Icons.school_outlined;
}

class _DebateTopicCard extends StatefulWidget {
  final _DebateTopic topic;
  final AppCommunityPost? post;
  final bool likeBusy;
  final bool saveBusy;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback onTap;

  const _DebateTopicCard({
    required this.topic,
    this.post,
    this.likeBusy = false,
    this.saveBusy = false,
    this.onLike,
    this.onSave,
    required this.onTap,
  });

  @override
  State<_DebateTopicCard> createState() => _DebateTopicCardState();
}

class _DebateTopicCardState extends State<_DebateTopicCard>
    with _PlazaCardActionTapShield<_DebateTopicCard> {
  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final hotReply = _plazaTopicHotReply(topic);
    final summary = hotReply.trim().isNotEmpty ? hotReply : topic.lead;
    final sourcePost = widget.post ?? topic.leadPost;
    return _PressableInsetCard(
      onTap: guardedCardTap(widget.onTap),
      builder: (pressed) => _PlazaOverviewGlassCard(
        pressed: pressed,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _homeFeedTitleStyle(
                      color: kGlassInk,
                      fontSize: 15.8,
                      height: 1.24,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _PlazaOverviewByline(
                    source: _plazaSourceText('${topic.channel}圈子'),
                    time: _plazaTopicTime(topic),
                    icon: topic.icon,
                    accent: topic.accent,
                  ),
                  const SizedBox(height: 7),
                  _PlazaHotReplyLine(
                    label: '',
                    text: summary,
                    accent: topic.accent,
                  ),
                  const SizedBox(height: 10),
                  _PlazaOverviewActionRow(
                    upLabel: _plazaTopicLikeLabel(topic),
                    favoriteLabel: topic.floor,
                    commentLabel: topic.comments,
                    upActive: sourcePost?.likedByMe ?? false,
                    favoriteActive: sourcePost?.savedByMe ?? false,
                    upBusy: widget.likeBusy,
                    favoriteBusy: widget.saveBusy,
                    onUpTap: sourcePost == null
                        ? null
                        : guardedActionTap(widget.onLike),
                    onFavoriteTap: sourcePost == null
                        ? null
                        : guardedActionTap(widget.onSave),
                    onCommentTap: guardedActionTap(widget.onTap),
                    onBackgroundTap: guardedActionTap(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: _PlazaTopicThumb(topic: topic, size: 72),
            ),
          ],
        ),
      ),
    );
  }
}

mixin _PlazaCardActionTapShield<T extends StatefulWidget> on State<T> {
  bool _ignoreNextCardTap = false;

  VoidCallback guardedCardTap(VoidCallback onTap) {
    return () {
      if (_ignoreNextCardTap) {
        _ignoreNextCardTap = false;
        return;
      }
      onTap();
    };
  }

  VoidCallback? guardedActionTap(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      _ignoreNextCardTap = true;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          if (mounted) _ignoreNextCardTap = false;
        }),
      );
      onTap();
    };
  }
}

class _PlazaOverviewGlassCard extends StatelessWidget {
  final Widget child;
  final bool pressed;

  const _PlazaOverviewGlassCard({
    required this.child,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    final borderRadius = BorderRadius.circular(radius);
    return Stack(
      children: [
        OpticalGlassSurface(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
          radius: radius,
          surfaceOpacity: pressed ? 0.09 : 0.072,
          blurSigma: pressed ? 28 : 34,
          elevated: true,
          borderOpacity: 0,
          innerBorderOpacity: 0,
          highlightOpacity: 0,
          bottomShadeOpacity: 0,
          shadowOpacity: pressed ? 0.003 : 0.028,
          glowOpacity: pressed ? 0.008 : 0.04,
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: pressed ? 1 : 0,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D9299).withValues(alpha: 0.16),
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: kGlassInk.withValues(alpha: 0.07),
                      width: 0.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kGlassInk.withValues(alpha: 0.12),
                        const Color(0xFF8D9299).withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.018),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PressableInsetCard extends StatefulWidget {
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;

  const _PressableInsetCard({
    required this.builder,
    required this.onTap,
  });

  @override
  State<_PressableInsetCard> createState() => _PressableInsetCardState();
}

class _PressableInsetCardState extends State<_PressableInsetCard> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (widget.onTap == null || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  Future<void> _handleTap() async {
    final onTap = widget.onTap;
    if (onTap == null) return;
    Feedback.forTap(context);
    _setPressed(true);
    await Future<void>.delayed(const Duration(milliseconds: 95));
    if (!mounted) return;
    _setPressed(false);
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {},
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 105),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _pressed ? 2.4 : 0, 0),
          child: AnimatedScale(
            scale: _pressed ? 0.988 : 1,
            duration: const Duration(milliseconds: 105),
            curve: Curves.easeOutCubic,
            child: widget.builder(_pressed),
          ),
        ),
      ),
    );
  }
}

class _PlazaMetaText extends StatelessWidget {
  final String text;

  const _PlazaMetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _homeFeedInfoStyle(
        color: kGlassMuted.withValues(alpha: 0.82),
        fontSize: 11,
      ),
    );
  }
}

class _PlazaOverviewByline extends StatelessWidget {
  final String source;
  final String time;
  final IconData icon;
  final Color accent;

  const _PlazaOverviewByline({
    required this.source,
    required this.time,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
          ),
          child: Icon(
            icon,
            size: 12,
            color: accent.withValues(alpha: 0.86),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$source · $time',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _homeFeedInfoStyle(
              color: kGlassMuted.withValues(alpha: 0.78),
              fontSize: 11.9,
              height: 1.18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlazaOverviewActionRow extends StatelessWidget {
  final String upLabel;
  final String favoriteLabel;
  final String commentLabel;
  final bool upActive;
  final bool favoriteActive;
  final bool upBusy;
  final bool favoriteBusy;
  final VoidCallback? onUpTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onBackgroundTap;

  const _PlazaOverviewActionRow({
    required this.upLabel,
    required this.favoriteLabel,
    required this.commentLabel,
    this.upActive = false,
    this.favoriteActive = false,
    this.upBusy = false,
    this.favoriteBusy = false,
    this.onUpTap,
    this.onFavoriteTap,
    this.onCommentTap,
    this.onBackgroundTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onBackgroundTap,
      child: Row(
        children: [
          _PlazaOverviewActionIcon(
            icon: Icons.change_history_rounded,
            activeIcon: Icons.arrow_drop_up_rounded,
            label: upLabel,
            tooltip: upActive ? '取消点赞' : '点赞',
            active: upActive,
            busy: upBusy,
            onTap: onUpTap,
          ),
          const SizedBox(width: 22),
          _PlazaOverviewActionIcon(
            icon:
                favoriteActive ? Icons.star_rounded : Icons.star_border_rounded,
            label: favoriteLabel,
            tooltip: favoriteActive ? '取消收藏' : '收藏',
            active: favoriteActive,
            busy: favoriteBusy,
            onTap: onFavoriteTap,
          ),
          const SizedBox(width: 22),
          _PlazaOverviewActionIcon(
            icon: Icons.chat_bubble_outline_rounded,
            label: commentLabel,
            tooltip: '查看评论',
            onTap: onCommentTap,
          ),
        ],
      ),
    );
  }
}

class _PlazaOverviewActionIcon extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String tooltip;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  const _PlazaOverviewActionIcon({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.tooltip = '',
    this.active = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? kGlassAccent.withValues(alpha: 0.94)
        : kGlassMuted.withValues(alpha: 0.82);
    final effectiveTap = busy ? () {} : onTap;
    final displayIcon = active ? activeIcon ?? icon : icon;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: busy
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    displayIcon,
                    key: ValueKey(displayIcon),
                    size: active && activeIcon != null ? 21 : 17,
                    color: color,
                  ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _homeFeedInfoStyle(
                color: active ? color : kGlassMuted.withValues(alpha: 0.76),
                fontSize: 11.9,
                height: 1.05,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
    final wrapped = effectiveTap == null
        ? content
        : _PressableScale(
            onTap: effectiveTap,
            pressedScale: 0.9,
            child: content,
          );
    return Flexible(
      fit: FlexFit.loose,
      child: Tooltip(
        message: tooltip,
        child: wrapped,
      ),
    );
  }
}

class _PlazaHotReplyLine extends StatelessWidget {
  final String label;
  final String text;
  final Color accent;

  const _PlazaHotReplyLine({
    required this.label,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = text.trim().isEmpty ? '等你写下第一条有用判断。' : text.trim();
    final hasLabel = label.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLabel) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '$label ·',
              style: _homeFeedInfoStyle(
                color: accent.withValues(alpha: 0.76),
                fontSize: 10.2,
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            displayText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _homeFeedInfoStyle(
              color: kGlassInk.withValues(alpha: 0.68),
              fontSize: 12.8,
              height: 1.38,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

String _compactPlazaMetric(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase().contains('k')) return trimmed;
  final numeric = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
  if (numeric == null || numeric < 10000) return trimmed;
  final compact = numeric / 1000;
  final text = compact == compact.roundToDouble()
      ? compact.toStringAsFixed(0)
      : compact.toStringAsFixed(1);
  return '${text}k';
}

String _plazaSourceText(String value) {
  final normalized = value.trim().replaceAll('小组', '圈子');
  if (normalized.isEmpty) return '广场';
  if (normalized.startsWith('来自')) {
    return normalized.replaceFirst(RegExp(r'^来自'), '').trim();
  }
  return normalized;
}

class _PlazaTopicThumb extends StatelessWidget {
  final _DebateTopic topic;
  final double size;

  const _PlazaTopicThumb({
    required this.topic,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        _plazaTopicImageUrl(topic),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Icon(
            topic.icon,
            color: kGlassAccent.withValues(alpha: 0.78),
            size: size * 0.38,
          ),
        ),
      ),
    );
  }
}

String _plazaTopicLikeLabel(_DebateTopic topic) {
  return topic.heat;
}

String _plazaTopicHotReply(_DebateTopic topic) {
  for (final candidate in [
    topic.hotComment,
    topic.proComment,
    topic.conComment,
    topic.agentReply,
  ]) {
    final trimmed = candidate.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return topic.askSeed;
}

String _plazaTopicImageUrl(_DebateTopic topic) {
  return 'https://picsum.photos/seed/artsee_plaza_${Uri.encodeComponent(topic.title)}/720/420';
}

String _plazaTopicTime(_DebateTopic topic) {
  final times = ['昨天10:57', '昨天10:35', '昨天10:32', '今天09:18', '今天13:40'];
  return times[topic.title.hashCode.abs() % times.length];
}

class _PlazaRatingCard extends StatefulWidget {
  final _PlazaRatingItem item;
  final AppCommunityPost? post;
  final bool likeBusy;
  final bool saveBusy;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback onTap;

  const _PlazaRatingCard({
    required this.item,
    this.post,
    this.likeBusy = false,
    this.saveBusy = false,
    this.onLike,
    this.onSave,
    required this.onTap,
  });

  @override
  State<_PlazaRatingCard> createState() => _PlazaRatingCardState();
}

class _PlazaRatingCardState extends State<_PlazaRatingCard>
    with _PlazaCardActionTapShield<_PlazaRatingCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final sourcePost = widget.post ?? item.leadPost;
    return _PressableInsetCard(
      onTap: guardedCardTap(widget.onTap),
      builder: (pressed) => _PlazaOverviewGlassCard(
        pressed: pressed,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlazaRatingTitle(item: item),
                  const SizedBox(height: 7),
                  _PlazaOverviewByline(
                    source: _plazaSourceText(item.source),
                    time: item.time,
                    icon: Icons.star_rate_rounded,
                    accent: item.accent,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.quote.trim().isEmpty ? item.subtitle : item.quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _homeFeedInfoStyle(
                      color: kGlassInk.withValues(alpha: 0.68),
                      fontSize: 12.8,
                      height: 1.38,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PlazaOverviewActionRow(
                    upLabel: item.likes,
                    favoriteLabel: _compactPlazaMetric(item.ratingCount),
                    commentLabel: item.comments,
                    upActive: sourcePost?.likedByMe ?? false,
                    favoriteActive: sourcePost?.savedByMe ?? false,
                    upBusy: widget.likeBusy,
                    favoriteBusy: widget.saveBusy,
                    onUpTap: sourcePost == null
                        ? null
                        : guardedActionTap(widget.onLike),
                    onFavoriteTap: sourcePost == null
                        ? null
                        : guardedActionTap(widget.onSave),
                    onCommentTap: guardedActionTap(widget.onTap),
                    onBackgroundTap: guardedActionTap(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: _PlazaRatingThumb(item: item, size: 72),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlazaRatingTitle extends StatelessWidget {
  final _PlazaRatingItem item;

  const _PlazaRatingTitle({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _homeFeedTitleStyle(
              color: kGlassInk,
              fontSize: 15.6,
              height: 1.24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Text(
            '评分 ${item.score}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: kGlassAccent.withValues(alpha: 0.68),
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              fontFamily: kAppFontFamily,
              fontFamilyFallback: kAppFontFallback,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlazaRatingThumb extends StatelessWidget {
  final _PlazaRatingItem item;
  final double size;

  const _PlazaRatingThumb({
    required this.item,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        _plazaRatingImageUrl(item),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Icon(
            Icons.star_rate_rounded,
            color: kGlassAccent.withValues(alpha: 0.78),
            size: size * 0.4,
          ),
        ),
      ),
    );
  }
}

String _plazaRatingImageUrl(_PlazaRatingItem item) {
  return 'https://picsum.photos/seed/artsee_rating_${Uri.encodeComponent(item.coverSeed)}/240/240';
}

const _ratingDetailAccent = kGlassAccent;
const _ratingDetailFontFamily = '方正刻本仿宋简体';
const _ratingDetailFontFallback = <String>[
  'FZKeBenFangSongS-R-GB',
  'STFangsong',
  'Songti SC',
  'STSong',
  'SimSong',
];

TextStyle _ratingDetailTextStyle({
  required Color color,
  double fontSize = 14,
  double height = 1.32,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    height: height,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFamily: _ratingDetailFontFamily,
    fontFamilyFallback: _ratingDetailFontFallback,
  );
}

class _PlazaRatingDetailScreen extends StatefulWidget {
  final _PlazaRatingItem item;
  final AppCommunityPost? leadPost;
  final _LeadPostAction? onToggleLeadSave;
  final _LeadPostAction? onConvertLead;

  const _PlazaRatingDetailScreen({
    required this.item,
    this.leadPost,
    this.onToggleLeadSave,
    this.onConvertLead,
  });

  @override
  State<_PlazaRatingDetailScreen> createState() =>
      _PlazaRatingDetailScreenState();
}

class _PlazaRatingDetailScreenState extends State<_PlazaRatingDetailScreen> {
  int _myRating = 0;
  bool _leadSaved = false;
  bool _leadBusy = false;
  final Set<int> _litReplyIndexes = {};
  late final List<_PlazaRatingReply> _replies;

  @override
  void initState() {
    super.initState();
    _leadSaved = widget.leadPost?.savedByMe ?? false;
    _replies = List<_PlazaRatingReply>.of(widget.item.replies);
  }

  bool get _hasLeadActions {
    return widget.leadPost != null &&
        widget.onToggleLeadSave != null &&
        widget.onConvertLead != null;
  }

  Future<void> _toggleLeadSave() async {
    final post = widget.leadPost;
    final action = widget.onToggleLeadSave;
    if (post == null || action == null || _leadBusy) return;
    setState(() => _leadBusy = true);
    final success = await action(post);
    if (!mounted) return;
    setState(() {
      if (success) _leadSaved = !_leadSaved;
      _leadBusy = false;
    });
  }

  Future<void> _convertLead() async {
    final post = widget.leadPost;
    final action = widget.onConvertLead;
    if (post == null || action == null || _leadBusy) return;
    setState(() => _leadBusy = true);
    final success = await action(post);
    if (!mounted) return;
    setState(() {
      if (success) _leadSaved = true;
      _leadBusy = false;
    });
  }

  void _shareRating() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享卡片已准备好')),
    );
  }

  void _setRating(int rating) {
    setState(() => _myRating = rating);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录 $rating 星评分')),
    );
  }

  void _toggleReplyLight(int index) {
    setState(() {
      if (!_litReplyIndexes.add(index)) {
        _litReplyIndexes.remove(index);
      }
    });
  }

  Future<void> _replyTo(_PlazaRatingReply reply) async {
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingReplyComposerSheet(
        reply: reply,
        accent: _ratingDetailAccent,
      ),
    );
    if (body == null || body.trim().isEmpty || !mounted) return;
    setState(() {
      _replies.add(
        _PlazaRatingReply(
          author: '我',
          date: '刚刚',
          body: body.trim(),
          likes: 0,
          avatarColor: _ratingDetailAccent,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回复已发布')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return HomeArtworkBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: _ratingDetailFontFamily,
            fontFamilyFallback: _ratingDetailFontFallback,
            letterSpacing: 0,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _PlazaRatingDetailHeader(
                  item: item,
                  onShare: _shareRating,
                  leadSaved: _leadSaved,
                  leadBusy: _leadBusy,
                  onSaveLead: _hasLeadActions ? _toggleLeadSave : null,
                  onConvertLead: _hasLeadActions ? _convertLead : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 24 + bottomInset),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PlazaRatingHero(item: item),
                            const SizedBox(height: 10),
                            _PlazaRatingScorePanel(
                              item: item,
                              selectedRating: _myRating,
                              onRatingSelected: _setRating,
                            ),
                            const SizedBox(height: 22),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '亮回复 ${_replies.length}',
                                style: _ratingDetailTextStyle(
                                  color: kGlassInk,
                                  fontSize: 20,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._replies.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _PlazaRatingReplyTile(
                                      reply: entry.value,
                                      accent: _ratingDetailAccent,
                                      liked:
                                          _litReplyIndexes.contains(entry.key),
                                      onLike: () =>
                                          _toggleReplyLight(entry.key),
                                      onReply: () => _replyTo(entry.value),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
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

class _PlazaRatingDetailHeader extends StatelessWidget {
  final _PlazaRatingItem item;
  final VoidCallback onShare;
  final bool leadSaved;
  final bool leadBusy;
  final VoidCallback? onSaveLead;
  final VoidCallback? onConvertLead;

  const _PlazaRatingDetailHeader({
    required this.item,
    required this.onShare,
    this.leadSaved = false,
    this.leadBusy = false,
    this.onSaveLead,
    this.onConvertLead,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 112),
              child: Text(
                item.collection,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _ratingDetailTextStyle(
                  color: kGlassInk,
                  fontSize: 16.5,
                  height: 1.1,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OpticalGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: '返回',
                size: 40,
                iconSize: 18,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onSaveLead != null)
                    _PlazaLeadHeaderIcon(
                      icon: leadSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      tooltip: leadSaved ? '取消收藏线索' : '收藏线索',
                      active: leadSaved,
                      busy: leadBusy,
                      onTap: onSaveLead,
                    ),
                  OpticalGlassIconButton(
                    icon: Icons.ios_share_rounded,
                    onTap: onShare,
                    tooltip: '分享',
                    size: 40,
                    iconSize: 20,
                  ),
                  if (onConvertLead != null)
                    _PlazaLeadMoreButton(
                      busy: leadBusy,
                      onConvertLead: onConvertLead!,
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

class _PlazaRatingHero extends StatelessWidget {
  final _PlazaRatingItem item;

  const _PlazaRatingHero({required this.item});

  @override
  Widget build(BuildContext context) {
    return OpticalGlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 26,
      surfaceOpacity: 0.1,
      blurSigma: 28,
      borderOpacity: 0.58,
      innerBorderOpacity: 0.14,
      highlightOpacity: 0.36,
      bottomShadeOpacity: 0.025,
      shadowOpacity: 0.045,
      glowOpacity: 0.06,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlazaRatingThumb(item: item, size: 92),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: _ratingDetailTextStyle(
                    color: kGlassInk,
                    fontSize: 21.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  item.subtitle,
                  style: _ratingDetailTextStyle(
                    color: kGlassMuted.withValues(alpha: 0.88),
                    fontSize: 13.2,
                    height: 1.46,
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

class _PlazaRatingScorePanel extends StatelessWidget {
  final _PlazaRatingItem item;
  final int selectedRating;
  final ValueChanged<int> onRatingSelected;

  const _PlazaRatingScorePanel({
    required this.item,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    const accent = _ratingDetailAccent;
    return OpticalGlassSurface(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      radius: 26,
      surfaceOpacity: 0.11,
      blurSigma: 30,
      borderOpacity: 0.58,
      innerBorderOpacity: 0.14,
      highlightOpacity: 0.38,
      bottomShadeOpacity: 0.025,
      shadowOpacity: 0.045,
      glowOpacity: 0.06,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '大家评分',
                      style: _ratingDetailTextStyle(
                        color: accent,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.score,
                      style: _ratingDetailTextStyle(
                        color: accent,
                        fontSize: 34,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.ratingCount} 人评分',
                      style: _ratingDetailTextStyle(
                        color: kGlassMuted.withValues(alpha: 0.86),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: _RatingDistribution(accent: accent),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                selectedRating == 0 ? '立即评分' : '已评分 $selectedRating 星',
                style: _ratingDetailTextStyle(
                  color: kGlassInk.withValues(alpha: 0.72),
                  fontSize: 14.5,
                ),
              ),
              const Spacer(),
              _RatingStars(
                accent: accent,
                size: 27,
                activeCount: selectedRating,
                outlined: selectedRating == 0,
                onSelected: onRatingSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingDistribution extends StatelessWidget {
  final Color accent;

  const _RatingDistribution({required this.accent});

  @override
  Widget build(BuildContext context) {
    const rows = [
      (stars: 5, value: 0.9897, label: '98.97%'),
      (stars: 4, value: 0.0009, label: '0.09%'),
      (stars: 3, value: 0.0, label: '0%'),
      (stars: 2, value: 0.0, label: '0%'),
      (stars: 1, value: 0.0095, label: '0.95%'),
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: _RatingStars(
                      accent: accent.withValues(alpha: 0.34),
                      size: 10,
                      activeCount: row.stars,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: accent.withValues(alpha: 0.12),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: row.value,
                              child: ColoredBox(color: accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      row.label,
                      textAlign: TextAlign.right,
                      style: _ratingDetailTextStyle(
                        color: context.artC.ink.withValues(alpha: 0.52),
                        fontSize: 11,
                      ),
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

class _RatingStars extends StatelessWidget {
  final Color accent;
  final double size;
  final int activeCount;
  final bool outlined;
  final ValueChanged<int>? onSelected;

  const _RatingStars({
    required this.accent,
    this.size = 14,
    this.activeCount = 5,
    this.outlined = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          if (onSelected == null)
            Icon(
              outlined || index >= activeCount
                  ? Icons.star_border_rounded
                  : Icons.star_rounded,
              color: accent,
              size: size,
            )
          else
            _RatingStarButton(
              value: index + 1,
              icon: outlined || index >= activeCount
                  ? Icons.star_border_rounded
                  : Icons.star_rounded,
              color: accent,
              size: size,
              onSelected: onSelected!,
            ),
      ],
    );
  }
}

class _RatingStarButton extends StatefulWidget {
  final int value;
  final IconData icon;
  final Color color;
  final double size;
  final ValueChanged<int> onSelected;

  const _RatingStarButton({
    required this.value,
    required this.icon,
    required this.color,
    required this.size,
    required this.onSelected,
  });

  @override
  State<_RatingStarButton> createState() => _RatingStarButtonState();
}

class _RatingStarButtonState extends State<_RatingStarButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  void _handleTap() {
    Feedback.forTap(context);
    widget.onSelected(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.value} 星',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Icon(
              widget.icon,
              color: widget.color,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlazaRatingReplyTile extends StatelessWidget {
  final _PlazaRatingReply reply;
  final Color accent;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _PlazaRatingReplyTile({
    required this.reply,
    required this.accent,
    required this.liked,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final displayedLikes = reply.likes + (liked ? 1 : 0);
    return OpticalGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 22,
      surfaceOpacity: 0.1,
      blurSigma: 24,
      borderOpacity: 0.54,
      innerBorderOpacity: 0.12,
      highlightOpacity: 0.32,
      bottomShadeOpacity: 0.02,
      shadowOpacity: 0.035,
      glowOpacity: 0.05,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              reply.author.characters.first,
              style: _ratingDetailTextStyle(
                color: accent,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      reply.author,
                      style: _ratingDetailTextStyle(
                        color: kGlassInk,
                        fontSize: 15,
                      ),
                    ),
                    _RatingStars(accent: accent, size: 15),
                    Text(
                      reply.date,
                      style: _ratingDetailTextStyle(
                        color: kGlassMuted.withValues(alpha: 0.76),
                        fontSize: 11.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  reply.body,
                  style: _ratingDetailTextStyle(
                    color: kGlassInk.withValues(alpha: 0.92),
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  children: [
                    _RatingReplyAction(
                      icon: Icons.offline_bolt_outlined,
                      label: '点亮($displayedLikes)',
                      active: liked,
                      color: accent,
                      onTap: onLike,
                    ),
                    _RatingReplyAction(
                      icon: Icons.edit_note_rounded,
                      label: '回复',
                      onTap: onReply,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingReplyComposerSheet extends StatefulWidget {
  final _PlazaRatingReply reply;
  final Color accent;

  const _RatingReplyComposerSheet({
    required this.reply,
    required this.accent,
  });

  @override
  State<_RatingReplyComposerSheet> createState() =>
      _RatingReplyComposerSheetState();
}

class _RatingReplyComposerSheetState extends State<_RatingReplyComposerSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '回复 ${widget.reply.author}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ratingDetailTextStyle(
                color: kGlassInk,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                style: _ratingDetailTextStyle(
                  color: kGlassInk,
                  fontSize: 15,
                  height: 1.42,
                ),
                decoration: InputDecoration(
                  hintText: '写下你的回应',
                  hintStyle: _ratingDetailTextStyle(
                    color: kGlassMuted.withValues(alpha: 0.62),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: _ratingDetailTextStyle(
                      color: kGlassMuted,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: canSubmit
                      ? () => Navigator.of(context).pop(_controller.text)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canSubmit
                          ? widget.accent
                          : widget.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '发布',
                      style: _ratingDetailTextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingReplyAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  const _RatingReplyAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor =
        active ? (color ?? kGlassInk) : kGlassMuted.withValues(alpha: 0.82);
    return _PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: actionColor,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: _ratingDetailTextStyle(
                color: actionColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebateProgressBar extends StatelessWidget {
  final int proPercent;

  const _DebateProgressBar({
    required this.proPercent,
  });

  @override
  Widget build(BuildContext context) {
    final conPercent = 100 - proPercent;
    return Column(
      children: [
        Row(
          children: [
            Text(
              '正方 $proPercent%',
              style: const TextStyle(
                color: _debateJade,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              '反方 $conPercent%',
              style: const TextStyle(
                color: _debateCoral,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Container(
              color: _instaBorder,
              child: Row(
                children: [
                  Expanded(
                    flex: proPercent,
                    child: Container(color: _debateJade),
                  ),
                  Expanded(
                    flex: conPercent,
                    child: Container(color: _debateCoral),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArgumentDuelPanel extends StatelessWidget {
  final _DebateTopic topic;

  const _ArgumentDuelPanel({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ArgumentColumn(
            side: '正方',
            thesis: topic.pro,
            comment: topic.proComment,
            color: _debateJade,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ArgumentColumn(
            side: '反方',
            thesis: topic.con,
            comment: topic.conComment,
            color: _debateCoral,
          ),
        ),
      ],
    );
  }
}

class _ArgumentColumn extends StatelessWidget {
  final String side;
  final String thesis;
  final String comment;
  final Color color;

  const _ArgumentColumn({
    required this.side,
    required this.thesis,
    required this.comment,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _instaCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _instaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _instaBorder),
            ),
            child: Text(
              side,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            thesis,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _instaInk.withValues(alpha: 0.88),
              fontSize: 12,
              height: 1.32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _instaMuted,
              fontSize: 11,
              height: 1.32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentReplyBlock extends StatelessWidget {
  final _DebateTopic topic;

  const _AgentReplyBlock({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _instaCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _instaBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InstaAvatar(
            icon: Icons.auto_awesome_outlined,
            size: 30,
            iconColor: topic.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.agentPersona,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _instaInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  topic.agentReply,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _instaMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
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

class _DebateTopicDetailScreen extends StatefulWidget {
  final _DebateTopic topic;
  final _AskQuestionLauncher onAskQuestion;
  final _StanceSubmission? initialSubmission;
  final AppCommunityPost? post;
  final _CommunityPostChanged? onPostChanged;
  final AppCommunityPost? leadPost;
  final _LeadPostAction? onToggleLeadSave;
  final _LeadPostAction? onConvertLead;

  const _DebateTopicDetailScreen({
    required this.topic,
    required this.onAskQuestion,
    this.initialSubmission,
    this.post,
    this.onPostChanged,
    this.leadPost,
    this.onToggleLeadSave,
    this.onConvertLead,
  });

  @override
  State<_DebateTopicDetailScreen> createState() =>
      _DebateTopicDetailScreenState();
}

class _DebateTopicDetailScreenState extends State<_DebateTopicDetailScreen> {
  late final List<_DebateThreadComment> _comments;
  final Set<String> _likedCommentIds = {};
  _DebateCommentFilter _filter = _DebateCommentFilter.all;
  AppCommunityPost? _post;
  bool _postLiked = false;
  bool _postSaved = false;
  bool _postLikeBusy = false;
  bool _postSaveBusy = false;
  bool _leadSaved = false;
  bool _leadBusy = false;
  int _postLikeCount = 0;
  int _postSaveCount = 0;
  int _commentSeed = 0;

  _DebateTopic get topic => widget.topic;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _postLiked = _post?.likedByMe ?? false;
    _postSaved = _post?.savedByMe ?? false;
    _postLikeCount = _post?.likeCount ?? 0;
    _postSaveCount = _post?.saveCount ?? 0;
    _leadSaved = widget.leadPost?.savedByMe ?? _postSaved;
    final comments = [
      _DebateThreadComment(
        id: 'seed-pro',
        side: _DebateSide.pro,
        author: '北美作品集第 4 版',
        body: topic.proComment,
        likes: 34,
        replies: 8,
      ),
      _DebateThreadComment(
        id: 'seed-con',
        side: _DebateSide.con,
        author: '不想被小作文绑架',
        body: topic.conComment,
        likes: 28,
        replies: 12,
      ),
      _DebateThreadComment(
        id: 'seed-agent',
        side: _DebateSide.watch,
        author: topic.agentPersona,
        body: topic.agentReply,
        likes: 41,
        replies: 15,
        isAgent: true,
      ),
      _DebateThreadComment(
        id: 'seed-hot',
        side: _DebateSide.watch,
        author: '高赞补刀',
        body: topic.hotComment,
        likes: 66,
        replies: 9,
      ),
    ];
    final initialSubmission = widget.initialSubmission;
    if (initialSubmission != null) {
      comments.insert(
        0,
        _DebateThreadComment(
          id: 'mine-${_commentSeed++}',
          side: initialSubmission.side,
          author: '我',
          body: initialSubmission.body,
          likes: 0,
          replies: 0,
          isMine: true,
        ),
      );
      final followUp = _agentFollowUpFor(initialSubmission.side);
      if (followUp != null) {
        comments.insert(
          1,
          _DebateThreadComment(
            id: 'agent-${_commentSeed++}',
            side: _DebateSide.watch,
            author: topic.agentPersona,
            body: followUp,
            likes: 0,
            replies: 0,
            isAgent: true,
          ),
        );
      }
    }
    _comments = comments;
  }

  bool get _hasLeadActions {
    return widget.leadPost != null &&
        widget.onToggleLeadSave != null &&
        widget.onConvertLead != null;
  }

  Future<void> _toggleLeadSave() async {
    final post = widget.leadPost;
    final action = widget.onToggleLeadSave;
    if (post == null || action == null || _leadBusy) return;
    setState(() => _leadBusy = true);
    final success = await action(post);
    if (!mounted) return;
    setState(() {
      if (success) {
        _leadSaved = !_leadSaved;
        if (_post?.id == post.id) {
          _postSaved = _leadSaved;
          _post = _post?.copyWith(savedByMe: _leadSaved);
        }
      }
      _leadBusy = false;
    });
  }

  Future<void> _convertLead() async {
    final post = widget.leadPost;
    final action = widget.onConvertLead;
    if (post == null || action == null || _leadBusy) return;
    setState(() => _leadBusy = true);
    final success = await action(post);
    if (!mounted) return;
    setState(() {
      if (success) _leadSaved = true;
      _leadBusy = false;
    });
  }

  List<_DebateThreadComment> get _visibleComments {
    return switch (_filter) {
      _DebateCommentFilter.pro =>
        _comments.where((comment) => comment.side == _DebateSide.pro).toList(),
      _DebateCommentFilter.con =>
        _comments.where((comment) => comment.side == _DebateSide.con).toList(),
      _DebateCommentFilter.agent =>
        _comments.where((comment) => comment.isAgent).toList(),
      _DebateCommentFilter.mine =>
        _comments.where((comment) => comment.isMine).toList(),
      _ => _comments,
    };
  }

  int get _currentCommentCount {
    final numeric = topic.comments.replaceAll(RegExp(r'[^0-9]'), '');
    final base = int.tryParse(numeric) ?? _comments.length;
    final local = _comments.where((comment) => comment.isMine).length;
    return base + local;
  }

  Future<void> _openStanceSheet({
    _DebateSide initialSide = _DebateSide.pro,
    String? initialDraft,
  }) async {
    final submission = await _showStanceCommentSheet(
      context,
      topic,
      initialSide: initialSide,
      initialDraft: initialDraft,
    );
    if (submission == null || !mounted) return;
    _addSubmission(submission);
  }

  void _addSubmission(_StanceSubmission submission) {
    setState(() {
      _comments.insert(
        0,
        _DebateThreadComment(
          id: 'mine-${_commentSeed++}',
          side: submission.side,
          author: '我',
          body: submission.body,
          likes: 0,
          replies: 0,
          isMine: true,
        ),
      );
      final followUp = _agentFollowUpFor(submission.side);
      if (followUp != null) {
        _comments.insert(
          1,
          _DebateThreadComment(
            id: 'agent-${_commentSeed++}',
            side: _DebateSide.watch,
            author: topic.agentPersona,
            body: followUp,
            likes: 0,
            replies: 0,
            isAgent: true,
          ),
        );
      }
      if (_filter != _DebateCommentFilter.all &&
          _filter != _DebateCommentFilter.mine &&
          submission.side == _DebateSide.watch) {
        _filter = _DebateCommentFilter.all;
      }
    });
  }

  void _toggleLike(_DebateThreadComment comment) {
    setState(() {
      if (!_likedCommentIds.add(comment.id)) {
        _likedCommentIds.remove(comment.id);
      }
    });
  }

  Future<void> _togglePostLike() async {
    if (_postLikeBusy) return;
    final post = _post;
    if (post == null) {
      setState(() {
        _postLiked = !_postLiked;
        _postLikeCount = math.max(0, _postLikeCount + (_postLiked ? 1 : -1));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_postLiked ? '已赞这篇帖子' : '已取消赞')),
      );
      return;
    }
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后点赞');
    if (!mounted || !loggedIn) return;
    setState(() => _postLikeBusy = true);
    try {
      final result = _postLiked
          ? await BackendApiService.unlikeCommunityPost(post.id)
          : await BackendApiService.likeCommunityPost(post.id);
      if (!mounted) return;
      final updated = post.copyWith(
        likedByMe: result.liked,
        likeCount: result.likeCount,
        savedByMe: _postSaved,
        saveCount: _postSaveCount,
      );
      setState(() {
        _post = updated;
        _postLiked = result.liked;
        _postLikeCount = result.likeCount;
        _postLikeBusy = false;
      });
      widget.onPostChanged?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.liked ? '已点赞' : '已取消点赞')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _postLikeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('点赞失败：$e')),
      );
    }
  }

  Future<void> _togglePostSave() async {
    if (_postSaveBusy) return;
    final post = _post;
    if (post == null) {
      setState(() {
        _postSaved = !_postSaved;
        _postSaveCount = math.max(0, _postSaveCount + (_postSaved ? 1 : -1));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_postSaved ? '已收藏到我的广场' : '已取消收藏')),
      );
      return;
    }
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后收藏');
    if (!mounted || !loggedIn) return;
    setState(() => _postSaveBusy = true);
    try {
      final result = _postSaved
          ? await BackendApiService.unsaveCommunityPost(post.id)
          : await BackendApiService.saveCommunityPost(post.id);
      if (!mounted) return;
      final updated = post.copyWith(
        savedByMe: result.saved,
        saveCount: result.saveCount,
        likedByMe: _postLiked,
        likeCount: _postLikeCount,
      );
      setState(() {
        _post = updated;
        _postSaved = result.saved;
        _postSaveCount = result.saveCount;
        _leadSaved = result.saved;
        _postSaveBusy = false;
      });
      widget.onPostChanged?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.saved ? '已收藏' : '已取消收藏')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _postSaveBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败：$e')),
      );
    }
  }

  Future<void> _openShareSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlazaShareSheet(topic: topic),
    );
    if (!mounted || action == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action 已准备好')),
    );
  }

  Future<void> _openAssociatedRating(_PlazaRatingItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PlazaRatingDetailScreen(item: item),
      ),
    );
  }

  String? _agentFollowUpFor(_DebateSide side) {
    return switch (side) {
      _DebateSide.pro => '我先接住你站正方的理由，但反方会追问：${topic.con}。你怎么堵住这个漏洞？',
      _DebateSide.con => '你这个反方角度成立一半，但正方会说：${topic.pro}。你愿意承认哪一部分？',
      _DebateSide.watch => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final associatedRating = _associatedRatingForTopic(topic);
    return HomeArtworkBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _DebateDetailHeader(
                onShare: _openShareSheet,
                leadSaved: _leadSaved,
                leadBusy: _leadBusy,
                onSaveLead: _hasLeadActions ? _toggleLeadSave : null,
                onConvertLead: _hasLeadActions ? _convertLead : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 18 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DebateDetailHero(topic: topic),
                      if (associatedRating != null) ...[
                        const SizedBox(height: 14),
                        _LinkedRatingOverviewCard(
                          item: associatedRating,
                          onTap: () => _openAssociatedRating(associatedRating),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PlazaTopicReplyActions(
                        onlyMine: _filter == _DebateCommentFilter.mine,
                        liked: _postLiked,
                        saved: _postSaved,
                        likeBusy: _postLikeBusy,
                        saveBusy: _postSaveBusy,
                        onReply: () => _openStanceSheet(
                          initialSide: _DebateSide.watch,
                          initialDraft: '我想接着这个话题说：',
                        ),
                        onShare: _openShareSheet,
                        onLike: _togglePostLike,
                        onSave: _togglePostSave,
                        onOnlyHost: () => setState(
                          () => _filter = _filter == _DebateCommentFilter.mine
                              ? _DebateCommentFilter.all
                              : _DebateCommentFilter.mine,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _DebateDetailSectionTitle(
                        title: _filter == _DebateCommentFilter.mine
                            ? '楼主回复 / ${_visibleComments.length}'
                            : '全部回复 / ${_comments.length}',
                        body: '$_currentCommentCount 条评论 · ${topic.heat} 喜欢',
                      ),
                      const SizedBox(height: 10),
                      if (_visibleComments.isEmpty)
                        _EmptyDebateFilterHint(filter: _filter)
                      else
                        ..._visibleComments.map(
                          (comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _DebateCommentTile(
                              side: comment.side,
                              author: comment.author,
                              body: comment.body,
                              likes: comment.likes.toString(),
                              replies: comment.replies.toString(),
                              isAgent: comment.isAgent,
                              isMine: comment.isMine,
                              liked: _likedCommentIds.contains(comment.id),
                              onLike: () => _toggleLike(comment),
                              onReply: () {
                                if (comment.isAgent) {
                                  _openStanceSheet(
                                    initialSide: _DebateSide.con,
                                    initialDraft:
                                        '我想反驳${comment.author}刚才这句，因为：',
                                  );
                                  return;
                                }
                                _openStanceSheet(
                                  initialSide: comment.side == _DebateSide.pro
                                      ? _DebateSide.con
                                      : _DebateSide.pro,
                                );
                              },
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
      ),
    );
  }
}

class _LinkedRatingOverviewCard extends StatelessWidget {
  final _PlazaRatingItem item;
  final VoidCallback onTap;

  const _LinkedRatingOverviewCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.36),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '关联评分',
                    style: TextStyle(
                      color: item.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '大家正在评分',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.artC.ink.withValues(alpha: 0.28),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 18,
                height: 1.24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${item.score} 分',
                  style: TextStyle(
                    color: item.accent,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 8),
                _RatingStars(accent: item.accent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.ratingCount} 人评分 · ${item.comments} 条亮回复',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.46),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.42,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LinkedRatingActionButton(
                  label: '我也评分',
                  color: item.accent,
                  filled: true,
                  onTap: onTap,
                ),
                const SizedBox(width: 8),
                _LinkedRatingActionButton(
                  label: '看大家怎么评',
                  color: item.accent,
                  onTap: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedRatingActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _LinkedRatingActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.28)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _DebateDetailHeader extends StatelessWidget {
  final VoidCallback onShare;
  final bool leadSaved;
  final bool leadBusy;
  final VoidCallback? onSaveLead;
  final VoidCallback? onConvertLead;

  const _DebateDetailHeader({
    required this.onShare,
    this.leadSaved = false,
    this.leadBusy = false,
    this.onSaveLead,
    this.onConvertLead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.18),
            width: 0.7,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 116),
            child: Text(
              '帖子详情',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _DetailHeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
              tooltip: '返回',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSaveLead != null)
                  _PlazaLeadHeaderIcon(
                    icon: leadSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    tooltip: leadSaved ? '取消收藏线索' : '收藏线索',
                    active: leadSaved,
                    busy: leadBusy,
                    onTap: onSaveLead,
                  ),
                _DetailHeaderIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                  tooltip: '分享',
                ),
                if (onConvertLead != null)
                  _PlazaLeadMoreButton(
                    busy: leadBusy,
                    onConvertLead: onConvertLead!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _DetailHeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: icon == Icons.ios_share_rounded ? 20 : 18,
            color: context.artC.ink.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _DebateDetailHero extends StatelessWidget {
  final _DebateTopic topic;

  const _DebateDetailHero({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.34)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 25.5,
              height: 1.22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _DebateDetailAuthorBlock(topic: topic),
          const SizedBox(height: 18),
          _PlazaDetailImage(topic: topic),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 19),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlazaArticleBody(topic: topic),
                const SizedBox(height: 18),
                _DebateTagWrap(tags: topic.tags, accent: topic.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebateDetailAuthorBlock extends StatelessWidget {
  final _DebateTopic topic;

  const _DebateDetailAuthorBlock({required this.topic});

  @override
  Widget build(BuildContext context) {
    final source = _plazaSourceText('${topic.channel}圈子');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: topic.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(topic.icon, color: topic.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: topic.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: topic.accent,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${_plazaTopicTime(topic)} · ${topic.heat} 喜欢 · ${topic.comments} 评论',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.42),
                  fontSize: 11.8,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebateTagWrap extends StatelessWidget {
  final List<String> tags;
  final Color accent;

  const _DebateTagWrap({
    required this.tags,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.1)),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: accent.withValues(alpha: 0.86),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlazaDetailImage extends StatelessWidget {
  final _DebateTopic topic;

  const _PlazaDetailImage({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            _plazaTopicImageUrl(topic),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: topic.accent.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(topic.icon, color: topic.accent, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlazaArticleBody extends StatelessWidget {
  final _DebateTopic topic;

  const _PlazaArticleBody({required this.topic});

  @override
  Widget build(BuildContext context) {
    final paragraphs = [
      topic.lead,
      '我想把这个问题拆开看：一边是“${topic.pro}”，另一边是“${topic.con}”。这两个判断都不算轻飘，所以才值得放到广场里讨论。',
      '如果你也在做类似选择，或者刚好经历过这个阶段，可以说说你会怎么判断。真正想问的是：${topic.askSeed}',
    ].where((text) => text.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          Text(
            paragraphs[index],
            style: TextStyle(
              color: index == 0
                  ? context.artC.ink.withValues(alpha: 0.82)
                  : context.artC.ink.withValues(alpha: 0.64),
              fontSize: index == 0 ? 15.8 : 15.4,
              height: index == 0 ? 1.58 : 1.68,
              fontWeight: index == 0 ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (index != paragraphs.length - 1)
            SizedBox(height: index == 0 ? 20 : 17),
        ],
      ],
    );
  }
}

class _PlazaTopicReplyActions extends StatelessWidget {
  final bool onlyMine;
  final bool liked;
  final bool saved;
  final bool likeBusy;
  final bool saveBusy;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onOnlyHost;

  const _PlazaTopicReplyActions({
    required this.onlyMine,
    required this.liked,
    required this.saved,
    this.likeBusy = false,
    this.saveBusy = false,
    required this.onReply,
    required this.onShare,
    required this.onLike,
    required this.onSave,
    required this.onOnlyHost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PlazaDetailAction(
                label: '回复',
                icon: Icons.mode_comment_outlined,
                color: const Color(0xFF73B764),
                filled: true,
                onTap: onReply,
              ),
              _PlazaDetailAction(
                label: '转发',
                icon: Icons.ios_share_rounded,
                onTap: onShare,
              ),
              _PlazaDetailAction(
                label: liked ? '已赞' : '赞',
                icon: liked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                active: liked,
                busy: likeBusy,
                color:
                    liked ? const Color(0xFFD95D3E) : const Color(0xFF2478B8),
                onTap: onLike,
              ),
              _PlazaDetailAction(
                label: saved ? '已收藏' : '收藏',
                icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border,
                active: saved,
                busy: saveBusy,
                onTap: onSave,
              ),
              _PlazaDetailAction(
                label: onlyMine ? '看全部' : '只看楼主',
                color: const Color(0xFF2478B8),
                onTap: onOnlyHost,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlazaDetailAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  const _PlazaDetailAction({
    required this.label,
    this.icon,
    this.color = const Color(0xFF2478B8),
    this.filled = false,
    this.active = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    final child = Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: EdgeInsets.symmetric(
        horizontal: filled ? 12 : 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: filled
            ? color
            : active
                ? color.withValues(alpha: 0.1)
                : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: filled || active
            ? null
            : Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, color: foreground, size: 15),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: child,
        ),
      ),
    );
  }
}

class _PlazaShareSheet extends StatelessWidget {
  final _DebateTopic topic;

  const _PlazaShareSheet({required this.topic});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              height: 1.28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ShareSheetAction(
                icon: Icons.forum_outlined,
                label: '转到热议',
                onTap: () => Navigator.of(context).pop('转发到热议'),
              ),
              const SizedBox(width: 10),
              _ShareSheetAction(
                icon: Icons.link_rounded,
                label: '复制链接',
                onTap: () => Navigator.of(context).pop('帖子链接'),
              ),
              const SizedBox(width: 10),
              _ShareSheetAction(
                icon: Icons.ios_share_rounded,
                label: '系统分享',
                onTap: () => Navigator.of(context).pop('系统分享'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF2478B8), size: 22),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2478B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebateLifecycleStrip extends StatelessWidget {
  final _DebateTopic topic;
  final int phaseIndex;

  const _DebateLifecycleStrip({
    required this.topic,
    required this.phaseIndex,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['预热', '正在吵', 'Agent 总结', '归档'];
    final phaseNote = topic.status == '已归档'
        ? '已沉淀为复盘'
        : phaseIndex >= 2
            ? 'Agent 正在归纳双方漏洞'
            : '${topic.timeLeft}后生成复盘';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.52)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: _porcelainDeepBlue,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '辩题生命周期',
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                phaseNote,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(
                  child: _LifecycleStep(
                    label: labels[i],
                    active: i == phaseIndex,
                    done: i < phaseIndex,
                  ),
                ),
                if (i != labels.length - 1)
                  Container(
                    width: 16,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: i < phaseIndex
                        ? _porcelainDeepBlue.withValues(alpha: 0.55)
                        : context.artC.silver.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LifecycleStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _LifecycleStep({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? _porcelainDeepBlue
        : done
            ? _debateJade
            : context.artC.ink.withValues(alpha: 0.28);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 24 : 18,
          height: active ? 24 : 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle,
            size: done ? 12 : 6,
            color: active ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active || done
                ? context.artC.ink
                : context.artC.ink.withValues(alpha: 0.42),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AgentModeratorPanel extends StatelessWidget {
  final _DebateTopic topic;
  final int proPercent;
  final int commentCount;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAskAgent;

  const _AgentModeratorPanel({
    required this.topic,
    required this.proPercent,
    required this.commentCount,
    required this.expanded,
    required this.onToggle,
    required this.onAskAgent,
  });

  @override
  Widget build(BuildContext context) {
    final conPercent = 100 - proPercent;
    final leadingSide = proPercent == conPercent
        ? '双方拉平'
        : proPercent > conPercent
            ? '正方暂时领先'
            : '反方暂时领先';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _porcelainDeepBlue.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: _porcelainNightBlue.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _porcelainDeepBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_outlined,
                    color: _porcelainDeepBlue,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agent 辩手',
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${topic.agentPersona} · $commentCount 条观点',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.46),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: context.artC.ink.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeratorStat(
                    label: '正方',
                    value: '$proPercent%',
                    color: _debateJade,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeratorStat(
                    label: '反方',
                    value: '$conPercent%',
                    color: _debateCoral,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeratorStat(
                    label: '局势',
                    value: leadingSide,
                    color: _porcelainDeepBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            _ModeratorLine(
              icon: Icons.compare_arrows_rounded,
              title: '主争点',
              body: '${topic.pro} vs ${topic.con}',
              color: _porcelainDeepBlue,
            ),
            const SizedBox(height: 8),
            _ModeratorLine(
              icon: Icons.bolt_outlined,
              title: '下一问',
              body: topic.agentReply,
              color: _debateGold,
            ),
            const SizedBox(height: 11),
            GestureDetector(
              onTap: onAskAgent,
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _porcelainDeepBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '让 Agent 回一楼',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeratorStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ModeratorStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.46),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeratorLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _ModeratorLine({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.48)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title：',
                    style: TextStyle(
                      color: context.artC.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1.36,
                    ),
                  ),
                  TextSpan(
                    text: body,
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebateDetailSectionTitle extends StatelessWidget {
  final String title;
  final String body;

  const _DebateDetailSectionTitle({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          body,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _EmptyDebateFilterHint extends StatelessWidget {
  final _DebateCommentFilter filter;

  const _EmptyDebateFilterHint({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mode_comment_outlined,
            color: _debateCommentFilterColor(filter),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '这里还没有${_debateCommentFilterLabel(filter)}观点，先抢一个楼层。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _debateCommentFilterLabel(_DebateCommentFilter filter) {
  return switch (filter) {
    _DebateCommentFilter.all => '全部',
    _DebateCommentFilter.pro => '正方',
    _DebateCommentFilter.con => '反方',
    _DebateCommentFilter.agent => 'Agent',
    _DebateCommentFilter.mine => '我的',
  };
}

Color _debateCommentFilterColor(_DebateCommentFilter filter) {
  return switch (filter) {
    _DebateCommentFilter.pro => _debateJade,
    _DebateCommentFilter.con => _debateCoral,
    _DebateCommentFilter.agent => _debateLilac,
    _DebateCommentFilter.mine => _debateGold,
    _ => _porcelainDeepBlue,
  };
}

class _DebateCommentTile extends StatelessWidget {
  final _DebateSide side;
  final String author;
  final String body;
  final String likes;
  final String replies;
  final bool isAgent;
  final bool isMine;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _DebateCommentTile({
    required this.side,
    required this.author,
    required this.body,
    required this.likes,
    required this.replies,
    this.isAgent = false,
    this.isMine = false,
    this.liked = false,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final color = _debateSideColor(side);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.34),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: isAgent
                ? Icon(
                    Icons.auto_awesome_outlined,
                    color: color,
                    size: 22,
                  )
                : Text(
                    (isMine ? '我' : author).characters.first,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: const Color(0xFFF0F6F3),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        isMine ? '我' : author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2478B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      if (isAgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _debateLilac.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _debateLilac.withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Text(
                            'AI 回复',
                            style: TextStyle(
                              color: _debateLilac,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      if (isMine)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _debateGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '楼主',
                            style: TextStyle(
                              color: _debateGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      if (!isAgent && !isMine && side != _DebateSide.watch)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _debateSideLabel(side),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      Text(
                        _plazaReplyTime(author),
                        style: const TextStyle(
                          color: Color(0xFF767676),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _CommentMetric(
                      icon: liked
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      label:
                          liked ? '${(int.tryParse(likes) ?? 0) + 1}' : likes,
                      active: liked,
                      color: color,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mode_comment_outlined,
                            color: Color(0xFF9B9B9B),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '回复 $replies',
                            style: const TextStyle(
                              color: Color(0xFF9B9B9B),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _plazaReplyTime(String seed) {
  final times = [
    '2026-07-06 11:31 湖北',
    '2026-07-06 13:37 浙江',
    '2026-07-06 14:33 北京',
  ];
  return times[seed.hashCode.abs() % times.length];
}

class _CommentMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback? onTap;

  const _CommentMetric({
    required this.icon,
    required this.label,
    this.active = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metricColor = active
        ? (color ?? _porcelainDeepBlue)
        : context.artC.ink.withValues(alpha: 0.42);
    return GestureDetector(
      onTap: onTap,
      behavior:
          onTap == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: metricColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: active
                  ? metricColor
                  : context.artC.ink.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebateArchivePanel extends StatelessWidget {
  final _DebateTopic topic;

  const _DebateArchivePanel({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _debateGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _debateGold.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_edu_outlined,
            color: _debateGold,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              topic.status == '已归档'
                  ? '本场已经进入复盘：保留最佳反驳、Agent 认输点和最终站队结果。'
                  : '辩题结束后会生成复盘：最佳反驳、Agent 被说服瞬间和最终站队结果。',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.68),
                fontSize: 12,
                height: 1.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlazaQuestionSheet extends StatefulWidget {
  final String? initialTitle;
  final String? initialCategory;

  const _PlazaQuestionSheet({
    this.initialTitle,
    this.initialCategory,
  });

  @override
  State<_PlazaQuestionSheet> createState() => _PlazaQuestionSheetState();
}

class _PlazaQuestionSheetState extends State<_PlazaQuestionSheet> {
  static const _categories = ['艺术留学', '作品集', '行业就业', '艺术市场', '版权法律'];

  late final TextEditingController _titleController;
  late String _category;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialTitle?.trim().isNotEmpty == true
          ? widget.initialTitle!.trim()
          : '我想提出一个关于艺术留学或艺术创作的争议问题：',
    );
    _category = _categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : '艺术留学';
    _titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: _titleController.text.length),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!await ensureLoggedIn(context, message: '请先登录后发布问题')) return;
    if (!mounted) return;
    final title = _titleController.text.trim();
    if (title.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问题再具体一点，会更容易获得回答')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await BackendApiService.createPlazaPost(
        title: title,
        body: '',
        kind: 'qa',
        group: _category,
        tags: [_category],
        metadata: {
          'kind': 'qa',
          'category': _category,
          'source': 'plaza_question',
          'promote_to_plaza': true,
          'anonymous': false,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(title);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.76,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _instaBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _instaBorder),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: _instaInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '提出问题',
                        style: TextStyle(
                          color: _instaInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submitting ? null : _submit,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _instaInk,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _submitting ? '发布中' : '发布',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 80,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _instaCanvas,
                    hintText: '把你想吵、想问、想让大家站队的点写出来',
                    hintStyle: TextStyle(
                      color: _instaMuted,
                      fontSize: 15,
                      height: 1.38,
                      fontWeight: FontWeight.w700,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _instaBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _instaBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _instaInk,
                        width: 1.2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: _instaInk,
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = _categories[index];
                      final selected = item == _category;
                      return GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => setState(() => _category = item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? _instaInk : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected ? _instaInk : _instaBorder,
                            ),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              color: selected ? Colors.white : _instaMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _instaInk,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _submitting ? '正在进入广场...' : '发布到广场',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
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

class _StanceCommentSheet extends StatefulWidget {
  final _DebateTopic topic;
  final _DebateSide initialSide;
  final String? initialDraft;

  const _StanceCommentSheet({
    required this.topic,
    required this.initialSide,
    this.initialDraft,
  });

  @override
  State<_StanceCommentSheet> createState() => _StanceCommentSheetState();
}

class _StanceCommentSheetState extends State<_StanceCommentSheet> {
  late _DebateSide _side;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _controller = TextEditingController(
      text: widget.initialDraft ?? _defaultDraft(widget.initialSide),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _defaultDraft(_DebateSide side) {
    return switch (side) {
      _DebateSide.pro => widget.topic.proComment,
      _DebateSide.con => widget.topic.conComment,
      _DebateSide.watch => '我先补充一个观察：',
    };
  }

  void _selectSide(_DebateSide side) {
    setState(() {
      _side = side;
      _controller.text = _defaultDraft(side);
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _instaBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '发表评论',
                  style: TextStyle(
                    color: _instaInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.topic.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _instaMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StanceChoiceButton(
                        label: '同意',
                        side: _DebateSide.pro,
                        selected: _side == _DebateSide.pro,
                        onTap: () => _selectSide(_DebateSide.pro),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StanceChoiceButton(
                        label: '不同意',
                        side: _DebateSide.con,
                        selected: _side == _DebateSide.con,
                        onTap: () => _selectSide(_DebateSide.con),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StanceChoiceButton(
                        label: '补充观察',
                        side: _DebateSide.watch,
                        selected: _side == _DebateSide.watch,
                        onTap: () => _selectSide(_DebateSide.watch),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _instaCanvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _instaBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 6,
                    style: TextStyle(
                      color: _instaInk,
                      fontSize: 14,
                      height: 1.38,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: '写下你的观点，最好留一个能让别人继续接话的点',
                      hintStyle: TextStyle(
                        color: _instaMuted,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _DraftAssistChip(
                      label: '加一句反问',
                      onTap: () => _controller.text =
                          '${_controller.text.trim()} 你怎么回应这个漏洞？',
                    ),
                    _DraftAssistChip(
                      label: '补充案例',
                      onTap: () => _controller.text =
                          '${_controller.text.trim()} 我想到的例子是：',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '发布后会进入这个话题的评论区',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _instaMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final body = _controller.text.trim();
                        if (body.isEmpty) return;
                        Navigator.of(context).pop(
                          _StanceSubmission(side: _side, body: body),
                        );
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _instaInk,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '发布观点',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StanceChoiceButton extends StatelessWidget {
  final String label;
  final _DebateSide side;
  final bool selected;
  final VoidCallback onTap;

  const _StanceChoiceButton({
    required this.label,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _debateSideColor(side);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _instaInk : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _instaInk : _instaBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _DraftAssistChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DraftAssistChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _instaBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _instaInk,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AiDebateBrief extends StatelessWidget {
  final _AiHomeProfileConfig config;
  final VoidCallback onStartAi;
  final ValueChanged<String> onPrompt;

  const _AiDebateBrief({
    required this.config,
    required this.onStartAi,
    required this.onPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = config.promptCloudItems.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: _inkWashGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _porcelainDeepBlue.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: _debateGold,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 观战席',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '把吵点压成问题、立场和下一步',
                      style: TextStyle(
                        color: _inkMistBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _PressableScale(
                onTap: onStartAi,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _debateGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: _porcelainNightBlue,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '开聊',
                        style: TextStyle(
                          color: _porcelainNightBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts
                .map(
                  (item) => _PressableScale(
                    onTap: () => onPrompt(item.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 15, color: _debateGold),
                          const SizedBox(width: 5),
                          Text(
                            item.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HomeActionDock extends StatelessWidget {
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onOpenForum;
  final bool showWorkbench;

  const _HomeActionDock({
    required this.onOpenExplore,
    required this.onOpenWorkbench,
    required this.onOpenForum,
    required this.showWorkbench,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DockAction(
            icon: Icons.explore_outlined,
            label: '发现',
            body: '案例 / 活动',
            color: _debateJade,
            onTap: onOpenExplore,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DockAction(
            icon: Icons.question_answer_outlined,
            label: '问答',
            body: '楼层讨论',
            color: _debateCoral,
            onTap: onOpenForum,
          ),
        ),
        if (showWorkbench) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _DockAction(
              icon: Icons.dashboard_customize_outlined,
              label: '工作台',
              body: '机构专属',
              color: _porcelainDeepBlue,
              onTap: onOpenWorkbench,
            ),
          ),
        ],
      ],
    );
  }
}

class _DockAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String body;
  final Color color;
  final VoidCallback onTap;

  const _DockAction({
    required this.icon,
    required this.label,
    required this.body,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.055),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.44)),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: context.artC.ink),
      ),
    );
  }
}

class _ConversationDrawer extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final _AiHomeProfileConfig config;
  final ValueChanged<Map<String, dynamic>> onConversationTap;
  final ValueChanged<String> onConversationDelete;
  final VoidCallback onNewChat;

  const _ConversationDrawer({
    required this.conversations,
    required this.config,
    required this.onConversationTap,
    required this.onConversationDelete,
    required this.onNewChat,
  });

  @override
  State<_ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<_ConversationDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) {
      return widget.conversations;
    }
    return widget.conversations.where((conversation) {
      final title = conversation['title']?.toString().toLowerCase() ?? '';
      final preview =
          conversation['last_message_preview']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || preview.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredConversations = _filteredConversations;

    return Drawer(
      backgroundColor: context.artC.porcelain,
      child: SafeArea(
        top: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '聊天记录',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '最近 50 条 AI 对话',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.36),
                ),
              ),
              const SizedBox(height: 16),
              _PressableScale(
                onTap: () {
                  widget.onNewChat();
                  Navigator.of(context).maybePop();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_porcelainNightBlue, _porcelainDeepBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _porcelainDeepBlue.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '新聊天',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.artC.cardIconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.artC.ink.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: context.artC.ink.withValues(alpha: 0.36),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '搜索聊天',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.artC.ink.withValues(alpha: 0.36),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: Icon(
                          Icons.clear,
                          color: context.artC.ink.withValues(alpha: 0.36),
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredConversations.isEmpty
                    ? _EmptyConversationState(
                        searchQuery: _searchQuery,
                        config: widget.config,
                        onAction: (action) {
                          Navigator.pop(context);
                          widget.onNewChat();
                        },
                      )
                    : ListView.separated(
                        itemCount: filteredConversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conversation = filteredConversations[index];
                          final conversationId =
                              conversation['id']?.toString() ?? '';
                          final title =
                              conversation['title']?.toString().trim();
                          final preview = conversation['last_message_preview']
                              ?.toString()
                              .trim();
                          return Dismissible(
                            key: Key(conversationId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('删除对话'),
                                      content: const Text('确定要删除这条聊天记录吗？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            '删除',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (direction) {
                              widget.onConversationDelete(conversationId);
                            },
                            child: _PressableScale(
                              onTap: () =>
                                  widget.onConversationTap(conversation),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: context.artC.cardIconBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.artC.silver
                                        .withValues(alpha: 0.34),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.artC.ink
                                          .withValues(alpha: 0.025),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title == null || title.isEmpty
                                          ? '新对话'
                                          : title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: context.artC.ink,
                                      ),
                                    ),
                                    if (preview != null &&
                                        preview.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        preview,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                          color: context.artC.ink
                                              .withValues(alpha: 0.42),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeChatView extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final bool sending;
  final ScrollController scrollController;
  final double bottomPadding;
  final String Function(String text) displayText;
  final ValueChanged<String>? onQuickAction;
  final List<String> quickChips;

  const _HomeChatView({
    required this.messages,
    required this.sending,
    required this.scrollController,
    required this.bottomPadding,
    required this.displayText,
    this.onQuickAction,
    required this.quickChips,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final safeTop = topPadding > 0 ? topPadding : 44;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        18,
        safeTop + 64,
        18,
        bottomPadding,
      ),
      itemCount: messages.length +
          (sending ? 1 : 0) +
          (messages.length == 1 && onQuickAction != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && sending) {
          return const _TypingBubble();
        }
        if (index == messages.length ||
            (index == messages.length + 1 && sending)) {
          return _QuickActionChips(chips: quickChips, onTap: onQuickAction!);
        }
        final message = messages[index];
        final user = message['role'] == 'user';
        final text = message['text']?.toString() ?? '';
        final sources = (message['sources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        return _MessageBubble(
          user: user,
          text: displayText(text),
          sources: user ? const [] : sources,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool user;
  final String text;
  final List<Map<String, dynamic>> sources;

  const _MessageBubble({
    required this.user,
    required this.text,
    this.sources = const [],
  });

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.76,
      520.0,
    );
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      decoration: BoxDecoration(
        color: user ? null : context.artC.cardIconBg,
        gradient: user ? _inkWashGradient : null,
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: user ? const Radius.circular(4) : null,
          bottomLeft: !user ? const Radius.circular(4) : null,
        ),
        border: user
            ? null
            : Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: user ? 0.07 : 0.035),
            blurRadius: user ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.48,
              color: user
                  ? Colors.white
                  : context.artC.ink.withValues(alpha: 0.88),
            ),
          ),
          if (!user && sources.isNotEmpty) _HomeSourceList(sources: sources),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: user
            ? [
                bubble,
                const SizedBox(width: 8),
                const _ChatAvatar(user: true),
              ]
            : [
                const _ChatAvatar(user: false),
                const SizedBox(width: 8),
                bubble,
              ],
      ),
    );
  }
}

class _HomeSourceList extends StatelessWidget {
  final List<Map<String, dynamic>> sources;

  const _HomeSourceList({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '信息源',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: context.artC.ink.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(height: 8),
          ...sources.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final source = entry.value;
            final schoolName = source['schoolName']?.toString().trim();
            final heading = source['heading']?.toString().trim();
            final similarity = source['similarity'];
            final score = similarity is num
                ? '${(similarity * 100).clamp(0, 100).toStringAsFixed(0)}%'
                : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.artC.porcelain.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.36),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '[$index]',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: kCobalt,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (schoolName == null || schoolName.isEmpty)
                              ? '知识库条目'
                              : schoolName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        if (heading != null && heading.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            heading,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: context.artC.ink.withValues(alpha: 0.52),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (score != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      score,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink.withValues(alpha: 0.34),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _ChatAvatar(user: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
              border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: context.artC.ink.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                SizedBox(width: 4),
                _TypingDot(delay: 1),
                SizedBox(width: 4),
                _TypingDot(delay: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final bool user;

  const _ChatAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user ? context.artC.ink : Colors.white,
        border: Border.all(
          color: user
              ? context.artC.ink.withValues(alpha: 0.08)
              : context.artC.silver.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: user
          ? const Icon(
              Icons.person_rounded,
              size: 19,
              color: Colors.white,
            )
          : const Padding(
              padding: EdgeInsets.all(4),
              child: CustomPaint(painter: _OrbitLogoPainter()),
            ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _opacity = Tween<double>(begin: 0.35, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay * 120), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: kCobalt.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BottomAskBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onEmojiTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final bool sending;
  final bool showEmojiPicker;
  final bool isRecording;

  const _BottomAskBar({
    required this.controller,
    required this.onSubmit,
    required this.onEmojiTap,
    required this.onPhotoTap,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.sending,
    required this.showEmojiPicker,
    required this.isRecording,
  });

  @override
  State<_BottomAskBar> createState() => _BottomAskBarState();
}

class _BottomAskBarState extends State<_BottomAskBar> {
  bool _voiceMode = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _toggleMode() {
    setState(() => _voiceMode = !_voiceMode);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.artC.porcelain.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Container(
              height: 58,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.artC.cardIconBg.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: context.artC.silver.withValues(alpha: 0.42),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.artC.ink.withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _ComposerCircleButton(
                    icon: Icons.add_rounded,
                    onTap: widget.onPhotoTap,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _voiceMode
                        ? GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('按住说话，松开发送')),
                              );
                            },
                            onLongPressStart: (_) => widget.onRecordStart(),
                            onLongPressEnd: (_) => widget.onRecordEnd(),
                            onLongPressCancel: () => widget.onRecordEnd(),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: widget.isRecording
                                    ? kCobalt.withValues(alpha: 0.1)
                                    : context.artC.cardIconBg,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: widget.isRecording
                                      ? kCobalt
                                      : context.artC.silver
                                          .withValues(alpha: 0.48),
                                  width: widget.isRecording ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.isRecording)
                                    const Icon(
                                      Icons.mic,
                                      color: kCobalt,
                                      size: 20,
                                    ),
                                  if (widget.isRecording)
                                    const SizedBox(width: 8),
                                  Text(
                                    widget.isRecording ? '松开 发送' : '按住 说话',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: widget.isRecording
                                          ? kCobalt
                                          : context.artC.ink
                                              .withValues(alpha: 0.76),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: context.artC.cardIconBg,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color:
                                    context.artC.silver.withValues(alpha: 0.48),
                              ),
                            ),
                            child: TextField(
                              controller: widget.controller,
                              textInputAction: TextInputAction.send,
                              textAlignVertical: TextAlignVertical.center,
                              onSubmitted: (_) => widget.onSubmit(),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                hintText: '输入你的问题...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      context.artC.ink.withValues(alpha: 0.32),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.artC.ink,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  _hasText || widget.sending
                      ? _PressableScale(
                          onTap: widget.sending ? null : widget.onSubmit,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: widget.sending
                                  ? context.artC.silver.withValues(alpha: 0.5)
                                  : kCobalt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.sending
                                  ? Icons.more_horiz_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : _ComposerCircleButton(
                          icon: _voiceMode
                              ? Icons.keyboard_alt_outlined
                              : Icons.mic_none_rounded,
                          onTap: _toggleMode,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ComposerCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.58),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: context.artC.ink),
      ),
    );
  }
}

class _TopAura extends StatelessWidget {
  const _TopAura();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kCobalt.withValues(alpha: 0.07),
            kCobalt.withValues(alpha: 0.025),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _OrbitLogoPainter extends CustomPainter {
  const _OrbitLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.28);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi * 0.55,
        endAngle: math.pi * 1.45,
        colors: [
          kCobalt,
          _inkGlowBlue,
          _debateGold,
          _inkMistBlue,
          _inkGlowBlue,
          kCobalt,
        ],
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi * 0.65, math.pi * 1.85, false, stroke);

    final inner = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, size.width * 0.21, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatHeader extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onActionTap;
  final VoidCallback onReturnTap;
  final bool showAppsIcon;
  final String title;
  final String subtitle;

  const _ChatHeader({
    required this.onMenuTap,
    required this.onActionTap,
    required this.onReturnTap,
    required this.showAppsIcon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final safeTop = topPadding > 0 ? topPadding : 44;
    return Container(
      padding: EdgeInsets.fromLTRB(8, safeTop + 4, 8, 8),
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          bottom:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.24)),
        ),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _HeaderIconButton(
                icon: Icons.menu_rounded,
                onTap: onMenuTap,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _HeaderIconButton(
                  icon: showAppsIcon
                      ? Icons.apps_rounded
                      : Icons.chat_bubble_outline_rounded,
                  onTap: onActionTap,
                ),
                const SizedBox(width: 6),
                _HeaderIconButton(
                  icon: Icons.school_outlined,
                  onTap: onReturnTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChips extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onTap;

  const _QuickActionChips({
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 4, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map((chip) => _PressableScale(
                  onTap: () => onTap(chip),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: kCobalt.withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kCobalt.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  final String searchQuery;
  final _AiHomeProfileConfig config;
  final ValueChanged<String> onAction;

  const _EmptyConversationState({
    required this.searchQuery,
    required this.config,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return Center(
        child: Text(
          '未找到匹配的聊天',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.artC.ink.withValues(alpha: 0.36),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: context.artC.ink.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无聊天记录',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.artC.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              config.emptyConversationText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: context.artC.ink.withValues(alpha: 0.36),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...config.emptyActions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PressableScale(
                  onTap: () => onAction(action.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: kCobalt.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon,
                            size: 18, color: kCobalt.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Text(
                          action.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kCobalt.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
