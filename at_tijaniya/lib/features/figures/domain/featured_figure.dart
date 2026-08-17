/// Résolution de la "Figure de la semaine" affichée sur l'accueil — logique
/// pure, testable indépendamment de Riverpod/Supabase, même principe que
/// `home/domain/home_dashboard.dart`.
library;

import '../../khadara/domain/khadara_models.dart' show KhadaraEvent;
import 'figure_models.dart';

/// Lundi ISO (minuit local) de la semaine contenant [now] — convention
/// utilisée à la fois pour `featured_figures.week_start` (colonne `date`
/// côté serveur) et pour la rotation automatique ci-dessous.
DateTime weekStartFor(DateTime now) {
  final date = DateTime(now.year, now.month, now.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

/// Figures éligibles à la rotation automatique. La demande du porteur de
/// projet est une carte "avec une photo de la figure" : une figure sans
/// portrait n'y apparaît donc jamais, même avec une biographie complète
/// (état des lieux du 2026-08-17 : 8 des 10 figures valides n'ont pas encore
/// de portrait — exclues jusqu'à ce qu'un admin en ajoute un). Triées par id
/// pour un ordre stable d'une exécution à l'autre.
List<Figure> eligibleForRotation(List<Figure> figures) {
  return figures.where((figure) => figure.portraitUrl != null).toList()..sort((a, b) => a.id.compareTo(b.id));
}

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
/// sur la rotation, même si la figure visée n'a pas de portrait (l'admin est
/// réputé avoir fait ce choix en connaissance de cause). Sans épinglage
/// valide, rotation déterministe sur [eligibleForRotation] : reproductible
/// sans aucun état à écrire côté client.
///
/// `null` si aucune figure n'est éligible (aucun portrait en base) et
/// qu'aucun épinglage n'est actif — état honnête plutôt qu'une figure par
/// défaut inventée.
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

  final weeksSinceEpoch = weekStartFor(now ?? DateTime.now()).difference(_rotationEpoch).inDays ~/ 7;
  return eligible[weeksSinceEpoch % eligible.length];
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
