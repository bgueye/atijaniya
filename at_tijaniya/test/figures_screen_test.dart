// Écran de liste des figures (onglet Figures) — premier test de cet écran,
// ajouté avec la recherche par nom (audit Figures du 2026-10-25, P2-1).
// Figures factices, locales au test : seuls les noms et le foyer comptent.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_screen.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

const _figures = [
  Figure(
    id: 'a',
    nameArabic: 'الاسم الأول',
    nameFrench: 'Sidi Bachir Tidjani',
    category: FigureCategory.founder,
    foyer: Foyer.fes,
  ),
  Figure(
    id: 'b',
    nameArabic: 'الاسم الثاني',
    nameFrench: 'Cheikh Ahmed Tidiane Niasse',
    category: FigureCategory.religiousFamily,
    foyer: Foyer.medinaBaye,
  ),
  Figure(
    id: 'c',
    nameArabic: 'الاسم الثالث',
    nameFrench: 'Thierno Omar Diop',
    category: FigureCategory.religiousFamily,
    foyer: Foyer.omarienne,
  ),
];

// `isAdminProvider` surchargé à `false` et `figuresProvider` à la liste
// ci-dessus : leurs valeurs par défaut appellent Supabase, non initialisé
// dans ce test.
Widget _wrap({Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(false),
      figuresProvider.overrideWith((ref) async => _figures),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: FiguresScreen()),
    ),
  );
}

void main() {
  testWidgets('la recherche filtre la liste par nom, variantes de translittération comprises', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Sidi Bachir Tidjani'), findsOneWidget);
    expect(find.text('Thierno Omar Diop'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tijani');
    await tester.pump();
    expect(find.text('Sidi Bachir Tidjani'), findsOneWidget);
    expect(find.text('Cheikh Ahmed Tidiane Niasse'), findsOneWidget);
    expect(find.text('Thierno Omar Diop'), findsNothing);

    // Le bouton d'effacement rend la liste entière.
    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(find.text('Thierno Omar Diop'), findsOneWidget);
  });

  testWidgets('une recherche sans résultat le dit, avec la saisie', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump();
    expect(find.text('Aucune figure ne correspond à « introuvable ».'), findsOneWidget);
    expect(find.text('Aucune figure pour ce foyer.'), findsNothing);
  });

  // Audit Figures du 2026-10-25 (P2-4) : libellé d'une puce non choisie en
  // encre secondaire, pas en bronze (3,72:1 sur parchemin).
  testWidgets('les puces de foyer non choisies sont écrites en encre secondaire', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final unselected = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fès'));
    expect(unselected.labelStyle?.color, AppColors.secondaryInk);
    final selected = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tous les foyers'));
    expect(selected.labelStyle, isNull);
  });

  testWidgets('la recherche se combine au filtre par foyer', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tidiane');
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fès'));
    await tester.pump();
    expect(find.text('Sidi Bachir Tidjani'), findsOneWidget);
    expect(find.text('Cheikh Ahmed Tidiane Niasse'), findsNothing);
  });
}
