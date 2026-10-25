// Vérifie que FigureDetailScreen rend correctement une biographie, des
// citations et un évènement lié (sous-section "Évènements liés" de l'onglet
// "Zawiya", ex-onglet "Ziyaras") quand ils sont présents, et affiche une
// note explicite quand la biographie est absente — avec une figure factice,
// locale au test (pas de contenu religieux réel dans ce fichier).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/figures/data/figures_repository.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figure_detail_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;
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
Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  double textScale = 1.0,
  bool isAdmin = false,
  Locale locale = const Locale('fr'),
}) {
  return ProviderScope(
    overrides: [isAdminProvider.overrideWithValue(isAdmin), ...overrides],
    child: MaterialApp(
      // Taille du texte imposée par le test (réglage d'accessibilité du
      // téléphone) — 1.0 par défaut, comme les tests existants.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: locale,
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
  testWidgets('FigureDetailScreen affiche la biographie, les citations et l\'évènement Ziyara lié quand présents',
      (tester) async {
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
    // Texte secondaire en encre secondaire, pas en bronze (audit Figures du
    // 2026-10-25, P2-4).
    expect(tester.widget<Text>(find.text('— Source de test')).style?.color, AppColors.secondaryInk);

    // Onglet "Zawiya" (ex-"Ziyaras") — sous-section "Évènements liés".
    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();
    expect(find.text('Évènement de test lié'), findsOneWidget);
  });

  // Audit Figures du 2026-10-25 (P2-2) : l'intertitre d'une biographie
  // s'affiche en titre et se laisse atteindre comme tel par un lecteur
  // d'écran ; une section faite d'un titre seul n'ajoute pas de texte vide.
  testWidgets('FigureDetailScreen annonce les intertitres de la biographie comme titres', (tester) async {
    final semantics = tester.ensureSemantics();
    const figure = Figure(
      id: 'test-figure-headings',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure à intertitres',
      category: FigureCategory.founder,
      biography: [
        FigureBiographyParagraph(heading: 'PREMIER TITRE DE TEST', translation: ''),
        FigureBiographyParagraph(translation: 'Texte sous le premier titre.'),
      ],
    );

    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure)));
    await tester.pumpAndSettle();

    expect(find.text('PREMIER TITRE DE TEST'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('PREMIER TITRE DE TEST')),
      matchesSemantics(label: 'PREMIER TITRE DE TEST', isHeader: true),
    );
    expect(
      tester.getSemantics(find.text('Texte sous le premier titre.')),
      isSemantics(label: 'Texte sous le premier titre.', isHeader: false),
    );
    semantics.dispose();
  });

  // Audit Figures du 2026-10-25 (P3-5) : l'admin voit les maillons en
  // brouillon d'une succession, marqués « Brouillon » (un disciple ne les
  // reçoit pas : la RLS les filtre).
  testWidgets('succession vue par l\'admin : seul le maillon en brouillon est marqué', (tester) async {
    const figure = Figure(
      id: 'test-founder-admin',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Fondateur publié',
      category: FigureCategory.founder,
    );
    const published = Figure(
      id: 'test-published',
      nameArabic: 'منشور',
      nameFrench: 'Maillon publié',
      category: FigureCategory.religiousFamily,
    );
    FigureKhalifaLink link(String id, String figureId, String nameFr, int order) => FigureKhalifaLink(
          id: id,
          founderFigureId: 'test-founder-admin',
          zawiyaId: 'z1',
          role: SuccessionRole.khalife,
          khalifaFigureId: figureId,
          khalifaNameAr: 'اسم',
          khalifaNameFr: nameFr,
          khalifaCategory: FigureCategory.religiousFamily,
          orderIndex: order,
        );
    final succession = ZawiyaSuccession(
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      role: SuccessionRole.khalife,
      founderFigureId: 'test-founder-admin',
      links: [link('l1', 'test-published', 'Maillon publié', 1), link('l2', 'test-draft', 'Maillon en brouillon', 2)],
    );

    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      isAdmin: true,
      overrides: [
        // Fiches `valide` seulement : « test-draft » n'y est pas.
        figuresProvider.overrideWith((ref) async => const [figure, published]),
        linkedEventsForFigureProvider('test-founder-admin').overrideWith((ref) async => []),
        linkedZawiyasForFigureProvider('test-founder-admin').overrideWith((ref) async => []),
        successionsForFigureProvider('test-founder-admin').overrideWith((ref) async => [succession]),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Maillon en brouillon'), 200, scrollable: find.byType(Scrollable).last);

    expect(find.text('Brouillon'), findsOneWidget);
    final tag = tester.getTopLeft(find.text('Brouillon')).dy;
    expect(tag, greaterThan(tester.getTopLeft(find.text('Maillon en brouillon')).dy));
  });

  // Audit Figures du 2026-10-25 (P3-7) : pour l'admin, le portrait est un
  // bouton nommé ; avant, TalkBack annonçait un bouton vide.
  testWidgets('admin : le portrait modifiable est annoncé « Changer le portrait »', (tester) async {
    final semantics = tester.ensureSemantics();
    const figure = Figure(
      id: 'test-figure-portrait',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure sans portrait',
      category: FigureCategory.founder,
    );
    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      isAdmin: true,
      overrides: [
        figuresProvider.overrideWith((ref) async => const [figure])
      ],
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Changer le portrait')),
      isSemantics(label: 'Changer le portrait', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  // Audit Figures du 2026-10-25 (P3-2) : un échec de chargement des zawiyas
  // ou des évènements liés propose « Réessayer », qui relance la requête.
  testWidgets('onglet Zawiya : « Réessayer » relance le chargement en échec', (tester) async {
    const figure = Figure(
      id: 'test-figure-retry',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure à recharger',
      category: FigureCategory.founder,
    );
    var zawiyaCalls = 0;
    var eventCalls = 0;
    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      overrides: [
        linkedZawiyasForFigureProvider('test-figure-retry').overrideWith((ref) async {
          zawiyaCalls++;
          if (zawiyaCalls == 1) throw Exception('hors ligne');
          return [];
        }),
        linkedEventsForFigureProvider('test-figure-retry').overrideWith((ref) async {
          eventCalls++;
          if (eventCalls == 1) throw Exception('hors ligne');
          return [];
        }),
        successionsForFigureProvider('test-figure-retry').overrideWith((ref) async => []),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();

    expect(find.text('Réessayer'), findsNWidgets(2));
    await tester.tap(find.text('Réessayer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Réessayer'), findsNothing);
    expect(zawiyaCalls, 2);
    expect(eventCalls, 2);
  });

  // Audit Figures du 2026-10-25 (P2-3) : en interface arabe, la biographie
  // française se range sur le début de ses lignes (à gauche) et l'onglet
  // précise qu'elle n'existe qu'en français. Rien de tel en français.
  testWidgets('FigureDetailScreen en arabe : biographie française rangée à gauche, avec la mention', (tester) async {
    const figure = Figure(
      id: 'test-figure-ar',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure en arabe',
      category: FigureCategory.founder,
      biography: [FigureBiographyParagraph(translation: 'Paragraphe biographique de test.')],
    );

    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('هذه السيرة متوفرة بالفرنسية فقط حاليا.'), findsOneWidget);
    final paragraph = tester.widget<Text>(find.text('Paragraphe biographique de test.'));
    expect(paragraph.textDirection, TextDirection.ltr);
    // Pas d'alignement forcé à droite : le texte suit son propre début.
    expect(paragraph.textAlign, isNull);

    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure)));
    await tester.pumpAndSettle();
    expect(find.text("Cette biographie n'existe qu'en français pour l'instant."), findsNothing);
  });

  // Constaté sur émulateur le 2026-10-25 : icônes sombres de la barre de
  // statut sur le vert de l'en-tête. La fiche demande des icônes claires,
  // sans toucher à la barre de navigation.
  testWidgets('FigureDetailScreen demande des icônes claires dans la barre de statut', (tester) async {
    const figure = Figure(
      id: 'test-figure-status-bar',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure test',
      category: FigureCategory.founder,
    );
    await tester.pumpWidget(_wrap(const FigureDetailScreen(figure: figure)));
    await tester.pumpAndSettle();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarColor, isNull);
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

  // Audit Figures du 2026-10-25 (P1) : en paysage avec le texte à 200 %,
  // l'en-tête fixe de l'ancienne mise en page débordait et ne laissait voir
  // aucune ligne de biographie. Surface 891 × 411 dp (téléphone 1080p en
  // paysage). L'en-tête doit pouvoir défiler hors de l'écran, les onglets
  // rester accrochés en haut, et la biographie apparaître dessous.
  testWidgets('FigureDetailScreen reste lisible en paysage avec le texte à 200 %', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final figure = Figure(
      id: 'test-figure-landscape',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure en paysage',
      category: FigureCategory.founder,
      biography: [
        for (var i = 1; i <= 12; i++)
          FigureBiographyParagraph(
              translation: 'Paragraphe de test numéro $i, assez long pour occuper '
                  'plusieurs lignes de la fiche une fois le texte agrandi.'),
      ],
    );

    await tester.pumpWidget(_wrap(FigureDetailScreen(figure: figure), textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final firstParagraph = find.textContaining('Paragraphe de test numéro 1,');
    // Dès l'ouverture, avec l'en-tête encore affiché, le début de la
    // biographie est visible.
    expect(firstParagraph.hitTestable(), findsOneWidget);

    // En-tête entièrement défilé, onglet encore en haut de son contenu.
    // Contrôleur externe plutôt qu'un glisser, qui peut lancer un défilement
    // inertiel et rendre la position finale imprévisible.
    final nested = tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    nested.outerController.jumpTo(nested.outerController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Le nom n'est plus à l'écran, les onglets sont accrochés en haut
    // (bandeau de barre de statut nul dans le test)...
    expect(find.text('FIGURE EN PAYSAGE').hitTestable(), findsNothing);
    final tabBarRect = tester.getRect(find.byType(TabBar));
    expect(tabBarRect.top, 0);
    // ... et le premier paragraphe commence sous eux, pas dessous : c'est le
    // rôle du `SliverOverlapInjector`.
    expect(tester.getRect(firstParagraph).top, greaterThanOrEqualTo(tabBarRect.bottom));
  });

  // Audit Figures du 2026-10-25 (P1) : en mode renforcé, l'or assombri
  // (pensé pour les fonds clairs) tombait à 2,03:1 sur le bas émeraude de
  // l'en-tête et à 2,41:1 sur zaytoune. Le foyer passe à `goldSoft`, la
  // mention « Fondateur » à `goldOnDark`, deux couleurs fixes.
  testWidgets('FigureDetailScreen garde le foyer et « Fondateur » lisibles sur fond vert en mode renforcé',
      (tester) async {
    AppColors.setHighContrast(true);
    addTearDown(() => AppColors.setHighContrast(false));

    const figure = Figure(
      id: 'test-figure-contrast',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure contrastée',
      category: FigureCategory.founder,
      foyer: Foyer.fes,
    );
    const succession = ZawiyaSuccession(
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      role: SuccessionRole.khalife,
      founderFigureId: 'test-figure-contrast',
      founderNameAr: 'المؤسس التجريبي',
      founderNameFr: 'Fondateur de test',
      links: [],
    );

    await tester.pumpWidget(_wrap(
      const FigureDetailScreen(figure: figure),
      overrides: [
        linkedEventsForFigureProvider('test-figure-contrast').overrideWith((ref) async => []),
        linkedZawiyasForFigureProvider('test-figure-contrast').overrideWith((ref) async => []),
        successionsForFigureProvider('test-figure-contrast').overrideWith((ref) async => [succession]),
      ],
    ));
    await tester.pumpAndSettle();

    Color? colorOf(Finder finder) => tester.widget<Text>(finder).style?.color;

    expect(colorOf(find.textContaining('Foyer : ')), AppColors.goldSoft);

    await tester.tap(find.text('Zawiya'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Fondateur'), 200, scrollable: find.byType(Scrollable).last);
    expect(colorOf(find.text('Fondateur')), AppColors.goldOnDark);
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

  // Audit Figures du 2026-10-25 (P2-7) : toucher un maillon dont la fiche
  // n'est pas en mémoire la recharge. Si elle a disparu, un message le dit ;
  // un double toucher pendant le chargement n'ouvre qu'une fiche.
  group('lien vers la fiche d\'un maillon', () {
    const current = Figure(
      id: 'test-current',
      nameArabic: 'اسم تجريبي',
      nameFrench: 'Figure consultée',
      category: FigureCategory.religiousFamily,
    );
    const target = Figure(
      id: 'test-target',
      nameArabic: 'الهدف',
      nameFrench: 'Maillon cible',
      category: FigureCategory.religiousFamily,
    );
    const succession = ZawiyaSuccession(
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      role: SuccessionRole.khalife,
      founderFigureId: 'test-founder',
      links: [
        FigureKhalifaLink(
          id: 'l1',
          founderFigureId: 'test-founder',
          zawiyaId: 'z1',
          role: SuccessionRole.khalife,
          khalifaFigureId: 'test-target',
          khalifaNameAr: 'الهدف',
          khalifaNameFr: 'Maillon cible',
          khalifaCategory: FigureCategory.religiousFamily,
          orderIndex: 1,
        ),
      ],
    );

    Future<void> openZawiyaTab(WidgetTester tester, _FakeFiguresRepository repository) async {
      await tester.pumpWidget(_wrap(
        const FigureDetailScreen(figure: current),
        overrides: [
          // Liste vide : la fiche du maillon n'est pas en mémoire, elle
          // passe donc par `fetchFigureById`.
          figuresProvider.overrideWith((ref) async => const []),
          figuresRepositoryProvider.overrideWithValue(repository),
          linkedEventsForFigureProvider('test-current').overrideWith((ref) async => []),
          linkedZawiyasForFigureProvider('test-current').overrideWith((ref) async => []),
          successionsForFigureProvider('test-current').overrideWith((ref) async => [succession]),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zawiya'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Maillon cible'), 200, scrollable: find.byType(Scrollable).last);
    }

    testWidgets('fiche disparue entre-temps : message, aucune navigation', (tester) async {
      final repository = _FakeFiguresRepository(
        (_) async => throw const PostgrestException(message: 'no rows', code: 'PGRST116'),
      );
      await openZawiyaTab(tester, repository);

      await tester.tap(find.text('Maillon cible'));
      await tester.pumpAndSettle();

      expect(find.text("Cette fiche n'est plus disponible."), findsOneWidget);
      expect(find.byType(FigureDetailScreen), findsOneWidget);
    });

    // Audit Figures du 2026-10-25 (P3-1) : la silsila mène aussi aux fiches,
    // sauf pour la figure consultée.
    testWidgets('silsila : toucher un maillon ouvre sa fiche, pas celui de la figure consultée', (tester) async {
      await tester.pumpWidget(_wrap(
        const FigureDetailScreen(figure: current),
        overrides: [
          // Dépôt factice : `figuresProvider`, que rien n'écoute sur cette
          // fiche, se lit encore « en chargement » au moment du toucher.
          figuresRepositoryProvider.overrideWithValue(_FakeFiguresRepository((_) async => target)),
          historicalSilsilaChainProvider('test-current').overrideWith((ref) async => const [
                HistoricalSilsilaLink(
                  figureId: 'test-target',
                  nameAr: 'الهدف',
                  nameFr: 'Maillon cible',
                  category: FigureCategory.religiousFamily,
                  orderIndex: 0,
                ),
                HistoricalSilsilaLink(
                  figureId: 'test-current',
                  nameAr: 'اسم تجريبي',
                  nameFr: 'Figure consultée',
                  category: FigureCategory.religiousFamily,
                  orderIndex: 1,
                ),
              ]),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silsila'));
      await tester.pumpAndSettle();

      // La figure consultée : aucun effet.
      await tester.tap(find.text('Figure consultée').last);
      await tester.pumpAndSettle();
      expect(find.byType(FigureDetailScreen), findsOneWidget);

      await tester.tap(find.text('Maillon cible'));
      await tester.pumpAndSettle();
      expect(find.byType(FigureDetailScreen, skipOffstage: false), findsNWidgets(2));
      expect(find.text('MAILLON CIBLE'), findsOneWidget);
    });

    testWidgets('double toucher pendant le chargement : une seule fiche ouverte', (tester) async {
      final pending = Completer<Figure>();
      final repository = _FakeFiguresRepository((_) => pending.future);
      await openZawiyaTab(tester, repository);

      await tester.tap(find.text('Maillon cible'));
      await tester.pump();
      await tester.tap(find.text('Maillon cible'));
      await tester.pump();
      pending.complete(target);
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(find.byType(FigureDetailScreen, skipOffstage: false), findsNWidgets(2));
    });
  });
}

/// Dépôt factice : seul `fetchFigureById` sert ici ; [onFetch] décide de sa
/// réponse et [calls] compte les appels.
class _FakeFiguresRepository extends FiguresRepository {
  _FakeFiguresRepository(this.onFetch);

  final Future<Figure> Function(String id) onFetch;
  int calls = 0;

  @override
  Future<Figure> fetchFigureById(String id) {
    calls++;
    return onFetch(id);
  }
}
