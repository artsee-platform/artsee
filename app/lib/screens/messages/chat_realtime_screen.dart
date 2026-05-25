import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/message_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ChatRealtimeScreen extends StatefulWidget {
  final String conversationId;
  final String chatName;
  final String? avatarUrl;
  final IconData? avatarIcon;
  final Color? avatarColor;

  const ChatRealtimeScreen({
    super.key,
    required this.conversationId,
    required this.chatName,
    this.avatarUrl,
    this.avatarIcon,
    this.avatarColor,
  });

  @override
  State<ChatRealtimeScreen> createState() => _ChatRealtimeScreenState();
}

class _ChatRealtimeScreenState extends State<ChatRealtimeScreen> {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();

  List<Message> _messages = [];
  List<String> _typingUsers = [];
  bool _sending = false;
  bool _loading = true;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _typingTimer;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _subscribeToTyping();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _messageService.unsubscribe(widget.conversationId);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _messageService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _loading = false;
        });
        _scrollToBottom();
        _messageService.markAsRead(widget.conversationId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载消息失败: $e')),
        );
      }
    }
  }

  void _subscribeToMessages() {
    _messageSubscription =
        _messageService.subscribeToMessages(widget.conversationId).listen(
      (message) {
        if (mounted) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
          if (!message.isMine) {
            _messageService.markAsRead(widget.conversationId);
          }
        }
      },
    );
  }

  void _subscribeToTyping() {
    _typingSubscription = _messageService
        .subscribeToTypingIndicators(widget.conversationId)
        .listen(
      (typingUserIds) {
        if (mounted) {
          setState(() {
            _typingUsers = typingUserIds;
          });
        }
      },
    );
  }

  void _onTextChanged() {
    if (_messageController.text.trim().isNotEmpty) {
      _messageService.setTyping(widget.conversationId, true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _messageService.setTyping(widget.conversationId, false);
      });
    } else {
      _messageService.setTyping(widget.conversationId, false);
      _typingTimer?.cancel();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messageController.clear();
    });

    _messageService.setTyping(widget.conversationId, false);

    try {
      await _messageService.sendTextMessage(widget.conversationId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _sending = true);

      final imageFile = File(image.path);
      await _messageService.sendImageMessage(widget.conversationId, imageFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送图片失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限')),
        );
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        setState(() => _sending = true);

        // 计算录音时长（简化版，实际应该在录音时计时）
        const duration = 5; // 秒

        final audioFile = File(path);
        await _messageService.sendVoiceMessage(
            widget.conversationId, audioFile, duration);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送语音失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: context.artC.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _buildAvatar(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink,
                    ),
                  ),
                  if (_typingUsers.isNotEmpty)
                    const Text(
                      '正在输入...',
                      style: TextStyle(
                        fontSize: 12,
                        color: kCobalt,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      '在线',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.artC.ink.withAlpha(100),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kCobalt))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(
                        message: message,
                        showAvatar: !message.isMine,
                        avatar: message.isMine ? null : _buildAvatar(size: 32),
                        onPlayVoice: (url) => _playVoice(url),
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    if (widget.avatarUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(widget.avatarUrl!),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.avatarColor ?? kCobalt,
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.avatarIcon ?? Icons.person,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.artC.silver.withAlpha(100)),
        ),
      ),
      child: Row(
        children: [
          if (!_isRecording) ...[
            IconButton(
              icon: Icon(Icons.image_outlined,
                  color: context.artC.ink.withAlpha(150)),
              onPressed: _sending ? null : _pickAndSendImage,
            ),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.artC.porcelain,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTextMessage(),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.artC.ink.withAlpha(100),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(fontSize: 14, color: context.artC.ink),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_messageController.text.trim().isEmpty)
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kCobalt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, size: 20, color: Colors.white),
                ),
              )
            else
              GestureDetector(
                onTap: _sending ? null : _sendTextMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _sending ? context.artC.ink.withAlpha(50) : kCobalt,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 20, color: Colors.white),
                ),
              ),
          ] else ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '正在录音...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '松开发送',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
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

  Future<void> _playVoice(String url) async {
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final Widget? avatar;
  final Function(String) onPlayVoice;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    this.avatar,
    required this.onPlayVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isMine && showAvatar) ...[
            avatar ?? const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(context),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.artC.ink.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
          if (message.isMine && showAvatar) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.messageType) {
      case 'image':
        return _buildImageMessage(context);
      case 'voice':
        return _buildVoiceMessage(context);
      default:
        return _buildTextMessage(context);
    }
  }

  Widget _buildTextMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.isMine ? kCobalt : Colors.white,
        borderRadius: BorderRadius.circular(18).copyWith(
          topRight: message.isMine ? const Radius.circular(4) : null,
          topLeft: message.isMine ? null : const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.content ?? '',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: message.isMine ? Colors.white : context.artC.ink,
        ),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          message.mediaUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 200,
            color: context.artC.porcelain,
            child: const Icon(Icons.broken_image, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceMessage(BuildContext context) {
    return GestureDetector(
      onTap: () => onPlayVoice(message.mediaUrl!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isMine ? kCobalt : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: context.artC.ink.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: message.isMine ? Colors.white : kCobalt,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '${message.mediaDuration ?? 0}"',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: message.isMine ? Colors.white : context.artC.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
