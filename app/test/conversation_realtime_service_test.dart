import 'package:artsee_app/services/conversation_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Realtime message reconciliation replaces duplicates and sorts rows',
      () {
    final merged = mergeConversationMessages(
      [
        {
          'id': 'message-2',
          'body': 'pending',
          'created_at': '2026-08-17T10:02:00.000Z',
        },
      ],
      [
        {
          'id': 'message-1',
          'body': 'first',
          'created_at': '2026-08-17T10:01:00.000Z',
        },
        {
          'id': 'message-2',
          'body': 'persisted',
          'created_at': '2026-08-17T10:02:00.000Z',
        },
      ],
    );

    expect(merged.map((message) => message['id']), [
      'message-1',
      'message-2',
    ]);
    expect(merged.last['body'], 'persisted');
  });
}
