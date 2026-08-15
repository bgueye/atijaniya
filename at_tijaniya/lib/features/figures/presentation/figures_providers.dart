import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../khadara/domain/khadara_models.dart' show KhadaraEvent;
import '../data/figures_repository.dart';
import '../domain/figure_models.dart';

final figuresRepositoryProvider = Provider<FiguresRepository>((ref) => const FiguresRepository());

final figuresProvider = FutureProvider<List<Figure>>((ref) {
  return ref.watch(figuresRepositoryProvider).fetchFigures();
});

/// Figures en brouillon, pour l'écran de review admin
/// (`FiguresReviewScreen`) — voir la note sur `is_admin` dans
/// `FiguresRepository.fetchDraftFigures`.
final draftFiguresProvider = FutureProvider<List<Figure>>((ref) {
  return ref.watch(figuresRepositoryProvider).fetchDraftFigures();
});

/// Silsila historique d'une figure donnée (onglet "Silsila",
/// `figure_detail_screen.dart`) — `family` car paramétré par `figureId`.
final historicalSilsilaChainProvider = FutureProvider.family<List<HistoricalSilsilaLink>, String>((ref, figureId) {
  return ref.watch(figuresRepositoryProvider).fetchHistoricalSilsilaChain(figureId);
});

/// Évènements Khadara liés à une figure donnée (onglet "Ziyaras",
/// `figure_detail_screen.dart`) — `family` car paramétré par `figureId`.
final linkedEventsForFigureProvider = FutureProvider.family<List<KhadaraEvent>, String>((ref, figureId) {
  return ref.watch(figuresRepositoryProvider).fetchLinkedEvents(figureId);
});
