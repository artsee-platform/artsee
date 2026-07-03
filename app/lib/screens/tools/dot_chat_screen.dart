import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/common.dart';

class DotChatScreen extends StatefulWidget {
  final String? initialQuery;

  const DotChatScreen({super.key, this.initialQuery});

  @override
  State<DotChatScreen> createState() => _DotChatScreenState();
}

class _DotChatScreenState extends State<DotChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late stt.SpeechToText _speech;

  final List<_DotMessage> _messages = [
    const _DotMessage(
      role: _DotRole.assistant,
      text: '欢迎回来，我是 Art Guide。你可以直接问我院校、专业、作品集、预算或申请时间线，我会尽量把答案拆成可执行的下一步。',
    ),
  ];

  List<Map<String, dynamic>> _conversations = [];
  bool _loadingConversations = false;
  bool _sending = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  String? _currentConversationId;
  String? _speechLocaleId;

  static const _suggestions = [
    'RCA 和 UAL 插画怎么选？',
    '预算 40 万，英国一年制硕士怎么排？',
    '帮我比较 Parsons 和 SVA 交互设计',
    '作品集到底要准备几个完整项目？',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _input.addListener(() {
      if (mounted) setState(() {});
    });
    _initSpeech();
    _loadConversations();

    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial));
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    if (!SupabaseService.isLoggedIn) return;
    setState(() => _loadingConversations = true);
    try {
      final conversations = await BackendApiService.getAiConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loadingConversations = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _ensureConversation(String firstMessage) async {
    if (!SupabaseService.isLoggedIn || _currentConversationId != null) return;
    try {
      final conversation = await BackendApiService.createAiConversation(
        title: firstMessage.length > 30
            ? '${firstMessage.substring(0, 30)}...'
            : firstMessage,
        aiProfileKey: 'student',
      );
      _currentConversationId = conversation['id']?.toString();
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
    required _DotRole role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    if (!SupabaseService.isLoggedIn) return;
    final conversationId = _currentConversationId;
    if (conversationId == null) return;
    try {
      await BackendApiService.saveAiMessage(
        conversationId: conversationId,
        role: role == _DotRole.user ? 'user' : 'assistant',
        content: content,
        metadata: metadata,
      );
    } catch (_) {}
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final id = conversation['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final data = await BackendApiService.getAiConversation(id);
      final rawMessages = data['messages'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _currentConversationId = id;
        _messages
          ..clear()
          ..addAll(rawMessages.map((message) {
            final role = message is Map && message['role'] == 'user'
                ? _DotRole.user
                : _DotRole.assistant;
            final content = message is Map
                ? message['content']?.toString() ?? ''
                : message.toString();
            return _DotMessage(role: role, text: content);
          }).where((message) => message.text.trim().isNotEmpty));
        if (_messages.isEmpty) {
          _messages.add(const _DotMessage(
            role: _DotRole.assistant,
            text: '我们可以继续聊选校、专业和申请节奏。',
          ));
        }
      });
      _scrollBottom();
    } catch (error) {
      _showSnack('读取对话失败: $error');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      await BackendApiService.deleteAiConversation(conversationId);
      if (!mounted) return;
      setState(() {
        _conversations.removeWhere(
          (conversation) => conversation['id']?.toString() == conversationId,
        );
        if (_currentConversationId == conversationId) {
          _currentConversationId = null;
          _messages
            ..clear()
            ..add(const _DotMessage(
              role: _DotRole.assistant,
              text: '这条对话已删除。可以直接开始新的问题。',
            ));
        }
      });
      _showSnack('已删除对话');
    } catch (error) {
      _showSnack('删除失败: $error');
    }
  }

  void _startNewChat() {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentConversationId = null;
      _sending = false;
      _messages
        ..clear()
        ..add(const _DotMessage(
          role: _DotRole.assistant,
          text: '新的对话开始了。告诉我学校、专业、国家城市或你的当前条件，我来帮你拆判断。',
        ));
      _input.clear();
    });
    _scrollTop();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _input.clear();
      _sending = true;
      _messages.add(_DotMessage(role: _DotRole.user, text: text));
      _messages.add(const _DotMessage(role: _DotRole.assistant, text: ''));
    });
    _scrollBottom();

    await _ensureConversation(text);
    await _saveMessage(role: _DotRole.user, content: text);

    final assistantIndex = _messages.length - 1;
    var reply = '';
    try {
      final chatMessages = _messages
          .take(assistantIndex)
          .where((message) => message.text.trim().isNotEmpty)
          .takeLast(14)
          .map((message) => <String, String>{
                'role':
                    message.role == _DotRole.assistant ? 'assistant' : 'user',
                'content': message.text,
              })
          .toList();

      await for (final chunk in BackendApiService.streamAiChat(
        messages: chatMessages,
        context: const {
          'surface': 'app_dot_chat',
          'entry': 'school_channel',
          'persona': 'art_guide',
          'focus': 'art_admissions_school_search',
        },
      )) {
        reply += chunk;
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex] =
              _DotMessage(role: _DotRole.assistant, text: reply);
        });
        _scrollBottom();
      }
      reply = reply.trim();
      if (reply.isEmpty) reply = '我收到了，但这次没有生成有效回复。你可以换个问法再试一次。';
    } catch (error) {
      reply = _fallbackReply(text, error);
      if (mounted) {
        setState(() {
          _messages[assistantIndex] =
              _DotMessage(role: _DotRole.assistant, text: reply);
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _messages[assistantIndex] =
          _DotMessage(role: _DotRole.assistant, text: reply);
      _sending = false;
    });
    _scrollBottom();
    await _saveMessage(
      role: _DotRole.assistant,
      content: reply,
      metadata: const {'surface': 'app_dot_chat'},
    );
    _loadConversations();
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    if (!await ensureLoggedIn(context, message: '请先登录后上传图片给 Art Guide 分析')) {
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 86,
      );
      if (image == null) return;

      setState(() {
        _sending = true;
        _messages.add(const _DotMessage(role: _DotRole.user, text: '[图片]'));
        _messages.add(const _DotMessage(role: _DotRole.assistant, text: ''));
      });
      _scrollBottom();

      await _ensureConversation('[图片]');
      await _saveMessage(
        role: _DotRole.user,
        content: '[图片]',
        metadata: const {'kind': 'image'},
      );

      final result = await BackendApiService.uploadImageAndAnalyze(
        bytes: await image.readAsBytes(),
        filename: image.name.isNotEmpty ? image.name : 'dot-chat-image.jpg',
        contentType: image.mimeType ?? 'image/jpeg',
        conversationId: _currentConversationId,
      );
      final reply = result['answer']?.toString().trim().isNotEmpty == true
          ? result['answer'].toString()
          : '图片已收到。你可以继续补充：这是作品集、学校页面、作品图还是申请材料？';

      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] =
            _DotMessage(role: _DotRole.assistant, text: reply);
        _sending = false;
      });
      _scrollBottom();
      await _saveMessage(role: _DotRole.assistant, content: reply);
      _loadConversations();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.text.isEmpty) {
          _messages[_messages.length - 1] = _DotMessage(
            role: _DotRole.assistant,
            text: '图片上传失败: $error\n\n你也可以先用文字描述图片内容，我会继续帮你判断。',
          );
        }
        _sending = false;
      });
      _scrollBottom();
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          final wasListening = _isListening;
          setState(() => _isListening = false);
          if (wasListening) _showSnack(_speechFailureMessage(error.errorMsg));
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              mounted &&
              _isListening) {
            setState(() => _isListening = false);
          }
        },
      );
      if (_speechAvailable) {
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
      const preferred = [
        'zh_CN',
        'zh-Hans-CN',
        'zh_Hans_CN',
        'zh-Hans',
        'zh_TW',
        'zh-Hant-TW',
        'zh_HK',
        'cmn_Hans_CN',
      ];
      for (final id in preferred) {
        for (final locale in locales) {
          if (locale.localeId == id) return locale.localeId;
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

  Future<void> _startSpeechInput() async {
    if (_sending) return;
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        final permanentlyDenied = micStatus.isPermanentlyDenied;
        _showSnack(
          permanentlyDenied ? '麦克风权限已关闭，请到系统设置中允许后再使用语音输入' : '需要麦克风权限才能使用语音输入',
          action: permanentlyDenied
              ? const SnackBarAction(label: '去设置', onPressed: openAppSettings)
              : null,
        );
        return;
      }
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (!_speechAvailable) await _initSpeech();
    if (!_speechAvailable) {
      _showSnack(
        kIsWeb
            ? '当前浏览器不支持语音识别。请使用 Chrome 或 Edge，并允许网页麦克风权限'
            : '语音识别不可用，请确认系统语音服务和麦克风权限可用',
        action: kIsWeb
            ? null
            : const SnackBarAction(label: '去设置', onPressed: openAppSettings),
      );
      return;
    }

    if (kIsWeb) {
      _showSnack('正在调用浏览器语音识别，请允许麦克风权限');
    }

    _speechLocaleId ??= await _resolveSpeechLocaleId();
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isListening = true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognized = result.recognizedWords.trim();
          if (recognized.isEmpty) return;
          _input.value = TextEditingValue(
            text: recognized,
            selection: TextSelection.collapsed(offset: recognized.length),
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _showSnack(_speechFailureMessage(error));
    }
  }

  Future<void> _stopSpeechInput() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _stopSpeechInputAndSend() async {
    final wasListening = _isListening;
    await _stopSpeechInput();
    if (!wasListening || _sending) return;
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final recognized = _input.text.trim();
    if (recognized.isEmpty) {
      _showSnack('没有听清语音内容，请按住说完后再松开');
      return;
    }
    await _send(recognized);
  }

  String _speechFailureMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('not-allowed') ||
        raw.contains('service-not-allowed') ||
        raw.contains('permission') ||
        raw.contains('denied')) {
      return kIsWeb ? '浏览器麦克风权限被拒绝，请在地址栏允许麦克风后重试' : '麦克风权限被拒绝，请到系统设置中开启后重试';
    }
    if (raw.contains('no-speech') || raw.contains('no_match')) {
      return '没有听清语音内容，请靠近麦克风后重试';
    }
    if (raw.contains('audio-capture')) return '没有检测到可用麦克风，请检查设备输入';
    if (raw.contains('network')) return '语音识别网络连接失败，请稍后重试';
    return '系统语音识别失败: $error';
  }

  String _displayText(String text) {
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
        .replaceAll(RegExp(r'\s*\[\d+\]'), '');
  }

  String _fallbackReply(String question, Object error) {
    return [
      'Art Guide 这会儿没有连上实时 AI 服务，我先帮你把问题拆一下。',
      '如果你问的是「$question」，建议补充 4 个信息：目标国家 / 城市、专业方向、预算上限、作品集进度。',
      '拿到这些后，可以先做冲刺 / 匹配 / 保底三档，再逐个核对课程、语言、作品集要求和申请截止日期。',
    ].join('\n\n');
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.artC.cardIconBg,
      builder: (sheetContext) {
        return _DotMoreSheet(
          conversations: _conversations,
          loading: _loadingConversations,
          onNewChat: () {
            Navigator.of(sheetContext).pop();
            _startNewChat();
          },
          onConversationTap: (conversation) {
            Navigator.of(sheetContext).pop();
            _openConversation(conversation);
          },
          onConversationDelete: _deleteConversation,
        );
      },
    );
  }

  void _showSnack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 96,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _DotHeader(
            onClose: () => Navigator.of(context).maybePop(),
            onMore: _showMoreSheet,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottomInset),
              itemCount: _messages.length + (_messages.length == 1 ? 1 : 0),
              itemBuilder: (context, index) {
                if (_messages.length == 1 && index == 1) {
                  return _DotSuggestions(
                    suggestions: _suggestions,
                    onTap: _send,
                  );
                }
                final message = _messages[index];
                return _DotMessageBubble(
                  user: message.role == _DotRole.user,
                  text: _displayText(message.text),
                  streaming: _sending &&
                      index == _messages.length - 1 &&
                      message.role == _DotRole.assistant &&
                      message.text.isEmpty,
                );
              },
            ),
          ),
          _DotComposer(
            controller: _input,
            sending: _sending,
            isRecording: _isListening,
            onPhotoTap: _pickAndSendImage,
            onRecordStart: _startSpeechInput,
            onRecordEnd: _stopSpeechInputAndSend,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

enum _DotRole { user, assistant }

class _DotMessage {
  final _DotRole role;
  final String text;

  const _DotMessage({required this.role, required this.text});
}

extension _TakeLastDotMessages<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final items = toList(growable: false);
    if (items.length <= count) return items;
    return items.sublist(items.length - count);
  }
}

class _DotHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onMore;

  const _DotHeader({
    required this.onClose,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        border: Border(
          bottom: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _DotHeaderButton(
                icon: Icons.close_rounded,
                tooltip: '关闭 Art Guide',
                onTap: onClose,
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DotBubbleLogo(size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Art Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          color: context.artC.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _DotHeaderButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'Art Guide 设置',
                onTap: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _DotHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              size: 25,
              color: context.artC.ink.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotBubbleLogo extends StatelessWidget {
  final double size;

  const _DotBubbleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kCobalt.withValues(alpha: 0.1),
        border: Border.all(color: kCobalt.withValues(alpha: 0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.chat_bubble_rounded,
            size: size * 0.62,
            color: kCobalt,
          ),
          Positioned(
            top: size * 0.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotLogoDot(size: size * 0.095),
                SizedBox(width: size * 0.075),
                _DotLogoDot(size: size * 0.095),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotLogoDot extends StatelessWidget {
  final double size;

  const _DotLogoDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DotSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _DotSuggestions({
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(42, 6, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '推荐问题',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: context.artC.ink.withValues(alpha: 0.44),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (suggestion) => _DotSuggestionChip(
                    label: suggestion,
                    onTap: () => onTap(suggestion),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DotSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DotSuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.artC.cardIconBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: context.artC.silver.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotMessageBubble extends StatelessWidget {
  final bool user;
  final String text;
  final bool streaming;

  const _DotMessageBubble({
    required this.user,
    required this.text,
    this.streaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = user
        ? _DotAvatar(
            color: context.artC.ink,
            child:
                const Icon(Icons.person_rounded, size: 18, color: Colors.white),
          )
        : const _DotAvatar(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(5),
              child: _DotBubbleLogo(size: 24),
            ),
          );
    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: user ? context.artC.deepPanel : context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(17).copyWith(
          bottomLeft: user ? null : const Radius.circular(5),
          bottomRight: user ? const Radius.circular(5) : null,
        ),
        border: user
            ? null
            : Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: streaming
          ? const _DotTypingDots()
          : SelectableText(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.48,
                color: user
                    ? Colors.white
                    : context.artC.ink.withValues(alpha: 0.88),
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: user
            ? [bubble, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), bubble],
      ),
    );
  }
}

class _DotAvatar extends StatelessWidget {
  final Color color;
  final Widget child;

  const _DotAvatar({
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DotTypingDots extends StatelessWidget {
  const _DotTypingDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DotTypingDot(delay: 0),
        SizedBox(width: 4),
        _DotTypingDot(delay: 1),
        SizedBox(width: 4),
        _DotTypingDot(delay: 2),
      ],
    );
  }
}

class _DotTypingDot extends StatelessWidget {
  final int delay;

  const _DotTypingDot({required this.delay});

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
    );
  }
}

class _DotComposer extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final bool isRecording;
  final VoidCallback onPhotoTap;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onSend;

  const _DotComposer({
    required this.controller,
    required this.sending,
    required this.isRecording,
    required this.onPhotoTap,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onSend,
  });

  @override
  State<_DotComposer> createState() => _DotComposerState();
}

class _DotComposerState extends State<_DotComposer> {
  bool _voiceMode = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _DotComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
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
    return Container(
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.5),
          ),
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
                _DotComposerCircleButton(
                  icon: Icons.add_rounded,
                  onTap: widget.sending ? null : widget.onPhotoTap,
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
                            enabled: !widget.sending,
                            textInputAction: TextInputAction.send,
                            textAlignVertical: TextAlignVertical.center,
                            onSubmitted: (_) {
                              if (_hasText && !widget.sending) widget.onSend();
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 12, 10, 12),
                              hintText: '问 Art Guide...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.artC.ink.withValues(alpha: 0.32),
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
                        onTap: widget.sending ? null : widget.onSend,
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
                    : _DotComposerCircleButton(
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
    );
  }
}

class _DotComposerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _DotComposerCircleButton({
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
        child: Icon(
          icon,
          size: 24,
          color: onTap == null
              ? context.artC.ink.withValues(alpha: 0.26)
              : context.artC.ink,
        ),
      ),
    );
  }
}

class _DotMoreSheet extends StatelessWidget {
  final List<Map<String, dynamic>> conversations;
  final bool loading;
  final VoidCallback onNewChat;
  final ValueChanged<Map<String, dynamic>> onConversationTap;
  final ValueChanged<String> onConversationDelete;

  const _DotMoreSheet({
    required this.conversations,
    required this.loading,
    required this.onNewChat,
    required this.onConversationTap,
    required this.onConversationDelete,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.74;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _DotBubbleLogo(size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Art Guide 设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '院校页左边缘右滑可唤起 Art Guide',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('新对话'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _DotSheetInfoRow(
                icon: Icons.swipe_right_alt_rounded,
                title: '唤起方式',
                subtitle: '仅屏幕左边缘滑动触发，避免和院校 / 对比 / 计划 Tab 打架。',
              ),
              const SizedBox(height: 14),
              Text(
                '最近对话',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (conversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    SupabaseService.isLoggedIn
                        ? '还没有历史对话。'
                        : '登录后会同步 Art Guide 对话记录。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.artC.ink.withValues(alpha: 0.42),
                    ),
                  ),
                )
              else
                ...conversations.take(12).map((conversation) {
                  final conversationId = conversation['id']?.toString() ?? '';
                  final title = conversation['title']?.toString().trim();
                  final preview =
                      conversation['last_message_preview']?.toString().trim();
                  final tile = Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: context.artC.porcelain,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onConversationTap(conversation),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                          child: Row(
                            children: [
                              Expanded(
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: context.artC.ink,
                                      ),
                                    ),
                                    if (preview != null &&
                                        preview.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.artC.ink
                                              .withValues(alpha: 0.42),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: '删除对话',
                                child: Material(
                                  color: const Color(0xFFE5484D)
                                      .withValues(alpha: 0.12),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: conversationId.isEmpty
                                        ? null
                                        : () => onConversationDelete(
                                              conversationId,
                                            ),
                                    child: const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: Color(0xFFE5484D),
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
                  if (conversationId.isEmpty) return tile;
                  return Dismissible(
                    key: ValueKey('dot-conversation-$conversationId'),
                    direction: DismissDirection.endToStart,
                    background: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5484D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    onDismissed: (_) => onConversationDelete(conversationId),
                    child: tile,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotSheetInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DotSheetInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCobalt.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kCobalt, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.5),
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
