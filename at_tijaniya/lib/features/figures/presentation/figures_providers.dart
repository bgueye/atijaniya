import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../khadara/domain/khadara_models.dart' show KhadaraEvent;
import '../data/figures_repository.dart';
import '../domain/featured_figure.dart';
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

/// Tous les maillons de la silsila historique — utilisé par l'onglet
/// Silsila (admin) pour retrouver le maillon propre à la figure consultée
/// et par `FigureSilsilaFormScreen` pour suggérer un rang à partir de celui
/// de la figure parente choisie.
final silsilaLinksProvider = FutureProvider<List<FigureSilsilaLink>>((ref) {
  return ref.watch(figuresRepositoryProvider).fetchAllSilsilaLinks();
});

/// Évènements Khadara liés à une figure donnée (onglet "Ziyaras",
/// `figure_detail_screen.dart`) — `family` car paramétré par `figureId`.
final linkedEventsForFigureProvider = FutureProvider.family<List<KhadaraEvent>, String>((ref, figureId) {
  return ref.watch(figuresRepositoryProvider).fetchLinkedEvents(figureId);
});

/// Épinglage admin ("Figure de la semaine") pour une semaine donnée —
/// `family` sur le lundi de la semaine (voir `weekStartFor`) pour que
/// l'écran admin puisse consulter/préparer une semaine autre que la
/// courante (ex. la semaine d'un Gamou à venir) sans perturber
/// `featuredFigureProvider`, qui ne regarde toujours que la semaine
/// courante.
final featuredFigureOverrideProvider = FutureProvider.family<String?, DateTime>((ref, weekStart) {
  return ref.watch(figuresRepositoryProvider).fetchFeaturedFigureOverride(weekStart);
});

/// Figure mise en avant sur l'accueil pour la semaine courante — épinglage
/// admin s'il existe, sinon rotation automatique (voir
/// `pickFigureOfTheWeek`). `null` tant qu'aucune figure valide n'a de
/// portrait et qu'aucun épinglage n'est actif : l'accueil masque alors la
/// carte plutôt que d'afficher un état vide.
final featuredFigureProvider = FutureProvider<FeaturedFigure?>((ref) async {
  final weekStart = weekStartFor(DateTime.now());
  final repo = ref.watch(figuresRepositoryProvider);

  final figures = await ref.watch(figuresProvider.future);
  final overrideId = await ref.watch(featuredFigureOverrideProvider(weekStart).future);
  final figure = pickFigureOfTheWeek(figures, overrideFigureId: overrideId);
  if (figure == null) return null;

  KhadaraEvent? nextZiyara;
  final now = DateTime.now();
  for (final event in await repo.fetchLinkedEvents(figure.id)) {
    if (event.startsAt.isAfter(now)) {
      nextZiyara = event;
      break;
    }
  }

  return FeaturedFigure(
    figure: figure,
    citation: figure.citations != null && figure.citations!.isNotEmpty ? figure.citations!.first : null,
    nextZiyara: nextZiyara,
    pinned: overrideId == figure.id,
  );
});
