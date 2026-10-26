// Audit Communauté du 2026-10-26 (P3-4) : la feuille de publication ne dit
// plus « Publié au nom de votre zawiya » (le fil affiche « disciple ·
// zawiya » depuis le 2026-10-06).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  for (final (locale, expected) in [
    (const Locale('fr'), 'Votre zawiya (Zawiya de test) sera indiquée à côté de votre nom.'),
    (const Locale('ar'), 'ستظهر زاويتك (Zawiya de test) بجانب اسمك.'),
  ]) {
    testWidgets('feuille de publication : zawiya indiquée à côté du nom (${locale.languageCode})', (tester) async {
      await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), locale: locale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('au nom de votre zawiya'), findsNothing);
    });
  }
}
