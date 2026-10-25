// Guide d'un wird : boutons audio des piliers annoncés, avec la zone tactile
// minimale d'Android, dans les deux états où aucune récitation n'est jouable
// (audit du 2026-10-25) :
// - aucune récitation validée : « pas encore disponible » ;
// - liste des récitations inaccessible (hors ligne) : « Réessayer », et la
//   barre le dit au lieu d'annoncer « bientôt disponible » (P2-2).
// Le dépôt Supabase est remplacé par une doublure.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_detail_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_pillar_audio_controller.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Dépôt simulé : aucune récitation, ou erreur réseau si [offline].
class _FakeRepository implements WirdRecitationRepository {
  _FakeRepository({required this.offline});

  final bool offline;

  @override
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async {
    if (offline) throw const SocketException('hors ligne');
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyManifest implements WirdRecitationAssetManifest {
  @override
  Future<Map<String, WirdRecitationAsset>> load() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child, {required Locale locale, required bool offline}) {
  return ProviderScope(
    overrides: [
      wirdPillarAudioProvider.overrideWith(
        (ref, wird) => WirdPillarAudioController(
          wird: wird,
          repository: _FakeRepository(offline: offline),
          assetManifest: _EmptyManifest(),
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('minutage du lecteur : minutes et secondes, puis heures au-delà d’une heure', () {
    expect(formatPlaybackDuration(Duration.zero), '00:00');
    expect(formatPlaybackDuration(const Duration(minutes: 2, seconds: 43)), '02:43');
    expect(formatPlaybackDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(formatPlaybackDuration(const Duration(hours: 1, minutes: 5, seconds: 3)), '1:05:03');
  });
  final lazim = validatedWirds.firstWhere((w) => w.id == 'lazim');

  testWidgets('la même erreur s’affiche à chaque toucher, pas seulement la première fois', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('fr'));
    await tester.pumpWidget(_wrap(WirdDetailScreen(wird: lazim), locale: const Locale('fr'), offline: false));
    await tester.pumpAndSettle();

    for (var attempt = 1; attempt <= 2; attempt++) {
      await tester.tap(find.byTooltip(l10n.a11yPlayPause));
      await tester.pump();
      expect(find.text(l10n.wirdAudioWirdUnavailable), findsOneWidget, reason: 'toucher n° $attempt');
      // Retire le message avant le toucher suivant : le second ne peut alors
      // venir que d'une nouvelle annonce de l'erreur.
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text(l10n.wirdAudioWirdUnavailable), findsNothing);
    }
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final l10n = lookupAppLocalizations(locale);

    testWidgets('piliers sans récitation annoncés comme tels (${locale.languageCode})', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(WirdDetailScreen(wird: lazim), locale: locale, offline: false));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(l10n.wirdAudioPillarUnavailable), findsWidgets);
      expect(find.text(l10n.wirdAudioSoonLabel), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('hors ligne : « Réessayer » sur les piliers, pas « bientôt disponible » (${locale.languageCode})',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(WirdDetailScreen(wird: lazim), locale: locale, offline: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.wirdAudioPillarRetry), findsWidgets);
      expect(find.text(l10n.wirdAudioLoadFailed), findsOneWidget);
      expect(find.text(l10n.wirdAudioSoonLabel), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }
}
