// Captures de l'écran Wird refait (2026-11-02), pour chaque état de sa
// maquette (`docs/maquettes/ecran-wird.html` : dimanche matin, dimanche soir
// avec la Wazifa en pause, vendredi), en français et en arabe, avec les
// vraies polices. Une image de l'écran entier, déroulé, par état et par
// langue, à comparer à la maquette.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).
// Contenu de la section « Comprendre et rattraper » : nombres de fiches de la
// base au 2026-11-01 (39 cas, 23 conditions, 34 bienfaits), sur des fiches
// d'exemple sans texte — seul leur nombre est affiché.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/data/tariqa_benefits_repository.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';
import 'wird_overview_fixtures.dart';

/// Contenu d'exemple : seuls les nombres de fiches s'affichent sur l'écran.
WirdRepairContent _repair() => WirdRepairContent(
      cases: [
        for (var i = 0; i < 39; i++)
          WirdRepairCase(
            id: 'cas-$i',
            wird: RepairWird.all,
            kind: RepairKind.erreur,
            orderIndex: i,
            situationFr: '',
            situationAr: '',
            actionFr: '',
            actionAr: '',
            isValid: true,
          ),
      ],
      notes: const [],
    );

List<TariqaCondition> _conditions() => [
      for (var i = 0; i < 23; i++)
        TariqaCondition(
          id: 'condition-$i',
          category: TariqaConditionCategory.values.first,
          orderIndex: i,
          textFr: '',
          textAr: '',
        ),
    ];

TariqaBenefitsRows _benefits() => (
      sections: [
        {'id': 's1', 'content_status': 'valide'},
      ],
      cards: [
        for (var i = 0; i < 34; i++) {'id': 'c$i', 'content_status': 'valide'},
      ],
    );

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final state in allMockupStates()) {
      testWidgets('capture écran Wird ${state.name} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(() => state.now),
            wirdOverviewProvider.overrideWith((ref) async => state.entries),
            isAdminProvider.overrideWithValue(true),
            wirdRepairContentProvider.overrideWith((ref) async => _repair()),
            tariqaConditionsProvider.overrideWith((ref) async => _conditions()),
            tariqaBenefitsRowsProvider.overrideWith((ref) async => _benefits()),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: captureTheme(),
              locale: locale,
              supportedLocales: const [Locale('fr'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Scaffold(
                  // Barre d'app du shell (titre de l'onglet), sans ses actions.
                  appBar: AppBar(title: Text(AppLocalizations.of(context)!.navWird)),
                  body: const WirdListScreen(),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'wird_${state.name}_${locale.languageCode}');
      });
    }
  }
}
