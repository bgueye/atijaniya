/// Modèles de contenu du module Figures et enseignements.
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : les instances de ces modèles ne doivent être construites qu'à
/// partir d'un document explicitement marqué "validé". Les biographies de
/// figures fondatrices et de familles religieuses sont *actuellement à
/// l'état "à valider"* — aucun nom, date, filiation ou enseignement ne doit
/// être inventé ou complété par le modèle. Voir `data/figures_content.dart`.
library;

enum FigureCategory { founder, religiousFamily }

/// Un paragraphe de biographie (arabe optionnel + traduction), même forme que
/// `WirdParagraph` pour rester cohérent avec le module Wirds.
class FigureBiographyParagraph {
  const FigureBiographyParagraph({this.arabic, this.transliteration, required this.translation});

  final String? arabic;
  final String? transliteration;
  final String translation;
}

/// Une citation attribuée à la figure — toujours avec sa source, pour rester
/// traçable (docs/01 § 8 : "Recueil de citations et enseignements", P2).
class FigureCitation {
  const FigureCitation({this.arabic, this.transliteration, required this.translation, required this.source});

  final String? arabic;
  final String? transliteration;
  final String translation;

  /// Référence du document source de la citation — jamais une citation sans
  /// provenance identifiable.
  final String source;
}

class Figure {
  const Figure({
    required this.id,
    required this.nameArabic,
    required this.nameFrench,
    required this.category,
    this.summary,
    this.biography,
    this.citations,
    this.ziyaraNote,
  });

  final String id;
  final String nameArabic;
  final String nameFrench;
  final FigureCategory category;

  /// Résumé court affiché dans la liste — `null` tant qu'aucun résumé validé
  /// n'est disponible.
  final String? summary;

  final List<FigureBiographyParagraph>? biography;
  final List<FigureCitation>? citations;

  /// Ziyara associée (lieu/évènement de pèlerinage lié à cette figure) —
  /// simple note textuelle, pas de lien direct au calendrier Khadara pour
  /// l'instant (à faire une fois le module Khadara connecté à des données
  /// réelles).
  final String? ziyaraNote;
}
