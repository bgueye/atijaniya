/// Récitation audio d'un pilier de wird (Supabase, table `wird_recitations`,
/// docs/decision-gestion-audio-wirds.md). Distincte du corpus texte local
/// (`wirds_content.dart`) : voir la note de résolution `wird_step_id` dans
/// ce même document, §10.
library;

class WirdRecitation {
  const WirdRecitation({
    required this.id,
    required this.audioPath,
    required this.contentVersion,
    this.durationSeconds,
  });

  final String id;

  /// Chemin dans le bucket Storage privé `wird-audio` — jamais une URL
  /// signée stockée (docs/decision-gestion-audio-wirds.md §2).
  final String audioPath;

  final int contentVersion;
  final int? durationSeconds;

  factory WirdRecitation.fromRow(Map<String, dynamic> row) {
    return WirdRecitation(
      id: row['id'] as String,
      audioPath: row['audio_path'] as String,
      contentVersion: row['content_version'] as int,
      durationSeconds: row['duration_seconds'] as int?,
    );
  }
}

/// État de disponibilité audio d'un pilier, tel qu'exposé à l'écran "Guide
/// du Wird" — combine "existe-t-il une récitation validée ?" et "est-elle
/// déjà téléchargée sur l'appareil ?" (docs/decision-gestion-audio-wirds.md §4).
enum PillarAudioAvailability {
  /// Aucune récitation validée pour ce pilier — état "bientôt disponible".
  noRecitation,
  notDownloaded,
  downloading,
  downloaded,
  error,
}

class PillarAudioState {
  const PillarAudioState({
    this.availability = PillarAudioAvailability.noRecitation,
    this.recitation,
    this.localPath,
    this.errorMessage,
  });

  final PillarAudioAvailability availability;
  final WirdRecitation? recitation;

  /// Chemin du fichier local une fois téléchargé — seule source lue par le
  /// lecteur (`WirdAudioPlayerService`), jamais un chemin/URL réseau.
  final String? localPath;

  final String? errorMessage;

  PillarAudioState copyWith({
    PillarAudioAvailability? availability,
    WirdRecitation? recitation,
    String? localPath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PillarAudioState(
      availability: availability ?? this.availability,
      recitation: recitation ?? this.recitation,
      localPath: localPath ?? this.localPath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
