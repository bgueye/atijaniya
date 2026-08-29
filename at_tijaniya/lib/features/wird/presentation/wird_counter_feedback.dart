/// Retour sensoriel (vibration + son) quand un compteur de wird atteint sa
/// cible — Tasbih des wirds validés (par pilier) et Wird libre. Partagé
/// entre `TasbihController` et `FreeWirdController` : même signal, un seul
/// endroit à ajuster.
///
/// Vibration : `Vibration.vibrate(duration: ...)` (plugin `vibration`) pour
/// un signal net et prolongé, plutôt que `HapticFeedback.heavyImpact()` —
/// ce dernier ne propose que des impulsions système brèves, gardé ici en
/// repli si l'appareil n'a pas de vibreur contrôlable (web/desktop).
///
/// Son : un bip synthétisé dédié (`assets/audio/sfx/pillar_complete.wav`)
/// plutôt que `SystemSound.play` — celui-ci ne propose que `click`/`alert`,
/// `alert` étant explicitement ignoré sur mobile par l'implémentation
/// Flutter, donc trop discret pour ce signal de fin de pilier. Lecteur
/// `just_audio` dédié, chargé une seule fois puis rejoué (`seek` + `play`)
/// pour éviter de recréer un `AudioPlayer` à chaque pilier.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

final AudioPlayer _sfxPlayer = AudioPlayer();
bool _sfxLoaded = false;

Future<void> playWirdCounterCompleteFeedback() async {
  unawaited(_vibrate());
  unawaited(_beep());
}

Future<void> _vibrate() async {
  try {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 450);
      return;
    }
  } catch (_) {
    // Plateforme sans plugin natif fonctionnel (web/desktop) — repli ci-dessous.
  }
  await HapticFeedback.heavyImpact();
}

Future<void> _beep() async {
  try {
    if (!_sfxLoaded) {
      await _sfxPlayer.setAsset('assets/audio/sfx/pillar_complete.wav');
      _sfxLoaded = true;
    }
    await _sfxPlayer.seek(Duration.zero);
    await _sfxPlayer.play();
  } catch (_) {
    // Asset non chargeable/lecteur indisponible — repli sur le son système.
    await SystemSound.play(SystemSoundType.click);
  }
}
