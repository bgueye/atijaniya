// Vérifie que FigureDetailScreen rend correctement une biographie, des
// citations et une ziyara quand elles sont présentes, et affiche une note
// explicite quand la biographie est absente — avec une figure factice,
// locale au test (pas de contenu religieux réel dans ce fichier).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figure_detail_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

// isAdminProvider surchargé à `false` : sa valeur par défaut dépend de
// currentUserIdProvider -> authStateChangesProvider, qui appelle
// SupabaseConfig.client (donc Supabase.instance) — non initialisé dans ce
// test. La surcharge évite d'évaluer cette chaîne, sans rapport avec ce que
// ce fichier vérifie (rendu de la biographie/citations/ziyara).
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [isAdminProvider.overrideWithValue(false)],
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
  testWidgets('FigureDetailScreen affiche la biographie, les citations et la ziyara quand présentes', (tester) async {
    const figure = Figure(
      id: 'test-figure',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure de test',
      category: FigureCategory.founder,
      summary: 'Résumé de test.',
      biography: [
        FigureBiographyParagraph(translation: 'Paragraphe biographique de test.'),
      ],
      citations: [
        FigureCitation(translation: 'Citation de test.', source: 'Source de test'),
      ],
      ziyaraNote: 'Note de ziyara de test.',
    );

    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure)));
    await tester.pumpAndSettle();

    // Onglet "Biographie" (actif par défaut).
    expect(find.text('Paragraphe biographique de test.'), findsOneWidget);
    expect(find.text('Biographie en attente de validation.'), findsNothing);

    // Onglet "Citations" — TabBarView ne construit que la page active,
    // il faut donc basculer d'onglet avant de chercher son contenu.
    await tester.tap(find.text('Citations'));
    await tester.pumpAndSettle();
    expect(find.text('Citation de test.'), findsOneWidget);
    expect(find.text('— Source de test'), findsOneWidget);

    // Onglet "Ziyaras".
    await tester.tap(find.text('Ziyaras'));
    await tester.pumpAndSettle();
    expect(find.text('Note de ziyara de test.'), findsOneWidget);
  });

  testWidgets('FigureDetailScreen indique une biographie en attente quand absente', (tester) async {
    const figure = Figure(
      id: 'test-figure-2',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure sans biographie',
      category: FigureCategory.religiousFamily,
    );

    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure)));
    await tester.pumpAndSettle();

    expect(find.text('Biographie en attente de validation.'), findsOneWidget);
  });
}
