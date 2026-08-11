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
/// sans collision avec l'ancien — la politique de rétention/suppression de
/// l'ancien fichier est un sujet distinct (sprint 3, non traité ici : cette
/// version ne supprime jamais un fichier déjà téléchargé).
library;

import 'dart:io';

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
}
