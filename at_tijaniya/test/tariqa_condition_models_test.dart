// Vérifie le parsing de TariqaCondition.fromRow depuis une ligne de la table
// Supabase `tariqa_conditions` : mapping de catégorie (snake_case -> enum),
// et gestion du texte arabe / de la source optionnels.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';

void main() {
  group('TariqaCondition.fromRow', () {
    test('parse une ligne complète', () {
      final condition = TariqaCondition.fromRow({
        'id': 'condition-1',
        'order_index': 1,
        'category': 'validite_talqin',
        'text_fr': 'Texte français.',
        'text_ar': 'نص عربي',
        'source_note': 'Source X',
      });

      expect(condition.id, 'condition-1');
      expect(condition.orderIndex, 1);
      expect(condition.category, TariqaConditionCategory.validiteTalqin);
      expect(condition.textFr, 'Texte français.');
      expect(condition.textAr, 'نص عربي');
      expect(condition.sourceNote, 'Source X');
    });

    test('mappe chacune des 5 catégories officielles', () {
      const expected = {
        'validite_talqin': TariqaConditionCategory.validiteTalqin,
        'compagnonnage': TariqaConditionCategory.compagnonnage,
        'conditions_generales': TariqaConditionCategory.conditionsGenerales,
        'validite_recitation': TariqaConditionCategory.validiteRecitation,
        'conditions_complementaires': TariqaConditionCategory.conditionsComplementaires,
      };

      for (final entry in expected.entries) {
        final condition = TariqaCondition.fromRow({
          'id': 'condition-x',
          'order_index': 1,
          'category': entry.key,
          'text_fr': 'Texte.',
        });
        expect(condition.category, entry.value, reason: 'category "${entry.key}"');
      }
    });

    test('texte arabe et source restent nuls quand absents', () {
      final condition = TariqaCondition.fromRow({
        'id': 'condition-23',
        'order_index': 23,
        'category': 'conditions_complementaires',
        'text_fr': 'Texte.',
        'text_ar': null,
        'source_note': null,
      });

      expect(condition.textAr, isNull);
      expect(condition.sourceNote, isNull);
    });
  });

  group('categoryToDb', () {
    test('est l\'inverse exact de _categoryFromDb pour les 5 catégories officielles', () {
      const expected = {
        TariqaConditionCategory.validiteTalqin: 'validite_talqin',
        TariqaConditionCategory.compagnonnage: 'compagnonnage',
        TariqaConditionCategory.conditionsGenerales: 'conditions_generales',
        TariqaConditionCategory.validiteRecitation: 'validite_recitation',
        TariqaConditionCategory.conditionsComplementaires: 'conditions_complementaires',
      };

      for (final entry in expected.entries) {
        expect(categoryToDb(entry.key), entry.value, reason: 'category "${entry.key}"');
      }
    });

    test('round-trip avec _categoryFromDb via fromRow/updateCondition', () {
      for (final category in TariqaConditionCategory.values) {
        final dbValue = categoryToDb(category);
        final condition = TariqaCondition.fromRow({
          'id': 'condition-roundtrip',
          'order_index': 1,
          'category': dbValue,
          'text_fr': 'Texte.',
        });
        expect(condition.category, category, reason: 'round-trip "$dbValue"');
      }
    });
  });
}
