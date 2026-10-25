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
    expect(selected.labelStyle?.color, AppColors.ink);
  });

  // Audit Figures du 2026-10-25 (P2-5) : un portrait introuvable laisse
  // place à l'icône de repli, au lieu d'une case vide. Dans `flutter test`,
  // toute image réseau échoue (HTTP 400), comme une URL qui ne répond plus.
  testWidgets('un portrait introuvable est remplacé par l\'icône de repli', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isAdminProvider.overrideWithValue(false),
        figuresProvider.overrideWith((ref) async => const [
              Figure(
                id: 'p',
                nameArabic: 'اسم',
                nameFrench: 'Figure au portrait cassé',
                category: FigureCategory.founder,
                portraitUrl: 'https://exemple.invalid/portrait.jpg',
              ),
            ]),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('fr'),
        home: Scaffold(body: FiguresScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  // Audit Figures du 2026-10-25 (P2-6) : les puces de foyer ne faisaient
  // que 34 dp de haut. Toutes les cibles de l'écran doivent atteindre 48 dp.
  testWidgets('les cibles tactiles de la liste atteignent 48 dp', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  // Audit Figures du 2026-10-25 (P2-8) : en arabe, nom arabe en titre et tri
  // sur le nom arabe. « الاسم الثالث » précède « الاسم الثاني » en arabe,
  // alors que leurs noms français se rangent dans l'ordre inverse.
  testWidgets('en arabe : nom arabe en titre, tri sur le nom arabe', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final third = tester.getTopLeft(find.text('الاسم الثالث')).dy;
    final second = tester.getTopLeft(find.text('الاسم الثاني')).dy;
    expect(third, lessThan(second));

    final arabicTitle = tester.widget<Text>(find.text('الاسم الثاني'));
    expect(arabicTitle.style?.fontSize, 18);
    expect(arabicTitle.maxLines, 2);
    // Le nom arabe passe avant le nom français dans la carte.
    expect(
      tester.getTopLeft(find.text('الاسم الثاني')).dy,
      lessThan(tester.getTopLeft(find.text('Cheikh Ahmed Tidiane Niasse')).dy),
    );

    // En français, rien ne change : tri et titre sur le nom français.
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cheikh Ahmed Tidiane Niasse')).dy,
      lessThan(tester.getTopLeft(find.text('Thierno Omar Diop')).dy),
    );
    expect(tester.widget<Text>(find.text('الاسم الثاني')).style?.fontSize, 16);
  });

  // Audit Figures du 2026-10-25 (P3-3) : tirer pour actualiser recharge la
  // liste — une fiche dépubliée entre-temps disparaît.
  testWidgets('tirer pour actualiser recharge la liste', (tester) async {
    var calls = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isAdminProvider.overrideWithValue(false),
        figuresProvider.overrideWith((ref) async {
          calls++;
          // Au second chargement, « Thierno Omar Diop » a été dépubliée.
          return calls == 1 ? _figures : _figures.where((f) => f.id != 'c').toList();
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('fr'),
        home: Scaffold(body: FiguresScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thierno Omar Diop'), findsOneWidget);

    await tester.fling(find.text('Sidi Bachir Tidjani'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Thierno Omar Diop'), findsNothing);
  });

  // Demande du porteur de projet du 2026-10-25 : filtre par foyer sur deux
  // lignes seulement, justifiées — chaque ligne va d'un bord à l'autre.
  testWidgets('les puces de foyer tiennent sur deux lignes justifiées', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Boîtes des libellés, et non de la `ChoiceChip` : celle-ci comprend la
    // zone tactile, qui s'étire même quand la puce dessinée ne le fait pas
    // (défaut d'une première version, invisible avec ce critère).
    final labels = find.descendant(of: find.byType(ChoiceChip), matching: find.byType(Text));
    final rows = <double, List<Rect>>{};
    for (final element in labels.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      rows.putIfAbsent(rect.top, () => []).add(rect);
    }
    expect(rows, hasLength(2));
    // Même bord gauche et même bord droit pour les deux lignes : celui de la
    // liste (marge de 16 sur la surface de test de 800 de large), plus les
    // 11 dp de la puce autour de son libellé (marge 6, 4 autour du libellé,
    // bordure 1). Tolérance d'un pixel : largeur de libellé arrondie.
    for (final row in rows.values) {
      final left = row.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final right = row.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      expect(left, moreOrLessEquals(16 + 11, epsilon: 1));
      expect(right, moreOrLessEquals(784 - 11, epsilon: 1));
    }
  });

  testWidgets('texte très agrandi : les puces reviennent à la ligne librement', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isAdminProvider.overrideWithValue(false),
        figuresProvider.overrideWith((ref) async => _figures),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: const Scaffold(body: FiguresScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tops = {
      for (final element in find.byType(ChoiceChip).evaluate()) tester.getRect(find.byWidget(element.widget)).top
    };
    expect(tops.length, greaterThan(2));
    // Aucun libellé tronqué : chaque nom de foyer reste entier.
    expect(find.text('Famille omarienne'), findsOneWidget);
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
