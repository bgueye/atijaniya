/// Sélection d'un fichier audio arbitraire par un admin, pour ajouter une
/// récitation de pilier de wird (`WirdRecitationsManagementScreen`).
/// Distinct de `ImageUploadService` (`lib/core/storage/image_upload_service.dart`,
/// basé sur `image_picker`, qui ne gère que les images) — scope propre au
/// module wird, pas de réutilisation ailleurs dans l'app.
library;

import 'package:file_picker/file_picker.dart';

import 'wird_recitation_repository.dart' show allowedWirdAudioExtensions;

class WirdAudioPickerService {
  /// Ouvre le sélecteur de fichiers natif, restreint aux extensions audio
  /// acceptées (`allowedWirdAudioExtensions`). `FileType.custom` plutôt que
  /// `FileType.audio` : sur iOS, `FileType.audio` ouvre la bibliothèque
  /// musicale (nécessite `NSAppleMusicUsageDescription`, une permission non
  /// pertinente ici — le fichier vient d'un enregistrement préparé par un
  /// moqaddam, pas de la musicothèque du disciple), alors que le document
  /// picker natif convient dans tous les cas. `withData: true` pour
  /// récupérer directement les octets (fichiers courts, cf. §4 du document
  /// de décision — jamais un enregistrement de plusieurs dizaines de
  /// minutes), sans passer par un chemin temporaire à gérer nous-mêmes.
  Future<PlatformFile?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedWirdAudioExtensions.toList(),
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }
}
