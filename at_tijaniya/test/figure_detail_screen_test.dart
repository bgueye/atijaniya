// Vérifie que FigureDetailScreen rend correctement une biographie, des
// citations et un évènement lié (sous-section "Évènements liés" de l'onglet
// "Zawiya", ex-onglet "Ziyaras") quand ils sont présents, et affiche une
// note explicite quand la biographie est absente — avec une figure factice,
// locale au test (pas de contenu religieux réel dans ce fichier).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figure_detail_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

// isAdminProvider surchargé à `false` : sa valeur par défaut dépend de
// currentUserIdProvider -> authStateChangesProvider, qui appelle
// SupabaseConfig.client (donc Supabase.instance) — non initialisé dans ce
// test. Même raison pour linkedEventsForFigureProvider/
// linkedZawiyasForFigureProvider/successionsForFigureProvider, tous les trois
// interrogés sans condition par `_ZawiyaTab` (pas seulement pour un admin)
// et qui appelleraient sinon FiguresRepository (réseau) sans surcharge —
// aucun des quatre n'a de rapport avec ce que ce fichier vérifie (rendu de
// la biographie/citations/évènement lié).
Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [isAdminProvider.overrideWithValue(false), ...overrides],
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
  testWidgets('FigureDetailScreen affiche la biographie, les citations et l\'évènement Ziyara lié quand présents', (tester) async {
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
    );
    final linkedEvent = KhadaraEvent(
      id: 'test-event',
      title: 'Évènement de test lié',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 1, 1, 10),
    );

    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      overrides: [
        linkedEventsForFigureProvider('test-figure').overrideWith((ref) async => [linkedEvent]),
        linkedZawiyasForFigureProvider('test-figure').overrideWith((ref) async => []),
        successionsForFigureProvider('test-figure').overrideWith((ref) async => []),
      ],
    ));
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

    // Onglet "Zawiya" (ex-"Ziyaras") — sous-section "Évènements liés".
    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();
    expect(find.text('Évènement de test lié'), findsOneWidget);
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

  // Succession rangée par zawiya + rôle (migration
  // `khalifa_chain_by_zawiya_with_role`, 2026-10-01) : la fiche d'un maillon
  // (et plus seulement celle du fondateur) affiche la succession entière,
  // titrée selon le rôle, avec la mention de lacune quand `followsGap` est
  // vrai. Noms factices, locaux au test.
  testWidgets('FigureDetailScreen affiche la succession par zawiya, son rôle et la mention de liste incomplète',
      (tester) async {
    const figure = Figure(
      id: 'test-mokaddem-2',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure consultée',
      category: FigureCategory.religiousFamily,
    );
    const succession = ZawiyaSuccession(
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      role: SuccessionRole.mokaddem,
      founderFigureId: 'test-founder',
      founderNameAr: 'المؤسس التجريبي',
      founderNameFr: 'Fondateur de test',
      links: [
        FigureKhalifaLink(
          id: 'l1',
          founderFigureId: 'test-founder',
          zawiyaId: 'z1',
          role: SuccessionRole.mokaddem,
          khalifaFigureId: 'test-mokaddem-1',
          khalifaNameAr: 'الأول',
          khalifaNameFr: 'Premier maillon',
          khalifaCategory: FigureCategory.religiousFamily,
          orderIndex: 1,
        ),
        FigureKhalifaLink(
          id: 'l2',
          founderFigureId: 'test-founder',
          zawiyaId: 'z1',
          role: SuccessionRole.mokaddem,
          khalifaFigureId: 'test-mokaddem-2',
          khalifaNameAr: 'الثاني',
          khalifaNameFr: 'Maillon consulté',
          khalifaCategory: FigureCategory.religiousFamily,
          orderIndex: 2,
          periodText: 'actuel',
          followsGap: true,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      overrides: [
        linkedEventsForFigureProvider('test-mokaddem-2').overrideWith((ref) async => []),
        linkedZawiyasForFigureProvider('test-mokaddem-2').overrideWith((ref) async => []),
        successionsForFigureProvider('test-mokaddem-2').overrideWith((ref) async => [succession]),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Maillon consulté'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('Mokaddems'), findsOneWidget);
    expect(find.text('Khalifes'), findsNothing);
    expect(find.text('Zawiya de test'), findsOneWidget);
    expect(find.text('Fondateur de test'), findsOneWidget);
    expect(find.text('Premier maillon'), findsOneWidget);
    expect(find.text('Maillon consulté'), findsOneWidget);
    expect(find.text('actuel'), findsOneWidget);
    expect(find.text('Liste incomplète : des noms manquent ici.'), findsOneWidget);
  });
}
