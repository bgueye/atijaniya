// Refonte de la Communauté (2026-11-02, maquette `ecran-communaute.html`,
// décisions validées le 2026-11-01) : ce que la refonte ajoute.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/auth/sign_in_request.dart';
import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/community_format.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_matches_screen.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_providers.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations_fr.dart';

import 'communaute_test_helpers.dart';

KhadaraEvent _event(String id, String title, int inDays) => KhadaraEvent(
      id: id,
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      title: title,
      type: KhadaraEventType.ziyara,
      startsAt: DateTime.now().add(Duration(days: inDays)),
    );

Group _group(String id, String name, {String? zawiyaId, bool isMember = false}) => Group(
      id: id,
      name: name,
      zawiyaId: zawiyaId,
      zawiyaName: zawiyaId == null ? null : 'Zawiya $zawiyaId',
      createdAt: DateTime(2026, 10, 1),
      memberCount: 4,
      isMember: isMember,
    );

void main() {
  testWidgets('fil : « Ma zawiya » filtre côté serveur sur la zawiya du disciple', (tester) async {
    final repo = FakeCommunityRepository(posts: [
      testPost(id: 'p1', contentText: 'De ma zawiya'),
      // Autre zawiya.
      testPost(id: 'p2', contentText: 'D\'ailleurs', authorZawiyaId: 'z2'),
    ]);
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();
    expect(find.text('D\'ailleurs'), findsOneWidget);

    // « Zawiya de test » devient « test » dans la puce.
    await tester.tap(find.text('Ma zawiya · test'));
    await tester.pumpAndSettle();
    expect(repo.feedZawiyas.last, 'z1');
    expect(find.text('D\'ailleurs'), findsNothing);
    expect(find.text('De ma zawiya'), findsOneWidget);
  });

  testWidgets('fil : un rendez-vous de la zawiya au plus toutes les trois publications', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCommunityRepository(posts: [
      for (var i = 1; i <= 5; i++) testPost(id: 'p$i', contentText: 'Publication $i'),
    ]);
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      community: repo,
      events: [_event('e1', 'Rendez-vous A', 3), _event('e2', 'Rendez-vous B', 10), _event('e3', 'Rendez-vous C', 20)],
    ));
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    // Après la 1re publication, puis après la 4e ; le 3e rendez-vous attend.
    expect(top('Rendez-vous A'), greaterThan(top('Publication 1')));
    expect(top('Rendez-vous A'), lessThan(top('Publication 2')));
    expect(top('Rendez-vous B'), greaterThan(top('Publication 4')));
    expect(top('Rendez-vous B'), lessThan(top('Publication 5')));
    expect(find.text('Rendez-vous C'), findsNothing);
    expect(find.text('RENDEZ-VOUS DE VOTRE ZAWIYA'), findsNWidgets(2)); // Eyebrow du kit, en capitales
  });

  testWidgets('fil sans zawiya : aucun rendez-vous', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      community: FakeCommunityRepository(posts: [testPost()]),
      userId: null,
      events: [_event('e1', 'Rendez-vous A', 3)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rendez-vous A'), findsNothing);
  });

  testWidgets('groupes : ceux de ma zawiya d\'abord, « Rejoindre » rejoint sans ouvrir la fiche', (tester) async {
    final groups = FakeGroupsRepository(groups: [
      _group('g-autre', 'Cercle en ligne'),
      _group('g-mien', 'Dahira de ma zawiya', zawiyaId: 'z1', isMember: true),
    ]);
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen(initialView: CommunityView.groups)),
      groups: groups,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Groupes de ma zawiya'), findsOneWidget);
    expect(find.text('Autres groupes'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Dahira de ma zawiya')).dy,
        lessThan(tester.getTopLeft(find.text('Cercle en ligne')).dy));
    expect(find.text('Membre'), findsOneWidget);

    await tester.tap(find.text('Rejoindre'));
    await tester.pumpAndSettle();
    expect(groups.calls, ['join:g-autre']);
  });

  testWidgets('condisciples : la carte n\'affiche aucune donnée et ouvre le parcours existant', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen(initialView: CommunityView.groups)),
      extraOverrides: [
        myLineageProvider.overrideWith(
          (ref) async => const LineageDeclaration(foyer: Foyer.tivaouane, moqaddamNameText: 'Nom privé'),
        ),
        lineageMatchesProvider.overrideWith((ref) async => const []),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Privé : rien n\'est visible sans votre accord'), findsOneWidget);
    expect(find.textContaining('Nom privé'), findsNothing);

    await tester.tap(find.text('Retrouver mes condisciples'));
    await tester.pumpAndSettle();
    expect(find.byType(LineageMatchesScreen), findsOneWidget);
  });

  testWidgets('condisciples sans lignée renseignée : la saisie de la lignée', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen(initialView: CommunityView.groups)),
      extraOverrides: [myLineageProvider.overrideWith((ref) async => null)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retrouver mes condisciples'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LineageScreen), findsOneWidget);
  });

  testWidgets('messages sans compte : invitation à se connecter', (tester) async {
    late final int Function() requests;
    await tester.pumpWidget(wrapCommunaute(
      Consumer(builder: (context, ref, _) {
        requests = () => ref.read(signInRequestProvider);
        return const Scaffold(body: CommunauteScreen(initialView: CommunityView.messages));
      }),
      userId: null,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connectez-vous pour retrouver vos conversations privées.'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    expect(requests(), 1);
  });

  test('date relative : minutes, heures, hier, jours, puis la date', () {
    final l10n = AppLocalizationsFr();
    final now = DateTime(2026, 11, 2, 15);
    expect(formatCommunityRelative(DateTime(2026, 11, 2, 14, 50), l10n, now: now), 'il y a 10 min');
    expect(formatCommunityRelative(DateTime(2026, 11, 2, 13), l10n, now: now), 'il y a 2 h');
    expect(formatCommunityRelative(DateTime(2026, 11, 1, 20), l10n, now: now), 'il y a 19 h');
    expect(formatCommunityRelative(DateTime(2026, 11, 1, 9), l10n, now: now), 'hier');
    expect(formatCommunityRelative(DateTime(2026, 10, 30, 9), l10n, now: now), 'il y a 3 j');
    expect(formatCommunityRelative(DateTime(2026, 10, 20, 9), l10n, now: now), '20/10/2026');
  });
}
