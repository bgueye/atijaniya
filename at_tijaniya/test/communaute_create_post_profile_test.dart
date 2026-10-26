// Audit Communauté du 2026-10-26 (P3-7) : « Publier » pendant le chargement
// du profil disait « rattachez-vous à une zawiya » à tort.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets('profil encore en chargement : la feuille s\'ouvre une fois chargé', (tester) async {
    final profile = Completer<Profile>();
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), loadProfile: () => profile.future));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pump();
    expect(find.textContaining('Seuls les comptes rattachés'), findsNothing);

    profile.complete(testProfile);
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle publication'), findsOneWidget);
  });

  testWidgets('profil en échec : message de chargement du profil', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      loadProfile: () => Future.error(StateError('refus')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger votre profil.'), findsOneWidget);
    expect(find.textContaining('Seuls les comptes rattachés'), findsNothing);
  });

  testWidgets('profil sans zawiya : le message de rattachement reste', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      loadProfile: () async => const Profile(userId: 'me', displayName: 'Sans zawiya', locale: 'fr'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Seuls les comptes rattachés'), findsOneWidget);
  });
}
