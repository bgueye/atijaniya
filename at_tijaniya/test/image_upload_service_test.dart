// Vérifie la logique pure (sans réseau ni Storage) du service de
// téléversement d'image partagé par Khadara/Figures/Communauté :
// résolution de l'extension de fichier et du Content-Type MIME associé.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/storage/image_upload_service.dart';

void main() {
  group('imageExtensionFromPath', () {
    test('extrait une extension supportée', () {
      expect(imageExtensionFromPath('/tmp/photo.png'), 'png');
      expect(imageExtensionFromPath('/tmp/photo.WEBP'), 'webp');
    });

    test('retombe sur jpg si aucune extension exploitable', () {
      expect(imageExtensionFromPath('/tmp/capture_camera'), 'jpg');
      expect(imageExtensionFromPath('/tmp/fichier.'), 'jpg');
    });

    test('retombe sur jpg pour une extension non supportée', () {
      expect(imageExtensionFromPath('/tmp/photo.heic'), 'jpg');
    });
  });

  group('imageContentTypeForExtension', () {
    test('résout les types MIME connus', () {
      expect(imageContentTypeForExtension('png'), 'image/png');
      expect(imageContentTypeForExtension('webp'), 'image/webp');
      expect(imageContentTypeForExtension('jpg'), 'image/jpeg');
      expect(imageContentTypeForExtension('jpeg'), 'image/jpeg');
    });
  });
}
