/// Ouvre l'app de plans du téléphone sur des coordonnées données — pas de
/// carte intégrée en V1 (docs/03-architecture-ecrans.md demande "liste +
/// carte" pour le calendrier, mais une carte native type google_maps_flutter
/// est un chantier à part : clé API, config native Android/iOS. Décision :
/// lien externe pour cette itération).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openInMaps(BuildContext context, {required double latitude, required double longitude}) async {
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impossible d'ouvrir l'application de plans.")),
    );
  }
}
