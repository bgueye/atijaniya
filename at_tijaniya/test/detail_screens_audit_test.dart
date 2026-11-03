// Corrections de l'audit des écrans refaits du 2026-11-03, étape 1
// (`docs/audits/2026-11-03-ecrans-refaits.md`) : fiche d'une zawiya
// (« Actuel » seulement si la période le dit, mention de liste incomplète)
// et fiche d'un évènement passé. Successions factices, sur le modèle de
// celles relevées en base (Nioro du Sahel, mokaddems de Fès).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/event_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/zawiya_detail_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'detail_screens_test_support.dart';

FigureKhalifaLink _link(int order, String name, String? period, {bool gap = false}) => FigureKhalifaLink(
      id: 'l$order',
      founderFigureId: 'fondateur',
      zawiyaId: 'z-test',
      khalifaFigureId: 'f$order',
      khalifaNameFr: name,
      khalifaNameAr: name,
      khalifaCategory: FigureCategory.religiousFamily,
      orderIndex: order,
      periodText: period,
      followsGap: gap,
    );

const _zawiya = Zawiya(id: 'z-test', name: 'Zawiya de test');

Widget _app(Widget home, {List<ZawiyaSuccession> successions = const [], List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [
      ...detailOverrides(),
      successionsForZawiyaProvider('z-test').overrideWith((ref) async => successions),
      figuresForZawiyaProvider('z-test').overrideWith((ref) async => const []),
      ...extra,
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('titulaire actuel d\'une succession', () {
    test('seulement le dernier maillon, et seulement si sa période le dit', () {
      expect(isCurrentSuccessionHolder(_link(5, 'A', 'depuis 2017'), isLast: true), isTrue);
      expect(isCurrentSuccessionHolder(_link(2, 'B', 'actuel'), isLast: true), isTrue);
      expect(isCurrentSuccessionHolder(_link(2, 'B', 'Actuel'), isLast: true), isTrue);
      // Nioro du Sahel : période close.
      expect(isCurrentSuccessionHolder(_link(2, 'C', '2007–2024'), isLast: true), isFalse);
      // Ségou : pas de période, rien n'est affirmé.
      expect(isCurrentSuccessionHolder(_link(2, 'D', null), isLast: true), isFalse);
      expect(isCurrentSuccessionHolder(_link(1, 'E', 'depuis 2006'), isLast: false), isFalse);
    });
  });

  group('évènement passé', () {
    final now = DateTime(2026, 11, 3, 12);
    KhadaraEvent event(DateTime start, {DateTime? end, bool approximate = false, bool recurring = false}) =>
        KhadaraEvent(
          id: 'e',
          title: 'Rendez-vous',
          type: KhadaraEventType.ziyara,
          startsAt: start,
          endsAt: end,
          isDateApproximate: approximate,
          isRecurring: recurring,
          recurrenceDayOfWeek: recurring ? DateTime.friday : null,
          recurrenceHour: recurring ? 17 : null,
          recurrenceMinute: recurring ? 0 : null,
        );

    test('date exacte d\'hier : passé ; aujourd\'hui ou plus tard : non', () {
      expect(isEventPast(event(DateTime(2026, 11, 2, 9)), now: now), isTrue);
      expect(isEventPast(event(DateTime(2026, 11, 3, 8)), now: now), isFalse);
      expect(isEventPast(event(DateTime(2026, 11, 4)), now: now), isFalse);
    });

    test('évènement sur plusieurs jours : passé seulement après le jour de fin', () {
      expect(isEventPast(event(DateTime(2026, 11, 1), end: DateTime(2026, 11, 3, 20)), now: now), isFalse);
    });

    test('date approximative ou récurrent : jamais passé', () {
      expect(isEventPast(event(DateTime(2026, 10, 1), approximate: true), now: now), isFalse);
      expect(isEventPast(event(DateTime(2025, 1, 3, 17), recurring: true), now: now), isFalse);
    });
  });

  testWidgets('zawiya : pas d\'« Actuel » sur une période close, liste incomplète signalée', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      const ZawiyaDetailScreen(zawiya: _zawiya),
      successions: [
        ZawiyaSuccession(
          zawiyaId: 'z-test',
          zawiyaName: 'Zawiya de test',
          role: SuccessionRole.khalife,
          founderFigureId: 'fondateur',
          links: [_link(1, 'Premier khalife', "jusqu'en 2007"), _link(2, 'Second khalife', '2007–2024')],
        ),
        ZawiyaSuccession(
          zawiyaId: 'z-test',
          zawiyaName: 'Zawiya de test',
          role: SuccessionRole.mokaddem,
          founderFigureId: 'fondateur',
          links: [_link(1, 'Premier mokaddem', null), _link(8, 'Mokaddem actuel', 'actuel', gap: true)],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Second khalife'), findsOneWidget);
    // Un seul « Actuel » : le mokaddem dont la période le dit, pas le
    // dernier khalife (2007–2024).
    expect(find.text('Actuel'), findsOneWidget);
    final actuel = tester.getTopLeft(find.text('Actuel')).dy;
    expect((actuel - tester.getTopLeft(find.text('Mokaddem actuel')).dy).abs(), lessThan(40));
    expect(find.text('Liste incomplète : des noms manquent ici.'), findsOneWidget);
    // La mention est entre les deux mokaddems.
    final gap = tester.getTopLeft(find.text('Liste incomplète : des noms manquent ici.')).dy;
    expect(gap, greaterThan(tester.getTopLeft(find.text('Premier mokaddem')).dy));
    expect(gap, lessThan(tester.getTopLeft(find.text('Mokaddem actuel')).dy));
  });

  testWidgets('évènement passé : « Passé », pas d\'annonce de direct ni de bouton pour le démarrer', (tester) async {
    _tall(tester);
    final now = DateTime.now();
    final past = KhadaraEvent(
      id: 'e-passe',
      zawiyaId: 'z-tivaouane',
      zawiyaName: 'Zawiya de Tivaouane',
      title: 'Gamou passé',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(now.year, now.month, now.day - 30, 9),
      createdBy: 'moi',
    );
    await tester.pumpWidget(_app(
      EventDetailScreen(event: past),
      extra: [
        latestStreamForEventProvider('e-passe').overrideWith((ref) async => null),
        // L'auteur de l'évènement pourrait démarrer un direct s'il était à venir.
        currentUserIdProvider.overrideWithValue('moi'),
        isAdminProvider.overrideWithValue(false),
        myManagedZawiyaIdProvider.overrideWithValue(null),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Passé'), findsOneWidget);
    expect(find.text('Ce rendez-vous est passé'), findsOneWidget);
    expect(find.text("Il apparaîtra ici dès qu'il commence."), findsNothing);
    expect(find.text('Démarrer un direct'), findsNothing);
  });

  testWidgets('évènement à venir : l\'auteur peut toujours démarrer un direct', (tester) async {
    _tall(tester);
    final now = DateTime.now();
    final upcoming = KhadaraEvent(
      id: 'e-avenir',
      title: 'Gamou à venir',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(now.year, now.month, now.day + 3, 9),
      createdBy: 'moi',
    );
    await tester.pumpWidget(_app(
      EventDetailScreen(event: upcoming),
      extra: [
        latestStreamForEventProvider('e-avenir').overrideWith((ref) async => null),
        currentUserIdProvider.overrideWithValue('moi'),
        isAdminProvider.overrideWithValue(false),
        myManagedZawiyaIdProvider.overrideWithValue(null),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Passé'), findsNothing);
    expect(find.text('Démarrer un direct'), findsOneWidget);
  });
}
