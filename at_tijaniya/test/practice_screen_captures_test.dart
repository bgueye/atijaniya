// Captures de l'écran de pratique refait (2026-11-02), pour chaque état de sa
// maquette (`docs/maquettes/ecran-pratique.html`, sur la fin du Lazim) :
// Fatiha (×1), comptage (Hailala 94 / 100), mode concentré, clôture, fin du
// wird — en français et en arabe, avec les vraies polices.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).
// Tous les textes viennent du corpus validé (`wirds_content.dart`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/core/widgets/app_buttons.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/presentation/tasbih_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';
import 'wird_overview_fixtures.dart';

/// Session du Lazim reprise au pilier et au compte voulus ; la bulle du mode
/// concentré déjà vue (la maquette ne la montre pas).
void _seed({required int pillarIndex, int count = 0}) {
  SharedPreferences.setMockInitialValues({
    'tasbih_session_lazim::guest': jsonEncode({
      'wirdId': 'lazim',
      'pillarIndex': pillarIndex,
      'currentCount': count,
      'mode': 'manual',
      'updatedAt': DateTime(2026, 11, 1).toIso8601String(),
      'useAlternative': false,
    }),
    'tasbih_reading_focus_hint_shown::guest': true,
  });
}

typedef _State = ({String name, int pillar, int count, Future<void> Function(WidgetTester tester)? then});

final List<_State> _states = [
  (name: 'fatiha', pillar: 1, count: 0, then: null),
  (name: 'comptage', pillar: 4, count: 94, then: null),
  (
    name: 'concentre',
    pillar: 4,
    count: 94,
    then: (tester) async {
      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();
    }
  ),
  (name: 'cloture', pillar: 4, count: 100, then: null),
  (
    name: 'fin',
    pillar: 4,
    count: 100,
    then: (tester) async {
      await tester.tap(find.byType(PracticeButton));
      await tester.pumpAndSettle();
    }
  ),
];

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final state in _states) {
      testWidgets('capture pratique ${state.name} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(380, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _seed(pillarIndex: state.pillar, count: state.count);
        // Écran de fin : série et rappel de l'exemple « dimanche soir ».
        final evening = sundayEvening();
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(() => evening.now),
            wirdOverviewProvider.overrideWith((ref) async => evening.entries),
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
              home: const TasbihScreen(wird: lazim),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await state.then?.call(tester);
        await captureToFile(tester, find.byKey(key), 'pratique_${state.name}_${locale.languageCode}');
      });
    }
  }
}
