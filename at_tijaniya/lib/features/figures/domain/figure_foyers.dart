/// Logique pure de l'onglet Figures refait le 2026-11-02 (maquette
/// `docs/maquettes/ecran-figures.html`, décisions validées dans
/// `docs/maquettes/README.md`) : ordre des foyers, nombre de disciples du
/// fondateur, arbre de silsila d'un foyer. Aucune I/O : les figures et les
/// liens de silsila (`historical_silsila_links`, lisibles une fois validés)
/// sont déjà chargés.
library;

import '../../lineage/domain/lineage_models.dart' show Foyer;
import 'figure_models.dart';

/// Ordre historique des foyers (décision validée du 2026-11-02) : Fès et
/// Aïn Madhi d'abord, puis la famille omarienne, Tivaouane, Kaolack, Médina
/// Baye ; « Autres foyers » toujours en dernier.
const historicalFoyerOrder = [
  Foyer.fes,
  Foyer.ainMadhi,
  Foyer.omarienne,
  Foyer.tivaouane,
  Foyer.kaolack,
  Foyer.medinaBaye,
  Foyer.autre,
];

/// Foyers présents parmi [figures], dans l'ordre historique, avec le foyer du
/// disciple connecté en premier s'il est renseigné ([userFoyer], lu dans sa
/// lignée déclarée : ne sert qu'à l'ordre d'affichage sur son téléphone).
/// « Autres foyers » reste en dernier même si c'est celui du disciple.
List<Foyer> orderedFoyers(List<Figure> figures, {Foyer? userFoyer}) {
  final present = figures.map((f) => f.foyer).whereType<Foyer>().toSet();
  final ordered = historicalFoyerOrder.where(present.contains).toList();
  if (userFoyer != null && userFoyer != Foyer.autre && ordered.remove(userFoyer)) {
    ordered.insert(0, userFoyer);
  }
  return ordered;
}

/// Nombre de figures rattachées directement à [figureId] dans la silsila
/// historique saisie dans l'app (liens dont il est le maître).
int discipleCount(String figureId, List<FigureSilsilaLink> links) =>
    links.where((l) => l.parentFigureId == figureId).length;

/// Un nœud de l'arbre de silsila d'un foyer, dans l'ordre d'affichage.
class FoyerSilsilaNode {
  const FoyerSilsilaNode({required this.figure, required this.depth, this.external = false, this.masterName});

  final Figure figure;

  /// Profondeur dans l'arbre (0 pour une racine).
  final int depth;

  /// Maître venu d'un autre foyer : affiché en pointillés, en tête de la
  /// branche de ses disciples du foyer.
  final bool external;

  /// Nom du maître quand le nœud n'est pas rangé directement sous lui (au-delà
  /// de la profondeur affichée), pour dire de qui il est le disciple.
  final String? masterName;
}

/// Arbre maître → disciple du [foyer], à partir des liens de silsila :
/// - chaque figure du foyer qui a un lien (ou qui est le maître d'une figure
///   du foyer) y figure ;
/// - un maître hors du foyer apparaît une fois, en racine, marqué [external] ;
/// - les figures du foyer sans aucun lien n'y sont pas (elles restent dans
///   la grille) ;
/// - parcours en profondeur, frères triés par rang puis par nom.
///
/// Ce n'est pas une généalogie : les liens sont historiques et incomplets,
/// l'écran le dit dans sa légende.
List<FoyerSilsilaNode> buildFoyerSilsilaTree(
  Foyer foyer,
  List<Figure> figures,
  List<FigureSilsilaLink> links, {
  int maxDepth = 4,
}) {
  final byId = {for (final f in figures) f.id: f};
  final parentOf = {for (final l in links) l.figureId: l.parentFigureId};
  final orderOf = {for (final l in links) l.figureId: l.orderIndex};
  final inFoyer = {
    for (final f in figures)
      if (f.foyer == foyer) f.id
  };

  // Enfants connus de chaque maître (seulement les liens dont les deux bouts
  // sont des figures chargées).
  final children = <String, List<String>>{};
  for (final l in links) {
    final parent = l.parentFigureId;
    if (parent == null || !byId.containsKey(parent) || !byId.containsKey(l.figureId)) continue;
    children.putIfAbsent(parent, () => []).add(l.figureId);
  }
  int compare(String a, String b) {
    final byOrder = (orderOf[a] ?? 0).compareTo(orderOf[b] ?? 0);
    return byOrder != 0 ? byOrder : byId[a]!.nameFrench.compareTo(byId[b]!.nameFrench);
  }

  // Les figures du foyer qui participent à l'arbre : liées à un maître, ou
  // maîtres d'une figure du foyer.
  final participants = <String>{
    for (final id in inFoyer)
      if ((parentOf[id] != null && byId.containsKey(parentOf[id])) || (children[id] ?? const []).any(inFoyer.contains))
        id,
  };

  // Racines : figures du foyer sans maître dans le foyer, regroupées sous
  // leur maître extérieur s'il est connu.
  final roots = <String>[];
  final externalRoots = <String, List<String>>{};
  for (final id in participants) {
    final parent = parentOf[id];
    if (parent != null && inFoyer.contains(parent)) continue;
    if (parent != null && byId.containsKey(parent)) {
      externalRoots.putIfAbsent(parent, () => []).add(id);
    } else {
      roots.add(id);
    }
  }

  final result = <FoyerSilsilaNode>[];
  final seen = <String>{};
  void visit(String id, int depth, String? master) {
    if (!seen.add(id)) return;
    final shownDepth = depth > maxDepth ? maxDepth : depth;
    result.add(FoyerSilsilaNode(
      figure: byId[id]!,
      depth: shownDepth,
      masterName: depth > maxDepth ? master : null,
    ));
    final kids = (children[id] ?? const []).where(inFoyer.contains).toList()..sort(compare);
    for (final kid in kids) {
      visit(kid, depth + 1, byId[id]!.nameFrench);
    }
  }

  final externalIds = externalRoots.keys.toList()..sort((a, b) => byId[a]!.nameFrench.compareTo(byId[b]!.nameFrench));
  for (final master in externalIds) {
    result.add(FoyerSilsilaNode(figure: byId[master]!, depth: 0, external: true));
    final kids = externalRoots[master]!..sort(compare);
    for (final kid in kids) {
      visit(kid, 1, byId[master]!.nameFrench);
    }
  }
  roots.sort(compare);
  for (final root in roots) {
    visit(root, 0, null);
  }
  return result;
}

/// Nombre de liens de silsila du foyer : figures du foyer rattachées à un
/// maître connu (dans le foyer ou non).
int foyerSilsilaLinkCount(Foyer foyer, List<Figure> figures, List<FigureSilsilaLink> links) {
  final ids = {for (final f in figures) f.id};
  final inFoyer = {
    for (final f in figures)
      if (f.foyer == foyer) f.id
  };
  return links.where((l) => inFoyer.contains(l.figureId) && ids.contains(l.parentFigureId)).length;
}
