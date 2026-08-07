import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/message_models.dart';

void main() {
  group('DirectMessage.fromRow', () {
    test('parse une ligne de message', () {
      final message = DirectMessage.fromRow({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content_text': 'Salam, comment vas-tu ?',
        'sent_at': '2026-08-07T09:00:00.000Z',
      });
      expect(message.id, 'm1');
      expect(message.conversationId, 'c1');
      expect(message.senderId, 'u1');
      expect(message.contentText, 'Salam, comment vas-tu ?');
    });
  });

  group('Conversation', () {
    test('expose les champs transmis au constructeur', () {
      final conversation = Conversation(
        id: 'c1',
        otherUserId: 'u2',
        otherDisplayName: 'Fatou',
        lastMessageText: 'À bientôt',
        lastMessageAt: DateTime(2026, 8, 7, 10),
      );
      expect(conversation.otherDisplayName, 'Fatou');
      expect(conversation.lastMessageText, 'À bientôt');
    });

    test('accepte des champs optionnels nuls (conversation sans message)', () {
      const conversation = Conversation(id: 'c2', otherUserId: 'u3');
      expect(conversation.otherDisplayName, isNull);
      expect(conversation.lastMessageText, isNull);
      expect(conversation.lastMessageAt, isNull);
    });
  });
}
