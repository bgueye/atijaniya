/// Contrôleur du lecteur audio du Wird (P0 — docs/03-architecture-ecrans.md :
/// "Récitation modèle, synchronisée au texte").
///
/// Lit les piliers dans l'ordre, un `AudioPlayer` par écran (voir
/// `WirdAudioPlayerService`), et avance automatiquement au pilier suivant
/// disposant d'une récitation quand une piste se termine — pour une lecture
/// continue du wird sans intervention. La disponibilité (existe-t-elle une
/// récitation validée ? est-elle déjà téléchargée ?) vient de
/// `WirdPillarAudioController`, pas d'un champ statique du corpus local —
/// voir `wird_pillar_audio_controller.dart` et
/// docs/decision-gestion-audio-wirds.md §10.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/wird_audio_player_service.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';
import 'wird_pillar_audio_controller.dart';

class WirdAudioState {
  const WirdAudioState({
    this.activePillarIndex,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration,
    this.errorMessage,
  });

  /// Index du pilier chargé dans `Wird.pillars`, `null` si aucune lecture
  /// n'a encore été démarrée.
  final int? activePillarIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration? duration;
  final String? errorMessage;

  WirdAudioState copyWith({
    int? activePillarIndex,
    bool clearActivePillar = false,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WirdAudioState(
      activePillarIndex: clearActivePillar ? null : (activePillarIndex ?? this.activePillarIndex),
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final wirdAudioControllerProvider =
    StateNotifierProvider.family<WirdAudioController, WirdAudioState, Wird>(
  (ref, wird) => WirdAudioController(ref: ref, wird: wird),
);

class WirdAudioController extends StateNotifier<WirdAudioState> {
  WirdAudioController({required this.ref, required this.wird}) : super(const WirdAudioState()) {
    _positionSub = _service.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _durationSub = _service.durationStream.listen((d) {
      state = state.copyWith(duration: d, clearDuration: d == null);
    });
    _playerStateSub = _service.playerStateStream.listen(_onPlayerState);
  }

  final Ref ref;
  final Wird wird;
  final WirdAudioPlayerService _service = WirdAudioPlayerService();

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<PlayerState> _playerStateSub;

  Map<int, PillarAudioState> get _pillarAudio => ref.read(wirdPillarAudioProvider(wird));

  bool _hasRecitation(int index) => _pillarAudio[index]?.recitation != null;

  bool get hasAnyAudio => _pillarAudio.values.any((s) => s.recitation != null);

  /// Démarre la lecture du pilier [index] (téléchargeant sa récitation au
  /// besoin, docs/decision-gestion-audio-wirds.md §4), ou reprend/suspend la
  /// piste en cours si c'est déjà celle-là.
  Future<void> playPillar(int index) async {
    if (index == state.activePillarIndex) {
      await togglePlayPause();
      return;
    }
    if (!_hasRecitation(index)) {
      state = state.copyWith(errorMessage: "Récitation audio pas encore disponible pour ce pilier.");
      return;
    }
    state = state.copyWith(
      activePillarIndex: index,
      clearError: true,
      position: Duration.zero,
      clearDuration: true,
    );
    final localPath = await ref.read(wirdPillarAudioProvider(wird).notifier).ensureDownloaded(index);
    if (localPath == null) {
      final downloadError = ref.read(wirdPillarAudioProvider(wird))[index]?.errorMessage;
      state = state.copyWith(errorMessage: downloadError ?? "Impossible de lire cette récitation pour le moment.");
      return;
    }
    if (!mounted) return;
    try {
      await _service.load(localPath);
      await _service.play();
    } catch (_) {
      state = state.copyWith(errorMessage: "Impossible de lire cette récitation pour le moment.");
    }
  }

  Future<void> togglePlayPause() async {
    if (state.activePillarIndex == null) {
      final firstWithAudio = _firstIndexWithAudio();
      if (firstWithAudio == -1) {
        state = state.copyWith(errorMessage: "Récitations audio pas encore disponibles pour ce Wird.");
        return;
      }
      await playPillar(firstWithAudio);
      return;
    }
    if (state.isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> seek(Duration position) => _service.seek(position);

  Future<void> playNext() => _jumpRelative(1);

  Future<void> playPrevious() => _jumpRelative(-1);

  bool get hasNext => _nextIndexWithAudio(1) != -1;

  bool get hasPrevious => _nextIndexWithAudio(-1) != -1;

  Future<void> _jumpRelative(int direction) async {
    final next = _nextIndexWithAudio(direction);
    if (next == -1) return;
    await playPillar(next);
  }

  int _nextIndexWithAudio(int direction) {
    final current = state.activePillarIndex;
    if (current == null) return _firstIndexWithAudio();
    var i = current + direction;
    while (i >= 0 && i < wird.pillars.length) {
      if (_hasRecitation(i)) return i;
      i += direction;
    }
    return -1;
  }

  int _firstIndexWithAudio() {
    for (var i = 0; i < wird.pillars.length; i++) {
      if (_hasRecitation(i)) return i;
    }
    return -1;
  }

  Future<void> stop() async {
    await _service.stop();
    state = state.copyWith(clearActivePillar: true, isPlaying: false, position: Duration.zero, clearDuration: true);
  }

  void _onPlayerState(PlayerState playerState) {
    if (!mounted) return;
    state = state.copyWith(
      isPlaying: playerState.playing,
      isBuffering: playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading,
    );
    if (playerState.processingState == ProcessingState.completed) {
      final next = _nextIndexWithAudio(1);
      if (next == -1) {
        stop();
      } else {
        playPillar(next);
      }
    }
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _playerStateSub.cancel();
    _service.dispose();
    super.dispose();
  }
}
