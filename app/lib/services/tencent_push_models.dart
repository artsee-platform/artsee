import 'dart:convert';

/// A normalized notification click from Tencent Push.
///
/// Artsee writes `action` and `conversation_id` into OfflinePushInfo.Ext. The
/// parser also accepts the camelCase spelling used by some Tencent examples so
/// a console-side template change does not silently break navigation.
class TencentPushNotificationClick {
  final String rawExt;
  final String? action;
  final String? conversationId;
  final String? userId;
  final String? groupId;

  const TencentPushNotificationClick({
    required this.rawExt,
    this.action,
    this.conversationId,
    this.userId,
    this.groupId,
  });

  bool get opensConversation =>
      action == 'open_chat' && conversationId?.isNotEmpty == true;

  factory TencentPushNotificationClick.fromExt(
    String ext, {
    String? userId,
    String? groupId,
  }) {
    Map<String, dynamic> payload = const {};
    try {
      final decoded = jsonDecode(ext);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Keep the raw payload so unsupported notification types can be logged
      // and ignored without crashing the app during a cold start.
    }

    final nested = <Map<String, dynamic>>[payload];
    for (final key in const ['data', 'custom', 'payload']) {
      final value = payload[key];
      if (value is Map) nested.add(Map<String, dynamic>.from(value));
    }

    String? read(List<String> keys) {
      for (final map in nested) {
        for (final key in keys) {
          final value = map[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
      return null;
    }

    return TencentPushNotificationClick(
      rawExt: ext,
      action: read(const ['action']),
      conversationId: read(
        const ['conversation_id', 'conversationID', 'conversationId'],
      ),
      userId: read(const ['user_id', 'userID', 'userId']) ?? userId,
      groupId: read(const ['group_id', 'groupID', 'groupId']) ?? groupId,
    );
  }
}

class TencentPushActionResult {
  final bool consentEnabled;
  final bool supported;
  final bool configured;
  final bool registered;
  final bool permissionGranted;
  final String message;
  final String? registrationId;
  final int? code;

  const TencentPushActionResult({
    required this.consentEnabled,
    required this.supported,
    required this.configured,
    required this.registered,
    required this.permissionGranted,
    required this.message,
    this.registrationId,
    this.code,
  });
}
