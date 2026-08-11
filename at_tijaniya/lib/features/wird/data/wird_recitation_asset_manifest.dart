/// Lecture du manifeste d'assets audio embarqués
/// (`assets/audio/manifest.json`, docs/decision-gestion-audio-wirds.md §4)
/// — corpus figé au moment du build, complément du téléchargement à la
/// demande (`WirdRecitationRepository`/`WirdRecitationDownloadStore`), pas
/// un mécanisme parallèle : un asset embarqué n'est qu'une entrée de cache
/// local pré-remplie à l'installation (voir §4, dernier paragraphe).
///
/// Vide tant qu'aucun contenu audio n'est validé (`recitations: []`,
/// cf. la règle "contenu religieux" de CLAUDE.md) — `load()` renvoie alors
/// une Map vide, comportement strictement identique à l'absence de
/// manifeste.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/wird_recitation.dart';

class WirdRecitationAssetManifest {
  const WirdRecitationAssetManifest();

  /// Indexé par `audio_path` — c'est aussi la clé de comparaison "cet asset
  /// est-il encore la version courante ?" (docs/decision-gestion-audio-wirds.md
  /// §10 : `audio_path` change 1:1 avec `content_version`).
  Future<Map<String, WirdRecitationAsset>> load() async {
    try {
      final raw = await rootBundle.loadString('assets/audio/manifest.json');
      return parseRecitationAssetManifest(raw);
    } catch (_) {
      // Manifeste absent/illisible : comportement identique à un manifeste
      // vide, jamais un blocage de l'écran pour un problème d'asset.
      return const {};
    }
  }
}

/// Logique pure (testée dans `test/wird_recitation_asset_manifest_test.dart`) :
/// parse le JSON du manifeste vers une Map indexée par `audio_path`.
Map<String, WirdRecitationAsset> parseRecitationAssetManifest(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final entries = (decoded['recitations'] as List? ?? const []).cast<Map<String, dynamic>>();
  return {
    for (final entry in entries) entry['audio_path'] as String: WirdRecitationAsset.fromJson(entry),
  };
}
