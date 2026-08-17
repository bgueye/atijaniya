/// Modèles et logique pure du tableau de bord Accueil — "Statut du jour,
/// accès rapide, prochain horaire" (docs/03-architecture-ecrans.md, P0).
/// Fonctions testables indépendamment de Riverpod/SharedPreferences, même
/// principe que `wird_progress_stats.dart` : ce fichier ne fait aucune
/// I/O, juste de la logique sur des données déjà chargées.
library;

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
HomeResumableSession? pickResumableSession(List<({Wird wird, TasbihSession? session})> loaded) {
  HomeResumableSession? best;
  for (final entry in loaded) {
    final session = entry.session;
    if (session == null) continue;
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
HomeNextReminder? pickNextReminderToday(
  List<({Wird wird, List<WirdReminderSetting> settings})> loaded, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final isFriday = today.weekday == DateTime.friday;
  final nowMinutes = today.hour * 60 + today.minute;

  HomeNextReminder? best;
  int? bestMinutes;
  for (final entry in loaded) {
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
