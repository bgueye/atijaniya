/// Disponibilité + téléchargement à la demande des récitations audio des
/// piliers d'un wird (docs/decision-gestion-audio-wirds.md §4) — distinct de
/// `WirdAudioController` (lecture/pause/position) : ce contrôleur ne
/// connaît rien de `just_audio`, seulement "cette récitation existe-t-elle,
/// est-elle sur l'appareil ?".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_recitation_download_store.dart';
import '../data/wird_recitation_repository.dart';
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

  Future<void> _loadRecitations() async {
    try {
      final recitations = await _repository.fetchRecitationsForWird(wird.id);
      final next = <int, PillarAudioState>{};
      for (var i = 0; i < wird.pillars.length; i++) {
        final recitation = recitations[i];
        if (recitation == null) {
          next[i] = const PillarAudioState();
          continue;
        }
        final downloaded = await _downloadStore.isDownloaded(recitation.audioPath);
        next[i] = PillarAudioState(
          availability: downloaded ? PillarAudioAvailability.downloaded : PillarAudioAvailability.notDownloaded,
          recitation: recitation,
          localPath: downloaded ? (await _downloadStore.localFileFor(recitation.audioPath)).path : null,
        );
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
  Future<String?> ensureDownloaded(int index) async {
    final current = state[index];
    if (current == null || current.recitation == null) return null;
    if (current.availability == PillarAudioAvailability.downloaded && current.localPath != null) {
      return current.localPath;
    }
    state = {...state, index: current.copyWith(availability: PillarAudioAvailability.downloading, clearError: true)};
    try {
      final bytes = await _repository.downloadAudioBytes(current.recitation!.audioPath);
      final file = await _downloadStore.save(current.recitation!.audioPath, bytes);
      if (!mounted) return file.path;
      state = {
        ...state,
        index: state[index]!.copyWith(availability: PillarAudioAvailability.downloaded, localPath: file.path),
      };
      return file.path;
    } catch (_) {
      if (mounted) {
        state = {
          ...state,
          index: state[index]!.copyWith(
            availability: PillarAudioAvailability.error,
            errorMessage: 'Téléchargement impossible — vérifiez votre connexion.',
          ),
        };
      }
      return null;
    }
  }
}
