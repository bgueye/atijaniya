/// « Bienfaits de la Tijaniyya » : ce que disent Jawâhir al-Ma'ânî et les
/// moqaddams des bienfaits de la tariqa et de ses wirds, avec la condition que
/// les textes attachent à chaque bienfait (docs/Bienfaits-Tijaniyya.html,
/// migration `2026-10-18_tariqa_benefits.sql`).
///
/// IMPORTANT (contenu religieux) : rien ici n'est écrit par l'app. Tout vient
/// des tables `tariqa_benefit_sections` et `tariqa_benefit_cards`, en
/// brouillon tant que le moqaddam référent ne les a pas validées. Ce fichier
/// ne fait que lire la forme du texte.
///
/// Forme du texte (décrite aussi en tête de la migration) :
/// - le corps d'une carte est une liste de blocs JSON (`p`, `quote`, `tr`,
///   `cond`, `list`, `table`), lue par [BenefitBlock.fromJson] ;
/// - dans chaque texte, trois balises en ligne : `<b>…</b>`, `<ar>…</ar>`
///   (citation arabe dans une phrase française) et `<ev X>…</ev>` (étiquette
///   de solidité), lues par [parseInline].
library;

/// Solidité d'un passage, telle que le document l'indique.
enum EvidenceLevel {
  /// « Lu dans… » : vérifié dans le texte du livre nommé.
  read,

  /// Au moins deux relais concordants.
  multiple,

  /// Un seul relais.
  single,

  /// Connu par un commentaire ou une traduction.
  secondHand;

  static EvidenceLevel fromCode(String code) => switch (code) {
        'v' => EvidenceLevel.read,
        'm' => EvidenceLevel.multiple,
        'u' => EvidenceLevel.single,
        's' => EvidenceLevel.secondHand,
        _ => throw FormatException('étiquette de solidité inconnue : $code'),
      };
}

/// Un morceau de texte en ligne : du texte simple, du gras, une citation
/// arabe ou une étiquette de solidité.
sealed class InlineSegment {
  const InlineSegment(this.text);

  final String text;
}

class PlainSegment extends InlineSegment {
  const PlainSegment(super.text, {this.bold = false});

  final bool bold;
}

class ArabicSegment extends InlineSegment {
  const ArabicSegment(super.text);
}

class EvidenceSegment extends InlineSegment {
  const EvidenceSegment(super.text, this.level);

  final EvidenceLevel level;
}

final _tag = RegExp(r'<(/?)(b|ar|ev)(?: ([vmus]))?>');

/// Découpe un texte balisé en morceaux, dans l'ordre.
///
/// Les balises ne s'imbriquent pas dans le contenu actuel (le gras entoure un
/// libellé, la citation arabe et l'étiquette sont à part) : un texte arabe ou
/// une étiquette à l'intérieur d'un gras est rendu sans le gras. Une balise
/// inconnue ou mal fermée lève une [FormatException] : mieux vaut un test qui
/// échoue qu'un contenu religieux affiché de travers.
List<InlineSegment> parseInline(String source) {
  final segments = <InlineSegment>[];
  var bold = false;
  String? open; // 'ar' ou 'ev' en cours
  EvidenceLevel? level;
  var buffer = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (buffer.isEmpty) return;
    segments.add(PlainSegment(buffer.toString(), bold: bold));
    buffer = StringBuffer();
  }

  for (final match in _tag.allMatches(source)) {
    buffer.write(source.substring(index, match.start));
    index = match.end;
    final closing = match.group(1) == '/';
    final name = match.group(2)!;
    if (name == 'b') {
      if (open != null || closing != bold) throw FormatException('gras mal formé : $source');
      flushPlain();
      bold = !closing;
      continue;
    }
    if (!closing) {
      if (open != null) throw FormatException('balise $name ouverte dans $open : $source');
      flushPlain();
      open = name;
      if (name == 'ev') {
        final code = match.group(3);
        if (code == null) throw FormatException('étiquette sans niveau : $source');
        level = EvidenceLevel.fromCode(code);
      }
    } else {
      if (open != name) throw FormatException('fermeture de $name sans ouverture : $source');
      final text = buffer.toString();
      buffer = StringBuffer();
      segments.add(name == 'ar' ? ArabicSegment(text) : EvidenceSegment(text, level!));
      open = null;
      level = null;
    }
  }
  buffer.write(source.substring(index));
  if (open != null || bold) throw FormatException('balise non fermée : $source');
  flushPlain();
  return segments;
}

/// Un bloc du corps d'une carte ou de l'introduction d'une section.
sealed class BenefitBlock {
  const BenefitBlock();

  static BenefitBlock fromJson(Map<String, dynamic> json) {
    final type = json['t'] as String;
    return switch (type) {
      'p' => ParagraphBlock(json['x'] as String),
      'quote' => QuoteBlock(json['x'] as String),
      'tr' => TranslationBlock(json['x'] as String),
      'cond' => ConditionBlock(json['x'] as String),
      'list' => ListBlock(
          ordered: json['ordered'] as bool? ?? false,
          items: [
            for (final item in json['items'] as List)
              [for (final block in item as List) BenefitBlock.fromJson(block as Map<String, dynamic>)],
          ],
        ),
      'table' => TableBlock(
          head: [for (final cell in json['head'] as List) cell as String],
          rows: [
            for (final row in json['rows'] as List) [for (final cell in row as List) cell as String],
          ],
        ),
      _ => throw FormatException('bloc inconnu : $type'),
    };
  }

  static List<BenefitBlock> listFromJson(Object? json) {
    if (json == null) return const [];
    return [for (final block in json as List) BenefitBlock.fromJson(block as Map<String, dynamic>)];
  }
}

class ParagraphBlock extends BenefitBlock {
  const ParagraphBlock(this.text);

  final String text;
}

/// Citation arabe en bloc, à lire de droite à gauche.
class QuoteBlock extends BenefitBlock {
  const QuoteBlock(this.text);

  final String text;
}

/// Traduction de la citation qui la précède.
class TranslationBlock extends BenefitBlock {
  const TranslationBlock(this.text);

  final String text;
}

/// Condition attachée au bienfait (« Condition : … »).
class ConditionBlock extends BenefitBlock {
  const ConditionBlock(this.text);

  final String text;
}

class ListBlock extends BenefitBlock {
  const ListBlock({required this.ordered, required this.items});

  /// Liste numérotée : seulement quand le document numérote (les quatre
  /// conditions de la Salat al-Fatih).
  final bool ordered;

  /// Chaque élément est lui-même une suite de blocs (texte, citation).
  final List<List<BenefitBlock>> items;
}

class TableBlock extends BenefitBlock {
  const TableBlock({required this.head, required this.rows});

  final List<String> head;
  final List<List<String>> rows;
}

/// Une carte : un bienfait (ou un tableau, une liste) avec ses sources.
class BenefitCard {
  const BenefitCard({
    required this.sectionSlug,
    required this.orderIndex,
    required this.group,
    required this.title,
    required this.blocks,
    required this.evidence,
    required this.isDraft,
  });

  /// Le texte n'existe qu'en français pour l'instant : la colonne `_ar` est
  /// prise quand elle est remplie et que l'app est en arabe, le français
  /// sinon (décision du porteur de projet du 2026-10-18).
  factory BenefitCard.fromRow(Map<String, dynamic> row, {required bool isArabic}) {
    String? pick(String base) {
      final ar = row['${base}_ar'] as String?;
      return isArabic && ar != null && ar.isNotEmpty ? ar : row['${base}_fr'] as String?;
    }

    final blocksAr = row['blocks_ar'];
    return BenefitCard(
      sectionSlug: row['section_slug'] as String,
      orderIndex: row['order_index'] as int,
      group: pick('group'),
      title: pick('title'),
      blocks: BenefitBlock.listFromJson(isArabic && blocksAr != null ? blocksAr : row['blocks_fr']),
      evidence: pick('evidence'),
      isDraft: row['content_status'] != 'valide',
    );
  }

  final String sectionSlug;
  final int orderIndex;

  /// Intertitre qui regroupe plusieurs cartes d'une section.
  final String? group;
  final String? title;
  final List<BenefitBlock> blocks;

  /// Ligne des sources, avec ses étiquettes de solidité.
  final String? evidence;
  final bool isDraft;
}

class BenefitSection {
  const BenefitSection({
    required this.slug,
    required this.orderIndex,
    required this.number,
    required this.title,
    required this.intro,
    required this.cards,
    required this.isDraft,
  });

  factory BenefitSection.fromRow(Map<String, dynamic> row, List<BenefitCard> cards, {required bool isArabic}) {
    final titleAr = row['title_ar'] as String?;
    final introAr = row['intro_ar'];
    return BenefitSection(
      slug: row['slug'] as String,
      orderIndex: row['order_index'] as int,
      number: row['number'] as String?,
      title: isArabic && titleAr != null && titleAr.isNotEmpty ? titleAr : row['title_fr'] as String,
      intro: BenefitBlock.listFromJson(isArabic && introAr != null ? introAr : row['intro_fr']),
      cards: cards,
      isDraft: row['content_status'] != 'valide',
    );
  }

  final String slug;
  final int orderIndex;

  /// « 1 » à « 6 » ; null pour L'essentiel, le récapitulatif et les sources.
  final String? number;
  final String title;
  final List<BenefitBlock> intro;
  final List<BenefitCard> cards;
  final bool isDraft;
}

class TariqaBenefitsContent {
  const TariqaBenefitsContent({required this.sections, required this.isArabicText});

  /// Assemble les sections et leurs cartes, chacune dans l'ordre. Une carte
  /// dont la section n'est pas renvoyée (section restée en brouillon alors
  /// que la carte est validée) n'est pas montrée : elle n'aurait pas de titre.
  factory TariqaBenefitsContent.fromRows({
    required List<Map<String, dynamic>> sectionRows,
    required List<Map<String, dynamic>> cardRows,
    required bool isArabic,
  }) {
    final cardsBySection = <String, List<BenefitCard>>{};
    for (final row in cardRows) {
      final card = BenefitCard.fromRow(row, isArabic: isArabic);
      cardsBySection.putIfAbsent(card.sectionSlug, () => []).add(card);
    }
    final sections = [
      for (final row in sectionRows)
        BenefitSection.fromRow(
          row,
          (cardsBySection[row['slug']] ?? [])..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
          isArabic: isArabic,
        ),
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final arabicText = isArabic &&
        sectionRows.any((r) => (r['title_ar'] as String?)?.isNotEmpty ?? false);
    return TariqaBenefitsContent(
      sections: [for (final s in sections) if (s.cards.isNotEmpty || s.intro.isNotEmpty) s],
      isArabicText: arabicText,
    );
  }

  final List<BenefitSection> sections;

  /// Le texte affiché est-il la version arabe ? Faux tant qu'elle n'existe
  /// pas : l'écran met alors le contenu en sens gauche-droite, même dans
  /// l'app en arabe.
  final bool isArabicText;

  bool get isEmpty => sections.isEmpty;

  bool get hasDrafts => sections.any((s) => s.isDraft || s.cards.any((c) => c.isDraft));

  /// Sections numérotées (1 à 6), proposées dans le sommaire.
  List<BenefitSection> get numberedSections => [for (final s in sections) if (s.number != null) s];
}
