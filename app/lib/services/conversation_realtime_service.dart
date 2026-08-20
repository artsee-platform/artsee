import 'package:supabase_flutter/supabase_flutter.dart';

typedef ConversationRealtimeStatusCallback = void Function(
  RealtimeSubscribeStatus status,
  Object? error,
);

class ConversationRealtimeSubscription {
  ConversationRealtimeSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _client.removeChannel(_channel);
  }
}

class ConversationRealtimeService {
  ConversationRealtimeService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static ConversationRealtimeSubscription subscribeToConversation({
    required String conversationId,
    required void Function(Map<String, dynamic> message) onMessage,
    ConversationRealtimeStatusCallback? onStatus,
  }) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    );
    final channel = _client.channel('conversation:$conversationId:messages');

    void emit(PostgresChangePayload payload) {
      if (payload.newRecord.isEmpty) return;
      final message = Map<String, dynamic>.from(payload.newRecord);
      if (message['conversation_id']?.toString() != conversationId) return;
      onMessage(message);
    }

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: filter,
        callback: emit,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: filter,
        callback: emit,
      )
      ..subscribe(onStatus);

    return ConversationRealtimeSubscription(_client, channel);
  }

  static ConversationRealtimeSubscription subscribeToInbox({
    required String userId,
    required void Function() onChanged,
    ConversationRealtimeStatusCallback? onStatus,
  }) {
    final channel = _client.channel('user:$userId:inbox');
    final ownParticipantFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );

    void changed(PostgresChangePayload _) => onChanged();

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: changed,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: changed,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'conversation_participants',
        filter: ownParticipantFilter,
        callback: changed,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversation_participants',
        filter: ownParticipantFilter,
        callback: changed,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'conversations',
        callback: changed,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: changed,
      )
      ..subscribe(onStatus);

    return ConversationRealtimeSubscription(_client, channel);
  }
}

List<Map<String, dynamic>> mergeConversationMessages(
  Iterable<Map<String, dynamic>> existing,
  Iterable<Map<String, dynamic>> incoming,
) {
  final merged = <Map<String, dynamic>>[];
  final indexById = <String, int>{};

  void add(Map<String, dynamic> source) {
    final message = Map<String, dynamic>.from(source);
    final id = message['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final index = indexById[id];
      if (index != null) {
        merged[index] = message;
        return;
      }
      indexById[id] = merged.length;
    }
    merged.add(message);
  }

  existing.forEach(add);
  incoming.forEach(add);
  merged.sort((left, right) {
    final leftTime = DateTime.tryParse(left['created_at']?.toString() ?? '');
    final rightTime = DateTime.tryParse(right['created_at']?.toString() ?? '');
    final byTime = (leftTime?.millisecondsSinceEpoch ?? 0)
        .compareTo(rightTime?.millisecondsSinceEpoch ?? 0);
    if (byTime != 0) return byTime;
    return (left['id']?.toString() ?? '')
        .compareTo(right['id']?.toString() ?? '');
  });
  return merged;
}
