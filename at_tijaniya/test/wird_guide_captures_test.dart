// Captures du guide d'un wird refait (2026-11-02), en français et en arabe,
// avec les vraies polices : Lazim un jour ordinaire, Wazifa en pause, Hadra
// hors vendredi et le vendredi. À comparer au bandeau et aux actions de
// `ecran-wird.html`, et aux piliers et clôtures de `ecran-pratique.html`.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).
// L'audio est remplacé par une doublure sans récitation.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_detail_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_pillar_audio_controller.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';
import 'wird_overview_fixtures.dart';

class _NoRecitations implements WirdRecitationRepository {
  @override
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyManifest implements WirdRecitationAssetManifest {
  @override
  Future<Map<String, WirdRecitationAsset>> load() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final List<(String, Wird, WirdMockupState Function())> _cases = [
  ('lazim_matin', lazim, sundayMorning),
  ('wazifa_pause', wazifa, sundayEvening),
  ('hadra_dimanche', hadratouJouma, sundayMorning),
  ('hadra_vendredi', hadratouJouma, friday),
];

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final (name, wird, stateOf) in _cases) {
      testWidgets('capture guide $name (${locale.languageCode})', skip: skip != null, (tester) async {
        // Le haut du guide : bandeau, actions, notes, résumé et premiers piliers.
        tester.view.physicalSize = const Size(400, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final state = stateOf();
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(() => state.now),
            wirdOverviewProvider.overrideWith((ref) async => state.entries),
            wirdPillarAudioProvider.overrideWith(
              (ref, w) =>
                  WirdPillarAudioController(wird: w, repository: _NoRecitations(), assetManifest: _EmptyManifest()),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: captureTheme(),
              locale: locale,
              supportedLocales: const [Locale('fr'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: WirdDetailScreen(wird: wird),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'guide_${name}_${locale.languageCode}');
      });
    }
  }
}
