/// Calcul des statistiques d'historique/progression du Wird — P1
/// "Historique & progression : régularité, jours consécutifs, taux de
/// complétion" (docs/03-architecture-ecrans.md).
///
/// Fonctions pures, testables indépendamment de Riverpod/SharedPreferences :
/// prennent la liste des dates de complétion et retournent des statistiques
/// "simples" (docs/01-perimetre-fonctionnel.md §5.1), pas de moyenne glissante
/// ni de calcul avancé.
library;

import '../../../core/date/calendar_days.dart';
import 'wird_models.dart';

/// État d'une période (un jour, ou un vendredi pour Hadratou-l-Jouma) dans
/// l'historique. Cinq états plutôt qu'un booléen "fait / pas fait" : l'écran
/// d'historique confondait un jour manqué, la journée en cours pas encore
/// faite, un jour à venir et un jour antérieur au début de la pratique — tous
/// dessinés comme un échec (revue de design du 2026-10-06).
enum WirdPeriodState {
  /// Wird terminé ce jour-là.
  done,

  /// Jour passé, postérieur au début de la pratique, sans wird terminé.
  missed,

  /// Aujourd'hui, pas encore fait : ni un échec ni une réussite.
  pending,

  /// Jour futur (fin de la semaine en cours dans la grille).
  upcoming,

  /// Jour antérieur à la toute première récitation enregistrée : le disciple
  /// n'utilisait pas encore l'app, ce n'est pas un jour manqué.
  beforeStart,
}

class WirdPeriodStatus {
  const WirdPeriodStatus({required this.date, required this.state});

  /// Jour du calendrier (wirds quotidiens) ou vendredi (Hadratou-l-Jouma).
  final DateTime date;
  final WirdPeriodState state;

  bool get completed => state == WirdPeriodState.done;
}

class WirdProgressStats {
  const WirdProgressStats({
    required this.today,
    required this.frequency,
    required this.completedDays,
    required this.firstCompletion,
    required this.currentStreak,
    required this.totalCompletions,
    required this.completedInRateWindow,
    required this.ratePeriods,
    required this.recentPeriods,
  });

  /// Jour de référence du calcul (sans heure).
  final DateTime today;

  final WirdFrequency frequency;

  /// Jours (sans heure) où le wird a été terminé.
  final Set<DateTime> completedDays;

  /// Première récitation enregistrée, `null` si aucune.
  final DateTime? firstCompletion;

  /// Nombre de périodes consécutives (jours, ou vendredis pour
  /// Hadratou-l-Jouma) terminées jusqu'à aujourd'hui — ne se réinitialise pas
  /// tant que la période du jour même n'est pas encore passée sans être
  /// faite.
  final int currentStreak;

  final int totalCompletions;

  /// Périodes terminées parmi les [ratePeriods] prises en compte.
  final int completedInRateWindow;

  /// Nombre de périodes sur lesquelles porte le taux : au plus 30 jours (ou
  /// 8 vendredis), mais jamais plus que ce qui s'est écoulé depuis la première
  /// récitation. Avant, la fenêtre était toujours de 30 jours : un disciple
  /// qui avait pratiqué ses 3 premiers jours sans en manquer un lisait "10 %".
  /// La journée en cours n'entre dans le compte qu'une fois faite — elle
  /// n'est pas encore manquée. Vaut 0 tant qu'aucune récitation n'existe.
  final int ratePeriods;

  /// Taux de complétion sur [ratePeriods] (0.0–1.0).
  double get completionRate => ratePeriods == 0 ? 0 : completedInRateWindow / ratePeriods;

  /// Dernières périodes (les plus récentes en dernier, la dernière étant la
  /// période en cours) : 14 jours, ou 8 vendredis. Sert à la frise des
  /// vendredis de l'écran d'historique et au statut du jour de l'accueil.
  final List<WirdPeriodStatus> recentPeriods;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Vendredi le plus récent inférieur ou égal à [today] — seul jour valide de
/// Hadratou-l-Jouma dans le corpus validé (`wirds_content.dart`). Couplage
/// assumé : c'est le seul wird hebdomadaire de l'app à ce jour.
DateTime _mostRecentFriday(DateTime today) {
  final diff = (today.weekday - DateTime.friday) % 7;
  return addDays(today, -diff);
}

DateTime _currentPeriod(DateTime today, WirdFrequency frequency) {
  return frequency == WirdFrequency.weekly ? _mostRecentFriday(today) : today;
}

DateTime _previousPeriod(DateTime period, WirdFrequency frequency) {
  return addDays(period, frequency == WirdFrequency.weekly ? -7 : -1);
}

WirdPeriodState _stateOf(
  DateTime period, {
  required DateTime today,
  required Set<DateTime> completed,
  required DateTime? first,
}) {
  if (completed.contains(period)) return WirdPeriodState.done;
  if (period.isAfter(today)) return WirdPeriodState.upcoming;
  if (period == today) return WirdPeriodState.pending;
  if (first == null || period.isBefore(first)) return WirdPeriodState.beforeStart;
  return WirdPeriodState.missed;
}

WirdProgressStats computeWirdProgressStats({
  required WirdFrequency frequency,
  required List<DateTime> completionDates,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final completed = completionDates.map(_dateOnly).toSet();
  final first = completed.isEmpty ? null : completed.reduce((a, b) => a.isBefore(b) ? a : b);
  final maxRatePeriods = frequency == WirdFrequency.weekly ? 8 : 30;
  final dotsWindow = frequency == WirdFrequency.weekly ? 8 : 14;
  final current = _currentPeriod(today, frequency);

  var cursor = current;
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

  // Taux : on remonte depuis la dernière période "jouée" — la période en
  // cours si elle est faite ou déjà passée (un vendredi manqué, vu le samedi),
  // la précédente si c'est aujourd'hui et qu'il reste le temps de la faire —
  // sans jamais dépasser la première récitation.
  var rateCursor = current;
  if (!completed.contains(current) && current == today) {
    rateCursor = _previousPeriod(current, frequency);
  }
  var ratePeriods = 0;
  var completedInWindow = 0;
  while (first != null && ratePeriods < maxRatePeriods && !rateCursor.isBefore(first)) {
    ratePeriods++;
    if (completed.contains(rateCursor)) completedInWindow++;
    rateCursor = _previousPeriod(rateCursor, frequency);
  }

  final window = <WirdPeriodStatus>[];
  var periodCursor = current;
  for (var i = 0; i < dotsWindow; i++) {
    window.add(WirdPeriodStatus(
      date: periodCursor,
      state: _stateOf(periodCursor, today: today, completed: completed, first: first),
    ));
    periodCursor = _previousPeriod(periodCursor, frequency);
  }

  return WirdProgressStats(
    today: today,
    frequency: frequency,
    completedDays: completed,
    firstCompletion: first,
    currentStreak: streak,
    totalCompletions: completed.length,
    completedInRateWindow: completedInWindow,
    ratePeriods: ratePeriods,
    recentPeriods: window.reversed.toList(),
  );
}

/// Grille calendaire d'un wird quotidien : [weeks] semaines entières se
/// terminant par la semaine en cours, du plus ancien au plus récent, soit
/// `7 × weeks` jours — jours à venir de la semaine en cours compris, pour que
/// chaque colonne reste un même jour de la semaine.
///
/// [firstWeekday] suit la convention de `DateTime.weekday` (1 = lundi …
/// 7 = dimanche) ; il vient de la langue de l'interface (lundi en français,
/// samedi en arabe), d'où un calcul séparé de [computeWirdProgressStats], qui
/// ne connaît pas la langue.
List<WirdPeriodStatus> buildWirdCalendar({
  required WirdProgressStats stats,
  int firstWeekday = DateTime.monday,
  int weeks = 5,
}) {
  final sinceWeekStart = (stats.today.weekday - firstWeekday) % 7;
  final start = addDays(stats.today, -sinceWeekStart - 7 * (weeks - 1));
  return [
    for (var i = 0; i < 7 * weeks; i++)
      WirdPeriodStatus(
        date: addDays(start, i),
        state: _stateOf(
          addDays(start, i),
          today: stats.today,
          completed: stats.completedDays,
          first: stats.firstCompletion,
        ),
      ),
  ];
}
