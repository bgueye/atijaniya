/// Contrôleur du Wird libre — compteur paramétré par le disciple (nom +
/// cible de répétitions), avec les deux mêmes façons de compter que le
/// Tasbih des wirds validés (tape manuelle ou reconnaissance vocale) et une
/// reprise automatique du compteur en cours. Un seul compteur libre actif à
/// la fois (voir `free_wird_store.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/free_wird_store.dart';
import '../data/tasbih_voice_service.dart';
import '../domain/free_wird_session.dart';
import '../domain/tasbih_session.dart' show TasbihMode;
import 'wird_counter_feedback.dart';

class FreeWirdState {
  const FreeWirdState({
    this.session,
    this.loading = true,
    this.isListening = false,
    this.voiceSupported = true,
    this.voiceError,
    this.completed = false,
  });

  /// `null` tant qu'aucun compteur n'a été paramétré — l'écran affiche
  /// alors le formulaire de configuration.
  final FreeWirdSession? session;
  final bool loading;
  final bool isListening;
  final bool voiceSupported;
  final String? voiceError;
  final bool completed;

  FreeWirdState copyWith({
    FreeWirdSession? session,
    bool clearSession = false,
    bool? loading,
    bool? isListening,
    bool? voiceSupported,
    String? voiceError,
    bool clearVoiceError = false,
    bool? completed,
  }) {
    return FreeWirdState(
      session: clearSession ? null : (session ?? this.session),
      loading: loading ?? this.loading,
      isListening: isListening ?? this.isListening,
      voiceSupported: voiceSupported ?? this.voiceSupported,
      voiceError: clearVoiceError ? null : (voiceError ?? this.voiceError),
      completed: completed ?? this.completed,
    );
  }
}

final freeWirdControllerProvider = StateNotifierProvider<FreeWirdController, FreeWirdState>(
  (ref) => FreeWirdController(),
);

class FreeWirdController extends StateNotifier<FreeWirdState> {
  FreeWirdController() : super(const FreeWirdState()) {
    _load();
  }

  final FreeWirdStore _store = const FreeWirdStore();
  final TasbihVoiceService _voice = TasbihVoiceService();

  /// `true` tant que le disciple n'a pas explicitement arrêté l'écoute et
  /// que la cible n'est pas atteinte : relance l'écoute en continu, même
  /// principe que `TasbihController`.
  bool _voiceLoopActive = false;

  bool get isTargetReached {
    final session = state.session;
    return session != null && session.currentCount >= session.target;
  }

  Future<void> _load() async {
    final saved = await _store.load();
    state = state.copyWith(session: saved, loading: false);
  }

  Future<void> configure({required String label, required int target}) async {
    final session = FreeWirdSession.initial(label: label.trim(), target: target);
    state = state.copyWith(session: session, completed: false);
    await _store.save(session);
  }

  void increment() {
    final session = state.session;
    if (session == null || isTargetReached) return;
    final next = session.copyWith(currentCount: session.currentCount + 1);
    state = state.copyWith(session: next);
    _store.save(next);
    if (next.currentCount >= next.target) {
      _stopVoiceLoop();
      playWirdCounterCompleteFeedback();
    }
  }

  void undo() {
    final session = state.session;
    if (session == null || session.currentCount == 0) return;
    final next = session.copyWith(currentCount: session.currentCount - 1);
    state = state.copyWith(session: next);
    _store.save(next);
  }

  Future<void> resetCount() async {
    final session = state.session;
    if (session == null) return;
    _stopVoiceLoop();
    final next = session.copyWith(currentCount: 0);
    state = state.copyWith(session: next);
    await _store.save(next);
  }

  /// Termine le compteur libre une fois la cible atteinte. Pas d'historique
  /// à conserver (contrairement aux wirds validés) : le store est vidé.
  Future<void> finish() async {
    _stopVoiceLoop();
    await _store.clear();
    state = state.copyWith(completed: true);
  }

  /// Repart sur un formulaire de configuration vide.
  Future<void> newCounter() async {
    _stopVoiceLoop();
    await _store.clear();
    state = state.copyWith(clearSession: true, completed: false, clearVoiceError: true);
  }

  Future<void> setMode(TasbihMode mode) async {
    final session = state.session;
    if (session == null || mode == session.mode) return;
    if (session.mode == TasbihMode.voice) {
      _stopVoiceLoop();
    }
    final next = session.copyWith(mode: mode);
    state = state.copyWith(session: next, clearVoiceError: true);
    await _store.save(next);
  }

  Future<void> startListening() async {
    if (isTargetReached || _voiceLoopActive) return;
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
    if (sessionEnded && _voiceLoopActive && !isTargetReached) {
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
