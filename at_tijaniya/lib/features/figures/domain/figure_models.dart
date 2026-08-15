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

import '../../lineage/domain/lineage_models.dart' show Foyer, foyerFromString;

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
  const FigureCitation({this.id, this.arabic, this.transliteration, required this.translation, required this.source});

  /// `figure_quotes.id` — `null` seulement pour une citation pas encore
  /// enregistrée (formulaire de création). Nécessaire pour cibler
  /// `updateCitation`/`deleteCitation`.
  final String? id;
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
  const FigureWork({this.id, required this.title, this.description, this.orderIndex = 0});

  /// `figure_works.id` — `null` seulement pour une œuvre pas encore
  /// enregistrée (formulaire de création). Nécessaire pour cibler
  /// `updateWork`/`deleteWork`.
  final String? id;
  final String title;
  final String? description;

  /// `figure_works.order_index` — position d'affichage (`created_at` seul
  /// n'est pas fiable pour un même insert groupé, voir `database/schema.sql`).
  final int orderIndex;
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
    this.portraitUrl,
    this.bioText,
    this.foyer,
    this.birthYearHijri,
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

  /// Portrait (`figures.portrait_url`, bucket Storage `figure-portraits`) —
  /// `null` tant qu'aucun portrait n'a été ajouté. Contrairement au reste du
  /// contenu de cette figure, ce n'est pas du texte religieux soumis à la
  /// règle de validation de CLAUDE.md — juste une image, modifiable par un
  /// admin depuis `FigureDetailScreen`.
  final String? portraitUrl;

  /// `figures.bio_text` brut, sans le découpage/filtrage fait par
  /// [_biographyFrom]/[_summaryFrom] pour l'affichage — nécessaire pour
  /// préremplir `FigureFormScreen` sans effacer silencieusement la section
  /// "SOURCES CONSULTÉES" ni la mise en forme d'origine.
  final String? bioText;

  /// `figures.foyer` — même énumération que la lignée du disciple
  /// (`Foyer`, `lineage/domain/lineage_models.dart`), réutilisée telle
  /// quelle plutôt que dupliquée.
  final Foyer? foyer;

  final int? birthYearHijri;

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
      bioText: row['bio_text'] as String?,
      foyer: row['foyer'] != null ? foyerFromString(row['foyer'] as String) : null,
      birthYearHijri: row['birth_year_hijri'] as int?,
    );
  }

  /// Reconstruit une `Figure` en ne remplaçant que les champs fournis —
  /// utilisé par `FigureDetailScreen` pour refléter localement un
  /// changement de portrait ou une édition, sans refetch réseau immédiat.
  /// Les champs non modifiables depuis l'app (`citations`/`works`) sont
  /// toujours repris de l'instance courante.
  Figure copyWith({
    String? nameArabic,
    String? nameFrench,
    FigureCategory? category,
    String? summary,
    List<FigureBiographyParagraph>? biography,
    Object? portraitUrl = _unset,
    String? bioText,
    Object? foyer = _unset,
    Object? birthYearHijri = _unset,
  }) {
    return Figure(
      id: id,
      nameArabic: nameArabic ?? this.nameArabic,
      nameFrench: nameFrench ?? this.nameFrench,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      biography: biography ?? this.biography,
      citations: citations,
      works: works,
      portraitUrl: identical(portraitUrl, _unset) ? this.portraitUrl : portraitUrl as String?,
      bioText: bioText ?? this.bioText,
      foyer: identical(foyer, _unset) ? this.foyer : foyer as Foyer?,
      birthYearHijri: identical(birthYearHijri, _unset) ? this.birthYearHijri : birthYearHijri as int?,
    );
  }
}

/// Sentinelle distincte de `null` — permet à [Figure.copyWith] de
/// distinguer "champ non fourni, garder la valeur actuelle" de "champ
/// fourni à `null`, effacer la valeur" pour les champs déjà nullables
/// (`portraitUrl`/`foyer`/`birthYearHijri`).
const Object _unset = Object();

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
        id: raw['id'] as String?,
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
    for (final raw in rows)
      FigureWork(
        id: raw['id'] as String?,
        title: raw['title'] as String,
        description: raw['description'] as String?,
        orderIndex: raw['order_index'] as int,
      ),
  ];
}
