/// Ouvre l'app de plans du téléphone — pas de carte intégrée en V1
/// (docs/03-architecture-ecrans.md demande "liste + carte" pour le
/// calendrier, mais une carte native type google_maps_flutter est un
/// chantier à part : clé API, config native Android/iOS. Décision : lien
/// externe pour cette itération).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// Coordonnées quand disponibles ; à défaut, une recherche texte sur
/// l'adresse (évènement sans coordonnées propres — voir
/// `KhadaraEvent.addressText`, 2026-09-27 — ou lieu de l'annuaire sans
/// coordonnées, 6 sur 34 au 2026-10-26). Les deux formes de requête `google.com/maps/search`
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
  // Lu avant l'attente : le contexte peut ne plus être monté après.
  final message = AppLocalizations.of(context)!.khadaraOpenInMapsError;
  final query = (latitude != null && longitude != null) ? '$latitude,$longitude' : Uri.encodeComponent(addressText!.trim());
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  // `launchUrl` renvoie `false` quand rien ne sait ouvrir le lien, mais peut
  // aussi lever (plateforme qui refuse, profil restreint) : les deux cas
  // donnent le même message au lieu d'une exception non rattrapée (audit
  // Zawiyas du 2026-10-25, P2-4, déjà relevé le 2026-10-04).
  bool launched;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!launched && context.mounted) {
    // Message traduit : il s'affichait en français dans l'interface en arabe.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
