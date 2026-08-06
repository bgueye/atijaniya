// Vérifie que "Comprendre la Khadara" respecte la règle "aucun contenu
// religieux/pratique non validé" (CLAUDE.md, docs/01-perimetre-fonctionnel.md
// § 8) : la liste de production (`validatedKhadaraUnderstanding`) doit
// rester vide, et l'écran doit alors afficher un état vide honnête plutôt
// qu'un contenu inventé.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/data/khadara_understanding_content.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_understanding_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  test('validatedKhadaraUnderstanding reste vide tant qu\'aucun contenu n\'est validé', () {
    expect(validatedKhadaraUnderstanding, isEmpty);
  });

  testWidgets('KhadaraUnderstandingScreen affiche un état vide honnête sans contenu validé', (tester) async {
    await tester.pumpWidget(_wrap(const KhadaraUnderstandingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Contenu en cours de compilation'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('Le bouton "en attendant" de l\'état vide referme l\'écran vers le Khadara sous-jacent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KhadaraUnderstandingScreen()),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(KhadaraUnderstandingScreen), findsOneWidget);

    await tester.tap(find.text('En attendant, découvrir le calendrier et les zawiyas'));
    await tester.pumpAndSettle();
    expect(find.byType(KhadaraUnderstandingScreen), findsNothing);
  });
}
