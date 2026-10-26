// Audit Communauté du 2026-10-26 (P1) : publier, créer un groupe, commenter,
// rejoindre ou quitter un groupe échouaient sans aucun message, et le
// commentaire pouvait partir en double.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets('publication refusée : message dans la feuille, texte conservé', (tester) async {
    final repo = FakeCommunityRepository()..failWith = StateError('refus RLS');
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Ma nouvelle');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Publier'));
    await tester.pumpAndSettle();

    expect(repo.createdPosts, ['Ma nouvelle']);
    expect(find.text("La publication n'a pas pu être envoyée. Réessayez."), findsOneWidget);
    expect(find.text('Ma nouvelle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('publication hors ligne : message de connexion', (tester) async {
    final repo = FakeCommunityRepository()..failWith = const SocketException('Failed host lookup');
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Ma nouvelle');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Publier'));
    await tester.pumpAndSettle();

    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);
  });

  testWidgets('création de groupe refusée : message dans la feuille, en arabe', (tester) async {
    final groups = FakeGroupsRepository()..failWith = StateError('refus');
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      groups: groups,
      locale: const Locale('ar'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المجموعات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Groupe');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(groups.calls, ['create:Groupe']);
    expect(find.text('تعذّر إنشاء المجموعة. حاول مرة أخرى.'), findsOneWidget);
  });

  testWidgets("commentaire : un second appui pendant l'envoi n'en publie pas deux", (tester) async {
    final gate = Completer<void>();
    final repo = FakeCommunityRepository()..gate = gate.future;
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost()), community: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Amine');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(repo.addedComments, ['Amine']);
  });

  testWidgets('commentaire refusé : message et texte rendu au champ', (tester) async {
    final repo = FakeCommunityRepository()..failWith = StateError('refus');
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost()), community: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Amine');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.text("Le commentaire n'a pas pu être envoyé. Réessayez."), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Amine');
  });

  testWidgets('rejoindre un groupe : échec annoncé, toujours non membre', (tester) async {
    final groups = FakeGroupsRepository()..failWith = StateError('refus');
    await tester.pumpWidget(wrapCommunaute(GroupDetailScreen(group: testGroup()), groups: groups));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejoindre le groupe'));
    await tester.pumpAndSettle();

    expect(groups.calls, ['join:g1']);
    expect(find.text('Impossible de rejoindre ce groupe. Réessayez.'), findsOneWidget);
    expect(find.text('Rejoindre le groupe'), findsOneWidget);
  });

  testWidgets('quitter un groupe hors ligne : message de connexion', (tester) async {
    final groups = FakeGroupsRepository()..failWith = const SocketException('Network is unreachable');
    await tester.pumpWidget(wrapCommunaute(
      GroupDetailScreen(group: testGroup(isMember: true)),
      groups: groups,
      extraOverrides: groupMemberOverrides,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quitter le groupe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
    await tester.pumpAndSettle();

    expect(groups.calls, ['leave:g1']);
    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);
    expect(find.text('Quitter le groupe'), findsOneWidget);
  });
}
