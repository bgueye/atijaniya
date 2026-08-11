import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRecitationAssetManifest', () {
    test('parse un manifeste avec des entrées, indexé par audio_path', () {
      const raw = '''
      {
        "recitations": [
          {"audio_path": "lazim/1.m4a", "asset_path": "assets/audio/wirds/lazim_1.m4a", "content_version": 1},
          {"audio_path": "lazim/2.m4a", "asset_path": "assets/audio/wirds/lazim_2.m4a", "content_version": 3}
        ]
      }
      ''';

      final result = parseRecitationAssetManifest(raw);

      expect(result.keys, containsAll(<String>['lazim/1.m4a', 'lazim/2.m4a']));
      expect(result['lazim/1.m4a']!.assetPath, 'assets/audio/wirds/lazim_1.m4a');
      expect(result['lazim/2.m4a']!.contentVersion, 3);
    });

    test('manifeste vide (aucun contenu audio validé) -> Map vide', () {
      const raw = '{"recitations": []}';
      expect(parseRecitationAssetManifest(raw), isEmpty);
    });

    test('clé "recitations" absente -> Map vide plutôt qu\'une exception', () {
      const raw = '{}';
      expect(parseRecitationAssetManifest(raw), isEmpty);
    });
  });
}
