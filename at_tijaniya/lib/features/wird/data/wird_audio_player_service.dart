/// Enrobe `just_audio` pour le lecteur audio du Wird (P0 —
/// docs/03-architecture-ecrans.md : "Récitation modèle, synchronisée au
/// texte"). Lit exclusivement des fichiers locaux déjà téléchargés
/// (`WirdRecitationDownloadStore`, docs/decision-gestion-audio-wirds.md §4)
/// — jamais une URL réseau : le principe retenu est le téléchargement
/// définitif, pas le streaming répété.
///
/// Ne connaît rien de la notion de "pilier" ni de wird — c'est un simple
/// lecteur de fichier local, orchestré par `WirdAudioController`.
library;

import 'package:just_audio/just_audio.dart';

class WirdAudioPlayerService {
  WirdAudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> load(String localPath) => _player.setFilePath(localPath);

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
