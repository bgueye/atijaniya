/// Calcul des statistiques d'historique/progression du Wird — P1
/// "Historique & progression : régularité, jours consécutifs, taux de
/// complétion" (docs/03-architecture-ecrans.md).
///
/// Fonctions pures, testables indépendamment de Riverpod/SharedPreferences :
/// prennent la liste des dates de complétion et retournent des statistiques
/// "simples" (docs/01-perimetre-fonctionnel.md §5.1), pas de moyenne glissante
/// ni de calcul avancé.
library;

import 'wird_models.dart';

class WirdPeriodStatus {
  const WirdPeriodStatus({required this.date, required this.completed});

  /// Jour du calendrier (wirds quotidiens) ou vendredi (Hadratou-l-Jouma).
  final DateTime date;
  final bool completed;
}

class WirdProgressStats {
  const WirdProgressStats({
    required this.currentStreak,
    required this.totalCompletions,
    required this.completionRate,
    required this.ratePeriods,
    required this.recentPeriods,
  });

  /// Nombre de périodes consécutives (jours, ou vendredis pour
  /// Hadratou-l-Jouma) terminées jusqu'à aujourd'hui — ne se réinitialise pas
  /// tant que la période du jour même n'est pas encore passée sans être
  /// faite.
  final int currentStreak;

  final int totalCompletions;

  /// Taux de complétion sur les [ratePeriods] dernières périodes (0.0–1.0).
  final double completionRate;

  final int ratePeriods;

  /// Dernières périodes (les plus récentes en dernier), pour un affichage en
  /// points façon habit-tracker.
  final List<WirdPeriodStatus> recentPeriods;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Vendredi le plus récent inférieur ou égal à [today] — seul jour valide de
/// Hadratou-l-Jouma dans le corpus validé (`wirds_content.dart`). Couplage
/// assumé : c'est le seul wird hebdomadaire de l'app à ce jour.
DateTime _mostRecentFriday(DateTime today) {
  final diff = (today.weekday - DateTime.friday) % 7;
  return today.subtract(Duration(days: diff));
}

DateTime _currentPeriod(DateTime today, WirdFrequency frequency) {
  return frequency == WirdFrequency.weekly ? _mostRecentFriday(today) : today;
}

DateTime _previousPeriod(DateTime period, WirdFrequency frequency) {
  return period.subtract(Duration(days: frequency == WirdFrequency.weekly ? 7 : 1));
}

WirdProgressStats computeWirdProgressStats({
  required WirdFrequency frequency,
  required List<DateTime> completionDates,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final completed = completionDates.map(_dateOnly).toSet();
  final ratePeriods = frequency == WirdFrequency.weekly ? 8 : 30;
  final dotsWindow = frequency == WirdFrequency.weekly ? 8 : 14;

  var cursor = _currentPeriod(today, frequency);
  if (!completed.contains(cursor)) {
    // Ne casse pas la série juste parce que la période du jour n'est pas
    // encore faite : on regarde si la précédente enchaîne toujours.
    cursor = _previousPeriod(cursor, frequency);
  }
  var streak = 0;
  while (completed.contains(cursor)) {
    streak++;
    cursor = _previousPeriod(cursor, frequency);
  }

  final window = <WirdPeriodStatus>[];
  var periodCursor = _currentPeriod(today, frequency);
  var completedInWindow = 0;
  for (var i = 0; i < ratePeriods; i++) {
    final isCompleted = completed.contains(periodCursor);
    if (isCompleted) completedInWindow++;
    if (i < dotsWindow) {
      window.add(WirdPeriodStatus(date: periodCursor, completed: isCompleted));
    }
    periodCursor = _previousPeriod(periodCursor, frequency);
  }

  return WirdProgressStats(
    currentStreak: streak,
    totalCompletions: completed.length,
    completionRate: ratePeriods == 0 ? 0 : completedInWindow / ratePeriods,
    ratePeriods: ratePeriods,
    recentPeriods: window.reversed.toList(),
  );
}
