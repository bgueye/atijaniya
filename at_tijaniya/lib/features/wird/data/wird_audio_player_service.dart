/// Enrobe `just_audio` pour le lecteur audio du Wird (P0 —
/// docs/03-architecture-ecrans.md : "Récitation modèle, synchronisée au
/// texte"). Lit les URL publiques du bucket Supabase Storage `wird-audio`
/// (docs/06-architecture-backend.md), une piste par pilier.
///
/// Ne connaît rien de la notion de "pilier" ni de wird — c'est un simple
/// lecteur d'URL, orchestré par `WirdAudioController`.
library;

import 'package:just_audio/just_audio.dart';

class WirdAudioPlayerService {
  WirdAudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> load(String url) => _player.setUrl(url);

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
