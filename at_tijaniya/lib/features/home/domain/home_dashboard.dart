/// Modèles et logique pure du tableau de bord Accueil — "Statut du jour,
/// accès rapide, prochain horaire" (docs/03-architecture-ecrans.md, P0).
/// Fonctions testables indépendamment de Riverpod/SharedPreferences, même
/// principe que `wird_progress_stats.dart` : ce fichier ne fait aucune
/// I/O, juste de la logique sur des données déjà chargées.
library;

import '../../../core/date/calendar_days.dart';
import '../../wird/data/wird_reminder_slots.dart';
import '../../wird/domain/tasbih_session.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_reminder.dart';

/// Statut du jour (ou de la période en cours, pour un wird hebdomadaire)
/// d'un wird donné, plus sa série en cours — dérivé de
/// `WirdProgressStats` (voir `home_dashboard_provider.dart`).
class HomeWirdStatus {
  const HomeWirdStatus({required this.wird, required this.doneToday, required this.streak});

  final Wird wird;
  final bool doneToday;

  /// Périodes consécutives terminées (jours pour un wird quotidien,
  /// vendredis pour Hadratou-l-Jouma) — `WirdProgressStats.currentStreak`.
  final int streak;
}

enum HomeStatusKind { allDone, noneDone, partial }

/// Résumé du statut du jour, tous wirds confondus — seuls les wirds
/// "applicables aujourd'hui" comptent (un wird hebdomadaire n'entre dans
/// le calcul que le jour de sa période, jamais les autres jours : sinon
/// Hadratou-l-Jouma apparaîtrait "non fait" en permanence du samedi au
/// jeudi).
class HomeTodayStatus {
  const HomeTodayStatus({required this.kind, required this.doneCount, required this.totalCount});

  final HomeStatusKind kind;
  final int doneCount;
  final int totalCount;
}

bool _isApplicableToday(Wird wird, DateTime now) {
  return wird.frequency == WirdFrequency.daily || now.weekday == DateTime.friday;
}

HomeTodayStatus summarizeTodayStatus(List<HomeWirdStatus> statuses, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final applicable = statuses.where((s) => _isApplicableToday(s.wird, today)).toList();
  final total = applicable.length;
  final done = applicable.where((s) => s.doneToday).length;
  final kind = total == 0 || done == 0
      ? HomeStatusKind.noneDone
      : done == total
          ? HomeStatusKind.allDone
          : HomeStatusKind.partial;
  return HomeTodayStatus(kind: kind, doneCount: done, totalCount: total);
}

/// Une session de Tasbih en cours (chargée), avec le wird auquel elle
/// appartient — nécessaire pour résoudre le pilier courant
/// (`wird.pillars[session.pillarIndex]`) et pour la navigation de reprise
/// (`TasbihScreen(wird: wird)`, qui recharge la session automatiquement).
class HomeResumableSession {
  const HomeResumableSession({required this.wird, required this.session});

  final Wird wird;
  final TasbihSession session;
}

/// Choisit, parmi les sessions de Tasbih chargées pour chaque wird, celle
/// à proposer en priorité sur l'accueil — la plus récemment modifiée.
/// `TasbihSessionStore` ne conserve jamais de session "vide" (voir
/// `TasbihController.increment`/`nextPillar` : la première sauvegarde a
/// toujours `currentCount >= 1` ou `pillarIndex >= 1`), donc toute entrée
/// non nulle ici est déjà "en cours" au sens utile du terme.
///
/// Audit du 2026-11-03 : la plus récente était choisie avant d'écarter les
/// wirds déjà faits ([doneWirdIds]) et les sessions qu'on ne peut plus
/// reprendre (Hadra d'un autre vendredi, `isTasbihSessionResumable`) ;
/// `pickNextStep` l'écartait ensuite, et un Lazim en pause n'était plus
/// proposé. Le filtre passe donc avant le choix.
HomeResumableSession? pickResumableSession(
  List<({Wird wird, TasbihSession? session})> loaded, {
  DateTime? now,
  Set<String> doneWirdIds = const {},
}) {
  final today = now ?? DateTime.now();
  HomeResumableSession? best;
  for (final entry in loaded) {
    final session = entry.session;
    if (session == null) continue;
    if (doneWirdIds.contains(entry.wird.id)) continue;
    if (!isTasbihSessionResumable(session, weekly: entry.wird.frequency == WirdFrequency.weekly, now: today)) {
      continue;
    }
    if (best == null || session.updatedAt.isAfter(best.session.updatedAt)) {
      best = HomeResumableSession(wird: entry.wird, session: session);
    }
  }
  return best;
}

/// Un rappel programmé, avec le wird et le créneau (`WirdReminderSlot`,
/// pour son libellé) auxquels il appartient.
class HomeNextReminder {
  const HomeNextReminder({required this.wird, required this.setting, required this.slot});

  final Wird wird;
  final WirdReminderSetting setting;
  final WirdReminderSlot slot;
}

/// Prochain rappel activé qui reste à venir aujourd'hui, tous wirds
/// confondus — un rappel déjà passé n'est jamais montré (pas de "rappel du
/// matin" affiché l'après-midi), et un créneau hebdomadaire
/// (`ReminderFrequency.weeklyFriday`) n'est considéré que le vendredi.
/// `null` si aucun rappel activé ne reste à venir aujourd'hui — état
/// honnête plutôt qu'une estimation de "demain" non demandée.
///
/// Un wird déjà accompli aujourd'hui ([doneWirdIds]) n'a plus de rappel à
/// montrer : l'accueil affichait « Wazifa — aujourd'hui à 18:00 » sous une
/// Wazifa déjà cochée (refonte de l'accueil du 2026-11-01).
HomeNextReminder? pickNextReminderToday(
  List<({Wird wird, List<WirdReminderSetting> settings})> loaded, {
  DateTime? now,
  Set<String> doneWirdIds = const {},
}) {
  final today = now ?? DateTime.now();
  final isFriday = today.weekday == DateTime.friday;
  final nowMinutes = today.hour * 60 + today.minute;

  HomeNextReminder? best;
  int? bestMinutes;
  for (final entry in loaded) {
    if (doneWirdIds.contains(entry.wird.id)) continue;
    final slots = wirdReminderSlots[entry.wird.id] ?? const [];
    for (final setting in entry.settings) {
      if (!setting.enabled) continue;
      WirdReminderSlot? slot;
      for (final candidate in slots) {
        if (candidate.id == setting.slotId) {
          slot = candidate;
          break;
        }
      }
      if (slot == null) continue;
      if (slot.frequency == ReminderFrequency.weeklyFriday && !isFriday) continue;
      final minutes = setting.hour * 60 + setting.minute;
      if (minutes < nowMinutes) continue;
      if (bestMinutes == null || minutes < bestMinutes) {
        bestMinutes = minutes;
        best = HomeNextReminder(wird: entry.wird, setting: setting, slot: slot);
      }
    }
  }
  return best;
}

/// Wird quotidien non marqué la veille, alors que le disciple pratiquait déjà
/// avec l'app (première récitation enregistrée avant hier). « Non marqué » et
/// non « manqué » : l'app ne sait que ce que le disciple a coché. Jamais pour
/// un wird hebdomadaire (Hadratou-l-Jouma ne se rattrape pas, voir la carte
/// du vendredi).
bool isUnmarkedYesterday({
  required WirdFrequency frequency,
  required Set<DateTime> completedDays,
  required DateTime? firstCompletion,
  required DateTime now,
}) {
  if (frequency != WirdFrequency.daily || firstCompletion == null) return false;
  final today = _dateOnly(now);
  final yesterday = addDays(today, -1);
  if (_dateOnly(firstCompletion).isAfter(yesterday)) return false;
  return !completedDays.contains(yesterday);
}

/// Le disciple a-t-il marqué au moins un wird ces 7 derniers jours (aujourd'hui
/// compris) ? Garde-fou de la carte « wird d'hier non marqué » : un disciple
/// qui ne coche pas ses wirds dans l'app la verrait tous les jours.
bool isRecentlyActive(Iterable<Set<DateTime>> completedDaysPerWird, {required DateTime now}) {
  final today = _dateOnly(now);
  final start = addDays(today, -6);
  for (final days in completedDaysPerWird) {
    for (final day in days) {
      if (!day.isBefore(start) && !day.isAfter(today)) return true;
    }
  }
  return false;
}

/// L'étape à proposer en premier sur l'accueil (carte d'action), parmi les
/// wirds applicables aujourd'hui et pas encore faits :
/// 1. une session de Tasbih en pause, à reprendre ;
/// 2. le wird du prochain rappel de la journée ;
/// 3. sinon le premier wird à faire, dans l'ordre du corpus validé.
/// `null` quand tout est accompli.
class HomeNextStep {
  const HomeNextStep({required this.status, this.resumable, this.reminder});

  final HomeWirdStatus status;
  final HomeResumableSession? resumable;
  final HomeNextReminder? reminder;
}

HomeNextStep? pickNextStep({
  required List<HomeWirdStatus> statuses,
  HomeResumableSession? resumable,
  HomeNextReminder? nextReminder,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final pending = statuses.where((s) => _isApplicableToday(s.wird, today) && !s.doneToday).toList();
  if (pending.isEmpty) return null;
  HomeWirdStatus? statusOf(String wirdId) => pending.where((s) => s.wird.id == wirdId).firstOrNull;

  if (resumable != null) {
    final status = statusOf(resumable.wird.id);
    if (status != null) {
      final reminder = nextReminder?.wird.id == status.wird.id ? nextReminder : null;
      return HomeNextStep(status: status, resumable: resumable, reminder: reminder);
    }
  }
  if (nextReminder != null) {
    final status = statusOf(nextReminder.wird.id);
    if (status != null) return HomeNextStep(status: status, reminder: nextReminder);
  }
  return HomeNextStep(status: pending.first);
}

/// Série à afficher quand la journée est accomplie : la plus courte des
/// séries des wirds quotidiens (la journée entière n'est « tenue » que
/// depuis ce nombre de jours). 0 s'il n'y a aucun wird quotidien.
int dailyStreakOfTheDay(List<HomeWirdStatus> statuses) {
  final daily = statuses.where((s) => s.wird.frequency == WirdFrequency.daily).map((s) => s.streak);
  if (daily.isEmpty) return 0;
  return daily.reduce((a, b) => a < b ? a : b);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
