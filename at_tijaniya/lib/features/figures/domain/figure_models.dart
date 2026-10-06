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
  const FigureCitation({
    this.id,
    this.arabic,
    this.transliteration,
    this.french,
    required this.translation,
    required this.source,
  });

  /// `figure_quotes.id` — `null` seulement pour une citation pas encore
  /// enregistrée (formulaire de création). Nécessaire pour cibler
  /// `updateCitation`/`deleteCitation`.
  final String? id;
  final String? arabic;
  final String? transliteration;

  /// Traduction française telle qu'enregistrée (`figure_quotes.text_fr`),
  /// `null` pour une citation saisie en arabe seul. À utiliser pour
  /// préremplir un formulaire : [translation] retombe sur l'arabe quand il
  /// n'y a pas de français, et s'en servir pour l'édition recopiait l'arabe
  /// dans `text_fr` au premier enregistrement (audit du 2026-10-04).
  final String? french;

  /// Texte à afficher : la traduction française, sinon l'arabe.
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

/// Le maillon d'UNE figure dans la silsila historique — sa propre ligne
/// dans `historical_silsila_links` (figure parente + rang), distinct de
/// [HistoricalSilsilaLink] qui représente toute la chaîne reconstruite par
/// `get_historical_silsila_chain()` pour l'affichage disciple. Sert
/// uniquement à l'édition admin (`FigureSilsilaFormScreen`) — au plus un
/// par figure (contrainte `unique(figure_id)`, voir `database/schema.sql`).
class FigureSilsilaLink {
  const FigureSilsilaLink({
    required this.id,
    required this.figureId,
    this.parentFigureId,
    required this.orderIndex,
  });

  final String id;
  final String figureId;

  /// `null` pour la racine de la chaîne (le fondateur).
  final String? parentFigureId;
  final int orderIndex;

  factory FigureSilsilaLink.fromRow(Map<String, dynamic> row) {
    return FigureSilsilaLink(
      id: row['id'] as String,
      figureId: row['figure_id'] as String,
      parentFigureId: row['parent_figure_id'] as String?,
      orderIndex: row['order_index'] as int,
    );
  }
}

/// Rôle porté par les maillons d'une succession
/// (`figure_zawiya_khalifas.role`, migration
/// `khalifa_chain_by_zawiya_with_role` du 2026-10-01) : une zawiya n'est pas
/// toujours dirigée par des khalifes — Fès a des mokaddems. Le rôle fait
/// partie de la clé d'une succession (une même zawiya peut en avoir une par
/// rôle) et détermine le titre affiché.
enum SuccessionRole { khalife, mokaddem, imam }

/// Toute valeur inconnue retombe sur [SuccessionRole.khalife], la valeur par
/// défaut de la colonne — une ancienne version de l'app ne doit pas planter
/// si un rôle est ajouté plus tard en base.
SuccessionRole successionRoleFromDb(String? value) {
  return switch (value) {
    'mokaddem' => SuccessionRole.mokaddem,
    'imam' => SuccessionRole.imam,
    _ => SuccessionRole.khalife,
  };
}

String successionRoleToDb(SuccessionRole role) {
  return switch (role) {
    SuccessionRole.khalife => 'khalife',
    SuccessionRole.mokaddem => 'mokaddem',
    SuccessionRole.imam => 'imam',
  };
}

/// Un maillon d'une succession (`figure_zawiya_khalifas`) — modèle à plat,
/// distinct de [HistoricalSilsilaLink]/[FigureSilsilaLink] : pas de
/// récursivité, `order_index` fixe le rang. Depuis la migration
/// `khalifa_chain_by_zawiya_with_role` (2026-10-01), une succession est
/// identifiée par le couple zawiya + rôle et non plus par la figure
/// fondatrice : [founderFigureId] ne sert plus qu'à afficher le nœud
/// "Fondateur" (voir [ZawiyaSuccession]). Le nom "Khalifa" est conservé pour
/// rester aligné sur la table, mais un maillon peut être un mokaddem ou un
/// imam selon [role].
/// La figure du maillon est résolue à part côté repository (deux FK de
/// `figure_zawiya_khalifas` vers `figures` : un embed PostgREST direct
/// serait ambigu) — voir `FiguresRepository.fetchSuccessionsForFigure`.
class FigureKhalifaLink {
  const FigureKhalifaLink({
    required this.id,
    required this.founderFigureId,
    required this.zawiyaId,
    this.role = SuccessionRole.khalife,
    required this.khalifaFigureId,
    required this.khalifaNameAr,
    required this.khalifaNameFr,
    required this.khalifaCategory,
    this.khalifaPortraitUrl,
    required this.orderIndex,
    this.periodText,
    this.followsGap = false,
  });

  final String id;
  final String founderFigureId;
  final String zawiyaId;
  final SuccessionRole role;
  final String khalifaFigureId;
  final String khalifaNameAr;
  final String khalifaNameFr;
  final FigureCategory khalifaCategory;
  final String? khalifaPortraitUrl;
  final int orderIndex;

  /// Texte libre ("1902-1922", "vers 1950"...) — voir le commentaire sur
  /// `figure_zawiya_khalifas.period_text` dans `database/schema.sql` pour la
  /// justification du texte libre plutôt que des dates structurées.
  final String? periodText;

  /// `figure_zawiya_khalifas.follows_gap` — `true` quand des noms manquent
  /// entre le maillon précédent et celui-ci : l'écran affiche alors une
  /// mention "liste incomplète" à la place du simple connecteur, pour ne pas
  /// laisser entendre que la succession est continue.
  final bool followsGap;

  /// [linkRow] = une ligne de `figure_zawiya_khalifas` ; [figureRow] = la
  /// ligne `figures` correspondante (`khalifa_figure_id`), résolue à part —
  /// voir `FiguresRepository.fetchSuccessionsForFigure`.
  factory FigureKhalifaLink.fromRow(Map<String, dynamic> linkRow, Map<String, dynamic> figureRow) {
    return FigureKhalifaLink(
      id: linkRow['id'] as String,
      founderFigureId: linkRow['founder_figure_id'] as String,
      zawiyaId: linkRow['zawiya_id'] as String,
      role: successionRoleFromDb(linkRow['role'] as String?),
      khalifaFigureId: linkRow['khalifa_figure_id'] as String,
      khalifaNameAr: figureRow['name_ar'] as String,
      khalifaNameFr: figureRow['name_fr'] as String,
      khalifaCategory: _categoryFromDb(figureRow['category'] as String),
      khalifaPortraitUrl: figureRow['portrait_url'] as String?,
      orderIndex: linkRow['order_index'] as int,
      periodText: linkRow['period_text'] as String?,
      followsGap: (linkRow['follows_gap'] as bool?) ?? false,
    );
  }
}

/// Une succession complète : tous les maillons d'une même zawiya pour un
/// même rôle, triés par rang, avec la figure fondatrice affichée en tête.
///
/// [founderNameAr]/[founderNameFr] sont `null` quand la figure fondatrice
/// n'est pas lisible par le compte courant (fiche encore en brouillon,
/// masquée par la RLS) : la succession s'affiche alors sans nœud
/// "Fondateur" plutôt que de disparaître entièrement.
class ZawiyaSuccession {
  const ZawiyaSuccession({
    required this.zawiyaId,
    required this.zawiyaName,
    required this.role,
    required this.founderFigureId,
    this.founderNameAr,
    this.founderNameFr,
    required this.links,
  });

  final String zawiyaId;
  final String zawiyaName;
  final SuccessionRole role;
  final String founderFigureId;
  final String? founderNameAr;
  final String? founderNameFr;
  final List<FigureKhalifaLink> links;
}

/// Regroupe des lignes brutes de `figure_zawiya_khalifas` en successions
/// (une par couple zawiya + rôle) — logique pure, isolée du repository pour
/// être testable sans réseau.
///
/// [linkRows] : lignes de la table, chacune embarquant `zawiyas(name)`.
/// [figuresById] : lignes `figures` lisibles par le compte courant, indexées
/// par id. Un maillon dont la figure n'y figure pas (brouillon masqué par la
/// RLS) est écarté : même défense en profondeur que le reste du module. Une
/// succession qui n'a plus aucun maillon visible n'est pas renvoyée.
///
/// Tri : par nom de zawiya puis par rôle pour un ordre d'affichage stable,
/// et par rang à l'intérieur de chaque succession. Le fondateur d'une
/// succession est celui de son premier maillon (toutes les lignes d'une même
/// succession partagent le même `founder_figure_id` par construction).
List<ZawiyaSuccession> groupSuccessions(
  List<Map<String, dynamic>> linkRows,
  Map<String, Map<String, dynamic>> figuresById,
) {
  final linksByKey = <String, List<FigureKhalifaLink>>{};
  final zawiyaNamesById = <String, String>{};
  for (final row in linkRows) {
    final figureRow = figuresById[row['khalifa_figure_id']];
    if (figureRow == null) continue;
    final link = FigureKhalifaLink.fromRow(row, figureRow);
    linksByKey.putIfAbsent('${link.zawiyaId}|${link.role.name}', () => []).add(link);
    final zawiyaRow = row['zawiyas'] as Map<String, dynamic>?;
    zawiyaNamesById[link.zawiyaId] = (zawiyaRow?['name'] as String?) ?? '';
  }

  final successions = <ZawiyaSuccession>[
    for (final links in linksByKey.values)
      () {
        links.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final first = links.first;
        final founderRow = figuresById[first.founderFigureId];
        return ZawiyaSuccession(
          zawiyaId: first.zawiyaId,
          zawiyaName: zawiyaNamesById[first.zawiyaId] ?? '',
          role: first.role,
          founderFigureId: first.founderFigureId,
          founderNameAr: founderRow?['name_ar'] as String?,
          founderNameFr: founderRow?['name_fr'] as String?,
          links: links,
        );
      }(),
  ];
  successions.sort((a, b) {
    final byName = a.zawiyaName.compareTo(b.zawiyaName);
    return byName != 0 ? byName : a.role.index.compareTo(b.role.index);
  });
  return successions;
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
        french: raw['text_fr'] as String?,
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
