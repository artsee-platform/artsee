import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};

  /// 获取用户的所有会话
  Future<List<Conversation>> getConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    final response = await _supabase
        .from('conversations')
        .select('''
          *,
          conversation_participants!inner(user_id, last_read_at),
          messages(id, content, message_type, created_at, sender_id)
        ''')
        .eq('conversation_participants.user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List)
        .map((json) => Conversation.fromJson(json))
        .toList();
  }

  /// 获取会话的消息列表
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) async {
    final response = await _supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => Message.fromJson(json)).toList();
  }

  /// 发送文本消息
  Future<Message> sendTextMessage(String conversationId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    final response = await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
      'message_type': 'text',
    }).select().single();

    // 更新会话的 updated_at
    await _supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return Message.fromJson(response);
  }

  /// 发送图片消息
  Future<Message> sendImageMessage(
      String conversationId, File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    // 上传图片到 Supabase Storage
    final fileName =
        'messages/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    await _supabase.storage.from('chat-media').upload(fileName, imageFile);

    // 获取公开 URL
    final imageUrl =
        _supabase.storage.from('chat-media').getPublicUrl(fileName);

    final response = await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message_type': 'image',
      'media_url': imageUrl,
    }).select().single();

    await _supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return Message.fromJson(response);
  }

  /// 发送语音消息
  Future<Message> sendVoiceMessage(
      String conversationId, File audioFile, int durationSeconds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    // 上传语音到 Supabase Storage
    final fileName =
        'messages/voice/${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _supabase.storage.from('chat-media').upload(fileName, audioFile);

    final audioUrl =
        _supabase.storage.from('chat-media').getPublicUrl(fileName);

    final response = await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message_type': 'voice',
      'media_url': audioUrl,
      'media_duration': durationSeconds,
    }).select().single();

    await _supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return Message.fromJson(response);
  }

  /// 订阅会话的实时消息
  Stream<Message> subscribeToMessages(String conversationId) {
    final controller = StreamController<Message>();

    final channel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            controller.add(message);
          },
        )
        .subscribe();

    _channels[conversationId] = channel;

    return controller.stream;
  }

  /// 设置输入状态
  Future<void> setTyping(String conversationId, bool isTyping) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (isTyping) {
      await _supabase.from('typing_indicators').upsert({
        'conversation_id': conversationId,
        'user_id': userId,
        'started_at': DateTime.now().toIso8601String(),
      });
    } else {
      await _supabase
          .from('typing_indicators')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    }
  }

  /// 订阅输入状态
  Stream<List<String>> subscribeToTypingIndicators(String conversationId) {
    final controller = StreamController<List<String>>();
    final userId = _supabase.auth.currentUser?.id;

    final channel = _supabase
        .channel('typing:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            // 获取当前所有正在输入的用户
            final response = await _supabase
                .from('typing_indicators')
                .select('user_id')
                .eq('conversation_id', conversationId)
                .neq('user_id', userId ?? '');

            final typingUserIds = (response as List)
                .map((e) => e['user_id'] as String)
                .toList();

            controller.add(typingUserIds);
          },
        )
        .subscribe();

    _channels['typing:$conversationId'] = channel;

    return controller.stream;
  }

  /// 标记消息为已读
  Future<void> markAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('conversation_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  /// 取消订阅
  Future<void> unsubscribe(String conversationId) async {
    final channel = _channels.remove(conversationId);
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }

    final typingChannel = _channels.remove('typing:$conversationId');
    if (typingChannel != null) {
      await _supabase.removeChannel(typingChannel);
    }
  }

  /// 清理所有订阅
  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await _supabase.removeChannel(channel);
    }
    _channels.clear();
  }
}

// 数据模型
class Conversation {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Message? lastMessage;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'] as List?;
    return Conversation(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: messages != null && messages.isNotEmpty
          ? Message.fromJson(messages.first)
          : null,
      unreadCount: 0, // TODO: 计算未读数
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String? senderId;
  final String? content;
  final String messageType;
  final String? mediaUrl;
  final int? mediaDuration;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    this.senderId,
    this.content,
    required this.messageType,
    this.mediaUrl,
    this.mediaDuration,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      content: json['content'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      mediaDuration: json['media_duration'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isMine {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return senderId == currentUserId;
  }
}
