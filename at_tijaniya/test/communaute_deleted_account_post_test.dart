// Audit Communauté du 2026-10-26 (P2-3) : une publication dont le compte a été
// supprimé ne s'affiche plus au nom de la zawiya seule, et l'admin peut la
// retirer — elle seule.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  final orphan = testPost(authorUserId: null, authorDisplayName: null);

  testWidgets('fil : « Compte supprimé · zawiya », jamais la zawiya seule', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      community: FakeCommunityRepository(posts: [orphan]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Compte supprimé · Zawiya de test'), findsOneWidget);
    expect(find.text('Zawiya de test'), findsNothing);
  });

  testWidgets('en arabe : libellé traduit', (tester) async {
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: orphan), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('حساب محذوف · Zawiya de test'), findsOneWidget);
  });

  testWidgets("l'admin a « Supprimer » sur une publication sans auteur", (tester) async {
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: orphan), isAdmin: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Supprimer'), findsOneWidget);
  });

  testWidgets("l'admin n'a pas « Supprimer » sur la publication d'un autre disciple", (tester) async {
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost()), isAdmin: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Supprimer'), findsNothing);
  });

  testWidgets("un disciple n'a pas « Supprimer » sur une publication sans auteur", (tester) async {
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: orphan)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Supprimer'), findsNothing);
  });
}
