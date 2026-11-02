/// Logique pure de l'écran Wird (refonte du 2026-11-02, maquette
/// `docs/maquettes/ecran-wird.html`) : état du jour de chaque wird, actions à
/// proposer, rappel à afficher, bandeau de la semaine. Aucune I/O ici, comme
/// `home_dashboard.dart` : le chargement est dans `wird_overview_provider.dart`.
///
/// Rien de nouveau n'est enregistré : complétions, sessions de tasbih en
/// pause et réglages de rappel existent déjà (stores du module Wird).
library;

import '../../../core/date/calendar_days.dart';
import 'tasbih_session.dart';
import 'wird_models.dart';
import 'wird_progress_stats.dart';
import 'wird_reminder.dart';

/// Ce que l'écran sait d'un wird, déjà chargé.
class WirdOverviewEntry {
  const WirdOverviewEntry({
    required this.wird,
    required this.stats,
    this.session,
    this.reminders = const [],
  });

  final Wird wird;
  final WirdProgressStats stats;

  /// Session de tasbih enregistrée (en pause), `null` s'il n'y en a pas.
  final TasbihSession? session;
  final List<WirdReminderSetting> reminders;

  bool get _weekly => wird.frequency == WirdFrequency.weekly;
  bool get _friday => stats.today.weekday == DateTime.friday;

  /// Le wird se récite-t-il aujourd'hui ? Toujours pour un wird quotidien ;
  /// le vendredi seulement pour la Hadratou-l-Jouma (« uniquement le
  /// vendredi entre l'Asr et le Maghreb », corpus validé).
  bool get applicableToday => !_weekly || _friday;

  /// « Commencer » (ou « Reprendre ») : seulement quand le wird se récite
  /// aujourd'hui. Il reste affiché quand le wird est déjà fait (décision du
  /// 2026-11-01 : le Lazim se récite matin et soir, la Wazifa de préférence
  /// deux fois par jour) ; seule exception, la Hadra hors vendredi.
  bool get canStart => applicableToday;

  /// Fait aujourd'hui. Pour la Hadra, seulement le vendredi même : le
  /// dimanche, la Hadra de vendredi dernier n'est pas « faite aujourd'hui »,
  /// la carte annonce le prochain vendredi.
  bool get doneToday => applicableToday && stats.completedDays.contains(stats.today);

  /// Session en pause à reprendre. Une session de la Hadra laissée un
  /// vendredi n'est pas proposée les autres jours (le créneau est passé).
  bool get paused => session != null && canStart;

  /// Carte repliée (sans ses piliers) : wird fait aujourd'hui et rien en
  /// pause — la carte garde sa série et toutes ses actions.
  bool get collapsed => doneToday && !paused;

  /// Piliers montrés en puces : ceux qui se répètent. L'intention et la
  /// Fatiha (une récitation chacune, communes aux trois wirds) n'en ont pas,
  /// comme dans la maquette ; elles restent dans le guide.
  List<WirdPillar> get chipPillars => [
        for (final pillar in wird.pillars)
          if (pillar.repetitions > 1) pillar
      ];

  /// Les 7 derniers jours, aujourd'hui en dernier (frise de la carte d'un
  /// wird quotidien).
  List<bool> get last7Days => [
        for (var i = 6; i >= 0; i--) stats.completedDays.contains(addDays(stats.today, -i)),
      ];
}

/// Heure à afficher sur le bouton Rappel : le prochain rappel activé de la
/// journée, sinon le premier de la journée (il sonnera demain). `null` si
/// aucun rappel n'est activé : le bouton dit alors seulement « Rappel ».
String? reminderTimeLabel(List<WirdReminderSetting> settings, DateTime now) {
  final enabled = [
    for (final s in settings)
      if (s.enabled) s
  ]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  if (enabled.isEmpty) return null;
  final nowMinutes = now.hour * 60 + now.minute;
  final next = enabled.firstWhere((s) => s.hour * 60 + s.minute >= nowMinutes, orElse: () => enabled.first);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(next.hour)}:${two(next.minute)}';
}

/// Ordre des cartes : celui du corpus validé, sauf le vendredi, où la
/// Hadratou-l-Jouma passe en tête (c'est son seul jour).
List<WirdOverviewEntry> orderForToday(List<WirdOverviewEntry> entries, DateTime now) {
  if (now.weekday != DateTime.friday) return entries;
  return [
    ...entries.where((e) => e.wird.frequency == WirdFrequency.weekly),
    ...entries.where((e) => e.wird.frequency != WirdFrequency.weekly),
  ];
}

/// Prochain vendredi strictement après [today] (la Hadra hors vendredi
/// annonce sa date).
DateTime nextFriday(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final diff = (DateTime.friday - day.weekday) % 7;
  return addDays(day, diff == 0 ? 7 : diff);
}

/// Un jour du bandeau de la semaine.
class WirdWeekDay {
  const WirdWeekDay({required this.date, required this.isToday, required this.isFuture, required this.done});

  final DateTime date;
  final bool isToday;
  final bool isFuture;

  /// Wirds marqués ce jour-là, par identifiant. Un wird absent est « non
  /// marqué », jamais « manqué » : l'app ne sait que ce qui est coché.
  final Set<String> done;
}

/// Semaine en cours, dans l'ordre de la langue de l'interface ([firstWeekday],
/// convention `DateTime.weekday` : lundi en français, samedi en arabe, comme
/// l'historique).
List<WirdWeekDay> buildWeekStrip(List<WirdOverviewEntry> entries, DateTime now, {int firstWeekday = DateTime.monday}) {
  final today = DateTime(now.year, now.month, now.day);
  final start = addDays(today, -((today.weekday - firstWeekday) % 7));
  return [
    for (var i = 0; i < 7; i++)
      () {
        final date = addDays(start, i);
        return WirdWeekDay(
          date: date,
          isToday: date == today,
          isFuture: date.isAfter(today),
          done: {
            for (final e in entries)
              if (e.stats.completedDays.contains(date)) e.wird.id
          },
        );
      }(),
  ];
}

/// Le bandeau de la semaine n'apparaît qu'après la première récitation
/// enregistrée (maquette, « Limites ») : avant, il ne montrerait que des
/// points vides.
bool showWeekStrip(List<WirdOverviewEntry> entries) => entries.any((e) => e.stats.firstCompletion != null);
