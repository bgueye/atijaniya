import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
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

  group('buildStepRecitations', () {
    test('regroupe et trie par order_index, piliers sans récitation inclus avec une liste vide', () {
      final steps = [
        {'id': 'step-2', 'order_index': 2},
        {'id': 'step-1', 'order_index': 1},
      ];
      final recitations = [
        {
          'id': 'rec-1a',
          'wird_step_id': 'step-1',
          'reciter_name': 'A',
          'audio_path': 'lazim/1.aac',
          'content_version': 1,
          'content_status': 'valide',
          'is_default': true,
          'duration_seconds': 10,
        },
        {
          'id': 'rec-1b',
          'wird_step_id': 'step-1',
          'reciter_name': 'B',
          'audio_path': 'lazim/1_v2.aac',
          'content_version': 2,
          'content_status': 'brouillon',
          'is_default': false,
          'duration_seconds': null,
        },
      ];

      final result = buildStepRecitations(steps: steps, recitations: recitations);

      expect(result.map((s) => s.orderIndex), [1, 2]);
      expect(result[0].recitations, hasLength(2));
      expect(result[1].recitations, isEmpty);
    });
  });

  group('buildWirdAudioPath', () {
    test('version 1 -> aucun suffixe', () {
      expect(
        buildWirdAudioPath(wirdKey: 'wazifa', orderIndex: 4, contentVersion: 1, extension: 'aac'),
        'wazifa/4.aac',
      );
    });

    test('version 2+ -> suffixe _v{n}', () {
      expect(
        buildWirdAudioPath(wirdKey: 'wazifa', orderIndex: 6, contentVersion: 2, extension: 'aac'),
        'wazifa/6_v2.aac',
      );
      expect(
        buildWirdAudioPath(wirdKey: 'lazim', orderIndex: 3, contentVersion: 3, extension: 'm4a'),
        'lazim/3_v3.m4a',
      );
    });
  });

  group('nextContentVersionFor', () {
    WirdRecitationEntry entryWithVersion(int v) => WirdRecitationEntry(
          id: 'r$v',
          wirdStepId: 'step-1',
          reciterName: 'x',
          audioPath: 'x.aac',
          contentVersion: v,
          contentStatus: 'valide',
          isDefault: false,
        );

    test('liste vide -> 1', () {
      expect(nextContentVersionFor(const []), 1);
    });

    test('versions [1] -> 2', () {
      expect(nextContentVersionFor([entryWithVersion(1)]), 2);
    });

    test('versions désordonnées [2,1] -> 3', () {
      expect(nextContentVersionFor([entryWithVersion(2), entryWithVersion(1)]), 3);
    });
  });

  group('wirdAudioExtensionFromPath', () {
    test('extensions valides acceptées, insensible à la casse', () {
      expect(wirdAudioExtensionFromPath('a/b.aac'), 'aac');
      expect(wirdAudioExtensionFromPath('a/b.M4A'), 'm4a');
      expect(wirdAudioExtensionFromPath('a/b.mp3'), 'mp3');
    });

    test('extension invalide ou absente -> null', () {
      expect(wirdAudioExtensionFromPath('a/b.wav'), isNull);
      expect(wirdAudioExtensionFromPath('a/b'), isNull);
      expect(wirdAudioExtensionFromPath('a/b.'), isNull);
    });
  });

  group('wirdAudioContentTypeForExtension', () {
    test('mapping par extension', () {
      expect(wirdAudioContentTypeForExtension('mp3'), 'audio/mpeg');
      expect(wirdAudioContentTypeForExtension('m4a'), 'audio/mp4');
      expect(wirdAudioContentTypeForExtension('aac'), 'audio/aac');
    });
  });
}
