/// Retour sensoriel (vibration + son) quand un compteur de wird atteint sa
/// cible — Tasbih des wirds validés (par pilier) et Wird libre. Partagé
/// entre `TasbihController` et `FreeWirdController` : même signal, un seul
/// endroit à ajuster.
///
/// `SystemSoundType.click` plutôt qu'`alert` : `alert` est explicitement
/// ignoré sur mobile (Android/iOS) par l'implémentation Flutter — seul
/// `click` produit un son audible sur ces plateformes, qui sont les seules
/// ciblées par ce projet. Aucune permission Android supplémentaire
/// nécessaire : `HapticFeedback`/`SystemSound` passent par les API de retour
/// haptique/sonore de la vue, pas par le service `Vibrator` brut.
library;

import 'package:flutter/services.dart';

Future<void> playWirdCounterCompleteFeedback() async {
  await HapticFeedback.heavyImpact();
  await SystemSound.play(SystemSoundType.click);
}
