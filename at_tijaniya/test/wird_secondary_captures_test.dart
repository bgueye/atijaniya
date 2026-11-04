// Captures des écrans secondaires du Wird mis au thème du kit le 2026-11-04
// (rappels, historique, rattrapage, conditions, bienfaits), en français et en
// arabe, avec les vraies polices : une image de l'écran entier, déroulé, par
// écran et par langue, plus l'état d'erreur des écrans qui en ont un.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).
// Textes d'exemple sans valeur religieuse, sauf les Bienfaits, qui reprennent
// la copie de la migration validée (`test/fixtures/tariqa_benefits_rows.json`).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/calendar_days.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/data/tariqa_benefits_repository.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_screen.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_history_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_reminders_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

WirdRepairCase _case(int order, RepairWird wird, RepairKind kind, String fr, {bool valid = true}) => WirdRepairCase(
      id: 'case-$order',
      orderIndex: order,
      wird: wird,
      kind: kind,
      situationFr: fr,
      situationAr: 'حالة مثال $order',
      actionFr: 'Réponse d’exemple pour « $fr ».',
      actionAr: 'جواب مثال $order',
      sourceFr: 'Source d’exemple $order',
      sourceAr: 'مصدر مثال $order',
      isValid: valid,
    );

WirdRepairNote _note(RepairWird wird, RepairNoteType type, int order, String fr, String ar) => WirdRepairNote(
      id: 'note-${wird.name}-${type.name}-$order',
      wird: wird,
      type: type,
      orderIndex: order,
      textFr: fr,
      textAr: ar,
      isValid: true,
    );

/// Rattrapage : un brouillon (bandeau admin), une mise en garde, des horaires.
WirdRepairContent _repair() => WirdRepairContent(
      cases: [
        _case(1, RepairWird.lazim, RepairKind.manque, 'Cas d’exemple du Lazim', valid: false),
        _case(2, RepairWird.lazim, RepairKind.interruption, 'Autre cas d’exemple'),
        _case(3, RepairWird.all, RepairKind.erreur, 'Règle commune d’exemple'),
      ],
      notes: [
        _note(RepairWird.lazim, RepairNoteType.quickAnswer, 1, 'Réponse rapide', 'جواب سريع'),
        _note(RepairWird.lazim, RepairNoteType.timing, 1, 'Horaire d’exemple : texte', 'وقت مثال : نص'),
        _note(RepairWird.lazim, RepairNoteType.warning, 1, 'Mise en garde d’exemple.', 'تنبيه مثال.'),
        _note(RepairWird.all, RepairNoteType.askMoqaddam, 1, 'Question d’exemple.', 'سؤال مثال.'),
      ],
    );

List<TariqaCondition> _conditions() => [
      for (var i = 1; i <= 4; i++)
        TariqaCondition(
          id: 'c$i',
          orderIndex: i,
          category: i <= 2 ? TariqaConditionCategory.validiteTalqin : TariqaConditionCategory.compagnonnage,
          textFr: 'Condition d’exemple numéro $i, sur deux lignes pour voir le retour à la ligne.',
          textAr: 'شرط مثال رقم $i',
          sourceNote: i.isEven ? 'Source d’exemple' : null,
        ),
    ];

TariqaBenefitsRows _benefits() {
  final json = jsonDecode(File('test/fixtures/tariqa_benefits_rows.json').readAsStringSync()) as Map<String, dynamic>;
  return (
    sections: [
      for (final r in (json['sections'] as List).cast<Map<String, dynamic>>()) {...r, 'content_status': 'valide'}
    ],
    cards: [
      for (final r in (json['cards'] as List).cast<Map<String, dynamic>>()) {...r, 'content_status': 'valide'}
    ],
  );
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Locale locale,
    Widget screen, {
    List<Override> overrides = const [],
    double height = 1600,
  }) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
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
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await captureToFile(tester, find.byKey(key), '${name}_${locale.languageCode}');
  }

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('capture rappels ($lang)', skip: skip != null, (tester) async {
      // Rappel du matin activé, notifications coupées : la mise en garde.
      SharedPreferences.setMockInitialValues({});
      await capture(tester, 'secondaire_rappels', locale, const WirdRemindersScreen(wird: lazim),
          overrides: [notificationsEnabledProvider.overrideWith((ref) async => false)], height: 900);
    });

    testWidgets('capture historique ($lang)', skip: skip != null, (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      SharedPreferences.setMockInitialValues({
        'wird_completions_${lazim.id}::guest': [
          for (final offset in [-20, -19, -18, -15, -12, -11, -10, -9, -6, -5, -4, -3, -2, -1, 0])
            _day(addDays(today, offset)),
        ],
      });
      await capture(tester, 'secondaire_historique', locale, const WirdHistoryScreen(wird: lazim), height: 1100);
    });

    testWidgets('capture rattrapage ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'secondaire_rattrapage', locale, const WirdRepairScreen(), overrides: [
        wirdRepairContentProvider.overrideWith((ref) async => _repair()),
        isAdminProvider.overrideWithValue(true),
      ]);
    });

    testWidgets('capture rattrapage en erreur ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'secondaire_rattrapage_erreur', locale, const WirdRepairScreen(),
          overrides: [wirdRepairContentProvider.overrideWith((ref) async => throw StateError('panne'))], height: 500);
    });

    testWidgets('capture conditions ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'secondaire_conditions', locale, const TariqaConditionsScreen(), overrides: [
        tariqaConditionsProvider.overrideWith((ref) async => _conditions()),
        isAdminProvider.overrideWithValue(false),
      ]);
    });

    testWidgets('capture conditions vides ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'secondaire_conditions_vides', locale, const TariqaConditionsScreen(),
          overrides: [
            tariqaConditionsProvider.overrideWith((ref) async => const []),
            isAdminProvider.overrideWithValue(false),
          ],
          height: 500);
    });

    testWidgets('capture bienfaits ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'secondaire_bienfaits', locale, const TariqaBenefitsScreen(),
          overrides: [
            tariqaBenefitsRowsProvider.overrideWith((ref) async => _benefits()),
            wirdRepairContentProvider.overrideWith((ref) async => WirdRepairContent(cases: const [], notes: const [])),
            isAdminProvider.overrideWithValue(false),
          ],
          height: 2600);
    });
  }
}
