// Captures de l'onglet Figures refait (2026-11-02), pour chaque état de sa
// maquette (`docs/maquettes/ecran-figures.html` : toutes les figures, foyer de
// Tivaouane en vue Grille et en vue Silsila), en français et en arabe, avec
// les vraies polices. Figures factices sans portrait (comme la maquette, qui
// ne charge pas les photos) : le nom arabe sert d'image.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/presentation/figures_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/foyer_screen.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';
import 'figures_test_support.dart';

final Map<String, Widget> _states = {
  'accueil': Builder(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.navFigures)),
      body: const FiguresScreen(),
    ),
  ),
  'tivaouane_grille': const FoyerScreen(foyer: Foyer.tivaouane),
  'tivaouane_silsila': const FoyerScreen(foyer: Foyer.tivaouane, initialView: FoyerView.silsila),
};

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final entry in _states.entries) {
      testWidgets('capture figures ${entry.key} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 1900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: figuresApp(home: entry.value, locale: locale, theme: captureTheme(), admin: true),
        ));
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'figures_${entry.key}_${locale.languageCode}');
      });
    }
  }
}
