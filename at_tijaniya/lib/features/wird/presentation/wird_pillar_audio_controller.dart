/// Disponibilité + téléchargement à la demande des récitations audio des
/// piliers d'un wird (docs/decision-gestion-audio-wirds.md §4) — distinct de
/// `WirdAudioController` (lecture/pause/position) : ce contrôleur ne
/// connaît rien de `just_audio`, seulement "cette récitation existe-t-elle,
/// est-elle sur l'appareil ?". Gère aussi la mise à jour de contenu et sa
/// rétention (§4) : quand `audio_path` change (correction validée),
/// l'ancienne version reste servie tant que la nouvelle n'est pas
/// téléchargée avec succès — remplacement silencieux ensuite (§8, décision
/// 4), jamais d'échange visible ni d'erreur affichée pour une mise à jour
/// que le disciple n'a pas demandée.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_recitation_asset_manifest.dart';
import '../data/wird_recitation_download_store.dart';
import '../data/wird_recitation_repository.dart';
import '../data/wird_recitation_version_store.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';

final wirdPillarAudioProvider =
    StateNotifierProvider.family<WirdPillarAudioController, Map<int, PillarAudioState>, Wird>(
  (ref, wird) => WirdPillarAudioController(wird: wird),
);

class WirdPillarAudioController extends StateNotifier<Map<int, PillarAudioState>> {
  WirdPillarAudioController({required this.wird}) : super(const {}) {
    _loadRecitations();
  }

  final Wird wird;
  final WirdRecitationRepository _repository = const WirdRecitationRepository();
  final WirdRecitationDownloadStore _downloadStore = const WirdRecitationDownloadStore();
  final WirdRecitationVersionStore _versionStore = const WirdRecitationVersionStore();
  final WirdRecitationAssetManifest _assetManifest = const WirdRecitationAssetManifest();

  /// Garde contre les téléchargements concurrents du même pilier (double-tap
  /// sur play, ou `playNext`/`playPrevious` déclenchés vite l'un après
  /// l'autre) : sans elle, deux appels à [ensureDownloaded] pour le même
  /// [index] passent tous les deux le test `availability == downloaded`
  /// (le premier appel ne bascule l'état en `downloading` qu'après son
  /// premier point d'`await`) et lancent chacun un téléchargement — les deux
  /// écrivent alors vers le même fichier temporaire
  /// (`WirdRecitationDownloadStore.save`), une vraie corruption possible,
  /// pas seulement de la bande passante gaspillée.
  final Map<int, Future<String?>> _inFlightDownloads = {};

  Future<void> _loadRecitations() async {
    try {
      final recitations = await _repository.fetchRecitationsForWird(wird.id);
      final assets = await _assetManifest.load();
      final next = <int, PillarAudioState>{};
      for (var i = 0; i < wird.pillars.length; i++) {
        final recitation = recitations[i];
        if (recitation == null) {
          next[i] = const PillarAudioState();
          continue;
        }
        if (await _downloadStore.isDownloaded(recitation.audioPath)) {
          next[i] = PillarAudioState(
            availability: PillarAudioAvailability.downloaded,
            recitation: recitation,
            localPath: (await _downloadStore.localFileFor(recitation.audioPath)).path,
          );
          unawaited(_promote(i, recitation.audioPath));
          continue;
        }
        final asset = assets[recitation.audioPath];
        if (asset != null) {
          // Asset embarqué encore à jour (même `audio_path` que la version
          // courante côté serveur, §4) : copie locale instantanée, zéro
          // appel réseau, disponible dès le tout premier lancement.
          try {
            final file = await _downloadStore.copyFromAsset(recitation.audioPath, asset.assetPath);
            await _promote(i, recitation.audioPath);
            next[i] = PillarAudioState(
              availability: PillarAudioAvailability.downloaded,
              recitation: recitation,
              localPath: file.path,
            );
            continue;
          } catch (_) {
            // Asset illisible/corrompu : on retombe sur le chemin normal
            // (téléchargement) plutôt que de bloquer ce pilier.
          }
        }
        // Pas encore téléchargé sous ce chemin (et pas d'asset embarqué à
        // jour) : si une version précédente est encore sur l'appareil, on
        // continue à la servir pendant qu'on tente la mise à jour en
        // arrière-plan (rétention, §4) — sinon, premier téléchargement
        // classique (état "notDownloaded", §4).
        final previousPath = await _versionStore.activeAudioPath(wird.id, i);
        if (previousPath != null && await _downloadStore.isDownloaded(previousPath)) {
          next[i] = PillarAudioState(
            availability: PillarAudioAvailability.downloaded,
            recitation: recitation,
            localPath: (await _downloadStore.localFileFor(previousPath)).path,
          );
          unawaited(_backgroundUpdate(i, recitation));
        } else {
          next[i] = PillarAudioState(availability: PillarAudioAvailability.notDownloaded, recitation: recitation);
        }
      }
      if (mounted) state = next;
    } catch (_) {
      // Erreur réseau au chargement des métadonnées : les piliers restent
      // dans leur état par défaut ("bientôt disponible" côté écran), pas de
      // blocage de l'écran — la récitation reste consultable dès que la
      // connexion revient (l'écran ne fait pas de requête en boucle).
    }
  }

  /// Télécharge (si nécessaire) la récitation du pilier [index], puis
  /// renvoie son chemin local. `null` si ce pilier n'a pas de récitation
  /// validée, ou si le téléchargement a échoué (voir `errorMessage` sur
  /// l'état correspondant).
  Future<String?> ensureDownloaded(int index) {
    final inFlight = _inFlightDownloads[index];
    if (inFlight != null) return inFlight;

    final future = _downloadPillar(index);
    _inFlightDownloads[index] = future;
    future.whenComplete(() => _inFlightDownloads.remove(index));
    return future;
  }

  Future<String?> _downloadPillar(int index) async {
    final current = state[index];
    if (current == null || current.recitation == null) return null;
    if (current.availability == PillarAudioAvailability.downloaded && current.localPath != null) {
      return current.localPath;
    }
    state = {...state, index: current.copyWith(availability: PillarAudioAvailability.downloading, clearError: true)};
    final audioPath = current.recitation!.audioPath;
    try {
      final bytes = await _repository.downloadAudioBytes(audioPath);
      final file = await _downloadStore.save(audioPath, bytes);
      await _promote(index, audioPath);
      if (!mounted) return file.path;
      state = {
        ...state,
        index: state[index]!.copyWith(availability: PillarAudioAvailability.downloaded, localPath: file.path),
      };
      return file.path;
    } catch (e) {
      if (mounted) {
        state = {
          ...state,
          index: state[index]!.copyWith(
            availability: PillarAudioAvailability.error,
            errorMessage: _downloadErrorMessage(e),
          ),
        };
      }
      return null;
    }
  }

  /// Distingue un problème de stockage local (espace disque insuffisant)
  /// d'un problème réseau — deux causes que le disciple ne corrige pas de
  /// la même façon (docs/decision-gestion-audio-wirds.md §4).
  String _downloadErrorMessage(Object error) {
    if (error is FileSystemException) {
      return "Espace de stockage insuffisant sur l'appareil.";
    }
    return 'Téléchargement impossible — vérifiez votre connexion.';
  }

  /// Marque [audioPath] comme version active pour le pilier [index] et, si
  /// une version différente était active avant, supprime son fichier local.
  /// Appelée uniquement après que [audioPath] est confirmé sur le disque
  /// (jamais avant, jamais depuis un téléchargement en échec) — c'est cette
  /// séquence, pas un minuteur, qui garantit la règle de rétention du §4 :
  /// l'ancienne version ne disparaît jamais avant que la nouvelle soit prête.
  Future<void> _promote(int index, String audioPath) async {
    final previousPath = await _versionStore.activeAudioPath(wird.id, index);
    if (previousPath == audioPath) return;
    await _versionStore.setActiveAudioPath(wird.id, index, audioPath);
    if (previousPath != null) {
      await _downloadStore.delete(previousPath);
    }
  }

  /// Tente de télécharger une nouvelle version en tâche de fond pendant que
  /// l'ancienne reste servie. Échec silencieux — "si le nouveau
  /// téléchargement échoue, l'ancienne version reste lisible" (§4) : jamais
  /// d'erreur affichée pour une mise à jour que le disciple n'a pas
  /// lui-même demandée.
  Future<void> _backgroundUpdate(int index, WirdRecitation recitation) async {
    try {
      final bytes = await _repository.downloadAudioBytes(recitation.audioPath);
      final file = await _downloadStore.save(recitation.audioPath, bytes);
      await _promote(index, recitation.audioPath);
      if (!mounted) return;
      final current = state[index];
      if (current == null) return;
      state = {
        ...state,
        index: current.copyWith(recitation: recitation, localPath: file.path),
      };
    } catch (_) {
      // Ignoré volontairement — voir le commentaire de la méthode.
    }
  }
}
