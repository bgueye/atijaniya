/// Chargement des données du tableau de bord Accueil — orchestre les stores
/// locaux déjà existants du module Wird (aucune nouvelle persistance créée
/// ici) et applique la logique pure de `home_dashboard.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/current_day.dart';

import '../../wird/data/wird_completion_store.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/data/tasbih_session_store.dart';
import '../../wird/data/wird_reminder_store.dart';
import '../../wird/domain/tasbih_session.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_progress_stats.dart';
import '../../wird/domain/wird_reminder.dart';
import '../domain/home_dashboard.dart';

class HomeDashboardData {
  const HomeDashboardData({
    required this.statuses,
    required this.todayStatus,
    this.resumableSession,
    this.nextReminder,
    this.nextStep,
    this.unmarkedYesterday = const [],
  });

  final List<HomeWirdStatus> statuses;
  final HomeTodayStatus todayStatus;
  final HomeResumableSession? resumableSession;
  final HomeNextReminder? nextReminder;

  /// Étape proposée par la carte d'action de l'accueil ; `null` quand tout
  /// est accompli (`pickNextStep`).
  final HomeNextStep? nextStep;

  /// Wirds quotidiens non marqués la veille, seulement si le disciple a
  /// marqué au moins un wird ces 7 derniers jours (`isUnmarkedYesterday`,
  /// `isRecentlyActive`) — alimente la carte de rattrapage du carrousel.
  final List<Wird> unmarkedYesterday;
}

/// `autoDispose` : recharge à chaque retour sur l'accueil plutôt que de
/// garder un état périmé (un wird terminé ou une session de tasbih avancée
/// entre deux visites doit se refléter immédiatement) — même principe que
/// `wirdHistoryControllerProvider`.
///
/// Dépend du jour courant (`currentDayProvider`, audit de l'accueil du
/// 2026-10-26, P1) : recalculé au passage de minuit et au retour au premier
/// plan un autre jour — sinon le statut de la veille restait affiché.
final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  ref.watch(currentDayProvider);
  final now = ref.read(clockProvider)();
  const completionStore = WirdCompletionStore();
  const sessionStore = TasbihSessionStore();
  const reminderStore = WirdReminderStore();

  final statuses = <HomeWirdStatus>[];
  final completedDays = <Set<DateTime>>[];
  final unmarkedCandidates = <Wird>[];
  final sessions = <({Wird wird, TasbihSession? session})>[];
  final reminders = <({Wird wird, List<WirdReminderSetting> settings})>[];

  // Les trois stores de chaque wird lus en parallèle (audit de l'accueil du
  // 2026-10-26, P3-5) plutôt que l'un après l'autre ; l'ordre des wirds est
  // gardé.
  final loaded = await Future.wait(validatedWirds.map((wird) async {
    final (dates, session, settings) = await (
      completionStore.load(wird.id),
      sessionStore.load(wird.id),
      reminderStore.load(wird.id),
    ).wait;
    return (wird: wird, dates: dates, session: session, settings: settings);
  }));

  for (final entry in loaded) {
    final wird = entry.wird;
    final stats = computeWirdProgressStats(frequency: wird.frequency, completionDates: entry.dates, now: now);
    statuses.add(HomeWirdStatus(
      wird: wird,
      doneToday: stats.recentPeriods.isNotEmpty && stats.recentPeriods.last.completed,
      streak: stats.currentStreak,
    ));
    completedDays.add(stats.completedDays);
    if (isUnmarkedYesterday(
      frequency: wird.frequency,
      completedDays: stats.completedDays,
      firstCompletion: stats.firstCompletion,
      now: now,
    )) {
      unmarkedCandidates.add(wird);
    }
    sessions.add((wird: wird, session: entry.session));
    reminders.add((wird: wird, settings: entry.settings));
  }

  final doneIds = {
    for (final s in statuses)
      if (s.doneToday) s.wird.id
  };
  final resumable = pickResumableSession(sessions);
  final nextReminder = pickNextReminderToday(reminders, now: now, doneWirdIds: doneIds);
  return HomeDashboardData(
    statuses: statuses,
    todayStatus: summarizeTodayStatus(statuses, now: now),
    resumableSession: resumable,
    nextReminder: nextReminder,
    nextStep: pickNextStep(statuses: statuses, resumable: resumable, nextReminder: nextReminder, now: now),
    unmarkedYesterday: isRecentlyActive(completedDays, now: now) ? unmarkedCandidates : const [],
  );
});
