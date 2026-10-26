/// Résolution de la "Figure de la semaine" affichée sur l'accueil — logique
/// pure, testable indépendamment de Riverpod/Supabase, même principe que
/// `home/domain/home_dashboard.dart`.
library;

import '../../../core/date/calendar_days.dart';
import '../../khadara/domain/khadara_models.dart' show KhadaraEvent;
import '../../lineage/domain/lineage_models.dart' show Foyer;
import 'figure_models.dart';

/// Lundi ISO (minuit local) de la semaine contenant [now] — convention
/// utilisée à la fois pour `featured_figures.week_start` (colonne `date`
/// côté serveur) et pour la rotation automatique ci-dessous.
DateTime weekStartFor(DateTime now) {
  final date = DateTime(now.year, now.month, now.day);
  return addDays(date, DateTime.monday - date.weekday);
}

/// Figures éligibles à la rotation automatique : toutes les figures reçues
/// (déjà filtrées `content_status = 'valide'`), triées par id pour un ordre
/// stable.
///
/// Jusqu'au 2026-10-26, seules les figures dotées d'un portrait l'étaient
/// (demande du 2026-08-17, « une carte avec une photo »). Résultat relevé par
/// l'audit de l'accueil (P2-3) : 22 des 32 figures éligibles venaient de
/// Tivaouane, Kaolack et Médina Baye, aucune d'Aïn Madhi. Décision du porteur
/// de projet du 2026-10-26 : les figures sans portrait entrent dans la
/// rotation, l'accueil leur donne une carte sans photo.
List<Figure> eligibleForRotation(List<Figure> figures) {
  return [...figures]..sort((a, b) => a.id.compareTo(b.id));
}

/// Foyer d'une figure pour la rotation : [Foyer.autre] quand il n'est pas
/// renseigné.
Foyer _rotationFoyer(Figure figure) => figure.foyer ?? Foyer.autre;

/// Époque fixe (lundi) servant d'ancre à la rotation automatique — choisie
/// avant le lancement de cette fonctionnalité, sans autre signification.
/// Compter les semaines entières écoulées depuis cette date plutôt que
/// d'utiliser le numéro de semaine ISO évite les ambiguïtés de fin/début
/// d'année (semaine 52/53 qui déborde sur l'année suivante).
final DateTime _rotationEpoch = DateTime(2026, 1, 5);

/// Choisit la figure de la semaine parmi [figures] (déjà filtrées
/// `content_status = 'valide'` par `FiguresRepository.fetchFigures`).
///
/// [overrideFigureId] (`featured_figures.figure_id` pour la semaine
/// courante, voir `featured_figure_providers.dart`) gagne toujours quand il
/// désigne une figure encore valide — un épinglage admin volontaire prime
/// sur la rotation. Sans épinglage valide, rotation déterministe,
/// reproductible sans aucun état à écrire côté client, **à tour de rôle entre
/// les foyers** (décision du porteur de projet du 2026-10-26, audit de
/// l'accueil P2-3) : la semaine n présente le foyer n mod k (foyers présents,
/// dans l'ordre de [Foyer]), puis, dans ce foyer, la figure suivante —
/// celles qui ont un portrait d'abord. Chaque foyer revient toutes les k
/// semaines, quel que soit son nombre de figures.
///
/// `null` si aucune figure n'est reçue et qu'aucun épinglage n'est actif —
/// état honnête plutôt qu'une figure par défaut inventée.
Figure? pickFigureOfTheWeek(
  List<Figure> figures, {
  String? overrideFigureId,
  DateTime? now,
}) {
  if (overrideFigureId != null) {
    for (final figure in figures) {
      if (figure.id == overrideFigureId) return figure;
    }
  }

  final eligible = eligibleForRotation(figures);
  if (eligible.isEmpty) return null;

  final byFoyer = <Foyer, List<Figure>>{};
  for (final figure in eligible) {
    byFoyer.putIfAbsent(_rotationFoyer(figure), () => []).add(figure);
  }
  final foyers = Foyer.values.where(byFoyer.containsKey).toList();
  for (final list in byFoyer.values) {
    // Portrait d'abord, puis ordre stable par id (déjà trié).
    list.sort((a, b) {
      final byPortrait = (a.portraitUrl == null ? 1 : 0).compareTo(b.portraitUrl == null ? 1 : 0);
      return byPortrait != 0 ? byPortrait : a.id.compareTo(b.id);
    });
  }

  // Arrondi sur les heures : une semaine contenant un changement d'heure
  // dure 167 ou 169 h, et `inDays ~/ 7` perdait alors une semaine entière.
  // Modulo positif : une date antérieure à l'époque ne doit pas planter.
  final weeksSinceEpoch = (weekStartFor(now ?? DateTime.now()).difference(_rotationEpoch).inHours / (7 * 24)).round();
  final foyer = foyers[weeksSinceEpoch % foyers.length];
  final inFoyer = byFoyer[foyer]!;
  return inFoyer[(weeksSinceEpoch ~/ foyers.length) % inFoyer.length];
}

/// Contenu affiché sur la carte "Figure de la semaine" — la figure elle-même
/// plus les deux éléments optionnels demandés (citation, date de ziara).
class FeaturedFigure {
  const FeaturedFigure({required this.figure, this.citation, this.nextZiyara, required this.pinned});

  final Figure figure;

  /// Première citation disponible, s'il y en a une — pas de sélection
  /// éditoriale plus fine pour l'instant (peu de figures ont plus d'une
  /// citation aujourd'hui).
  final FigureCitation? citation;

  /// Prochaine ziara à venir liée à cette figure (`figure_events` →
  /// `events.starts_at` dans le futur) — `null` s'il n'y en a aucune de
  /// programmée, plutôt que d'afficher une date déjà passée comme si elle
  /// était à venir.
  final KhadaraEvent? nextZiyara;

  /// `true` si épinglée par un admin pour cette semaine précise, `false` si
  /// choisie par la rotation automatique — purement informatif côté écran
  /// admin, sans effet sur l'affichage disciple.
  final bool pinned;
}
