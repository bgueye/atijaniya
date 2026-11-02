/// Chargement des données de l'écran Wird (refonte du 2026-11-02) : lit les
/// stores locaux déjà existants (complétions, session de tasbih en pause,
/// rappels) et calcule les séries. Aucune nouvelle persistance ; même
/// principe que `homeDashboardProvider`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/current_day.dart';
import '../data/tasbih_session_store.dart';
import '../data/wird_completion_store.dart';
import '../data/wird_reminder_store.dart';
import '../data/wirds_content.dart';
import '../domain/wird_overview.dart';
import '../domain/wird_progress_stats.dart';

/// Wirds du corpus validé avec leur état, dans l'ordre du corpus (l'ordre du
/// jour est appliqué par l'écran, `orderForToday`).
///
/// L'onglet Wird reste monté dans l'`IndexedStack` du shell : ce provider
/// n'est donc jamais libéré, et il est invalidé explicitement à l'arrivée sur
/// l'onglet (`HomeShell._selectTab`), au retour sur l'écran racine
/// (`_ReturnToRootObserver`, app.dart) et au passage de minuit
/// (`currentDayProvider`).
final wirdOverviewProvider = FutureProvider.autoDispose<List<WirdOverviewEntry>>((ref) async {
  ref.watch(currentDayProvider);
  final now = ref.read(clockProvider)();
  const completionStore = WirdCompletionStore();
  const sessionStore = TasbihSessionStore();
  const reminderStore = WirdReminderStore();

  return Future.wait(validatedWirds.map((wird) async {
    final (dates, session, reminders) = await (
      completionStore.load(wird.id),
      sessionStore.load(wird.id),
      reminderStore.load(wird.id),
    ).wait;
    return WirdOverviewEntry(
      wird: wird,
      stats: computeWirdProgressStats(frequency: wird.frequency, completionDates: dates, now: now),
      session: session,
      reminders: reminders,
    );
  }));
});
