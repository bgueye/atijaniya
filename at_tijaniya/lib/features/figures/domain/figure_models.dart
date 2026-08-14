/// Modèles de contenu du module Figures et enseignements.
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : contrairement au module Wirds (corpus statique dans
/// `wirds_content.dart`), ce contenu provient de la table Supabase
/// `figures` (voir `data/figures_repository.dart`), alimentée et validée
/// par le porteur de projet directement en base. La RLS
/// (`figures_read_valid_or_admin`) ne renvoie au client que les lignes
/// `content_status = 'valide'` : une figure en `brouillon` n'est jamais
/// lisible côté app, quoi qu'il arrive côté client. Aucun nom, date,
/// filiation ou enseignement ne doit être inventé ou complété par le
/// modèle — seul un enregistrement marqué `valide` en base fait foi.
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

/// Une œuvre écrite (livre, traité, diwan...) attribuée à la figure —
/// complète les citations sans les remplacer (demande du porteur de projet
/// du 2026-08-08). `description` reste `null` quand le texte source ne
/// donne aucun détail au-delà du titre (pas de résumé inventé).
class FigureWork {
  const FigureWork({required this.title, this.description});

  final String title;
  final String? description;
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
    this.works,
    this.ziyaraNote,
    this.portraitUrl,
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
  final List<FigureWork>? works;

  /// Ziyara associée (lieu/évènement de pèlerinage lié à cette figure) —
  /// simple note textuelle, pas de lien direct au calendrier Khadara pour
  /// l'instant (à faire une fois le module Khadara connecté à des données
  /// réelles).
  final String? ziyaraNote;

  /// Portrait (`figures.portrait_url`, bucket Storage `figure-portraits`) —
  /// `null` tant qu'aucun portrait n'a été ajouté. Contrairement au reste du
  /// contenu de cette figure, ce n'est pas du texte religieux soumis à la
  /// règle de validation de CLAUDE.md — juste une image, modifiable par un
  /// admin depuis `FigureDetailScreen`.
  final String? portraitUrl;

  /// Construit une figure à partir d'une ligne de la table Supabase
  /// `figures` (embarquant `figure_quotes` via PostgREST — voir
  /// `FiguresRepository.fetchFigures`).
  ///
  /// `bio_text` est un bloc de texte unique (sections séparées par une ligne
  /// vide) plutôt qu'une liste structurée arabe/translittération/traduction
  /// comme dans le module Wirds : chaque section devient un paragraphe. La
  /// section "SOURCES CONSULTÉES" (note de traçabilité interne au
  /// compilateur, pas un contenu destiné au disciple) est exclue de
  /// l'affichage.
  factory Figure.fromRow(Map<String, dynamic> row) {
    final quotesRows = row['figure_quotes'] as List<dynamic>?;
    final worksRows = row['figure_works'] as List<dynamic>?;
    return Figure(
      id: row['id'] as String,
      nameArabic: row['name_ar'] as String,
      nameFrench: row['name_fr'] as String,
      category: _categoryFromDb(row['category'] as String),
      summary: _summaryFrom(row['bio_text'] as String?),
      biography: _biographyFrom(row['bio_text'] as String?),
      citations: _citationsFrom(quotesRows),
      works: _worksFrom(worksRows),
      portraitUrl: row['portrait_url'] as String?,
    );
  }

  /// `portraitUrl` explicitement passable à `null` (retrait du portrait) —
  /// utilisé par `FigureDetailScreen` pour refléter localement un
  /// changement de portrait sans refetch réseau immédiat.
  Figure copyWithPortraitUrl(String? portraitUrl) {
    return Figure(
      id: id,
      nameArabic: nameArabic,
      nameFrench: nameFrench,
      category: category,
      summary: summary,
      biography: biography,
      citations: citations,
      works: works,
      ziyaraNote: ziyaraNote,
      portraitUrl: portraitUrl,
    );
  }
}

FigureCategory _categoryFromDb(String value) {
  return value == 'founder' ? FigureCategory.founder : FigureCategory.religiousFamily;
}

/// Un maillon de la silsila historique (généalogie spirituelle de la
/// tarikha), du fondateur jusqu'à la figure consultée — voir
/// `get_historical_silsila_chain()` (fonction Postgres,
/// `database/schema.sql`). Distinct de la silsila d'ijaza du mouqaddam
/// (§5.4.2, `get_ijaza_chain()`), qui décrit un tout autre graphe
/// (parrainage entre disciples vivants).
class HistoricalSilsilaLink {
  const HistoricalSilsilaLink({
    required this.figureId,
    required this.nameAr,
    required this.nameFr,
    required this.category,
    required this.orderIndex,
  });

  final String figureId;
  final String nameAr;
  final String nameFr;
  final FigureCategory category;
  final int orderIndex;

  factory HistoricalSilsilaLink.fromRow(Map<String, dynamic> row) {
    return HistoricalSilsilaLink(
      figureId: row['figure_id'] as String,
      nameAr: row['name_ar'] as String,
      nameFr: row['name_fr'] as String,
      category: _categoryFromDb(row['category'] as String),
      orderIndex: row['order_index'] as int,
    );
  }
}

List<String> _biographySections(String bioText) {
  return bioText
      .split('\n\n')
      .map((section) => section.trim())
      .where((section) => section.isNotEmpty)
      .where((section) => !section.toUpperCase().startsWith('SOURCES CONSULTÉES'))
      .toList();
}

List<FigureBiographyParagraph>? _biographyFrom(String? bioText) {
  if (bioText == null || bioText.trim().isEmpty) return null;
  final sections = _biographySections(bioText);
  if (sections.isEmpty) return null;
  return [for (final section in sections) FigureBiographyParagraph(translation: section)];
}

String? _summaryFrom(String? bioText) {
  if (bioText == null) return null;
  final sections = _biographySections(bioText);
  return sections.isEmpty ? null : sections.first;
}

List<FigureCitation>? _citationsFrom(List<dynamic>? quotesRows) {
  if (quotesRows == null || quotesRows.isEmpty) return null;
  return [
    for (final raw in quotesRows.cast<Map<String, dynamic>>())
      FigureCitation(
        arabic: raw['text_ar'] as String?,
        translation: (raw['text_fr'] as String?) ?? (raw['text_ar'] as String?) ?? '',
        source: (raw['source_note'] as String?) ?? '—',
      ),
  ];
}

List<FigureWork>? _worksFrom(List<dynamic>? worksRows) {
  if (worksRows == null || worksRows.isEmpty) return null;
  final rows = worksRows.cast<Map<String, dynamic>>().toList()
    ..sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
  return [
    for (final raw in rows) FigureWork(title: raw['title'] as String, description: raw['description'] as String?),
  ];
}
