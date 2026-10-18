// Vérifie la lecture du contenu de « Bienfaits de la Tijaniyya » :
// - le balisage en ligne (gras, arabe, étiquettes de solidité), et le refus
//   d'un balisage mal formé plutôt qu'un affichage de travers ;
// - les blocs JSON des cartes ;
// - l'assemblage des sections, le repli sur le français tant que l'arabe
//   n'existe pas, et le signalement du brouillon ;
// - tout le contenu réel (copie de la migration dans test/fixtures) se lit
//   sans erreur.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/tariqa_benefits/domain/tariqa_benefits_models.dart';

Map<String, dynamic> _section(String slug, int order, {String? number, String status = 'valide', String? titleAr}) => {
      'slug': slug,
      'order_index': order,
      'number': number,
      'title_fr': 'Titre $slug',
      'title_ar': titleAr,
      'intro_fr': null,
      'intro_ar': null,
      'content_status': status,
    };

Map<String, dynamic> _card(String slug, int order, {String status = 'valide', String? titleAr}) => {
      'section_slug': slug,
      'order_index': order,
      'group_fr': null,
      'group_ar': null,
      'title_fr': 'Carte $slug $order',
      'title_ar': titleAr,
      'blocks_fr': [
        {'t': 'p', 'x': 'Texte'},
      ],
      'blocks_ar': null,
      'evidence_fr': null,
      'evidence_ar': null,
      'content_status': status,
    };

void main() {
  group('parseInline', () {
    test('texte simple', () {
      final segments = parseInline('Le Lazim se fait matin et soir.');
      expect(segments, hasLength(1));
      expect((segments.single as PlainSegment).bold, isFalse);
    });

    test('gras, arabe et étiquette, dans l\'ordre', () {
      final segments = parseInline('<b>Condition :</b> « <ar>بشرط</ar> » p. 10 <ev v>Lu dans Jawâhir</ev> éd. Kanûn');
      expect(segments.map((s) => s.runtimeType), [
        PlainSegment,
        PlainSegment,
        ArabicSegment,
        PlainSegment,
        EvidenceSegment,
        PlainSegment,
      ]);
      expect((segments[0] as PlainSegment).bold, isTrue);
      expect(segments[0].text, 'Condition :');
      expect((segments[1] as PlainSegment).bold, isFalse);
      expect(segments[2].text, 'بشرط');
      final badge = segments[4] as EvidenceSegment;
      expect(badge.text, 'Lu dans Jawâhir');
      expect(badge.level, EvidenceLevel.read);
    });

    test('les quatre niveaux de solidité', () {
      final levels = parseInline('<ev v>a</ev><ev m>b</ev><ev u>c</ev><ev s>d</ev>')
          .whereType<EvidenceSegment>()
          .map((s) => s.level);
      expect(levels, [EvidenceLevel.read, EvidenceLevel.multiple, EvidenceLevel.single, EvidenceLevel.secondHand]);
    });

    test('un balisage mal formé est refusé', () {
      expect(() => parseInline('<ar>non fermé'), throwsFormatException);
      expect(() => parseInline('<b>gras'), throwsFormatException);
      expect(() => parseInline('fin</ar>'), throwsFormatException);
      expect(() => parseInline('<ev>sans niveau</ev>'), throwsFormatException);
      expect(() => parseInline('<ar><ev v>imbriqué</ev></ar>'), throwsFormatException);
    });
  });

  group('BenefitBlock.fromJson', () {
    test('lit chaque type de bloc', () {
      final blocks = BenefitBlock.listFromJson([
        {'t': 'p', 'x': 'paragraphe'},
        {'t': 'quote', 'x': 'نص'},
        {'t': 'tr', 'x': '« traduction »'},
        {'t': 'cond', 'x': '<b>Condition :</b> x'},
        {
          't': 'list',
          'ordered': true,
          'items': [
            [
              {'t': 'p', 'x': 'un'},
              {'t': 'quote', 'x': 'واحد'},
            ],
          ],
        },
        {
          't': 'table',
          'head': ['A', 'B'],
          'rows': [
            ['a', 'b'],
          ],
        },
      ]);
      expect(blocks.map((b) => b.runtimeType), [
        ParagraphBlock,
        QuoteBlock,
        TranslationBlock,
        ConditionBlock,
        ListBlock,
        TableBlock,
      ]);
      final list = blocks[4] as ListBlock;
      expect(list.ordered, isTrue);
      expect(list.items.single, hasLength(2));
      expect((blocks[5] as TableBlock).rows.single, ['a', 'b']);
    });

    test('un type de bloc inconnu est refusé', () {
      expect(() => BenefitBlock.fromJson({'t': 'image', 'x': 'x'}), throwsFormatException);
    });
  });

  group('TariqaBenefitsContent.fromRows', () {
    test('range sections et cartes dans l\'ordre', () {
      final content = TariqaBenefitsContent.fromRows(
        sectionRows: [_section('lazim', 2, number: '2'), _section('essentiel', 1)],
        cardRows: [_card('lazim', 2), _card('lazim', 1), _card('essentiel', 1)],
        isArabic: false,
      );
      expect(content.sections.map((s) => s.slug), ['essentiel', 'lazim']);
      expect(content.sections[1].cards.map((c) => c.orderIndex), [1, 2]);
      expect(content.numberedSections.map((s) => s.slug), ['lazim']);
      expect(content.hasDrafts, isFalse);
    });

    test('une carte sans sa section n\'est pas montrée, une section vide non plus', () {
      final content = TariqaBenefitsContent.fromRows(
        sectionRows: [_section('essentiel', 1), _section('vide', 2)],
        cardRows: [_card('essentiel', 1), _card('absente', 1)],
        isArabic: false,
      );
      expect(content.sections.map((s) => s.slug), ['essentiel']);
    });

    test('signale le brouillon', () {
      final content = TariqaBenefitsContent.fromRows(
        sectionRows: [_section('essentiel', 1)],
        cardRows: [_card('essentiel', 1, status: 'brouillon')],
        isArabic: false,
      );
      expect(content.hasDrafts, isTrue);
    });

    test('en arabe, garde le français tant que l\'arabe est vide', () {
      final content = TariqaBenefitsContent.fromRows(
        sectionRows: [_section('essentiel', 1)],
        cardRows: [_card('essentiel', 1)],
        isArabic: true,
      );
      expect(content.isArabicText, isFalse);
      expect(content.sections.single.title, 'Titre essentiel');
      expect(content.sections.single.cards.single.title, 'Carte essentiel 1');
    });

    test('en arabe, prend l\'arabe quand il existe', () {
      final content = TariqaBenefitsContent.fromRows(
        sectionRows: [_section('essentiel', 1, titleAr: 'الخلاصة')],
        cardRows: [_card('essentiel', 1, titleAr: 'بطاقة')],
        isArabic: true,
      );
      expect(content.isArabicText, isTrue);
      expect(content.sections.single.title, 'الخلاصة');
      expect(content.sections.single.cards.single.title, 'بطاقة');
    });
  });

  test('tout le contenu réel se lit sans erreur', () {
    final fixture = jsonDecode(File('test/fixtures/tariqa_benefits_rows.json').readAsStringSync()) as Map<String, dynamic>;
    final content = TariqaBenefitsContent.fromRows(
      sectionRows: (fixture['sections'] as List).cast<Map<String, dynamic>>(),
      cardRows: (fixture['cards'] as List).cast<Map<String, dynamic>>(),
      isArabic: false,
    );
    expect(content.sections, hasLength(9));
    expect(content.sections.fold<int>(0, (n, s) => n + s.cards.length), 34);
    expect(content.numberedSections.map((s) => s.number), ['1', '2', '3', '4', '5', '6']);

    // Chaque texte balisé du contenu se découpe sans erreur.
    var inlineTexts = 0;
    void visit(List<BenefitBlock> blocks) {
      for (final block in blocks) {
        switch (block) {
          case ParagraphBlock(:final text) || TranslationBlock(:final text) || ConditionBlock(:final text):
            parseInline(text);
            inlineTexts++;
          case QuoteBlock():
            break;
          case ListBlock(:final items):
            items.forEach(visit);
          case TableBlock(:final rows):
            for (final row in rows) {
              row.forEach(parseInline);
              inlineTexts += row.length;
            }
        }
      }
    }

    for (final section in content.sections) {
      visit(section.intro);
      for (final card in section.cards) {
        visit(card.blocks);
        if (card.evidence != null) parseInline(card.evidence!);
      }
    }
    expect(inlineTexts, greaterThan(100));
  });
}
