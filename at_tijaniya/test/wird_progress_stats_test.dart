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

    test('taux plafonné à une fenêtre de 30 jours', () {
      // Première récitation il y a 59 jours, puis un jour sur deux.
      final dates = List.generate(30, (i) => DateTime(2026, 8, 6 - 2 * i));
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: dates,
        now: today,
      );
      expect(stats.ratePeriods, 30);
      expect(stats.completedInRateWindow, 15);
      expect(stats.completionRate, closeTo(15 / 30, 0.001));
    });

    test('taux compté depuis la première récitation quand elle a moins de 30 jours', () {
      // Trois premiers jours de pratique, sans en manquer un : 3 sur 3, pas 3 sur 30.
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [DateTime(2026, 8, 4), DateTime(2026, 8, 5), DateTime(2026, 8, 6)],
        now: today,
      );
      expect(stats.ratePeriods, 3);
      expect(stats.completedInRateWindow, 3);
      expect(stats.completionRate, 1);
      expect(stats.firstCompletion, DateTime(2026, 8, 4));
    });

    test("la journée en cours, pas encore faite, n'entre pas dans le taux", () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [DateTime(2026, 8, 3), DateTime(2026, 8, 5)],
        now: today,
      );
      // 3, 4 (manqué) et 5 août ; le 6 reste à faire.
      expect(stats.ratePeriods, 3);
      expect(stats.completedInRateWindow, 2);
      expect(stats.recentPeriods.last.state, WirdPeriodState.pending);
    });

    test('aucune récitation : pas de fenêtre de taux', () {
      final stats = computeWirdProgressStats(frequency: WirdFrequency.daily, completionDates: const [], now: today);
      expect(stats.ratePeriods, 0);
      expect(stats.firstCompletion, isNull);
    });

    test('calendrier : semaines entières, états distincts pour manqué, à venir et avant le début', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.daily,
        completionDates: [DateTime(2026, 8, 3), DateTime(2026, 8, 5)],
        now: today, // jeudi 6 août
      );
      final days = buildWirdCalendar(stats: stats);
      WirdPeriodState stateOf(int day) => days.firstWhere((d) => d.date == DateTime(2026, 8, day)).state;

      expect(days.length, 35);
      expect(days.first.date, DateTime(2026, 7, 6)); // lundi, quatre semaines avant celle en cours
      expect(days.first.date.weekday, DateTime.monday);
      expect(days.last.date, DateTime(2026, 8, 9)); // dimanche de la semaine en cours
      expect(days.first.state, WirdPeriodState.beforeStart);
      expect(stateOf(2), WirdPeriodState.beforeStart);
      expect(stateOf(3), WirdPeriodState.done);
      expect(stateOf(4), WirdPeriodState.missed);
      expect(stateOf(6), WirdPeriodState.pending);
      expect(stateOf(7), WirdPeriodState.upcoming);
    });

    test('calendrier : la semaine commence le samedi quand la langue le demande', () {
      final stats = computeWirdProgressStats(frequency: WirdFrequency.daily, completionDates: const [], now: today);
      final days = buildWirdCalendar(stats: stats, firstWeekday: DateTime.saturday);
      expect(days.first.date.weekday, DateTime.saturday);
      expect(days.last.date, DateTime(2026, 8, 7)); // vendredi
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

    test('un vendredi manqué, vu le samedi, compte dans le taux', () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.weekly,
        completionDates: [DateTime(2026, 7, 24), DateTime(2026, 7, 31)],
        now: DateTime(2026, 8, 8),
      );
      expect(stats.ratePeriods, 3);
      expect(stats.completedInRateWindow, 2);
      expect(stats.recentPeriods.last.state, WirdPeriodState.missed);
      // Vendredis antérieurs à la première Hadra : ni faits ni manqués.
      expect(stats.recentPeriods.first.state, WirdPeriodState.beforeStart);
    });

    test("le vendredi même, pas encore fait, n'est pas compté comme manqué", () {
      final stats = computeWirdProgressStats(
        frequency: WirdFrequency.weekly,
        completionDates: [DateTime(2026, 7, 31)],
        now: DateTime(2026, 8, 7),
      );
      expect(stats.ratePeriods, 1);
      expect(stats.recentPeriods.last.state, WirdPeriodState.pending);
    });
  });
}
