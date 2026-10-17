// Vérifie les modèles de « Rattraper son wird » : lecture d'une ligne des
// tables Supabase `wird_repair_cases` / `wird_repair_notes`, choix de la
// langue, et règles de sélection de l'écran — en particulier que les règles
// communes (`wird = 'all'`) s'affichent quel que soit le wird choisi.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';

Map<String, dynamic> _caseRow({
  required int order,
  required String wird,
  required String kind,
  String status = 'valide',
  String? sourceFr = 'Source FR',
}) {
  return {
    'id': 'case-$order',
    'order_index': order,
    'wird': wird,
    'kind': kind,
    'situation_fr': 'Situation $order',
    'situation_ar': 'حالة $order',
    'action_fr': 'Action $order',
    'action_ar': 'عمل $order',
    'source_fr': sourceFr,
    'source_ar': 'مصدر',
    'content_status': status,
  };
}

Map<String, dynamic> _noteRow({
  required String wird,
  required String type,
  int order = 1,
  String? labelFr,
  String status = 'valide',
}) {
  return {
    'id': 'note-$wird-$type-$order',
    'wird': wird,
    'note_type': type,
    'order_index': order,
    'label_fr': labelFr,
    'label_ar': labelFr == null ? null : 'تسمية',
    'text_fr': 'Texte $wird $type $order',
    'text_ar': 'نص',
    'content_status': status,
  };
}

void main() {
  group('WirdRepairCase.fromRow', () {
    test('lit une ligne complète et choisit la langue', () {
      final repairCase = WirdRepairCase.fromRow(_caseRow(order: 3, wird: 'lazim', kind: 'interruption'));

      expect(repairCase.orderIndex, 3);
      expect(repairCase.wird, RepairWird.lazim);
      expect(repairCase.kind, RepairKind.interruption);
      expect(repairCase.isValid, isTrue);
      expect(repairCase.situationFor(false), 'Situation 3');
      expect(repairCase.situationFor(true), 'حالة 3');
      expect(repairCase.actionFor(true), 'عمل 3');
      expect(repairCase.sourceFor(false), 'Source FR');
    });

    test('lit les quatre wirds et les quatre types de la contrainte check', () {
      for (final wird in ['all', 'lazim', 'wazifa', 'hadra']) {
        for (final kind in ['manque', 'erreur', 'interruption', 'empechement']) {
          final repairCase = WirdRepairCase.fromRow(_caseRow(order: 1, wird: wird, kind: kind));
          expect(repairCase.wird.name, wird);
          expect(repairCase.kind.name, kind);
        }
      }
    });

    test('un brouillon est marqué comme tel, une source absente reste nulle', () {
      final repairCase = WirdRepairCase.fromRow(
        _caseRow(order: 1, wird: 'all', kind: 'erreur', status: 'brouillon', sourceFr: null),
      );
      expect(repairCase.isValid, isFalse);
      expect(repairCase.sourceFor(false), isNull);
    });
  });

  group('WirdRepairNote.fromRow', () {
    test('lit les cinq types de note, dont les noms en snake_case', () {
      const expected = {
        'intro': RepairNoteType.intro,
        'quick_answer': RepairNoteType.quickAnswer,
        'timing': RepairNoteType.timing,
        'warning': RepairNoteType.warning,
        'ask_moqaddam': RepairNoteType.askMoqaddam,
      };
      for (final entry in expected.entries) {
        expect(WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: entry.key)).type, entry.value);
      }
    });

    test('un type inconnu échoue franchement plutôt que d\'être deviné', () {
      expect(() => WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: 'autre')), throwsArgumentError);
    });

    test('le libellé d\'un horaire suit la langue', () {
      final note = WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: 'timing', labelFr: 'Matin'));
      expect(note.labelFor(false), 'Matin');
      expect(note.labelFor(true), 'تسمية');
    });
  });

  group('WirdRepairContent', () {
    WirdRepairContent build({String draftStatus = 'valide'}) {
      return WirdRepairContent(
        // Volontairement dans le désordre : le contenu se trie lui-même.
        cases: [
          WirdRepairCase.fromRow(_caseRow(order: 4, wird: 'wazifa', kind: 'manque')),
          WirdRepairCase.fromRow(_caseRow(order: 1, wird: 'all', kind: 'erreur')),
          WirdRepairCase.fromRow(_caseRow(order: 3, wird: 'lazim', kind: 'manque', status: draftStatus)),
          WirdRepairCase.fromRow(_caseRow(order: 2, wird: 'all', kind: 'interruption')),
          WirdRepairCase.fromRow(_caseRow(order: 5, wird: 'hadra', kind: 'manque')),
        ],
        notes: [
          WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: 'timing', order: 2, labelFr: 'Soir')),
          WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: 'timing', order: 1, labelFr: 'Matin')),
          WirdRepairNote.fromRow(_noteRow(wird: 'lazim', type: 'quick_answer')),
          WirdRepairNote.fromRow(_noteRow(wird: 'all', type: 'ask_moqaddam')),
        ],
      );
    }

    test('un wird montre ses cas et les règles communes, communes d\'abord', () {
      final ids = build().casesFor(RepairWird.lazim).map((c) => c.orderIndex).toList();
      expect(ids, [1, 2, 3]);
    });

    test('les cas d\'un autre wird ne se mélangent pas', () {
      final ids = build().casesFor(RepairWird.wazifa).map((c) => c.orderIndex).toList();
      expect(ids, [1, 2, 4]);
    });

    test('le filtre par type garde les règles communes de ce type', () {
      final content = build();
      expect(content.casesFor(RepairWird.hadra, kind: RepairKind.interruption).map((c) => c.orderIndex), [2]);
      expect(content.casesFor(RepairWird.hadra, kind: RepairKind.manque).map((c) => c.orderIndex), [5]);
      expect(content.casesFor(RepairWird.hadra, kind: RepairKind.empechement), isEmpty);
    });

    test('la lecture complète sépare les règles communes de chaque wird', () {
      final content = build();
      expect(content.casesOnlyFor(RepairWird.all).map((c) => c.orderIndex), [1, 2]);
      expect(content.casesOnlyFor(RepairWird.lazim).map((c) => c.orderIndex), [3]);
    });

    test('les horaires sortent dans l\'ordre de la base', () {
      final labels = build().notesFor(RepairWird.lazim, RepairNoteType.timing).map((n) => n.labelFor(false));
      expect(labels, ['Matin', 'Soir']);
    });

    test('noteFor renvoie null quand la note n\'existe pas', () {
      final content = build();
      expect(content.noteFor(RepairWird.lazim, RepairNoteType.quickAnswer), isNotNull);
      expect(content.noteFor(RepairWird.lazim, RepairNoteType.warning), isNull);
    });

    test('hasDrafts ne s\'allume que s\'il reste une ligne en brouillon', () {
      expect(build().hasDrafts, isFalse);
      expect(build(draftStatus: 'brouillon').hasDrafts, isTrue);
    });

    test('sans cas, le contenu est vide même s\'il reste des notes', () {
      final content = WirdRepairContent(
        cases: const [],
        notes: [WirdRepairNote.fromRow(_noteRow(wird: 'all', type: 'ask_moqaddam'))],
      );
      expect(content.isEmpty, isTrue);
    });
  });
}
