// Audit Communauté du 2026-10-26 (P3-3) : hors ligne distingué, « Réessayer »
// partout, tirer pour actualiser, états vides qui disent comment commencer.

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversations_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/messages_providers.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets('fil hors ligne : message de connexion, puis « Réessayer » recharge', (tester) async {
    final repo = FakeCommunityRepository(posts: [testPost()])..feedError = const SocketException('Failed host lookup');
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();
    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);

    repo.feedError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Salam à tous'), findsOneWidget);
  });

  testWidgets('fil vide : invitation à publier, le bouton ouvre la feuille', (tester) async {
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Soyez le premier à partager'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle publication'), findsOneWidget);
  });

  testWidgets('tirer pour actualiser recharge le fil, même vide', (tester) async {
    final repo = FakeCommunityRepository();
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();
    final loads = repo.feedLimits.length;

    await tester.fling(find.textContaining('Soyez le premier'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.feedLimits.length, greaterThan(loads));
  });

  testWidgets('groupes vides : invitation à créer, en arabe', (tester) async {
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المجموعات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أنشئ مجموعة زاويتك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discussion de groupe en échec : « Réessayer » recharge', (tester) async {
    final groups = FakeGroupsRepository()..postsError = StateError('refus');
    await tester.pumpWidget(wrapCommunaute(
      GroupDetailScreen(group: testGroup(isMember: true)),
      groups: groups,
      extraOverrides: groupMemberOverrides,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les discussions.'), findsOneWidget);

    groups.postsError = null;
    final loads = groups.postsLoads;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(groups.postsLoads, greaterThan(loads));
    expect(find.text('Impossible de charger les discussions.'), findsNothing);
  });

  testWidgets('aucune conversation : explique comment en ouvrir une', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const ConversationsScreen(),
      extraOverrides: [conversationsProvider.overrideWith((ref) async => [])],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('ouvrez une de ses publications'), findsOneWidget);
  });
}
