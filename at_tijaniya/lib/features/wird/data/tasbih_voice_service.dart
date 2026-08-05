/// Enrobe `speech_to_text` pour le mode "reconnaissance vocale" du Tasbih
/// digital (docs/03-architecture-ecrans.md, P0).
///
/// Principe retenu (cohérent avec les compteurs de dhikr vocaux usuels) :
/// la reconnaissance fine du texte arabe récité par un moteur de
/// speech-to-text grand public n'est pas fiable, donc on ne cherche pas à
/// faire correspondre le texte reconnu à la formule attendue. Chaque
/// énoncé détecté (segment de parole séparé d'une pause de 2s) compte pour
/// une répétition : le disciple récite, marque une courte pause, le
/// compteur avance. Le contrôleur (TasbihController) relance une nouvelle
/// écoute à chaque fin de session pour un comptage continu.
library;

import 'package:speech_to_text/speech_to_text.dart';

class TasbihVoiceService {
  TasbihVoiceService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  /// Initialise le moteur de reconnaissance vocale (demande la permission
  /// micro au premier appel). Retourne `false` si le moteur ou la
  /// permission ne sont pas disponibles sur l'appareil. Idempotent : les
  /// appels suivants réutilisent l'initialisation déjà faite.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
    return _initialized;
  }

  bool get isListening => _speech.isListening;

  /// Démarre une session d'écoute unique. [onUtteranceDetected] est appelé
  /// dès qu'un énoncé complet est reconnu (fin de session déclenchée par une
  /// pause de silence ou le timeout). L'appelant (contrôleur) est notifié de
  /// la fin de session via le `onStatus` fourni à [initialize] et décide
  /// alors de relancer [listenOnce] ou de s'arrêter.
  Future<void> listenOnce({required void Function() onUtteranceDetected}) {
    return _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          onUtteranceDetected();
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
        localeId: 'ar',
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
