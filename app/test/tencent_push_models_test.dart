import 'package:artsee_app/services/tencent_push_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TencentPushNotificationClick', () {
    test('parses the BFF OfflinePushInfo ext contract', () {
      final click = TencentPushNotificationClick.fromExt(
        '{"action":"open_chat","conversation_id":"conversation-1"}',
      );

      expect(click.action, 'open_chat');
      expect(click.conversationId, 'conversation-1');
      expect(click.opensConversation, isTrue);
    });

    test('accepts Tencent example camelCase fields and callback identifiers',
        () {
      final click = TencentPushNotificationClick.fromExt(
        '{"action":"open_chat","conversationID":"conversation-2"}',
        userId: 'im-user-1',
        groupId: 'im-group-1',
      );

      expect(click.conversationId, 'conversation-2');
      expect(click.userId, 'im-user-1');
      expect(click.groupId, 'im-group-1');
    });

    test('does not crash or navigate for malformed ext', () {
      final click = TencentPushNotificationClick.fromExt('not-json');

      expect(click.rawExt, 'not-json');
      expect(click.opensConversation, isFalse);
    });

    test('reads payload nested by a console template', () {
      final click = TencentPushNotificationClick.fromExt(
        '{"payload":{"action":"open_chat","conversationId":"nested"}}',
      );

      expect(click.conversationId, 'nested');
      expect(click.opensConversation, isTrue);
    });
  });
}
