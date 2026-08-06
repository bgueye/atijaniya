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

final tasbihControllerProvider =
    StateNotifierProvider.family<TasbihController, TasbihState, Wird>(
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

  WirdPillar get currentPillar => wird.pillars[state.session.pillarIndex];

  int get targetCount => currentPillar.repetitions;

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
    final ready = await _voice.initialize(
      onStatus: _onVoiceStatus,
      onError: (error) => state = state.copyWith(voiceError: error, isListening: false),
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
    await _voice.listenOnce(onUtteranceDetected: increment);
  }

  void stopListening() => _stopVoiceLoop();

  void _stopVoiceLoop() {
    if (!_voiceLoopActive) return;
    _voiceLoopActive = false;
    _voice.stop();
    state = state.copyWith(isListening: false);
  }

  void _onVoiceStatus(String status) {
    if (!mounted) return;
    state = state.copyWith(isListening: status == 'listening');
    final sessionEnded = status == 'notListening' || status == 'done';
    if (sessionEnded && _voiceLoopActive && !isPillarComplete) {
      _voice.listenOnce(onUtteranceDetected: increment);
    }
  }

  @override
  void dispose() {
    _voiceLoopActive = false;
    _voice.cancel();
    super.dispose();
  }
}
