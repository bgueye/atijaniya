import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_progress_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeWirdProgressStats — wird quotidien', () {
    final today = DateTime(2026, 8, 6); // jeudi

    test('série en cours : compte les jours consécutifs jusqu\'à hier si le jour même n\'est pas encore fait', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [
          DateTime(2026, 8, 3),
          DateTime(2026, 8, 4),
          DateTime(2026, 8, 5),
        ],
        now: today,
      );
      expect(stats.currentStreak, 3);
    });

    test('série en cours : inclut aujourd\'hui s\'il est déjà fait', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [
          DateTime(2026, 8, 4),
          DateTime(2026, 8, 5),
          DateTime(2026, 8, 6),
        ],
        now: today,
      );
      expect(stats.currentStreak, 3);
    });

    test('série cassée par un jour manqué', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [
          DateTime(2026, 8, 1),
          DateTime(2026, 8, 2),
          // 3 août manqué
          DateTime(2026, 8, 4),
          DateTime(2026, 8, 5),
        ],
        now: today,
      );
      expect(stats.currentStreak, 2);
    });

    test('aucune complétion : série à zéro', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: const [],
        now: today,
      );
      expect(stats.currentStreak, 0);
      expect(stats.totalCompletions, 0);
      expect(stats.completionRate, 0);
    });

    test('taux de complétion calculé sur la fenêtre de 30 jours', () {
      final dates = List.generate(15, (i) => today.subtract(Duration(days: i)));
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: dates,
        now: today,
      );
      expect(stats.ratePeriods, 30);
      expect(stats.completionRate, closeTo(15 / 30, 0.001));
    });

    test('les points récents sont triés du plus ancien au plus récent', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [today],
        now: today,
      );
      expect(stats.recentPeriods.last.date, today);
      expect(stats.recentPeriods.last.completed, isTrue);
      expect(stats.recentPeriods.length, 14);
    });
  });

  group('computeWirdProgressStats — Hadratou-l-Jouma (hebdomadaire, vendredi)', () {
    test('la série ne compte que les vendredis', () {
      // 2026-08-07 est un vendredi ; on se place le samedi suivant.
      final friday1 = DateTime(2026, 7, 24);
      final friday2 = DateTime(2026, 7, 31);
      final friday3 = DateTime(2026, 8, 7);
      final saturdayAfter = DateTime(2026, 8, 8);

      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.weekly,
        completionDates: [friday1, friday2, friday3],
        now: saturdayAfter,
      );
      expect(stats.currentStreak, 3);
      expect(stats.recentPeriods.every((p) => p.date.weekday == DateTime.friday), isTrue);
    });

    test('un vendredi manqué casse la série', () {
      final friday1 = DateTime(2026, 7, 24);
      // 31 juillet manqué
      final friday3 = DateTime(2026, 8, 7);

      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.weekly,
        completionDates: [friday1, friday3],
        now: DateTime(2026, 8, 8),
      );
      expect(stats.currentStreak, 1);
    });
  });
}
