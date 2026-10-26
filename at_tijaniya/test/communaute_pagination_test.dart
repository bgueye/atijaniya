// Audit Communauté du 2026-10-26 (P2-9) : fil chargé par pages de 20 avec
// « Voir plus », discussion de groupe par tranches de 50, aperçus de
// conversation servis par le serveur.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets('fil : une page de 20, puis « Voir plus » charge la suivante', (tester) async {
    final repo = FakeCommunityRepository(posts: [for (var i = 0; i < 25; i++) testPost(id: 'p$i', contentText: 'Publication $i')]);
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();
    expect(repo.feedLimits, [20]);

    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Voir plus de publications'), 500, scrollable: list);
    await tester.tap(find.text('Voir plus de publications'));
    await tester.pumpAndSettle();

    expect(repo.feedLimits, [20, 40]);
    await tester.scrollUntilVisible(find.text('Publication 24'), 500, scrollable: list);
    expect(find.text('Voir plus de publications'), findsNothing);
  });

  testWidgets('fil incomplet : pas de « Voir plus »', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      community: FakeCommunityRepository(posts: [testPost()]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Voir plus de publications'), findsNothing);
  });

  testWidgets('discussion de groupe : 50 derniers messages, puis les précédents', (tester) async {
    final posts = [
      for (var i = 0; i < 60; i++)
        GroupPost(id: 'm$i', groupId: 'g1', authorUserId: 'other', contentText: 'Message $i', createdAt: DateTime(2026, 10, 1, 0, i)),
    ];
    await tester.pumpWidget(wrapCommunaute(
      GroupDetailScreen(group: testGroup(isMember: true)),
      groups: FakeGroupsRepository(posts: posts),
      extraOverrides: groupMemberOverrides,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Message 59'), findsOneWidget);

    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Messages précédents'), 500, scrollable: list);
    expect(find.text('Message 9'), findsNothing);
    await tester.tap(find.text('Messages précédents'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Message 0'), 500, scrollable: list);
    expect(find.text('Messages précédents'), findsNothing);
  });

  test("aperçu de conversation : ligne de conversation_previews", () {
    final conversation = Conversation.fromPreviewRow({
      'conversation_id': 'c1',
      'other_user_id': 'u2',
      'other_display_name': 'Disciple',
      'last_message_text': 'Salam',
      'last_message_at': '2026-10-26T10:00:00+00:00',
    });
    expect(conversation.id, 'c1');
    expect(conversation.otherUserId, 'u2');
    expect(conversation.lastMessageText, 'Salam');
    expect(conversation.lastMessageAt, DateTime.utc(2026, 10, 26, 10).toLocal());

    final empty = Conversation.fromPreviewRow({
      'conversation_id': 'c2',
      'other_user_id': 'u3',
      'other_display_name': null,
      'last_message_text': null,
      'last_message_at': null,
    });
    expect(empty.lastMessageAt, isNull);
  });
}
