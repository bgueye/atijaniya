// Guide d'un wird refait le 2026-11-02 (bandeau et actions de `ecran-wird.html`,
// piliers et clôtures de `ecran-pratique.html`) : état du jour, « Commencer »
// absent pour la Hadra hors vendredi, « Reprendre » pour une session en pause,
// résumé des piliers, Fatiha déroulée, clôtures en entier, « Aa » limité à la
// taille de l'arabe. Les textes viennent du corpus validé ; l'audio est
// remplacé par une doublure sans récitation.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_detail_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_pillar_audio_controller.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'wird_overview_fixtures.dart';

class _NoRecitations implements WirdRecitationRepository {
  @override
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyManifest implements WirdRecitationAssetManifest {
  @override
  Future<Map<String, WirdRecitationAsset>> load() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Wird wird, WirdMockupState state, {Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => state.now),
      wirdOverviewProvider.overrideWith((ref) async => state.entries),
      wirdPillarAudioProvider.overrideWith(
        (ref, w) => WirdPillarAudioController(wird: w, repository: _NoRecitations(), assetManifest: _EmptyManifest()),
      ),
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
      home: WirdDetailScreen(wird: wird),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Fenêtre haute : le guide est une longue liste, les tests portent sur
  /// des éléments éloignés.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 20000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('Lazim : état du jour, actions, résumé des piliers, Fatiha déroulée, clôtures en entier', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(lazim, sundayMorning()));
    await tester.pumpAndSettle();

    expect(find.text('À faire aujourd\'hui'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('6 jours d\'affilée'), findsOneWidget);
    // Résumé : Istighfar, Salatoul Fatihi, Hailala, chacun ×100.
    expect(find.text('×100'), findsNWidgets(6), reason: '3 puces du résumé + 3 en-têtes de pilier');
    // Fatiha déroulée, verset par verset, sans « Texte intégral ».
    for (final verse in lazim.pillars[1].fullText!) {
      expect(find.text(verse.arabic), findsOneWidget);
    }
    expect(find.text('Texte intégral'), findsNothing);
    // Clôtures du dernier pilier, chacune en entier.
    for (final formula in lazim.pillars[4].closingFormulas!) {
      expect(find.text(formula.intro), findsOneWidget);
    }
  });

  testWidgets('Wazifa en pause : « Reprendre » ; Jawharatoul Kamal reste repliée', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(wazifa, sundayEvening()));
    await tester.pumpAndSettle();

    expect(find.text('En pause'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Texte intégral'), findsOneWidget);
  });

  testWidgets('Hadra : pas de « Commencer » hors vendredi, présent le vendredi', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(hadratouJouma, sundayMorning()));
    await tester.pumpAndSettle();
    expect(find.text('Vendredi 6 novembre'), findsOneWidget);
    expect(find.text('Commencer'), findsNothing);
    expect(find.textContaining('uniquement le vendredi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(hadratouJouma, friday()));
    await tester.pumpAndSettle();
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('« Aa » : la taille de l\'arabe seulement, translittération et traduction toujours là', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(lazim, sundayMorning()));
    await tester.pumpAndSettle();
    expect(find.text(lazim.pillars[2].translation), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Réglages de lecture'));
    await tester.pumpAndSettle();
    expect(find.text('Taille de l\'arabe'), findsOneWidget);
    expect(find.text('Traduction'), findsNothing);
    expect(find.text('Translittération'), findsNothing);
  });

  testWidgets("références validées sous les piliers, dont l'Istighfar de la Wazifa (Munyat al-Murîd)", (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(lazim, sundayMorning()));
    await tester.pumpAndSettle();
    expect(find.text("Source : Jawâhir al-Ma'ânî, trad. R. Mbaye, p. 340 ; éd. arabe, pp. 251-252"), findsNWidgets(3));
    expect(find.text('Source : Coran, sourate 1 (Al-Fatiha)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(wazifa, sundayMorning()));
    await tester.pumpAndSettle();
    expect(find.text("Source : Jawâhir al-Ma'ânî, trad. R. Mbaye, p. 344"), findsNWidgets(2));
    expect(find.text('Source : Munyat al-Murîd, p. 18 (trente avec la formule longue)'), findsOneWidget);
  });

  testWidgets('en arabe : noms courts arabes dans le résumé', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(lazim, sundayMorning(), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('صلاة الفاتح'), findsWidgets);
    expect(find.text('الاستغفار'), findsWidgets);
  });
}
