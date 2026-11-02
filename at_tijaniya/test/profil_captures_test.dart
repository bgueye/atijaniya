// Captures du Profil refait (2026-11-02), pour chaque état de sa maquette
// (`docs/maquettes/ecran-profil.html` : sans compte, disciple, parrainage
// confirmé, admin), en français et en arabe, avec les vraies polices.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_support.dart';
import 'profil_test_support.dart';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final state in ProfilState.values) {
      testWidgets('capture profil ${state.name} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 2300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        setUpProfilMocks();
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: profilApp(state, locale: locale, theme: captureTheme()),
        ));
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'profil_${state.name}_${locale.languageCode}');
      });
    }
  }
}
