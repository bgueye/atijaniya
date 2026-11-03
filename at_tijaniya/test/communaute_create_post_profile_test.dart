// Audit Communauté du 2026-10-26 (P3-7) : pendant le chargement du profil,
// l'app disait « rattachez-vous à une zawiya » à tort. Depuis la refonte du
// 2026-11-02 (maquette `ecran-communaute.html`), l'en-tête du fil dépend du
// profil : champ de publication pour un disciple rattaché, carte de
// rattachement sinon, et rien tant que le profil n'est pas connu.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';

import 'communaute_test_helpers.dart';

const _composer = 'Partager avec la communauté…';
const _unlock = 'Rattachez votre profil à votre zawiya';

void main() {
  testWidgets('profil encore en chargement : ni carte de rattachement, puis le champ de publication', (tester) async {
    final profile = Completer<Profile>();
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), loadProfile: () => profile.future));
    await tester.pump();
    expect(find.text(_unlock), findsNothing);
    expect(find.text(_composer), findsNothing);

    profile.complete(testProfile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_composer));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle publication'), findsOneWidget);
  });

  testWidgets('profil en échec : pas de carte de rattachement à tort', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      loadProfile: () => Future.error(StateError('refus')),
    ));
    await tester.pumpAndSettle();
    expect(find.text(_unlock), findsNothing);
    expect(find.text(_composer), findsNothing);
  });

  testWidgets('profil sans zawiya : la carte dit la règle et mène au choix de la zawiya', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      loadProfile: () async => const Profile(userId: 'me', displayName: 'Sans zawiya', locale: 'fr'),
    ));
    await tester.pumpAndSettle();
    expect(find.text(_unlock), findsOneWidget);
    expect(find.text('Choisir ma zawiya'), findsOneWidget);
    expect(find.text(_composer), findsNothing);
    // Pas de filtre « Ma zawiya » sans zawiya.
    expect(find.text('Toute la communauté'), findsNothing);
  });

  testWidgets('invité : carte de connexion, ni champ ni filtre', (tester) async {
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), userId: null));
    await tester.pumpAndSettle();
    expect(find.text('Connectez-vous pour participer'), findsOneWidget);
    expect(find.text(_composer), findsNothing);
    expect(find.text('Toute la communauté'), findsNothing);
  });
}
