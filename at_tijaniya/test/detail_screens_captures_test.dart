// Captures des fiches de détail refaites (2026-11-02), pour chaque état de
// leur maquette (`docs/maquettes/ecrans-detail.html` : fiche d'une figure et
// ses quatre onglets, fiche de la Zawiya de Tivaouane, Ziarra générale 2027),
// en français et en arabe, avec les vraies polices. Figure sans portrait :
// l'en-tête typographique. Textes de remplissage (voir
// `detail_screens_test_support.dart`).
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/figures/presentation/figure_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/event_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/zawiya_detail_screen.dart';

import 'capture_support.dart';
import 'detail_screens_test_support.dart';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Onglet de la fiche d'une figure : index dans la barre d'onglets.
  const figureTabs = {'bio': 0, 'silsila': 1, 'oeuvres': 2, 'lieux': 3};

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final code = locale.languageCode;

    for (final tab in figureTabs.entries) {
      testWidgets('capture fiche figure ${tab.key} ($code)', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: detailApp(const FigureDetailScreen(figure: detailFigure), locale: locale, theme: captureTheme()),
        ));
        await tester.pumpAndSettle();
        if (tab.value != 0) {
          await tester.tap(find.byType(Tab).at(tab.value));
          await tester.pumpAndSettle();
        }
        await captureToFile(tester, find.byKey(key), 'detail_figure_${tab.key}_$code');
      });
    }

    testWidgets('capture fiche zawiya ($code)', skip: skip != null, (tester) async {
      tester.view.physicalSize = const Size(400, 1900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: detailApp(const ZawiyaDetailScreen(zawiya: detailZawiya), locale: locale, theme: captureTheme()),
      ));
      await tester.pumpAndSettle();
      await captureToFile(tester, find.byKey(key), 'detail_zawiya_$code');
    });

    testWidgets('capture fiche évènement ($code)', skip: skip != null, (tester) async {
      tester.view.physicalSize = const Size(400, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: detailApp(EventDetailScreen(event: detailEvent()), locale: locale, theme: captureTheme()),
      ));
      await tester.pumpAndSettle();
      await captureToFile(tester, find.byKey(key), 'detail_event_$code');
    });
  }
}
