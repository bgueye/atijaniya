// Onglet Figures refait le 2026-11-02 (`docs/maquettes/ecran-figures.html`),
// décisions validées : fondateur en tête sans année de naissance, foyers en
// cartes dans l'ordre historique (foyer du disciple d'abord, « Autres foyers »
// en dernier), grille où le nom arabe remplace un portrait absent, page d'un
// foyer (Grille par défaut, Silsila avec sa légende), administration en bas.
// La recherche (audit Figures du 2026-10-25, P2-1) est inchangée.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_theme.dart';
import 'package:at_tijaniya/features/figures/domain/figure_foyers.dart';
import 'package:at_tijaniya/features/figures/presentation/figure_cards.dart';
import 'package:at_tijaniya/features/figures/presentation/foyer_screen.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;

import 'figures_test_support.dart';

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('logique', () {
    test('ordre historique, foyer du disciple en premier, « Autres foyers » en dernier', () {
      expect(orderedFoyers(testFigures), [
        Foyer.fes,
        Foyer.ainMadhi,
        Foyer.omarienne,
        Foyer.tivaouane,
        Foyer.kaolack,
        Foyer.medinaBaye,
        Foyer.autre,
      ]);
      expect(orderedFoyers(testFigures, userFoyer: Foyer.tivaouane).first, Foyer.tivaouane);
      expect(orderedFoyers(testFigures, userFoyer: Foyer.autre).last, Foyer.autre);
    });

    test('disciples du fondateur rattachés dans l\'app', () {
      expect(discipleCount('tijani', testLinks), 2);
    });

    test('arbre de Tivaouane : maître extérieur en tête, puis la chaîne et les fils', () {
      final tree = buildFoyerSilsilaTree(Foyer.tivaouane, testFigures, testLinks);
      expect([for (final n in tree) n.figure.id], ['oumar', 'mayoro', 'malick', 'babacar', 'mansour', 'dabakh']);
      expect(tree.first.external, isTrue);
      expect([for (final n in tree) n.depth], [0, 1, 2, 3, 3, 3]);
      expect(foyerSilsilaLinkCount(Foyer.tivaouane, testFigures, testLinks), 5);
    });

    test('foyer sans lien : arbre vide', () {
      expect(buildFoyerSilsilaTree(Foyer.ainMadhi, testFigures, testLinks), isEmpty);
    });
  });

  group('page principale', () {
    testWidgets('fondateur en tête, sans année ; foyers ; aperçu de la grille', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();

      expect(find.text('Fondateur de la Tariqa'.toUpperCase()), findsOneWidget);
      expect(find.text('2 disciples rattachés dans l\'app'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d{3,4} H')), findsNothing,
          reason: 'aucune année de naissance hors de la fiche');
      expect(find.text('Foyers'), findsOneWidget);
      // Dernière carte de la rangée horizontale des foyers.
      await tester.dragUntilVisible(find.text('Autres foyers'), find.byType(ListView).at(1), const Offset(-300, 0));
      expect(find.text('Autres foyers'), findsOneWidget);
      expect(find.text('Afficher les 12 figures'), findsOneWidget);
    });

    // Audit des écrans refaits du 2026-11-03 : la rangée des foyers avait une
    // hauteur fixe, et le nombre de figures était coupé à texte agrandi.
    testWidgets('texte agrandi : les cartes de foyer ne débordent pas', (tester) async {
      tall(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FoyerCollectionCard), findsWidgets);
    });

    testWidgets('sans portrait, le nom arabe sert d\'image', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();
      final grid = find.byType(FigureGrid);
      expect(find.descendant(of: grid, matching: find.byType(FigureImage)), findsWidgets);
      expect(find.byIcon(Icons.person_outline), findsNothing);
      expect(find.descendant(of: grid, matching: find.text('الحاج مالك سي')), findsOneWidget);
    });

    testWidgets('la recherche tolère les translittérations et affiche une grille', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'tijani');
      await tester.pumpAndSettle();
      expect(find.text('Résultats'), findsOneWidget);
      expect(find.text('Sidi Mohamed El Habib Tidjani'), findsOneWidget);
      expect(find.text('El Hadj Malick Sy'), findsNothing);
      expect(find.text('Foyers'), findsNothing);
    });

    testWidgets('une recherche sans résultat le dit, avec la saisie', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucune figure ne correspond à « introuvable ».'), findsOneWidget);
    });

    testWidgets('administration : une ligne en bas, admin seulement', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard));
      await tester.pumpAndSettle();
      expect(find.textContaining('Administration'), findsNothing);

      await tester.pumpWidget(figuresApp(theme: AppTheme.standard, admin: true));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Administration'));
      await tester.pumpAndSettle();
      expect(find.text('Contenu à valider'), findsOneWidget);
      expect(find.text('Créer une figure'), findsOneWidget);
    });

    testWidgets('en arabe : noms arabes dans la grille', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(theme: AppTheme.standard, locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('الفروع'), findsOneWidget);
      await tester.dragUntilVisible(find.text('فروع أخرى'), find.byType(ListView).at(1), const Offset(300, 0));
      expect(find.text('فروع أخرى'), findsOneWidget);
    });
  });

  group('page d\'un foyer', () {
    testWidgets('chiffres, grille par défaut, puis silsila avec sa légende', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(
        theme: AppTheme.standard,
        home: const FoyerScreen(foyer: Foyer.tivaouane),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FigureGrid), findsOneWidget);
      expect(find.text('5'), findsWidgets, reason: '5 figures et 5 liens de silsila');
      await tester.tap(find.text('Silsila'));
      await tester.pumpAndSettle();
      expect(find.byType(FigureGrid), findsNothing);
      expect(find.text('Famille omarienne · maître venu d\'un autre foyer'), findsOneWidget);
      expect(find.textContaining('Ce n\'est pas un arbre généalogique'), findsOneWidget);
    });

    testWidgets('foyer sans lien de silsila : le dit', (tester) async {
      tall(tester);
      await tester.pumpWidget(figuresApp(
        theme: AppTheme.standard,
        home: const FoyerScreen(foyer: Foyer.ainMadhi, initialView: FoyerView.silsila),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Aucun lien de silsila n\'est encore renseigné pour ce foyer.'), findsOneWidget);
    });
  });
}
