import 'package:at_tijaniya/features/home/domain/home_dashboard.dart';
import 'package:at_tijaniya/features/wird/data/wird_reminder_slots.dart';
import 'package:at_tijaniya/features/wird/domain/tasbih_session.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

Wird _wird(String id, WirdFrequency frequency) => Wird(
      id: id,
      nameArabic: id,
      nameFrench: id,
      frequency: frequency,
      pillars: const [],
    );

final _lazim = _wird('lazim', WirdFrequency.daily);
final _wazifa = _wird('wazifa', WirdFrequency.daily);
final _hadratouJouma = _wird('hadratou_jouma', WirdFrequency.weekly);

void main() {
  group('summarizeTodayStatus', () {
    // Lundi 17/08/2026 — jamais un vendredi, pour isoler le comportement
    // "wird hebdomadaire hors de sa période".
    final monday = DateTime(2026, 8, 17);
    // Vendredi 21/08/2026.
    final friday = DateTime(2026, 8, 21);

    test('wird hebdomadaire exclu du calcul un jour ordinaire', () {
      final result = summarizeTodayStatus([
        HomeWirdStatus(wird: _lazim, doneToday: true, streak: 1),
        HomeWirdStatus(wird: _wazifa, doneToday: true, streak: 1),
        HomeWirdStatus(wird: _hadratouJouma, doneToday: false, streak: 0),
      ], now: monday);

      expect(result.kind, HomeStatusKind.allDone);
      expect(result.totalCount, 2);
      expect(result.doneCount, 2);
    });

    test('wird hebdomadaire inclus le vendredi', () {
      final result = summarizeTodayStatus([
        HomeWirdStatus(wird: _lazim, doneToday: true, streak: 1),
        HomeWirdStatus(wird: _wazifa, doneToday: true, streak: 1),
        HomeWirdStatus(wird: _hadratouJouma, doneToday: false, streak: 0),
      ], now: friday);

      expect(result.kind, HomeStatusKind.partial);
      expect(result.totalCount, 3);
      expect(result.doneCount, 2);
    });

    test('aucun wird accompli -> noneDone', () {
      final result = summarizeTodayStatus([
        HomeWirdStatus(wird: _lazim, doneToday: false, streak: 0),
        HomeWirdStatus(wird: _wazifa, doneToday: false, streak: 0),
      ], now: monday);

      expect(result.kind, HomeStatusKind.noneDone);
      expect(result.doneCount, 0);
    });

    test('liste vide -> noneDone, total 0', () {
      final result = summarizeTodayStatus(const [], now: monday);
      expect(result.kind, HomeStatusKind.noneDone);
      expect(result.totalCount, 0);
    });
  });

  group('pickResumableSession', () {
    test('aucune session -> null', () {
      expect(
        pickResumableSession([(wird: _lazim, session: null), (wird: _wazifa, session: null)]),
        isNull,
      );
    });

    test('choisit la session la plus récemment modifiée', () {
      final older = TasbihSession(
        wirdId: _lazim.id,
        pillarIndex: 0,
        currentCount: 5,
        mode: TasbihMode.manual,
        updatedAt: DateTime(2026, 8, 20, 8),
      );
      final newer = TasbihSession(
        wirdId: _wazifa.id,
        pillarIndex: 1,
        currentCount: 2,
        mode: TasbihMode.manual,
        updatedAt: DateTime(2026, 8, 20, 19),
      );

      final result = pickResumableSession([
        (wird: _lazim, session: older),
        (wird: _wazifa, session: newer),
      ]);

      expect(result?.wird.id, 'wazifa');
      expect(result?.session.currentCount, 2);
    });
  });

  group('pickNextReminderToday', () {
    final at18h00 = DateTime(2026, 8, 21, 18); // vendredi

    test('ignore un rappel désactivé', () {
      final result = pickNextReminderToday([
        (wird: _lazim, settings: [const WirdReminderSetting(slotId: 'lazim_evening', enabled: false, hour: 19, minute: 0)]),
      ], now: at18h00);
      expect(result, isNull);
    });

    test('ignore un rappel déjà passé aujourd\'hui', () {
      final result = pickNextReminderToday([
        (wird: _lazim, settings: [const WirdReminderSetting(slotId: 'lazim_morning', enabled: true, hour: 7, minute: 0)]),
      ], now: at18h00);
      expect(result, isNull);
    });

    test('rappel hebdomadaire ignoré hors vendredi, inclus le vendredi', () {
      final monday = DateTime(2026, 8, 17, 10);
      final settings = [
        (wird: _hadratouJouma, settings: [const WirdReminderSetting(slotId: 'hadratou_jouma_weekly', enabled: true, hour: 19, minute: 0)]),
      ];

      expect(pickNextReminderToday(settings, now: monday), isNull);
      expect(pickNextReminderToday(settings, now: at18h00)?.wird.id, 'hadratou_jouma');
    });

    test('choisit le plus proche parmi plusieurs wirds', () {
      final result = pickNextReminderToday([
        (wird: _lazim, settings: [const WirdReminderSetting(slotId: 'lazim_evening', enabled: true, hour: 20, minute: 0)]),
        (wird: _wazifa, settings: [const WirdReminderSetting(slotId: 'wazifa_daily', enabled: true, hour: 19, minute: 0)]),
      ], now: at18h00);

      expect(result?.wird.id, 'wazifa');
      expect(result?.setting.hour, 19);
    });

    test('identifiant de créneau inconnu -> ignoré sans planter', () {
      final result = pickNextReminderToday([
        (wird: _lazim, settings: [const WirdReminderSetting(slotId: 'inexistant', enabled: true, hour: 20, minute: 0)]),
      ], now: at18h00);
      expect(result, isNull);
    });
  });

  // Refonte de l'accueil du 2026-11-01.
  group('rappel d\'un wird déjà fait', () {
    test('pickNextReminderToday ignore un wird accompli aujourd\'hui', () {
      final result = pickNextReminderToday([
        (wird: _wazifa, settings: [const WirdReminderSetting(slotId: 'wazifa_daily', enabled: true, hour: 19, minute: 0)]),
        (wird: _lazim, settings: [const WirdReminderSetting(slotId: 'lazim_evening', enabled: true, hour: 20, minute: 0)]),
      ], now: DateTime(2026, 8, 21, 18), doneWirdIds: {'wazifa'});
      expect(result?.wird.id, 'lazim');
    });
  });

  group('pickNextStep', () {
    final monday = DateTime(2026, 8, 17, 10);
    HomeWirdStatus status(Wird wird, {bool done = false}) => HomeWirdStatus(wird: wird, doneToday: done, streak: 0);

    test('tout accompli : aucune étape', () {
      expect(pickNextStep(statuses: [status(_lazim, done: true), status(_wazifa, done: true)], now: monday), isNull);
    });

    test('Hadratou-l-Jouma non faite un lundi : ne compte pas', () {
      expect(
        pickNextStep(statuses: [status(_lazim, done: true), status(_wazifa, done: true), status(_hadratouJouma)], now: monday),
        isNull,
      );
    });

    test('sans rappel ni session : premier wird à faire, dans l\'ordre du corpus', () {
      final step = pickNextStep(statuses: [status(_lazim), status(_wazifa)], now: monday);
      expect(step?.status.wird.id, 'lazim');
    });

    test('le wird du prochain rappel passe avant l\'ordre du corpus', () {
      final reminder = HomeNextReminder(
        wird: _wazifa,
        setting: const WirdReminderSetting(slotId: 'wazifa_daily', enabled: true, hour: 18, minute: 0),
        slot: wirdReminderSlots['wazifa']!.first,
      );
      final step = pickNextStep(statuses: [status(_lazim), status(_wazifa)], nextReminder: reminder, now: monday);
      expect(step?.status.wird.id, 'wazifa');
      expect(step?.reminder, same(reminder));
    });

    test('une session de tasbih en pause passe en premier', () {
      final session = HomeResumableSession(
        wird: _wazifa,
        session: TasbihSession(wirdId: 'wazifa', pillarIndex: 1, currentCount: 3, mode: TasbihMode.manual, updatedAt: monday),
      );
      final step = pickNextStep(statuses: [status(_lazim), status(_wazifa)], resumable: session, now: monday);
      expect(step?.status.wird.id, 'wazifa');
      expect(step?.resumable, same(session));
    });

    test('une session d\'un wird déjà accompli est ignorée', () {
      final session = HomeResumableSession(
        wird: _lazim,
        session: TasbihSession(wirdId: 'lazim', pillarIndex: 1, currentCount: 3, mode: TasbihMode.manual, updatedAt: monday),
      );
      final step = pickNextStep(statuses: [status(_lazim, done: true), status(_wazifa)], resumable: session, now: monday);
      expect(step?.status.wird.id, 'wazifa');
      expect(step?.resumable, isNull);
    });
  });

  group('wird d\'hier non marqué', () {
    final now = DateTime(2026, 11, 1, 9);

    test('wird quotidien non marqué hier, pratique déjà commencée', () {
      expect(
        isUnmarkedYesterday(
          frequency: WirdFrequency.daily,
          completedDays: {DateTime(2026, 10, 30)},
          firstCompletion: DateTime(2026, 10, 30),
          now: now,
        ),
        isTrue,
      );
    });

    test('marqué hier : rien à signaler', () {
      expect(
        isUnmarkedYesterday(
          frequency: WirdFrequency.daily,
          completedDays: {DateTime(2026, 10, 31)},
          firstCompletion: DateTime(2026, 10, 30),
          now: now,
        ),
        isFalse,
      );
    });

    test('jamais pratiqué, ou commencé aujourd\'hui : rien à signaler', () {
      expect(
        isUnmarkedYesterday(frequency: WirdFrequency.daily, completedDays: const {}, firstCompletion: null, now: now),
        isFalse,
      );
      expect(
        isUnmarkedYesterday(
          frequency: WirdFrequency.daily,
          completedDays: {DateTime(2026, 11, 1)},
          firstCompletion: DateTime(2026, 11, 1),
          now: now,
        ),
        isFalse,
      );
    });

    test('jamais pour un wird hebdomadaire', () {
      expect(
        isUnmarkedYesterday(
          frequency: WirdFrequency.weekly,
          completedDays: {DateTime(2026, 10, 23)},
          firstCompletion: DateTime(2026, 10, 23),
          now: DateTime(2026, 10, 31),
        ),
        isFalse,
      );
    });

    test('isRecentlyActive : au moins un wird marqué ces 7 derniers jours', () {
      expect(isRecentlyActive([{DateTime(2026, 10, 26)}], now: now), isTrue);
      expect(isRecentlyActive([{DateTime(2026, 10, 25)}, const {}], now: now), isFalse);
    });
  });

  test('dailyStreakOfTheDay : la plus courte des séries quotidiennes', () {
    expect(
      dailyStreakOfTheDay([
        HomeWirdStatus(wird: _lazim, doneToday: true, streak: 5),
        HomeWirdStatus(wird: _wazifa, doneToday: true, streak: 3),
        HomeWirdStatus(wird: _hadratouJouma, doneToday: false, streak: 1),
      ]),
      3,
    );
  });
}
