/// Chargement des données du tableau de bord Accueil — orchestre les stores
/// locaux déjà existants du module Wird (aucune nouvelle persistance créée
/// ici) et applique la logique pure de `home_dashboard.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final List<HomeWirdStatus> statuses;
  final HomeTodayStatus todayStatus;
  final HomeResumableSession? resumableSession;
  final HomeNextReminder? nextReminder;
}

/// `autoDispose` : recharge à chaque retour sur l'accueil plutôt que de
/// garder un état périmé (un wird terminé ou une session de tasbih avancée
/// entre deux visites doit se refléter immédiatement) — même principe que
/// `wirdHistoryControllerProvider`.
final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  const completionStore = WirdCompletionStore();
  const sessionStore = TasbihSessionStore();
  const reminderStore = WirdReminderStore();

  final statuses = <HomeWirdStatus>[];
  final sessions = <({Wird wird, TasbihSession? session})>[];
  final reminders = <({Wird wird, List<WirdReminderSetting> settings})>[];

  for (final wird in validatedWirds) {
    final dates = await completionStore.load(wird.id);
    final stats = computeWirdProgressStats(frequency: wird.frequency, completionDates: dates);
    statuses.add(HomeWirdStatus(
      wird: wird,
      doneToday: stats.recentPeriods.isNotEmpty && stats.recentPeriods.last.completed,
      streak: stats.currentStreak,
    ));

    sessions.add((wird: wird, session: await sessionStore.load(wird.id)));
    reminders.add((wird: wird, settings: await reminderStore.load(wird.id)));
  }

  return HomeDashboardData(
    statuses: statuses,
    todayStatus: summarizeTodayStatus(statuses),
    resumableSession: pickResumableSession(sessions),
    nextReminder: pickNextReminderToday(reminders),
  );
});
