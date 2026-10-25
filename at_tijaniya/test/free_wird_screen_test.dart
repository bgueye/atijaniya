// Vérifie le flux complet du Wird libre : formulaire de configuration ->
// compteur -> fin -> nouveau compteur, sans dépendre d'un contenu religieux
// fixe (voir la règle "contenu religieux" de CLAUDE.md — le label est saisi
// par le disciple, jamais fourni par l'app).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
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

  testWidgets('Formulaire accessible : zones tactiles de 48 dp, pastilles et champ « cible » annoncés',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    // Pastilles agrandies en hauteur, pas en largeur : les quatre tiennent
    // sur une ligne (une première version les étirait sur toute la largeur).
    final pill = tester.getSize(find.widgetWithText(InkWell, '33'));
    expect(pill.height, greaterThanOrEqualTo(48));
    expect(pill.width, lessThan(120));
    expect(tester.getTopLeft(find.widgetWithText(InkWell, '1000')).dy,
        tester.getTopLeft(find.widgetWithText(InkWell, '33')).dy);

    // Le champ porte le libellé affiché au-dessus des pastilles, pas seulement
    // son indication « 100 ».
    expect(
      tester.getSemantics(find.byType(TextField).last),
      // L'indication « 100 » suit le libellé dans la même annonce.
      isSemantics(label: 'Nombre de répétitions\n100', isTextField: true),
    );

    // Pastille choisie annoncée comme telle.
    await tester.tap(find.text('99'));
    await tester.pumpAndSettle();
    expect(
      // `InkWell` : après le toucher, « 99 » s'affiche aussi dans le champ.
      tester.getSemantics(find.widgetWithText(InkWell, '99')),
      isSemantics(label: '99', isButton: true, isSelected: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('sur fond zaytoune, le bouton principal a un contour visible', (tester) async {
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(of: find.widgetWithText(ElevatedButton, 'Commencer'), matching: find.byType(Material)).first,
    );
    expect((material.shape! as RoundedRectangleBorder).side.color, AppColors.secondaryOnDark);
  });

  testWidgets('en mode voix, le compte est annoncé au lecteur d’écran à chaque changement', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('33'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    Finder zone() => find.byWidgetPredicate((w) => w is Semantics && w.properties.value == '0 / 33');
    expect(tester.getSemantics(zone()), isSemantics(isLiveRegion: false));

    await tester.tap(find.byTooltip('Voix'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(zone()), isSemantics(isLiveRegion: true));
    handle.dispose();
  });

  testWidgets('« Annuler » après « Réinitialiser » rétablit le compte, sans perdre les répétitions comptées depuis',
      (tester) async {
    await tester.pumpWidget(_wrap(const FreeWirdScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('33'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Toucher pour compter'));
      await tester.pump();
    }
    expect(find.text('5'), findsOneWidget);

    // Toucher de travers sur « Réinitialiser » : remise à zéro immédiate,
    // avec un message qui propose d'annuler.
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Compteur remis à zéro.'), findsOneWidget);
    // Le message ne recouvre pas les commandes du compteur.
    expect(
      // La carte du message (son `Material`), pas le `SnackBar` entier, dont
      // le rectangle inclut la marge.
      tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Réinitialiser')).top),
    );

    // Le disciple continue de réciter avant de remarquer l'erreur.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Toucher pour compter'));
      await tester.pump();
    }

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
  });
}
