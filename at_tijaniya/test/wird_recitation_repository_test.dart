import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildRecitationsByPillarIndex', () {
    test('associe chaque pilier (order_index - 1) à sa récitation par défaut', () {
      final steps = [
        {'id': 'step-1', 'order_index': 1},
        {'id': 'step-2', 'order_index': 2},
        {'id': 'step-3', 'order_index': 3},
      ];
      final recitations = [
        {
          'id': 'rec-1',
          'wird_step_id': 'step-1',
          'audio_path': 'lazim/1.m4a',
          'content_version': 1,
          'duration_seconds': 12,
        },
        {
          'id': 'rec-3',
          'wird_step_id': 'step-3',
          'audio_path': 'lazim/3.m4a',
          'content_version': 2,
          'duration_seconds': null,
        },
      ];

      final result = buildRecitationsByPillarIndex(steps: steps, recitations: recitations);

      expect(result.keys, containsAll(<int>[0, 2]));
      expect(result.containsKey(1), isFalse); // pilier 2 (step-2) sans récitation validée
      expect(result[0]!.audioPath, 'lazim/1.m4a');
      expect(result[0]!.durationSeconds, 12);
      expect(result[2]!.contentVersion, 2);
      expect(result[2]!.durationSeconds, isNull);
    });

    test('liste de récitations vide -> Map vide, aucune erreur', () {
      final steps = [
        {'id': 'step-1', 'order_index': 1},
      ];
      final result = buildRecitationsByPillarIndex(steps: steps, recitations: const []);
      expect(result, isEmpty);
    });

    test('ignore une récitation dont le wird_step_id ne correspond à aucun pilier fourni', () {
      final steps = [
        {'id': 'step-1', 'order_index': 1},
      ];
      final recitations = [
        {
          'id': 'rec-orphan',
          'wird_step_id': 'step-inconnu',
          'audio_path': 'x.m4a',
          'content_version': 1,
          'duration_seconds': null,
        },
      ];
      final result = buildRecitationsByPillarIndex(steps: steps, recitations: recitations);
      expect(result, isEmpty);
    });
  });
}
