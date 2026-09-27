/// Ouvre l'app de plans du téléphone — pas de carte intégrée en V1
/// (docs/03-architecture-ecrans.md demande "liste + carte" pour le
/// calendrier, mais une carte native type google_maps_flutter est un
/// chantier à part : clé API, config native Android/iOS. Décision : lien
/// externe pour cette itération).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Coordonnées précises quand disponibles (toujours le cas pour une
/// zawiya) ; à défaut, une recherche texte sur l'adresse (cas d'un
/// évènement sans coordonnées propres — voir `KhadaraEvent.addressText`,
/// 2026-09-27). Les deux formes de requête `google.com/maps/search`
/// s'ouvrent dans l'app de plans par défaut du téléphone de la même façon.
Future<void> openInMaps(
  BuildContext context, {
  double? latitude,
  double? longitude,
  String? addressText,
}) async {
  assert(
    (latitude != null && longitude != null) || (addressText != null && addressText.trim().isNotEmpty),
    'openInMaps requiert soit des coordonnées, soit une adresse.',
  );
  final query = (latitude != null && longitude != null) ? '$latitude,$longitude' : Uri.encodeComponent(addressText!.trim());
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impossible d'ouvrir l'application de plans.")),
    );
  }
}
