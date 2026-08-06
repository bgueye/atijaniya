import 'package:flutter_riverpod/flutter_riverpod.dart';

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
