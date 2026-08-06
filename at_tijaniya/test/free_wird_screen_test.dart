// Vérifie le flux complet du Wird libre : formulaire de configuration ->
// compteur -> fin -> nouveau compteur, sans dépendre d'un contenu religieux
// fixe (voir la règle "contenu religieux" de CLAUDE.md — le label est saisi
// par le disciple, jamais fourni par l'app).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/presentation/free_wird_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('fr'),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Affiche le formulaire de configuration quand aucun compteur n\'est en cours', (tester) async {
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Nombre de répétitions'), findsOneWidget);
  });

  testWidgets('Une cible vide ou nulle bloque le démarrage avec un message d\'erreur', (tester) async {
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Indiquez un nombre de répétitions supérieur à 0.'), findsOneWidget);
    // Toujours sur le formulaire, pas sur le compteur.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('Configurer une cible affiche le compteur, puis "Terminer" une fois atteinte', (tester) async {
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();

    // Puce rapide "33" comme cible.
    await tester.tap(find.text('33'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('/ 33'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    for (var i = 0; i < 33; i++) {
      await tester.tap(find.text('Toucher pour compter'));
      await tester.pump();
    }

    expect(find.text('Terminer'), findsOneWidget);
    expect(find.text('Toucher pour compter'), findsNothing);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    expect(find.text('Compteur terminé'), findsOneWidget);
    expect(find.text('Nouveau compteur'), findsOneWidget);

    await tester.tap(find.text('Nouveau compteur'));
    await tester.pumpAndSettle();

    // Retour au formulaire vide, prêt pour un nouveau paramétrage.
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('/ 33'), findsNothing);
  });
}
