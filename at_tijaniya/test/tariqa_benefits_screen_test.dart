// Vérifie l'écran « Bienfaits de la Tijaniyya » et sa carte d'accès dans
// l'écran Wirds, avec le contenu réel (copie de la migration dans
// test/fixtures), sans Supabase :
// - la carte n'existe que s'il y a du contenu, et rappelle le brouillon ;
// - toute la page s'affiche : en-tête, essentiel, sections, conditions,
//   tableaux, sources ;
// - la légende des étiquettes s'ouvre, le sommaire amène à sa section ;
// - en arabe, le contenu reste en français de gauche à droite, et une phrase
//   le dit ; les citations arabes, elles, se lisent de droite à gauche.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/data/tariqa_benefits_repository.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_screen.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

TariqaBenefitsRows _fixture() {
  final json = jsonDecode(File('test/fixtures/tariqa_benefits_rows.json').readAsStringSync()) as Map<String, dynamic>;
  return (
    sections: (json['sections'] as List).cast<Map<String, dynamic>>(),
    cards: (json['cards'] as List).cast<Map<String, dynamic>>(),
  );
}

TariqaBenefitsRows _validated(TariqaBenefitsRows rows) => (
      sections: [for (final r in rows.sections) {...r, 'content_status': 'valide'}],
      cards: [for (final r in rows.cards) {...r, 'content_status': 'valide'}],
    );

Widget _wrap(Widget child, {required TariqaBenefitsRows rows, Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      tariqaBenefitsRowsProvider.overrideWith((ref) async => rows),
      wirdRepairContentProvider.overrideWith((ref) async => WirdRepairContent(cases: const [], notes: const [])),
      isAdminProvider.overrideWithValue(false),
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
      home: child,
    ),
  );
}

/// Trouve un texte, qu'il soit un `Text` simple ou une partie d'un texte
/// balisé (`Text.rich`).
Finder _rich(String fragment) => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(fragment),
      description: 'texte contenant « $fragment »',
    );

void main() {
  group('carte de l\'écran Wirds', () {
    testWidgets('absente sans contenu (disciple, rien de validé)', (tester) async {
      await tester.pumpWidget(_wrap(
        const Scaffold(body: WirdListScreen()),
        rows: (sections: <Map<String, dynamic>>[], cards: <Map<String, dynamic>>[]),
      ));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Bienfaits de la Tijaniyya'), findsNothing);
    });

    testWidgets('présente avec du contenu, et mentionne le brouillon', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: WirdListScreen()), rows: _fixture()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Bienfaits de la Tijaniyya'), 200);
      expect(find.text('Bienfaits de la Tijaniyya'), findsOneWidget);
      expect(find.text('La tariqa et ses wirds, avec leurs conditions (Brouillon)'), findsOneWidget);
    });
  });

  group('écran', () {
    // Écran de téléphone (360 × 780) plutôt que la surface de test par défaut.
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 2340);
      view.devicePixelRatio = 3;
    });
    tearDown(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    testWidgets('affiche toute la page, avec le bandeau de brouillon', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Brouillon en attente'), findsOneWidget);
      expect(find.text('فضائل الطريقة التجانية وأورادها'), findsOneWidget);
      expect(find.text("L'essentiel"), findsOneWidget);
      expect(_rich("Aucun bienfait n'est inconditionnel."), findsOneWidget);
      // La page est construite d'un seul tenant (pour le sommaire) : chaque
      // section existe, même hors écran.
      for (final title in [
        'La tariqa : le Paradis sans jugement, étendu à la famille',
        'Les conditions communes',
        'Récapitulatif',
      ]) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      expect(_rich('Condition : mourir dans la foi'), findsOneWidget);
      expect(find.text('Lu dans Jawâhir'), findsWidgets);
      expect(find.text('Autorisation (idhn)'), findsOneWidget);
      // Le texte « En arabe… » n'apparaît que dans l'app en arabe.
      expect(find.text("Cette page n'existe qu'en français pour l'instant."), findsNothing);
    });

    testWidgets('sans brouillon, pas de bandeau', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _validated(_fixture())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Brouillon en attente'), findsNothing);
    });

    testWidgets('la légende s\'ouvre au tap', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();
      expect(find.text('un seul relais'), findsNothing);
      await tester.ensureVisible(find.text('Comment lire les étiquettes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comment lire les étiquettes'));
      await tester.pumpAndSettle();
      expect(find.text('un seul relais'), findsOneWidget);
      expect(find.text('Seconde main'), findsWidgets);
    });

    testWidgets('le sommaire amène à la section choisie', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();

      // Entrée du sommaire : la première occurrence du titre ; la section
      // elle-même : la seconde, loin en dessous.
      final entry = find.text('Les conditions communes').first;
      final heading = find.text('Les conditions communes').last;
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(heading).dy, greaterThan(2000));

      await tester.tap(entry);
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(heading).dy;
      expect(after, lessThan(200));
    });

    testWidgets('le bouton « Sommaire » apparaît après le sommaire et y ramène', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FloatingActionButton, 'Sommaire');
      double opacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: button, matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacity(), 0);

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(opacity(), 1);

      await tester.tap(button);
      await tester.pumpAndSettle();
      // La feuille liste L'essentiel puis les sections.
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text("L'essentiel")), findsOneWidget);
      await tester.tap(find.descendant(of: sheet, matching: find.text('Récapitulatif')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.getTopLeft(find.text('Récapitulatif').last).dy, lessThan(200));
    });

    testWidgets('une longue citation arabe dans une phrase passe sur sa propre ligne', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();

      // Vers de la Munya cité dans une phrase française, entre « (« » et « ») » :
      // il devient un `Text` à part, sans ses guillemets ni ses parenthèses.
      const verse = 'مَنْ تَلَا مِنْ هَذِهِ الصَّلَاةِ عَشْرًا حَصَّلَا · مَا لَمْ يُحَصِّلْهُ وَلِيٌّ سَامِ قَدْرًا وَعَاشَ أَلْفَ أَلْفِ عَامِ';
      expect(find.text(verse), findsOneWidget);
      expect(Directionality.of(tester.element(find.text(verse))), TextDirection.rtl);
      expect(_rich("qui aurait vécu un million d'années («"), findsNothing);
      expect(_rich("qui aurait vécu un million d'années"), findsOneWidget);
      // Une citation courte reste dans sa phrase.
      expect(_rich('ses trois piliers (أركان الورد ثلاثة)'), findsOneWidget);
    });

    testWidgets('les sources : une ligne par étiquette, sans « · » en bout de ligne', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture()));
      await tester.pumpAndSettle();

      // Carte « Ceux qui aiment le Cheikh et leurs familles » : deux étiquettes.
      expect(_rich('éd. Kanûn, p. 263-265'), findsOneWidget);
      expect(_rich('éd. Kanûn, p. 263-265 ·'), findsNothing);
      expect(_rich('al-Durra al-Kharida, t. 4, p. 28'), findsOneWidget);
    });

    testWidgets('en arabe : contenu en français de gauche à droite, citations de droite à gauche', (tester) async {
      await tester.pumpWidget(_wrap(const TariqaBenefitsScreen(), rows: _fixture(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // L'app bar suit l'interface.
      expect(find.text('فضائل الطريقة التجانية'), findsOneWidget);
      expect(find.text('هذه الصفحة متوفرة بالفرنسية فقط حاليا.'), findsOneWidget);
      // Le texte français garde son sens et ses libellés en français.
      final essential = find.text("L'essentiel");
      expect(Directionality.of(tester.element(essential)), TextDirection.ltr);
      expect(find.text('Comment lire les étiquettes'), findsOneWidget);
      // Une citation arabe, elle, se lit de droite à gauche.
      final quote = find.text('ضَمِنْتُ لَهُمْ هَذَا كُلَّهُ ضَمَانَةً لَا تَنْقَطِعُ حَتَّى تُجَاوِرَنِي أَنْتَ وَهُمْ فِي عِلِّيِّينَ');
      expect(quote, findsOneWidget);
      expect(Directionality.of(tester.element(quote)), TextDirection.rtl);
    });
  });
}
