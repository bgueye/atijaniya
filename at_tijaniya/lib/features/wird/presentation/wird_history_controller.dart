/// Contrôleur de l'écran "Historique & progression" du Wird — P1
/// (docs/03-architecture-ecrans.md).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_completion_store.dart';
import '../domain/wird_models.dart';
import '../domain/wird_progress_stats.dart';

class WirdHistoryState {
  const WirdHistoryState({this.loading = true, this.stats});

  final bool loading;
  final WirdProgressStats? stats;

  WirdHistoryState copyWith({bool? loading, WirdProgressStats? stats}) {
    return WirdHistoryState(loading: loading ?? this.loading, stats: stats ?? this.stats);
  }
}

/// `autoDispose` : recharge l'historique à chaque ouverture de l'écran
/// plutôt que de garder un état potentiellement périmé si un wird a été
/// terminé entre deux visites (voir `TasbihController.nextPillar()`).
final wirdHistoryControllerProvider =
    StateNotifierProvider.autoDispose.family<WirdHistoryController, WirdHistoryState, Wird>(
  (ref, wird) => WirdHistoryController(wird: wird),
);

class WirdHistoryController extends StateNotifier<WirdHistoryState> {
  WirdHistoryController({required this.wird}) : super(const WirdHistoryState()) {
    _load();
  }

  final Wird wird;
  final WirdCompletionStore _store = const WirdCompletionStore();

  Future<void> _load() async {
    List<DateTime> dates;
    try {
      dates = await _store.load(wird.id);
    } catch (_) {
      // Date enregistrée illisible : un historique vide plutôt qu'un
      // chargement sans fin (audits du 2026-10-04 et du 2026-10-25, P3-2).
      dates = const [];
    }
    // Écran quitté pendant la lecture (`.autoDispose`).
    if (!mounted) return;
    final stats = computeWirdProgressStats(frequency: wird.frequency, completionDates: dates);
    state = state.copyWith(loading: false, stats: stats);
  }
}
