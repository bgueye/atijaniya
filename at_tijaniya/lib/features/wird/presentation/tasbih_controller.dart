/// Contrôleur du Tasbih digital (P0 — docs/03-architecture-ecrans.md :
/// "Tape manuel, reconnaissance vocale, reprise de session").
///
/// Fait avancer le disciple pilier par pilier dans l'ordre impératif du wird
/// (`Wird.pillars`), avec deux façons de compter (tape manuelle ou
/// reconnaissance vocale — une seule active à la fois) et une reprise
/// automatique de la session en cours au retour sur l'écran.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasbih_session_store.dart';
import '../data/tasbih_voice_service.dart';
import '../data/wird_completion_store.dart';
import '../domain/tasbih_session.dart';
import '../domain/wird_models.dart';
import 'wird_counter_feedback.dart';

class TasbihState {
  const TasbihState({
    required this.session,
    this.loadingSession = true,
    this.isListening = false,
    this.voiceSupported = true,
    this.voiceError,
    this.wirdCompleted = false,
  });

  final TasbihSession session;
  final bool loadingSession;
  final bool isListening;
  final bool voiceSupported;
  final String? voiceError;
  final bool wirdCompleted;

  TasbihState copyWith({
    TasbihSession? session,
    bool? loadingSession,
    bool? isListening,
    bool? voiceSupported,
    String? voiceError,
    bool clearVoiceError = false,
    bool? wirdCompleted,
  }) {
    return TasbihState(
      session: session ?? this.session,
      loadingSession: loadingSession ?? this.loadingSession,
      isListening: isListening ?? this.isListening,
      voiceSupported: voiceSupported ?? this.voiceSupported,
      voiceError: clearVoiceError ? null : (voiceError ?? this.voiceError),
      wirdCompleted: wirdCompleted ?? this.wirdCompleted,
    );
  }
}

// `.autoDispose` : sans lui, quitter l'écran pendant une écoute vocale active
// laisse le contrôleur (et donc `_voiceLoopActive`) vivre indéfiniment en
// arrière-plan — la boucle continue de relancer `SpeechRecognizer` (Android
// ne permet qu'une session active à la fois) et provoque un `error_busy`
// permanent sur n'importe quel autre wird ouvert ensuite. Sans risque pour la
// reprise de session : `TasbihSessionStore` persiste la progression, `_load()`
// la recharge à la recréation du contrôleur.
final tasbihControllerProvider =
    StateNotifierProvider.autoDispose.family<TasbihController, TasbihState, Wird>(
  (ref, wird) => TasbihController(wird: wird),
);

class TasbihController extends StateNotifier<TasbihState> {
  TasbihController({required this.wird})
      : super(TasbihState(session: TasbihSession.initial(wird.id))) {
    _load();
  }

  final Wird wird;
  final TasbihSessionStore _store = const TasbihSessionStore();
  final WirdCompletionStore _completionStore = const WirdCompletionStore();
  final TasbihVoiceService _voice = TasbihVoiceService();

  /// `true` tant que le disciple n'a pas explicitement arrêté l'écoute et
  /// que le pilier courant n'est pas terminé : permet de relancer l'écoute
  /// en continu à chaque fin de segment de parole détecté.
  bool _voiceLoopActive = false;

  /// Nombre d'erreurs consécutives (`error_busy`, etc.) depuis le dernier
  /// énoncé reconnu avec succès. Remise à zéro sur un succès ; au-delà de
  /// [_maxConsecutiveVoiceErrors], on arrête la boucle au lieu de continuer
  /// à relancer une écoute vouée à échouer.
  int _consecutiveVoiceErrors = 0;
  static const _maxConsecutiveVoiceErrors = 3;

  /// `speech_to_text` (Android) émet **deux** statuts de fin de session
  /// (`notListening` puis `done`) pour une seule session terminée. Sans ce
  /// verrou, chacun déclenche sa propre relance : deux appels `listenOnce()`
  /// concurrents sur le même moteur natif, qui répond alors `error_busy` —
  /// la vraie cause de la boucle/blocage initial, pas seulement l'absence de
  /// compteur d'erreurs. Posé à la première relance programmée, levé une
  /// fois celle-ci exécutée (ou abandonnée).
  bool _restartScheduled = false;

  WirdPillar get currentPillar => wird.pillars[state.session.pillarIndex];

  int get targetCount => currentPillar.repetitions;

  /// Une formule longue (ex. Salatoul Fatihi, ~230 caractères) contient des
  /// pauses naturelles pour respirer qu'un silence trop court interprète à
  /// tort comme la fin de l'énoncé. Les formules courtes (ex. "Allah",
  /// répété des centaines de fois) ont au contraire besoin d'un silence
  /// court pour rester réactives entre deux répétitions. Voir
  /// `tasbih_voice_service.dart` pour pourquoi cette segmentation est faite
  /// côté Dart plutôt que via le paramètre natif `pauseFor`.
  Duration get _utteranceSilence {
    final length = currentPillar.arabic.length;
    if (length > 120) return const Duration(seconds: 8);
    if (length > 50) return const Duration(seconds: 5);
    return const Duration(seconds: 3);
  }

  bool get isPillarComplete => state.session.currentCount >= targetCount;

  bool get isLastPillar => state.session.pillarIndex == wird.pillars.length - 1;

  Future<void> _load() async {
    final saved = await _store.load(wird.id);
    if (saved != null && saved.pillarIndex < wird.pillars.length) {
      state = state.copyWith(session: saved, loadingSession: false);
    } else {
      state = state.copyWith(loadingSession: false);
    }
  }

  void increment() {
    if (isPillarComplete) return;
    final next = state.session.copyWith(currentCount: state.session.currentCount + 1);
    state = state.copyWith(session: next);
    _store.save(next);
    if (next.currentCount >= targetCount) {
      _stopVoiceLoop();
      playWirdCounterCompleteFeedback();
    }
  }

  void undo() {
    if (state.session.currentCount == 0) return;
    final next = state.session.copyWith(currentCount: state.session.currentCount - 1);
    state = state.copyWith(session: next);
    _store.save(next);
  }

  Future<void> resetPillar() async {
    _stopVoiceLoop();
    final next = state.session.copyWith(currentCount: 0);
    state = state.copyWith(session: next);
    await _store.save(next);
  }

  /// Passe au pilier suivant, ou termine le wird si c'était le dernier.
  Future<void> nextPillar() async {
    _stopVoiceLoop();
    if (isLastPillar) {
      await _store.clear(wird.id);
      await _completionStore.recordCompletionToday(wird.id);
      state = state.copyWith(wirdCompleted: true);
      return;
    }
    final next = state.session.copyWith(
      pillarIndex: state.session.pillarIndex + 1,
      currentCount: 0,
    );
    state = state.copyWith(session: next);
    await _store.save(next);
  }

  Future<void> setMode(TasbihMode mode) async {
    if (mode == state.session.mode) return;
    if (state.session.mode == TasbihMode.voice) {
      _stopVoiceLoop();
    }
    final next = state.session.copyWith(mode: mode);
    state = state.copyWith(session: next, clearVoiceError: true);
    await _store.save(next);
  }

  Future<void> startListening() async {
    if (isPillarComplete || _voiceLoopActive) return;
    _consecutiveVoiceErrors = 0;
    final ready = await _voice.initialize(
      onStatus: _onVoiceStatus,
      onError: _onVoiceError,
    );
    if (!ready) {
      state = state.copyWith(
        voiceSupported: false,
        voiceError: "Micro indisponible ou permission refusée — utilisez le mode tape manuel.",
      );
      return;
    }
    _voiceLoopActive = true;
    state = state.copyWith(clearVoiceError: true);
    await _voice.startListening(
      onUtteranceDetected: _onUtteranceDetected,
      utteranceSilence: _utteranceSilence,
    );
  }

  void stopListening() => _stopVoiceLoop();

  void _stopVoiceLoop() {
    if (!_voiceLoopActive) return;
    _voiceLoopActive = false;
    _voice.stop();
    state = state.copyWith(isListening: false);
  }

  void _onUtteranceDetected() {
    // `mounted` : ce callback est asynchrone (résultat natif différé) et peut
    // arriver après que l'écran a été quitté et le contrôleur détruit
    // (`.autoDispose`) — écrire sur `state` à ce moment lève `Bad state:
    // Tried to use TasbihController after dispose was called`.
    if (!mounted) return;
    // Un énoncé reconnu avec succès prouve que le moteur natif fonctionne :
    // on repart avec un compteur d'erreurs propre.
    _consecutiveVoiceErrors = 0;
    increment();
  }

  /// Le plugin `speech_to_text` (Android) marque **toutes** les erreurs
  /// comme "permanentes", ce qui annule systématiquement la session en
  /// cours et déclenche un `notListening`/`done` côté `_onVoiceStatus`, qui
  /// relance aussitôt une écoute. Sans compteur, une vraie panne (ex.
  /// `error_busy` répété — le service de reconnaissance de l'appareil reste
  /// occupé) produit une boucle serrée erreur → relance → erreur, visible à
  /// l'écran comme un clignotement sans fin du bouton "Démarrer
  /// l'écoute"/"Mettre en pause".
  void _onVoiceError(String error) {
    if (!mounted) return;
    _consecutiveVoiceErrors++;
    if (_consecutiveVoiceErrors >= _maxConsecutiveVoiceErrors) {
      _stopVoiceLoop();
      state = state.copyWith(
        voiceError:
            "La reconnaissance vocale rencontre un problème répété sur cet appareil ($error) — utilisez le mode tape manuel.",
      );
    } else {
      state = state.copyWith(voiceError: error, isListening: false);
    }
  }

  void _onVoiceStatus(String status) {
    if (!mounted) return;
    state = state.copyWith(isListening: status == 'listening');
    final sessionEnded = status == 'notListening' || status == 'done';
    if (sessionEnded && _voiceLoopActive && !isPillarComplete && !_restartScheduled) {
      _restartScheduled = true;
      _restartListening();
    }
  }

  /// Laisse le temps au moteur de reconnaissance natif de libérer la
  /// session précédente avant d'en relancer une — sans ce délai, la
  /// relance immédiate court-circuite la libération de `SpeechRecognizer`
  /// côté Android et provoque `error_busy` en boucle (voir [_onVoiceError]).
  Future<void> _restartListening() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _restartScheduled = false;
    if (!mounted || !_voiceLoopActive || isPillarComplete) return;
    await _voice.startListening(
      onUtteranceDetected: _onUtteranceDetected,
      utteranceSilence: _utteranceSilence,
    );
  }

  @override
  void dispose() {
    _voiceLoopActive = false;
    _restartScheduled = false;
    _voice.cancel();
    super.dispose();
  }
}
