import 'package:at_tijaniya/features/home/domain/home_dashboard.dart';
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
}
