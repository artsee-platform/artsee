import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/backend_api_service.dart';
import '../../services/conversation_realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../widgets/common.dart';

const _waGreen = kCobalt;
const _waHeaderBlue = Colors.white;
const _waGreenLight = kCobalt;
const _waChatBg = Color(0xFFECE5DD);
const _waMineBubble = Color(0xFFEAF1FF);
const _waOtherBubble = Colors.white;
const _waMuted = Color(0xFF667781);
const _waInk = Color(0xFF111B21);

enum LightMessagePeerKind { person, organization, group }

class LightMessagePeer {
  final String name;
  final String identityLabel;
  final LightMessagePeerKind kind;
  final String? avatarUrl;
  final String? handle;
  final String? serviceStatus;
  final String? responseTime;
  final String? peerUserId;
  final String? imIdentifier;
  final String? imGroupId;
  final String? profileActionLabel;
  final WidgetBuilder? profileBuilder;

  const LightMessagePeer({
    required this.name,
    required this.identityLabel,
    required this.kind,
    this.avatarUrl,
    this.handle,
    this.serviceStatus,
    this.responseTime,
    this.peerUserId,
    this.imIdentifier,
    this.imGroupId,
    this.profileActionLabel,
    this.profileBuilder,
  });

  factory LightMessagePeer.person({
    required String name,
    String? avatarUrl,
    String? handle,
    String identityLabel = '社区用户',
    String? peerUserId,
    String? imIdentifier,
    String? imGroupId,
    WidgetBuilder? profileBuilder,
  }) {
    return LightMessagePeer(
      name: name,
      avatarUrl: avatarUrl,
      handle: handle,
      peerUserId: peerUserId,
      imIdentifier: imIdentifier,
      imGroupId: imGroupId,
      identityLabel: identityLabel,
      kind: LightMessagePeerKind.person,
      profileActionLabel: '查看主页',
      profileBuilder: profileBuilder,
    );
  }

  factory LightMessagePeer.organization({
    required String name,
    String? avatarUrl,
    String identityLabel = '机构认证',
    String? serviceStatus,
    String? responseTime,
    String? peerUserId,
    String? imIdentifier,
    String? imGroupId,
    WidgetBuilder? profileBuilder,
  }) {
    return LightMessagePeer(
      name: name,
      avatarUrl: avatarUrl,
      identityLabel: identityLabel,
      kind: LightMessagePeerKind.organization,
      serviceStatus: serviceStatus ?? '服务中',
      responseTime: responseTime ?? '2小时内',
      peerUserId: peerUserId,
      imIdentifier: imIdentifier,
      imGroupId: imGroupId,
      profileActionLabel: '查看机构页',
      profileBuilder: profileBuilder,
    );
  }

  factory LightMessagePeer.group({
    required String name,
    String? avatarUrl,
    String? imGroupId,
  }) {
    return LightMessagePeer(
      name: name,
      avatarUrl: avatarUrl,
      identityLabel: '群聊',
      kind: LightMessagePeerKind.group,
      imGroupId: imGroupId,
      profileActionLabel: '群聊信息',
    );
  }

  factory LightMessagePeer.fromConversation(Map<String, dynamic> conversation) {
    final peerRaw = conversation['peer_profile'];
    final peer = peerRaw is Map ? Map<String, dynamic>.from(peerRaw) : null;
    final metadataRaw = conversation['metadata'];
    final Map<String, dynamic> metadata = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};
    final type = conversation['type']?.toString() ?? 'direct';
    final userType = peer?['user_type']?.toString() ??
        metadata['peer_type']?.toString() ??
        metadata['target_type']?.toString();
    final isOrg = userType == 'business' ||
        userType == 'institution' ||
        type == 'organization' ||
        type == 'cooperation' ||
        metadata['organization_name'] != null;
    final fallbackTitle = conversation['title']?.toString().trim();
    final name = peer?['nickname']?.toString().trim().isNotEmpty == true
        ? peer!['nickname'].toString().trim()
        : metadata['organization_name']?.toString().trim().isNotEmpty == true
            ? metadata['organization_name'].toString().trim()
            : fallbackTitle?.isNotEmpty == true
                ? fallbackTitle!
                : isOrg
                    ? '机构会话'
                    : 'Artsee 用户';
    final avatarUrl = peer?['avatar_url']?.toString() ??
        metadata['organization_avatar_url']?.toString() ??
        metadata['avatar_url']?.toString() ??
        metadata['logo_url']?.toString();
    final peerUserId = conversation['peer_user_id']?.toString() ??
        peer?['id']?.toString() ??
        metadata['peer_user_id']?.toString();
    final imIdentifier = conversation['peer_im_identifier']?.toString() ??
        peer?['im_identifier']?.toString() ??
        metadata['peer_im_identifier']?.toString();
    final imGroupId = conversation['tencent_im_group_id']?.toString() ??
        metadata['tencent_im_group_id']?.toString();

    if (isOrg) {
      return LightMessagePeer.organization(
        name: name,
        avatarUrl: avatarUrl,
        serviceStatus: metadata['service_status']?.toString() ?? '服务中',
        responseTime: metadata['response_time']?.toString() ?? '2小时内',
        peerUserId: peerUserId,
        imIdentifier: imIdentifier,
        imGroupId: imGroupId,
      );
    }
    if (type != 'direct') {
      return LightMessagePeer.group(
        name: name,
        avatarUrl: avatarUrl,
        imGroupId: imGroupId,
      );
    }
    return LightMessagePeer.person(
      name: name,
      avatarUrl: avatarUrl,
      handle: metadata['handle']?.toString(),
      peerUserId: peerUserId,
      imIdentifier: imIdentifier,
      identityLabel: _conversationPersonIdentity(peer, metadata),
    );
  }
}

class LightMessageScreen extends StatefulWidget {
  final Map<String, dynamic>? conversation;
  final LightMessagePeer? peer;
  final String? initialMessage;

  const LightMessageScreen({
    super.key,
    this.conversation,
    this.peer,
    this.initialMessage,
  });

  @override
  State<LightMessageScreen> createState() => _LightMessageScreenState();
}

class _LightMessageScreenState extends State<LightMessageScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = false;
  bool _sending = false;
  bool _refreshingMessages = false;
  String? _error;
  Timer? _readReceiptDebounce;
  Timer? _realtimeRecoveryTimer;
  ConversationRealtimeSubscription? _realtimeSubscription;

  String? get _conversationId => widget.conversation?['id']?.toString();

  LightMessagePeer get _peer =>
      widget.peer ??
      (widget.conversation != null
          ? LightMessagePeer.fromConversation(widget.conversation!)
          : LightMessagePeer.person(name: 'Artsee 用户'));

  @override
  void initState() {
    super.initState();
    final id = _conversationId;
    if (id != null && id.isNotEmpty) {
      _attachRealtime(id);
      unawaited(_loadMessages());
    } else {
      _messages = [
        {
          'sender_role': 'peer',
          'body': widget.initialMessage ?? '你好，可以先简单说说想沟通的内容。',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
    }
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.close());
    _readReceiptDebounce?.cancel();
    _realtimeRecoveryTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    final id = _conversationId;
    if (id == null || id.isEmpty || _refreshingMessages) return;
    _refreshingMessages = true;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result =
          await BackendApiService.fetchConversationMessages(conversationId: id);
      if (!mounted) return;
      setState(() {
        _messages = mergeConversationMessages(
          result.data.reversed,
          _messages,
        );
        if (showLoading) _loading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      } else {
        debugPrint('Supabase Realtime message catch-up failed: $e');
      }
    } finally {
      _refreshingMessages = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final id = _conversationId;
    try {
      if (id != null && id.isNotEmpty) {
        final message = await BackendApiService.sendConversationMessage(
          conversationId: id,
          body: text,
        );
        if (!mounted) return;
        _input.clear();
        setState(() {
          _messages = mergeConversationMessages(_messages, [message]);
        });
      } else {
        _input.clear();
        setState(() {
          _messages = [
            ..._messages,
            {
              'sender_id': 'local_me',
              'body': text,
              'created_at': DateTime.now().toIso8601String(),
            }
          ];
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final id = _conversationId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会话创建后可发送图片')),
      );
      return;
    }
    if (_sending) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final filename = image.name.isNotEmpty
          ? image.name
          : 'artsee-message-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _sendAttachment(
        conversationId: id,
        bytes: bytes,
        filename: filename,
        contentType: image.mimeType ?? _contentTypeForFilename(filename),
        messageType: 'image',
        folder: 'messages/images',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送图片失败：$e')),
      );
    }
  }

  Future<void> _pickAndSendFile() async {
    final id = _conversationId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会话创建后可发送文件')),
      );
      return;
    }
    if (_sending) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件内容')),
        );
        return;
      }
      const maxBytes = 50 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不能超过 50MB')),
        );
        return;
      }
      final filename = file.name.isNotEmpty
          ? file.name
          : 'artsee-file-${DateTime.now().millisecondsSinceEpoch}';
      final contentType = _contentTypeForFilename(filename);
      await _sendAttachment(
        conversationId: id,
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        messageType: contentType.startsWith('image/') ? 'image' : 'file',
        folder: contentType.startsWith('image/')
            ? 'messages/images'
            : 'messages/files',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送文件失败：$e')),
      );
    }
  }

  Future<void> _sendAttachment({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    required String messageType,
    required String folder,
  }) async {
    setState(() => _sending = true);
    try {
      final upload = await BackendApiService.uploadFile(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        folder: folder,
      );
      final url = upload['url']?.toString().trim().isNotEmpty == true
          ? upload['url'].toString().trim()
          : upload['public_url']?.toString().trim() ?? '';
      if (url.isEmpty) throw Exception('上传结果缺少文件链接');
      final message = await BackendApiService.sendConversationAttachment(
        conversationId: conversationId,
        url: url,
        messageType: messageType,
        filename: filename,
        contentType: contentType,
        size: bytes.length,
        metadata: {
          'provider': upload['provider']?.toString() ?? 'tencent_cos',
          if (upload['key'] != null) 'storage_key': upload['key'].toString(),
          if (upload['bucket'] != null) 'bucket': upload['bucket'].toString(),
          if (upload['public_url'] != null)
            'public_url': upload['public_url'].toString(),
        },
      );
      if (!mounted) return;
      setState(() {
        _messages = mergeConversationMessages(_messages, [message]);
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _attachRealtime(String conversationId) {
    _realtimeSubscription = ConversationRealtimeService.subscribeToConversation(
      conversationId: conversationId,
      onMessage: _handleRealtimeMessage,
      onStatus: (status, error) {
        if (!mounted) return;
        if (status.name == 'subscribed') {
          _realtimeRecoveryTimer?.cancel();
          unawaited(_loadMessages(showLoading: false));
          return;
        }
        if (status.name == 'channelError' || status.name == 'timedOut') {
          debugPrint('Supabase Realtime subscription issue: $error');
          _realtimeRecoveryTimer?.cancel();
          _realtimeRecoveryTimer = Timer(
            const Duration(seconds: 3),
            () => unawaited(_loadMessages(showLoading: false)),
          );
        }
      },
    );
  }

  void _handleRealtimeMessage(Map<String, dynamic> message) {
    if (!mounted || message['conversation_id']?.toString() != _conversationId) {
      return;
    }
    setState(() {
      _messages = mergeConversationMessages(_messages, [message]);
    });
    _scrollToBottom();

    // GET also advances last_read_at. Debounce the catch-up so bursts of
    // Realtime events produce one read receipt and one consistency check.
    _readReceiptDebounce?.cancel();
    _readReceiptDebounce = Timer(
      const Duration(milliseconds: 220),
      () => unawaited(_loadMessages(showLoading: false)),
    );
  }

  void _openProfile() {
    final builder = _peer.profileBuilder;
    if (builder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_peer.profileActionLabel ?? '主页'}资料同步中')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: _waHeaderBlue,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _waHeaderBlue,
        body: SafeArea(
          child: Column(
            children: [
              _LightMessageTopBar(peer: peer, onOpenProfile: _openProfile),
              Expanded(
                child: ColoredBox(
                  color: _waChatBg,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: kCobalt,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _error != null
                          ? _MessageErrorState(
                              error: _error!, onRetry: _loadMessages)
                          : ListView.builder(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(10, 12, 10, 18),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) => _MessageBubbleLite(
                                message: _messages[index],
                                peer: peer,
                              ),
                            ),
                ),
              ),
              _LightMessageInputBar(
                controller: _input,
                sending: _sending,
                onSend: _send,
                onPickImage: _pickAndSendImage,
                onPickFile: _pickAndSendFile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _messageMetadata(Map<String, dynamic> message) {
  final raw = message['metadata'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

String? _attachmentUrl(Map<String, dynamic> message) {
  final metadata = _messageMetadata(message);
  final value = message['attachment_url'] ??
      metadata['attachment_url'] ??
      metadata['asset_url'] ??
      metadata['public_url'] ??
      metadata['url'];
  final url = value?.toString().trim();
  return url == null || url.isEmpty ? null : url;
}

String? _attachmentName(Map<String, dynamic> message) {
  final metadata = _messageMetadata(message);
  final value = message['attachment_name'] ??
      message['file_name'] ??
      metadata['attachment_name'] ??
      metadata['file_name'] ??
      metadata['filename'];
  final name = value?.toString().trim();
  return name == null || name.isEmpty ? null : name;
}

Future<void> _openAttachment(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _contentTypeForFilename(String filename) {
  final ext =
      filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'md' => 'text/markdown',
    'csv' => 'text/csv',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

class _LightMessageTopBar extends StatelessWidget {
  final LightMessagePeer peer;
  final VoidCallback onOpenProfile;

  const _LightMessageTopBar({
    required this.peer,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isOrg = peer.kind == LightMessagePeerKind.organization;
    final isGroup = peer.kind == LightMessagePeerKind.group;
    final meta = [
      peer.identityLabel,
      if (!isOrg && !isGroup && peer.handle?.isNotEmpty == true) peer.handle!,
      if (isOrg && peer.responseTime?.isNotEmpty == true) peer.responseTime!,
    ].join(' · ');
    return Container(
      color: _waHeaderBlue,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 7),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _waInk,
            onPressed: () => Navigator.of(context).pop(),
          ),
          _PeerAvatar(peer: peer, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _waInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _waMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: peer.profileActionLabel ?? '查看主页',
            onPressed: onOpenProfile,
            icon: Icon(
              isOrg
                  ? Icons.storefront_outlined
                  : isGroup
                      ? Icons.group_outlined
                      : Icons.person_outline_rounded,
              size: 20,
              color: _waInk.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final LightMessagePeer peer;
  final double size;

  const _PeerAvatar({required this.peer, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = peer.avatarUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        size / 2,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _PeerAvatarFallback(peer: peer),
              )
            : _PeerAvatarFallback(peer: peer),
      ),
    );
  }
}

class _PeerAvatarFallback extends StatelessWidget {
  final LightMessagePeer peer;

  const _PeerAvatarFallback({required this.peer});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _waGreenLight,
      child: Center(
        child: Text(
          peer.name.isEmpty ? '艺' : peer.name.characters.first,
          style: TextStyle(
            color: Colors.white,
            fontSize: peer.kind == LightMessagePeerKind.organization ? 15 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MessageBubbleLite extends StatelessWidget {
  final Map<String, dynamic> message;
  final LightMessagePeer peer;

  const _MessageBubbleLite({required this.message, required this.peer});

  @override
  Widget build(BuildContext context) {
    final mine = _isMine(message);
    final body = message['body']?.toString() ?? '';
    final type = message['message_type']?.toString() ?? 'text';
    final attachmentUrl = _attachmentUrl(message);
    if (body.isEmpty && attachmentUrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            _PeerAvatar(peer: peer, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mine ? _waMineBubble : _waOtherBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(mine ? 12 : 3),
                  bottomRight: Radius.circular(mine ? 3 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _MessageBubbleContent(
                message: message,
                type: type,
                body: body,
                attachmentUrl: attachmentUrl,
                mine: mine,
              ),
            ),
          ),
          if (mine) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _MessageBubbleContent extends StatelessWidget {
  final Map<String, dynamic> message;
  final String type;
  final String body;
  final String? attachmentUrl;
  final bool mine;

  const _MessageBubbleContent({
    required this.message,
    required this.type,
    required this.body,
    required this.attachmentUrl,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = _waInk;
    final url = attachmentUrl;
    if (type == 'image' && url != null) {
      return InkWell(
        onTap: () {
          _openAttachment(url);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 220,
              maxHeight: 260,
              minWidth: 120,
              minHeight: 80,
            ),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _AttachmentFallback(
                icon: Icons.broken_image_outlined,
                label: '图片加载失败',
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    if (type == 'file' && url != null) {
      final name =
          _attachmentName(message) ?? body.replaceFirst('[文件]', '').trim();
      return InkWell(
        onTap: () {
          _openAttachment(url);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 22,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name.isEmpty ? '文件' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      body,
      style: const TextStyle(
        color: textColor,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AttachmentFallback({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 120,
      color: color.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightMessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  const _LightMessageInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _waChatBg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _InputIconButton(
              tooltip: '发送图片',
              icon: Icons.image_outlined,
              disabled: sending,
              onPressed: onPickImage,
            ),
            const SizedBox(width: 6),
            _InputIconButton(
              tooltip: '发送文件',
              icon: Icons.attach_file_rounded,
              disabled: sending,
              onPressed: onPickFile,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: '写一条消息...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: _waMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: const TextStyle(
                    color: _waInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filled(
                tooltip: '发送',
                style: IconButton.styleFrom(
                  backgroundColor:
                      sending ? _waGreen.withValues(alpha: 0.45) : _waGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;

  const _InputIconButton({
    required this.tooltip,
    required this.icon,
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: disabled ? null : onPressed,
        icon: Icon(
          icon,
          size: 20,
          color: disabled
              ? _waMuted.withValues(alpha: 0.35)
              : kCobalt.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _MessageErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _MessageErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                color: context.artC.ink.withValues(alpha: 0.25), size: 36),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

bool _isMine(Map<String, dynamic> message) {
  final currentUserId = SupabaseService.currentUser?.id;
  final senderId = message['sender_id']?.toString();
  final role = message['sender_role']?.toString();
  return senderId == 'local_me' ||
      (currentUserId != null && senderId == currentUserId) ||
      role == 'me' ||
      role == 'user';
}

String _conversationPersonIdentity(
  Map<String, dynamic>? peer,
  Map<String, dynamic> metadata,
) {
  final role = peer?['user_role']?.toString() ??
      metadata['user_role']?.toString() ??
      metadata['peer_role']?.toString();
  return switch (role) {
    'artist' => '认证艺术家',
    'mentor' => '导师',
    'student' => '学生',
    _ => metadata['identity_label']?.toString() ?? '用户',
  };
}
