/// Cache local des récitations audio téléchargées
/// (docs/decision-gestion-audio-wirds.md §4) : téléchargement définitif,
/// pas de streaming réseau répété — `just_audio` ne lit ensuite que ce
/// fichier local.
///
/// Le statut "téléchargé" n'est PAS dupliqué dans un index séparé
/// (SharedPreferences) : l'existence du fichier local en est la seule
/// source de vérité, pour ne jamais risquer un désync entre un index et le
/// disque (ex. app tuée pendant un téléchargement). `audio_path` change à
/// chaque nouvelle version de contenu (docs/decision-gestion-audio-wirds.md
/// §2) : une correction produit donc naturellement un nouveau fichier local
/// sans collision avec l'ancien — c'est `WirdRecitationVersionStore` qui
/// décide quand l'ancien peut être supprimé (rétention, §4).
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class WirdRecitationDownloadStore {
  const WirdRecitationDownloadStore();

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/wird_audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileNameFor(String audioPath) => audioPath.replaceAll('/', '_');

  Future<File> localFileFor(String audioPath) async {
    final dir = await _directory();
    return File('${dir.path}/${_fileNameFor(audioPath)}');
  }

  Future<bool> isDownloaded(String audioPath) async {
    final file = await localFileFor(audioPath);
    return file.exists();
  }

  /// Écrit dans un fichier temporaire puis renomme vers la destination
  /// finale une fois l'écriture terminée — un téléchargement interrompu
  /// (app tuée en cours de route) ne doit jamais laisser un fichier partiel
  /// visible comme "téléchargé" par [isDownloaded].
  Future<File> save(String audioPath, List<int> bytes) async {
    final destination = await localFileFor(audioPath);
    final temp = File('${destination.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    return temp.rename(destination.path);
  }

  /// Copie un asset embarqué (`assets/audio/manifest.json`, §4) vers le
  /// même cache local qu'un téléchargement classique — à partir de là, un
  /// asset embarqué est indiscernable d'un fichier téléchargé pour le reste
  /// du contrôleur (rétention, lecture...), exactement l'intention du §4 :
  /// "une simple entrée de cache local pré-remplie à l'installation".
  Future<File> copyFromAsset(String audioPath, String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return save(audioPath, bytes);
  }

  /// Supprime le fichier local d'une ancienne version — best effort : un
  /// fichier orphelin qui échappe à la suppression n'est qu'un peu d'espace
  /// disque gaspillé, pas une raison de faire échouer une mise à jour.
  Future<void> delete(String audioPath) async {
    try {
      final file = await localFileFor(audioPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignoré volontairement — voir commentaire ci-dessus.
    }
  }
}
