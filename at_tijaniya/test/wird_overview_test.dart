// Écran Wird (refonte du 2026-11-02) : logique pure (`wird_overview.dart`) et
// rendu des trois états de la maquette (`docs/maquettes/ecran-wird.html`),
// d'après les décisions validées dans `docs/maquettes/README.md`.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/core/theme/app_theme.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_overview.dart';
import 'package:at_tijaniya/features/wird/domain/wird_progress_stats.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_band.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'wird_overview_fixtures.dart';

Widget _wrap(WirdMockupState state, {Locale locale = const Locale('fr'), bool admin = false, Object? loadError}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => state.now),
      wirdOverviewProvider.overrideWith((ref) async {
        if (loadError != null) throw loadError;
        return state.entries;
      }),
      isAdminProvider.overrideWithValue(admin),
      wirdRepairContentProvider.overrideWith((ref) async => WirdRepairContent(cases: const [], notes: const [])),
      tariqaConditionsProvider.overrideWith((ref) async => const <TariqaCondition>[]),
      tariqaBenefitsRowsProvider.overrideWith(
          (ref) async => (sections: const <Map<String, dynamic>>[], cards: const <Map<String, dynamic>>[])),
    ],
    child: MaterialApp(
      theme: AppTheme.standard,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: WirdListScreen()),
    ),
  );
}

/// Fenêtre haute : la liste ne construit que ce qui est visible, et les
/// tests portent sur les trois cartes à la fois.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('logique', () {
    test('dimanche matin : rien de fait, la Hadra ne se commence pas', () {
      final state = sundayMorning();
      final [l, w, h] = state.entries;
      expect(l.doneToday, isFalse);
      expect(l.canStart, isTrue);
      expect(l.stats.currentStreak, 6);
      expect(w.stats.currentStreak, 3);
      expect(h.canStart, isFalse, reason: 'Hadra hors vendredi : pas de Commencer');
      expect(h.doneToday, isFalse, reason: 'faite vendredi dernier, pas aujourd\'hui');
      expect(nextFriday(state.now), DateTime(2026, 11, 6));
      expect(w.last7Days, [true, true, false, true, true, true, false]);
    });

    test('dimanche soir : Lazim fait et replié mais encore commençable, Wazifa en pause', () {
      final [l, w, _] = sundayEvening().entries;
      expect(l.doneToday, isTrue);
      expect(l.collapsed, isTrue);
      expect(l.canStart, isTrue, reason: 'Commencer reste affiché quand le wird est fait');
      expect(w.paused, isTrue);
      expect(w.collapsed, isFalse);
    });

    test('vendredi : la Hadra passe en tête et se commence', () {
      final state = friday();
      final ordered = orderForToday(state.entries, state.now);
      expect(ordered.first.wird, hadratouJouma);
      expect(ordered.first.canStart, isTrue);
      expect(ordered.first.stats.currentStreak, 2);
    });

    test('puces : pas d\'intention ni de Fatiha, noms courts du corpus', () {
      final entry = sundayMorning().entries[1];
      expect([for (final p in entry.chipPillars) p.labelFor(arabic: false)],
          ['Istighfar', 'Salatoul Fatihi', 'Hailala', 'Jawharatoul Kamal']);
      expect([for (final p in entry.chipPillars) p.repetitions], [30, 50, 100, 12]);
      expect(entry.chipPillars.first.labelFor(arabic: true), 'الاستغفار');
      expect(entry.chipPillars[1].labelFor(arabic: true), 'صلاة الفاتح');
      // Jawharatoul Kamal : son texte arabe est déjà son nom.
      expect(entry.chipPillars.last.labelFor(arabic: true), 'جَوْهَرَةُ الْكَمَالِ');
    });

    test('rappel : le prochain de la journée, sinon le premier, sinon rien', () {
      const settings = [
        WirdReminderSetting(slotId: 'a', enabled: true, hour: 6, minute: 30),
        WirdReminderSetting(slotId: 'b', enabled: true, hour: 19, minute: 5),
      ];
      expect(reminderTimeLabel(settings, DateTime(2026, 11, 1, 8)), '19:05');
      expect(reminderTimeLabel(settings, DateTime(2026, 11, 1, 21)), '06:30');
      expect(
          reminderTimeLabel(
              const [WirdReminderSetting(slotId: 'a', enabled: false, hour: 6, minute: 0)], DateTime(2026)),
          isNull);
    });

    test('bandeau : semaine du lundi en français, du samedi en arabe ; caché avant la première récitation', () {
      final state = sundayMorning();
      final monday = buildWeekStrip(state.entries, state.now);
      expect(monday.first.date, DateTime(2026, 10, 26));
      expect(monday.last.isToday, isTrue);
      expect(monday[2].done, {'lazim'}, reason: 'mercredi : Wazifa non marquée');
      final saturday = buildWeekStrip(state.entries, state.now, firstWeekday: DateTime.saturday);
      expect(saturday.first.date, DateTime(2026, 10, 31));
      expect(saturday[1].isToday, isTrue);
      expect(saturday.last.isFuture, isTrue);

      final empty = [
        for (final e in state.entries)
          WirdOverviewEntry(
            wird: e.wird,
            stats: computeWirdProgressStats(frequency: e.wird.frequency, completionDates: const [], now: state.now),
          )
      ];
      expect(showWeekStrip(empty), isFalse);
      expect(showWeekStrip(state.entries), isTrue);
    });
  });

  group('écran', () {
    testWidgets('dimanche matin : états, piliers, actions, prochain vendredi', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(sundayMorning()));
      await tester.pumpAndSettle();

      expect(find.text('Cette semaine'.toUpperCase()), findsOneWidget);
      expect(find.text('À faire aujourd\'hui'), findsNWidgets(2));
      expect(find.text('Vendredi 6 novembre'), findsOneWidget);
      expect(find.text('Istighfar'), findsNWidgets(3));
      expect(find.text('×100'), findsWidgets);
      // Deux « Commencer » : Lazim et Wazifa ; pas pour la Hadra hors vendredi.
      expect(find.widgetWithText(FilledButton, 'Commencer'), findsNWidgets(2));
      expect(find.widgetWithText(OutlinedButton, 'Guide'), findsNWidgets(3));
      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('6 jours d\'affilée'), findsOneWidget);
      expect(find.textContaining('uniquement le vendredi entre l\'Asr'), findsOneWidget);
    });

    testWidgets('dimanche soir : Lazim replié et « Fait », Wazifa « Reprendre » avec sa progression', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(sundayEvening()));
      await tester.pumpAndSettle();

      expect(find.text('Fait aujourd\'hui'), findsOneWidget);
      expect(find.text('En pause'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reprendre'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Commencer'), findsOneWidget, reason: 'Lazim fait, encore commençable');
      expect(find.text('Pilier 4 / 6 · Salatoul Fatihi — 18 / 50'), findsOneWidget);
      // Lazim replié : ses puces ont disparu, il reste celles de la Wazifa
      // et de la Hadra.
      expect(find.text('Istighfar'), findsNWidgets(2));
    });

    testWidgets('vendredi : la Hadra en tête, avec « Commencer »', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(friday()));
      await tester.pumpAndSettle();

      expect(find.text('Aujourd\'hui, vendredi'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Commencer'), findsNWidgets(3));
      // Les noms des bandeaux (la légende du bandeau de la semaine les porte
      // aussi, sur une même ligne).
      Finder band(String name) => find.descendant(of: find.byType(WirdBand), matching: find.text(name));
      final hadra = tester.getTopLeft(band('Hadratou-l-Jouma')).dy;
      final lazimY = tester.getTopLeft(band('Lazim')).dy;
      expect(hadra, lessThan(lazimY));
    });

    testWidgets('en arabe : noms courts arabes des piliers', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(sundayMorning(), locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('صلاة الفاتح'), findsWidgets);
      expect(find.text('الاستغفار'), findsWidgets);
    });

    testWidgets('administration : une ligne en bas, seulement pour l\'admin', (tester) async {
      await tester.pumpWidget(_wrap(sundayMorning()));
      await tester.pumpAndSettle();
      expect(find.text('Administration · audios des wirds', skipOffstage: false), findsNothing);

      await tester.pumpWidget(_wrap(sundayMorning(), admin: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Administration · audios des wirds'), 300);
      await tester.tap(find.text('Administration · audios des wirds'));
      await tester.pumpAndSettle();
      expect(find.text('Récitations à valider'), findsOneWidget);
      expect(find.text('Gestion des récitations audio'), findsOneWidget);
    });
  });

  // Audit des écrans refaits du 2026-11-03 : sans données locales lues, les
  // cartes annonçaient « À faire aujourd'hui » et « 0 jours d'affilée ».
  testWidgets("données locales illisibles : ni état ni série inventés, actions gardées", (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(sundayMorning(), loadError: StateError('stockage illisible')));
    await tester.pumpAndSettle();

    expect(find.text("À faire aujourd'hui"), findsNothing);
    expect(find.textContaining("d'affilée"), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Commencer'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Guide'), findsNWidgets(3));
  });
}
