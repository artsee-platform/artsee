import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../data/mock_compare_schools.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../../theme/artsee_ui_colors.dart';
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
      _AiPromptItem(Icons.fact_check_outlined, '怎么判断作品集机构靠不靠谱？'),
    ],
    quickChips: ['孩子适合学什么专业？', '艺术留学大概要多少钱？', '什么时候开始准备作品集？', '怎么判断机构？'],
    emptyActions: [
      _AiPromptItem(Icons.route_outlined, '专业选择'),
      _AiPromptItem(Icons.payments_outlined, '留学费用'),
      _AiPromptItem(Icons.schedule_outlined, '准备时间'),
    ],
  );

  static const business = _AiHomeProfileConfig(
    profileKey: 'business',
    heroTitle: '艺见心 AI 机构助手',
    heroSubtitle: '帮你完善入驻资料、发布课程活动、提升曝光和对接用户',
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

  const HomeScreen({super.key, this.onReturnToMain});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      'text': _aiConfig.welcomeText,
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
    final text = query.isEmpty ? _aiConfig.defaultPrompt : query;
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
        mode: _aiConfig.aiMode,
        persona: _aiConfig.profileKey,
        intent: 'home_${_aiConfig.profileKey}_chat',
        context: {
          'surface': 'app_home_ai',
          'profileKey': _aiConfig.profileKey,
        },
        messages: aiMessages,
        userProfile: {
          if (_profile != null) ..._profile!,
          'aiProfileKey': _aiConfig.profileKey,
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
        aiProfileKey: _aiConfig.profileKey,
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
    if (_aiConfig.profileKey != 'student' && _aiConfig.profileKey != 'parent') {
      return [
        '当前 AI 或后端环境还没完全配置好，我先按“${_aiConfig.heroTitle}”的方向给你一个可执行判断。',
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
    final tabInset = mainTabBottomInset(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const composerBottom = 0.0;
    final inputMode = _conversationStarted && _chatInputVisible;
    final bottomComposerSpace = inputMode ? 88.0 + safeBottom : tabInset + 32;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      onDrawerChanged: (isOpened) {
        final shouldHideNav =
            isOpened || (_conversationStarted && _chatInputVisible);
        MainScaffold.globalKey.currentState?.setHomeNavHidden(shouldHideNav);
      },
      drawer: _ConversationDrawer(
        conversations: _conversations,
        config: _aiConfig,
        onConversationTap: _openConversation,
        onConversationDelete: _deleteConversation,
        onNewChat: _startNewChat,
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleScroll,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: _handleChatDragEnd,
          child: Stack(
            children: [
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
                  quickChips: _aiConfig.quickChips,
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
                    title: _aiConfig.chatTitle,
                    subtitle: _aiConfig.chatSubtitle,
                  ),
                ),
              ] else
                SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                      20,
                      (MediaQuery.paddingOf(context).top > 0
                              ? MediaQuery.paddingOf(context).top
                              : 44) +
                          60,
                      20,
                      bottomComposerSpace),
                  child: Column(
                    children: [
                      _HeroIntro(
                        onLogoTap: _startConversation,
                        config: _aiConfig,
                      ),
                      const SizedBox(height: 20),
                      _StartConversationButton(
                        label: _aiConfig.startButtonLabel,
                        onTap: _startConversation,
                      ),
                      const SizedBox(height: 26),
                      _PromptCloud(
                        items: _aiConfig.promptCloudItems,
                        onTap: _runPrompt,
                        showHeader: true,
                      ),
                    ],
                  ),
                ),
              if (!_conversationStarted) ...[
                Positioned(
                  left: 8,
                  top: (MediaQuery.paddingOf(context).top > 0
                          ? MediaQuery.paddingOf(context).top
                          : 44) +
                      4,
                  child: _HeaderIconButton(
                    icon: Icons.menu_rounded,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: (MediaQuery.paddingOf(context).top > 0
                          ? MediaQuery.paddingOf(context).top
                          : 44) +
                      4,
                  child: _HeaderIconButton(
                    icon: Icons.school_outlined,
                    onTap: _returnToMainInterface,
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
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  final VoidCallback onLogoTap;
  final _AiHomeProfileConfig config;

  const _HeroIntro({
    required this.onLogoTap,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onLogoTap,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.artC.cardIconBg,
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: kCobalt.withValues(alpha: 0.1),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const CustomPaint(painter: _OrbitLogoPainter()),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          config.heroTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          config.heroSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: context.artC.ink.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 18),
      ],
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
    return GestureDetector(
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
              color: context.artC.ink.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: context.artC.ink),
      ),
    );
  }
}

class _StartConversationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StartConversationButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: context.artC.ink,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: kCobalt.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
      backgroundColor: Colors.white,
      child: SafeArea(
        top: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
              GestureDetector(
                onTap: () {
                  widget.onNewChat();
                  Navigator.of(context).maybePop();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.artC.ink,
                    borderRadius: BorderRadius.circular(12),
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
                  color: context.artC.porcelain,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.42),
                  ),
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
                            child: GestureDetector(
                              onTap: () =>
                                  widget.onConversationTap(conversation),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: context.artC.porcelain,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.artC.silver
                                        .withValues(alpha: 0.42),
                                  ),
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
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.68,
      ),
      decoration: BoxDecoration(
        color: user ? context.artC.deepPanel : context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(17).copyWith(
          bottomRight: user ? const Radius.circular(4) : null,
          bottomLeft: !user ? const Radius.circular(4) : null,
        ),
        border: user
            ? null
            : Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
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

class _TypingDot extends StatelessWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1),
      duration: Duration(milliseconds: 620 + delay * 120),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class _PromptCloud extends StatelessWidget {
  final List<_AiPromptItem> items;
  final ValueChanged<String> onTap;
  final bool showHeader;

  const _PromptCloud({
    required this.items,
    required this.onTap,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            '你可以这样开始',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.artC.ink.withValues(alpha: 0.56),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.75,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _PromptPill(
              icon: item.icon,
              label: item.text,
              onTap: () => onTap(item.text),
            );
          },
        ),
      ],
    );
  }
}

class _PromptPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PromptPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ArtseeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        radius: 14,
        child: Row(
          children: [
            Icon(icon, size: 18, color: kCobalt.withValues(alpha: 0.62)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
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
          color: context.artC.porcelain.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: context.artC.silver.withValues(alpha: 0.5)),
          ),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            child: SizedBox(
              height: 50,
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
                      ? GestureDetector(
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
    return GestureDetector(
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
              blurRadius: 8,
              offset: const Offset(0, 2),
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
      height: 180,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.05,
          colors: [
            kCobalt.withValues(alpha: 0.08),
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
          Color(0xFF003399),
          Color(0xFF7C3AED),
          Color(0xFFFB7185),
          Color(0xFFFF8A3D),
          Color(0xFF7C3AED),
          Color(0xFF003399),
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
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: context.artC.silver.withValues(alpha: 0.3)),
        ),
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
            .map((chip) => GestureDetector(
                  onTap: () => onTap(chip),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kCobalt.withValues(alpha: 0.2)),
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
                child: GestureDetector(
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
