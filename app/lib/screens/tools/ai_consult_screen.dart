import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../data/mock_compare_schools.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 懂车帝式：全屏沉浸、深色顶栏、对话 + 「对比选校」数据面板（雷达 + 参数表）
class AiConsultScreen extends StatefulWidget {
  final String? initialQuery;
  final int initialTabIndex;

  const AiConsultScreen({
    super.key,
    this.initialQuery,
    this.initialTabIndex = 0,
  });

  @override
  State<AiConsultScreen> createState() => _AiConsultScreenState();
}

class _AiConsultScreenState extends State<AiConsultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'text': '你好！我是 Artiqore AI 助手。可以问我选校、作品集与职业路径；也可切换到「对比选校」添加院校查看多维数据面板。',
      'sources': <Map<String, dynamic>>[],
    },
  ];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _useKnowledge = true;
  bool _showHistory = false;
  List<Map<String, dynamic>> _conversations = [];
  String? _currentConversationId;
  bool _loadingHistory = false;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  String? _speechLocaleId;

  final TextEditingController _compareSearch = TextEditingController();
  final Set<String> _selectedIds = {};

  static const _suggestions = [
    'RCA 和 RISD 哪个更适合交互方向？',
    '一年制硕士总预算 40 万可以选哪些院校？',
    '作品集里需要几个完整项目？',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _speech = stt.SpeechToText();
    _initSpeech();
    _input.addListener(() => setState(() {}));
    _loadConversations();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial));
    }
  }

  Future<void> _loadConversations() async {
    if (!SupabaseService.isLoggedIn) return;
    setState(() => _loadingHistory = true);
    try {
      final conversations = await BackendApiService.getAiConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _createNewConversation() async {
    try {
      final conversation = await BackendApiService.createAiConversation();
      setState(() {
        _currentConversationId = conversation['id'] as String?;
        _messages.clear();
        _messages.add({
          'role': 'assistant',
          'text':
              '你好！我是 Artiqore AI 助手。可以问我选校、作品集与职业路径；也可切换到「对比选校」添加院校查看多维数据面板。',
          'sources': <Map<String, dynamic>>[],
        });
      });
      await _loadConversations();
    } catch (e) {
      print('创建对话失败: $e');
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    try {
      final data = await BackendApiService.getAiConversation(conversationId);
      final messages = data['messages'] as List<dynamic>? ?? [];
      setState(() {
        _currentConversationId = conversationId;
        _messages.clear();
        _messages.addAll(messages.map((m) => {
              'role': m['role'] as String,
              'text': m['content'] as String,
              'sources': <Map<String, dynamic>>[],
            }));
        _showHistory = false;
      });
    } catch (e) {
      print('加载对话失败: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    print('🗑️ 开始删除对话: $conversationId');
    try {
      await BackendApiService.deleteAiConversation(conversationId);
      print('🗑️ 后端删除成功');
      if (_currentConversationId == conversationId) {
        print('🗑️ 清空当前对话');
        setState(() {
          _currentConversationId = null;
          _messages.clear();
          _messages.add({
            'role': 'assistant',
            'text':
                '你好！我是 Artiqore AI 助手。可以问我选校、作品集与职业路径；也可切换到「对比选校」添加院校查看多维数据面板。',
            'sources': <Map<String, dynamic>>[],
          });
        });
      }
      print('🗑️ 重新加载对话列表');
      await _loadConversations();
      print('🗑️ 删除完成');
    } catch (e, stackTrace) {
      print('删除对话失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tabCtrl.dispose();
    _input.dispose();
    _scrollCtrl.dispose();
    _compareSearch.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          final wasListening = _isListening;
          setState(() => _isListening = false);
          if (wasListening) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_speechFailureMessage(error.errorMsg))),
            );
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      _speechAvailable = available;
      if (available) {
        _speechLocaleId = await _resolveSpeechLocaleId();
      }
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
      if (mounted) setState(() {});
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
          if (locale.localeId == preferred) return locale.localeId;
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

      return (await _speech.systemLocale())?.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _stopSpeechInput();
    } else {
      await _startSpeechInput();
    }
  }

  Future<void> _startSpeechInput() async {
    if (_sending) return;

    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (!mounted) return;
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
        return;
      }
    }

    FocusScope.of(context).unfocus();
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      if (!mounted) return;
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
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognizedWords = result.recognizedWords.trim();
          if (recognizedWords.isEmpty) return;
          _input.value = TextEditingValue(
            text: recognizedWords,
            selection: TextSelection.collapsed(offset: recognizedWords.length),
          );
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
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_speechFailureMessage(e))),
      );
    }
  }

  Future<void> _stopSpeechInput() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(
          {'role': 'user', 'text': text, 'sources': <Map<String, dynamic>>[]});
      _sending = true;
    });
    _input.clear();
    _scrollBottom();

    final canPersistConversation = SupabaseService.isLoggedIn;

    if (canPersistConversation && _currentConversationId == null) {
      try {
        final conversation = await BackendApiService.createAiConversation(
          title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
        );
        print('📦 创建对话返回: $conversation');
        print('📦 conversation 类型: ${conversation.runtimeType}');
        print('📦 conversation[\'id\'] 类型: ${conversation['id'].runtimeType}');
        _currentConversationId = conversation['id'] as String?;
        print('📦 设置的 conversationId: $_currentConversationId');
        await _loadConversations();
      } catch (e) {
        print('创建对话失败: $e');
      }
    }

    if (canPersistConversation && _currentConversationId != null) {
      try {
        await BackendApiService.saveAiMessage(
          conversationId: _currentConversationId!,
          role: 'user',
          content: text,
        );
      } catch (e, stackTrace) {
        print('保存用户消息失败: $e');
        print('堆栈跟踪: $stackTrace');
      }
    }

    String reply;
    List<Map<String, dynamic>> sources = const [];
    try {
      if (_useKnowledge) {
        final aiMessages = _messages
            .map((m) => <String, dynamic>{
                  'role': m['role'] == 'assistant' ? 'assistant' : 'user',
                  'content': (m['text'] ?? m['content'] ?? '').toString(),
                })
            .where((m) => (m['content'] as String).trim().isNotEmpty)
            .toList();
        final result = await BackendApiService.aiConsult(
          text,
          mode: 'chat',
          persona: 'general',
          intent: 'tools_ai_chat',
          context: {'surface': 'app_ai_consult'},
          messages: aiMessages,
        );
        reply = _formatConsultReply(result);
        sources = _extractSources(result);
      } else {
        final result = await BackendApiService.aiSchoolSearch(text);
        reply = _formatAiReply(result);
      }
    } catch (e) {
      reply = _buildFallbackReply(text, e);
    }
    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'assistant',
        'text': reply,
        'sources': sources,
      });
      _sending = false;
    });
    _scrollBottom();

    if (canPersistConversation && _currentConversationId != null) {
      try {
        await BackendApiService.saveAiMessage(
          conversationId: _currentConversationId!,
          role: 'assistant',
          content: reply,
        );
        await _loadConversations();
      } catch (e, stackTrace) {
        print('保存助手消息失败: $e');
        print('堆栈跟踪: $stackTrace');
      }
    }
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
    final result = text
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
        .replaceAllMapped(
          RegExp(r'[A-Za-z0-9_./:#?=&%-]{24,}'),
          (match) => match.group(0)!.replaceAllMapped(
                RegExp(r'.{1,16}'),
                (part) => '${part.group(0)} ',
              ),
        );

    if (text.length > 500 && result.length != text.length) {
      print('⚠️ _displayMessageText 改变了长度: ${text.length} → ${result.length}');
    }

    return result;
  }

  Widget _buildSourceList(List<Map<String, dynamic>> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '信息源',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: context.artC.ink.withOpacity(0.38),
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
                color: context.artC.porcelain.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: context.artC.silver.withOpacity(0.36)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kCobalt.withOpacity(0.1),
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
                              color: context.artC.ink.withOpacity(0.52),
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
                        color: context.artC.ink.withOpacity(0.34),
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

  String _buildFallbackReply(String question, Object error) {
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

  List<CompareSchool> get _filteredSchools {
    final q = _compareSearch.text.trim().toLowerCase();
    if (q.isEmpty) return kMockCompareSchools;
    return kMockCompareSchools
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.enName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<CompareSchool> get _selected =>
      kMockCompareSchools.where((s) => _selectedIds.contains(s.id)).toList();

  void _toggleSchool(CompareSchool s) {
    setState(() {
      if (_selectedIds.contains(s.id)) {
        _selectedIds.remove(s.id);
      } else if (_selectedIds.length < 5) {
        _selectedIds.add(s.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: ArtseeSegmentedTabs(
                  controller: _tabCtrl,
                  labelFontSize: 12,
                  height: 40,
                  tabs: const [
                    ArtseeSegmentTab(
                      label: '智能问答',
                      icon: Icons.smart_toy_outlined,
                    ),
                    ArtseeSegmentTab(
                      label: '对比选校',
                      icon: Icons.compare_arrows_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildChatTab(),
                    _buildCompareTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_showHistory) _buildHistorySidebar(context),
        ],
      ),
    );
  }

  Widget _buildHistorySidebar(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showHistory = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: Offset(5, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '对话历史',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.artC.ink,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: _createNewConversation,
                            icon:
                                Icon(Icons.add_circle_outline, color: kCobalt),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _showHistory = false),
                            icon: Icon(Icons.close,
                                color: context.artC.ink.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    if (_loadingHistory)
                      Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: kCobalt),
                        ),
                      )
                    else if (_conversations.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48,
                                  color: context.artC.ink.withOpacity(0.2)),
                              SizedBox(height: 12),
                              Text(
                                '暂无历史对话',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.artC.ink.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: _conversations.length,
                          itemBuilder: (context, i) {
                            final conv = _conversations[i];
                            final isActive =
                                conv['id'] == _currentConversationId;
                            return InkWell(
                              onTap: () => _loadConversation(conv['id']),
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? kCobalt.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? kCobalt
                                        : context.artC.silver.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            conv['title'] ?? '新对话',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: context.artC.ink,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (conv['last_message_preview'] !=
                                              null) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              conv['last_message_preview'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.artC.ink
                                                    .withOpacity(0.5),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _deleteConversation(conv['id']),
                                      icon: Icon(Icons.delete_outline,
                                          size: 20,
                                          color: Colors.red.withOpacity(0.6)),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 6, 12, 14),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.white, size: 22),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kCobalt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artiqore AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Intelligent Concierge · 选校参谋',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: Colors.white.withOpacity(0.45),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: Icon(
              _showHistory ? Icons.chat_bubble : Icons.history,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                color: _useKnowledge
                    ? Color(0xFF22C55E)
                    : Colors.white.withOpacity(0.3),
                size: 14,
              ),
              const SizedBox(height: 2),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _useKnowledge,
                  onChanged: (v) => setState(() => _useKnowledge = v),
                  activeColor: Color(0xFF22C55E),
                  inactiveThumbColor: Colors.white.withOpacity(0.5),
                  inactiveTrackColor: Colors.white.withOpacity(0.15),
                ),
              ),
              Text(
                _useKnowledge ? '知识库' : '纯对话',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((s) {
                        return ActionChip(
                          label: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.artC.ink,
                            ),
                          ),
                          backgroundColor:
                              context.artC.cardIconBg.withOpacity(0.82),
                          side: BorderSide(
                            color: context.artC.silver.withOpacity(0.45),
                          ),
                          onPressed: _sending ? null : () => _send(s),
                        );
                      }).toList(),
                    ),
                  );
                }

                final msg = _messages[i - 1];
                final user = msg['role'] == 'user';
                final text = msg['text']?.toString() ?? '';
                final sources = (msg['sources'] as List<dynamic>? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
                return Align(
                  alignment:
                      user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: user ? context.artC.ink : context.artC.cardIconBg,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: user ? const Radius.circular(4) : null,
                        bottomLeft: !user ? const Radius.circular(4) : null,
                      ),
                      border: user
                          ? null
                          : Border.all(
                              color: context.artC.silver.withOpacity(0.45),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: context.artC.ink.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          _displayMessageText(text),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: user
                                ? context.artC.porcelain
                                : context.artC.ink.withOpacity(0.88),
                          ),
                        ),
                        if (!user) _buildSourceList(sources),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _typingDot(0),
                _typingDot(1),
                _typingDot(2),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          decoration: BoxDecoration(
            color: context.artC.cardIconBg,
            border: Border(
                top: BorderSide(color: context.artC.silver.withOpacity(0.5))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        autofocus: widget.initialQuery == null ||
                            widget.initialQuery!.trim().isEmpty,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.none,
                        enableSuggestions: true,
                        autocorrect: true,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? '正在听，请直接说出你的问题…'
                              : '询问学习、创作、展览、收藏或申请…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: context.artC.ink.withOpacity(0.28),
                          ),
                          filled: true,
                          fillColor: context.artC.porcelain,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: context.artC.silver.withOpacity(0.6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: context.artC.silver.withOpacity(0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: kCobalt.withOpacity(0.55)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleSpeechInput,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? kCobalt.withOpacity(0.14)
                              : context.artC.porcelain,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isListening
                                ? kCobalt.withOpacity(0.68)
                                : context.artC.silver.withOpacity(0.6),
                          ),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? kCobalt
                              : context.artC.ink.withOpacity(0.52),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _send(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _input.text.trim().isEmpty && !_sending
                              ? context.artC.ink.withOpacity(0.12)
                              : kCobalt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isListening
                      ? (kIsWeb
                          ? '浏览器语音识别中 · Chrome/Edge 效果最佳'
                          : '系统语音识别中 · Android 可使用 Google 语音服务')
                      : 'AI 支持学习、创作、展览、收藏与申请咨询',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: context.artC.ink.withOpacity(0.22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _typingDot(int i) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: kCobalt.withOpacity(0.35 + i * 0.2),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCompareTab() {
    final selected = _selected;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _compareSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search,
                        color: context.artC.ink.withOpacity(0.25)),
                    hintText: '搜索伦敦艺术大学、罗德岛设计学院…',
                    hintStyle: TextStyle(
                        fontSize: 12,
                        color: context.artC.ink.withOpacity(0.28)),
                    filled: true,
                    fillColor: context.artC.cardIconBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: context.artC.silver.withOpacity(0.55)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.artC.cardIconBg,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: context.artC.silver.withOpacity(0.55)),
                ),
                child: Icon(Icons.tune, color: kCobalt.withOpacity(0.85)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '点击封面右上角「+」加入对比（最多 5 所） · 已选 ${selected.length} 所',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.artC.ink.withOpacity(0.38),
            ),
          ),
          const SizedBox(height: 14),
          ..._filteredSchools.map((s) => _CompareSchoolRow(
                school: s,
                selected: _selectedIds.contains(s.id),
                onToggle: () => _toggleSchool(s),
              )),
          const SizedBox(height: 24),
          if (selected.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: context.artC.silver.withOpacity(0.45)),
              ),
              child: Column(
                children: [
                  Icon(Icons.compare_arrows,
                      size: 40, color: context.artC.ink.withOpacity(0.15)),
                  const SizedBox(height: 12),
                  Text(
                    '对比中心暂无数据',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink.withOpacity(0.45),
                      fontFamily: kAppFontFamily,
                      fontFamilyFallback: kAppFontFallback,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '在上方列表中点击「+」加入院校，即可查看雷达图与参数表。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: context.artC.ink.withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: context.artC.silver.withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '能力多维对比',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: context.artC.ink,
                    ),
                  ),
                  Text(
                    'Comparative Data Visualization',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      color: context.artC.ink.withOpacity(0.28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: CustomPaint(
                      painter: _RadarPainter(schools: selected),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: selected.asMap().entries.map((e) {
                      final colors = [
                        kCobalt,
                        kCobaltMuted,
                        const Color(0xFF64748B)
                      ];
                      final c = colors[e.key % colors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration:
                                BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.value.name,
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _CompareTable(schools: selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareSchoolRow extends StatelessWidget {
  final CompareSchool school;
  final bool selected;
  final VoidCallback onToggle;

  const _CompareSchoolRow({
    required this.school,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    school.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: context.artC.silver.withOpacity(0.3)),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Wrap(
                  spacing: 6,
                  children: school.tags.take(2).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: context.artC.silver.withOpacity(0.38),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: context.artC.ink,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: selected ? kCobalt : Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        selected ? Icons.check : Icons.add,
                        color: selected
                            ? Colors.white
                            : context.artC.ink.withOpacity(0.55),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            school.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.artC.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            school.enName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              color: context.artC.ink.withOpacity(0.32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.artC.silver.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${school.id}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kCobalt,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          school.cityCountry,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            color: context.artC.ink.withOpacity(0.38),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      school.tuition,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.artC.ink,
                      ),
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

class _RadarPainter extends CustomPainter {
  final List<CompareSchool> schools;

  _RadarPainter({required this.schools});

  static const _labels = ['排名', '就业', '费用', '设施', '声誉'];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    final r = math.min(size.width, size.height) * 0.36;
    final paintGrid = Paint()
      ..color = kSilver.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      final rr = r * ring / 4;
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        final x = c.dx + rr * math.cos(ang);
        final y = c.dy + rr * math.sin(ang);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paintGrid);
    }

    for (var i = 0; i < 5; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawLine(
        c,
        Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang)),
        paintGrid,
      );
      final lx = c.dx + (r + 18) * math.cos(ang);
      final ly = c.dy + (r + 18) * math.sin(ang);
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: kInk.withOpacity(0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    final colors = [kCobalt, kCobaltMuted, const Color(0xFF64748B)];
    for (var s = 0; s < schools.length; s++) {
      final school = schools[s];
      final path = Path();
      final scores = school.radarScores;
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        final v = scores[i] / 100.0;
        final rr = r * v;
        final x = c.dx + rr * math.cos(ang);
        final y = c.dy + rr * math.sin(ang);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final fill = Paint()
        ..color = colors[s % colors.length].withOpacity(0.22)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = colors[s % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.schools != schools;
}

class _CompareTable extends StatelessWidget {
  final List<CompareSchool> schools;

  const _CompareTable({required this.schools});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('预计学费/年', (CompareSchool s) => s.tuition, false),
      ('语言成绩要求', (CompareSchool s) => s.language, false),
      ('硕士就业率', (CompareSchool s) => s.employmentRate, true),
      ('GPA 录取建议', (CompareSchool s) => s.gpa, true),
      ('毕业平均起薪', (CompareSchool s) => s.avgSalary, true),
    ];
    return DataTable(
      headingRowColor: WidgetStateProperty.all(context.artC.porcelain),
      dataRowMinHeight: 44,
      horizontalMargin: 12,
      columns: [
        DataColumn(
          label: Text(
            '指标',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
        ),
        ...schools.map(
          (s) => DataColumn(
            label: SizedBox(
              width: 120,
              child: Text(
                s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
      rows: rows.map((row) {
        return DataRow(
          cells: [
            DataCell(
              Text(
                row.$1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withOpacity(0.38),
                ),
              ),
            ),
            ...schools.map((s) {
              return DataCell(
                Text(
                  row.$2(s),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
