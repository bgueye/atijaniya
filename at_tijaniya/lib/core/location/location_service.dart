/// Position de l'utilisateur pour "Trouver l'évènement récurrent le plus
/// proche" (module Khadara, `nearby_recurring_events_screen.dart`) — seul
/// usage de la géolocalisation dans l'app à ce jour. Permission "quand l'app
/// est utilisée" uniquement, précision approximative (`LocationAccuracy.low`,
/// `ACCESS_COARSE_LOCATION` côté Android) : suffisant pour classer des
/// zawiyas généralement distantes de plusieurs kilomètres, pas besoin d'une
/// précision GPS fine.
library;

import 'package:geolocator/geolocator.dart';

enum LocationFailure { serviceDisabled, permissionDenied, unknown }

class LocationResult {
  const LocationResult({this.position, this.failure});

  final Position? position;
  final LocationFailure? failure;

  bool get isSuccess => position != null;
}

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(failure: LocationFailure.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationResult(failure: LocationFailure.permissionDenied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      return LocationResult(position: position);
    } catch (_) {
      return const LocationResult(failure: LocationFailure.unknown);
    }
  }
}
