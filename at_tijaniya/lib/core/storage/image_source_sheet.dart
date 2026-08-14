/// Feuille de choix "Galerie / Appareil photo" partagée par les trois
/// endroits de l'app qui proposent d'ajouter une image (Khadara, Figures,
/// Communauté) — évite de dupliquer ce `showModalBottomSheet` trois fois.
library;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';

Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.imagePickerGallery),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.imagePickerCamera),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}
