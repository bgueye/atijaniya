/// Sélection + téléversement d'une image vers Supabase Storage, partagé par
/// l'image de couverture d'un évènement Khadara, le portrait d'une figure
/// et l'image d'une publication du fil communautaire
/// (docs/09-journal-implementation-frontend.md). Point d'implémentation
/// unique plutôt que de dupliquer la logique de pick+upload trois fois —
/// chaque appelant garde la responsabilité du bucket/chemin/policy RLS qui
/// lui correspond (voir database/schema.sql, section 11).
library;

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Extensions de fichier acceptées par les buckets d'images de ce projet
/// (mêmes `allowed_mime_types` que le bucket `event-images`, repris pour
/// `figure-portraits`/`post-media`).
const Set<String> allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

/// Résout l'extension à utiliser pour le chemin de Storage à partir du
/// chemin local choisi par l'utilisateur — repli sur `jpg` si l'appareil ne
/// fournit aucune extension exploitable (ex. certaines captures caméra).
/// Logique pure, testée dans `image_upload_service_test.dart`.
String imageExtensionFromPath(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == path.length - 1) return 'jpg';
  final extension = path.substring(dotIndex + 1).toLowerCase();
  return allowedImageExtensions.contains(extension) ? extension : 'jpg';
}

/// Content-Type MIME à déclarer au téléversement pour une [extension] déjà
/// résolue par [imageExtensionFromPath].
String imageContentTypeForExtension(String extension) {
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

class ImageUploadService {
  ImageUploadService() : _picker = ImagePicker();

  final ImagePicker _picker;

  /// Ouvre la galerie ou l'appareil photo. Redimensionnement/compression
  /// côté appareil (`maxWidth`/`imageQuality`) pour rester confortablement
  /// sous la limite de 5 Mo des buckets d'images de ce projet. `null` si le
  /// disciple annule la sélection.
  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
  }

  /// Téléverse [bytes] vers `[bucket]/[path]` (upsert — remplace un fichier
  /// existant au même chemin) et renvoie l'URL publique. [path] doit
  /// suivre la convention documentée pour le bucket ciblé.
  ///
  /// [path] est stable par entité chez tous les appelants actuels (ex.
  /// `figure-portraits/{figureId}/portrait.jpg`,
  /// `event-images/{eventId}/cover.jpg`) : remplacer une image avec la même
  /// extension renvoie exactement la même URL qu'avant. Sans le paramètre
  /// `v` ajouté ci-dessous, le cache image en mémoire de Flutter
  /// (`ImageCache`, dont la clé inclut l'URL) continuerait de servir
  /// indéfiniment l'ancienne image à tout widget qui se (re)construit avec
  /// cette URL, quelle que soit la taille de décodage demandée
  /// (`cacheWidth`/`cacheHeight` génèrent chacun leur propre entrée dérivée
  /// de l'URL, donc les évincer une par une n'aurait pas été fiable).
  Future<String> uploadImage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await SupabaseConfig.client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    final publicUrl = SupabaseConfig.client.storage.from(bucket).getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
