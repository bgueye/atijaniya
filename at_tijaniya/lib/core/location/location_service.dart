/// Position de l'utilisateur pour "Trouver l'évènement récurrent le plus
/// proche" (module Khadara, `nearby_recurring_events_screen.dart`) — seul
/// usage de la géolocalisation dans l'app à ce jour. Permission "quand l'app
/// est utilisée" uniquement, précision approximative (`LocationAccuracy.low`,
/// `ACCESS_COARSE_LOCATION` côté Android) : suffisant pour classer des
/// zawiyas généralement distantes de plusieurs kilomètres, pas besoin d'une
/// précision GPS fine.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// [permissionDeniedForever] distingué de [permissionDenied] depuis l'audit
/// Zawiyas du 2026-10-25 (P2-8) : après un refus définitif, le système ne
/// redemande plus, et « Réessayer » échouait indéfiniment ; seul le passage
/// par les réglages de l'app débloque la situation.
enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever, unknown }

class LocationResult {
  const LocationResult({this.position, this.failure});

  final Position? position;
  final LocationFailure? failure;

  bool get isSuccess => position != null;
}

/// Fournisseur du service, remplaçable dans les tests (refus, service coupé,
/// réglages) : l'écran l'instanciait en dur, ce qui rendait ces cas
/// intestables.
final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentPosition() async {
    LocationPermission permission;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(failure: LocationFailure.serviceDisabled);
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Ces appels peuvent lever (demande de permission déjà en cours...) :
      // un échec propre plutôt qu'une exception non rattrapée.
      return const LocationResult(failure: LocationFailure.unknown);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(failure: LocationFailure.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(failure: LocationFailure.permissionDenied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        // Sans limite, l'attente pouvait durer indéfiniment en intérieur.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult(position: position);
    } catch (_) {
      return const LocationResult(failure: LocationFailure.unknown);
    }
  }

  /// Réglages de l'app (autorisation de localisation), après un refus
  /// définitif. `false` si le système ne les a pas ouverts.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Réglages de localisation de l'appareil, quand le service est coupé.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
