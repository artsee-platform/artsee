import 'package:flutter/material.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? avatarUrl;
  final IconData? avatarIcon;
  final Color? avatarColor;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.avatarUrl,
    this.avatarIcon,
    this.avatarColor,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    // 模拟加载历史消息
    setState(() {
      _messages.addAll([
        ChatMessage(
          id: '1',
          content: '你好！我想咨询一下关于作品集的问题。',
          isMine: true,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        ChatMessage(
          id: '2',
          content: '你好！很高兴为你解答。请问你想申请哪个学校和专业？',
          isMine: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 1)),
        ),
        ChatMessage(
          id: '3',
          content: '我想申请 RCA 的工业设计硕士。',
          isMine: true,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        ),
        ChatMessage(
          id: '4',
          content:
              'RCA 的工业设计非常优秀！作品集建议包含 3-5 个项目，展示你的设计思维、调研能力和实践技能。每个项目最好有完整的设计流程展示。',
          isMine: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 48)),
        ),
      ]);
    });
    _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isMine: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });

    _scrollToBottom();

    // 模拟发送延迟
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _sending = false;
    });

    // 模拟对方回复
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: '收到！我会尽快回复你的。',
          isMine: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
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
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: context.artC.ink),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  showAvatar: !message.isMine,
                  avatar: message.isMine ? null : _buildAvatar(size: 32),
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
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: context.artC.ink.withAlpha(150)),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
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
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _sending
                    ? context.artC.ink.withAlpha(50)
                    : kCobalt,
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
        ],
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isMine;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isMine,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  final Widget? avatar;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    this.avatar,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMine
                        ? kCobalt
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      topRight: message.isMine
                          ? const Radius.circular(4)
                          : null,
                      topLeft: message.isMine
                          ? null
                          : const Radius.circular(4),
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
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: message.isMine
                          ? Colors.white
                          : context.artC.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
