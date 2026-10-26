// Audit Communauté du 2026-10-26 (P3-8) : conversations non lues signalées
// (pastille sur l'icône de la messagerie et dans la liste), marquées lues à
// l'ouverture, et notifications « nouveau message » / « nouveau commentaire »
// reconnues par l'app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversation_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversations_screen.dart';
import 'package:at_tijaniya/features/notifications/domain/app_notification.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_providers.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_screen.dart';

import 'communaute_test_helpers.dart';

const _conversations = [
  Conversation(id: 'c1', otherUserId: 'u1', otherDisplayName: 'Aïssatou', lastMessageText: 'Salam', unreadCount: 3),
  Conversation(id: 'c2', otherUserId: 'u2', otherDisplayName: 'Moussa', lastMessageText: 'Merci', unreadCount: 1),
  Conversation(id: 'c3', otherUserId: 'u3', otherDisplayName: 'Ibrahima', lastMessageText: 'Ok'),
];

void main() {
  testWidgets("icône de la messagerie : pastille avec le nombre de conversations non lues", (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      messages: FakeMessagesRepository(conversations: _conversations),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Messages, 2 conversations non lues'), findsOneWidget);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
  });

  testWidgets('liste des conversations : nombre de messages non lus, nom en gras', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapCommunaute(
      const ConversationsScreen(),
      messages: FakeMessagesRepository(conversations: _conversations),
    ));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
    // Annoncé avec le reste de la ligne (le ListTile fusionne ses libellés).
    expect(find.bySemanticsLabel(RegExp('3 messages non lus')), findsOneWidget);
    expect(tester.widget<Text>(find.text('Aïssatou')).style?.fontWeight, FontWeight.w700);
    expect(tester.widget<Text>(find.text('Ibrahima')).style?.fontWeight, isNot(FontWeight.w700));
    semantics.dispose();
  });

  testWidgets("ouvrir une conversation marque lus les messages reçus", (tester) async {
    final repo = FakeMessagesRepository(messages: [
      DirectMessage(id: 'm1', conversationId: 'c1', senderId: 'u1', contentText: 'Salam', sentAt: DateTime(2026, 10, 26)),
    ]);
    await tester.pumpWidget(wrapCommunaute(
      const ConversationScreen(conversationId: 'c1', otherUserId: 'u1', otherDisplayName: 'Aïssatou'),
      messages: repo,
    ));
    await tester.pumpAndSettle();
    expect(repo.markedRead, ['c1']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('notifications : « nouveau message » et « nouveau commentaire » affichés', (tester) async {
    final notifications = [
      AppNotification.fromRow({
        'id': 'n1',
        'type': 'direct_message',
        'payload': {'conversation_id': 'c1'},
        'read_at': null,
        'created_at': '2026-10-26T10:00:00Z',
      }),
      AppNotification.fromRow({
        'id': 'n2',
        'type': 'post_comment',
        'payload': {'post_id': 'p1'},
        'read_at': null,
        'created_at': '2026-10-26T09:00:00Z',
      }),
    ];
    expect(notifications.map((n) => n.type), [AppNotificationType.directMessage, AppNotificationType.postComment]);
    expect(notifications.first.conversationId, 'c1');
    expect(notifications.last.postId, 'p1');

    await tester.pumpWidget(wrapCommunaute(
      const NotificationsScreen(),
      extraOverrides: [myNotificationsProvider.overrideWith((ref) => Stream.value(notifications))],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau message'), findsOneWidget);
    expect(find.text('Nouveau commentaire'), findsOneWidget);
  });
}
