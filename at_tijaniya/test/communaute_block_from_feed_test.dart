// Audit Communauté du 2026-10-26 (P2-6) : bloquer un disciple depuis sa
// publication ou son commentaire, sans devoir le retrouver dans un groupe
// commun ou une conversation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';
import 'package:at_tijaniya/features/moderation/data/blocks_repository.dart';
import 'package:at_tijaniya/features/moderation/presentation/block_user.dart';

import 'communaute_test_helpers.dart';

class _FakeBlocksRepository extends BlocksRepository {
  final blocked = <String>[];

  @override
  Future<void> blockUser(String userId) async => blocked.add(userId);
}

Future<void> _blockVia(WidgetTester tester, Finder menu) async {
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bloquer ce disciple'));
  await tester.pumpAndSettle();
  // Confirmation : bouton du dialogue.
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Bloquer ce disciple')));
  await tester.pumpAndSettle();
}

void main() {
  final comment = CommunityComment(
    id: 'c1',
    userId: 'commentateur',
    authorDisplayName: 'Commentateur',
    contentText: 'Un commentaire',
    createdAt: DateTime(2026, 10, 26, 11),
  );

  testWidgets("bloquer l'auteur d'une publication depuis son menu, puis quitter l'écran", (tester) async {
    final blocks = _FakeBlocksRepository();
    await tester.pumpWidget(wrapCommunaute(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: testPost()))),
            child: const Text('ouvrir'),
          ),
        ),
      ),
      extraOverrides: [blocksRepositoryProvider.overrideWithValue(blocks)],
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await _blockVia(tester, find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));

    expect(blocks.blocked, ['other']);
    expect(find.byType(PostDetailScreen), findsNothing);
  });

  testWidgets("bloquer l'auteur d'un commentaire depuis son menu", (tester) async {
    final blocks = _FakeBlocksRepository();
    await tester.pumpWidget(wrapCommunaute(
      PostDetailScreen(post: testPost()),
      community: FakeCommunityRepository(comments: [comment]),
      extraOverrides: [blocksRepositoryProvider.overrideWithValue(blocks)],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    await _blockVia(tester, find.descendant(of: find.byType(ListView), matching: find.byType(PopupMenuButton<String>)));

    expect(blocks.blocked, ['commentateur']);
  });

  testWidgets('publication sans auteur (compte supprimé) : signalement seul', (tester) async {
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost(authorUserId: null, authorDisplayName: null))));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    expect(find.text('Signaler'), findsOneWidget);
    expect(find.text('Bloquer ce disciple'), findsNothing);
  });
}
