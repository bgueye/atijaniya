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

/// Entrée du manifeste d'assets embarqués
/// (`assets/audio/manifest.json`, docs/decision-gestion-audio-wirds.md §4)
/// — la version validée au moment du build, figée dans l'APK/IPA. Utilisée
/// seulement si `audioPath` correspond encore à la version courante côté
/// serveur (sinon l'asset est périmé, on retombe sur un téléchargement
/// normal).
class WirdRecitationAsset {
  const WirdRecitationAsset({
    required this.audioPath,
    required this.assetPath,
    required this.contentVersion,
  });

  final String audioPath;
  final String assetPath;
  final int contentVersion;

  factory WirdRecitationAsset.fromJson(Map<String, dynamic> json) {
    return WirdRecitationAsset(
      audioPath: json['audio_path'] as String,
      assetPath: json['asset_path'] as String,
      contentVersion: json['content_version'] as int,
    );
  }
}

/// Récitation en `brouillon`, avec assez de contexte (wird + pilier) pour
/// l'écran de review admin (`WirdRecitationsReviewScreen`,
/// docs/decision-gestion-audio-wirds.md §7) — `WirdRecitation` seul ne
/// suffit pas ici : la liste mélange des piliers de wirds différents.
class WirdRecitationDraft {
  const WirdRecitationDraft({
    required this.id,
    required this.reciterName,
    required this.audioPath,
    required this.contentVersion,
    required this.wirdNameFrench,
    required this.pillarLabel,
    this.durationSeconds,
  });

  final String id;
  final String reciterName;
  final String audioPath;
  final int contentVersion;
  final String wirdNameFrench;

  /// Translittération du pilier (ou, à défaut, son texte arabe) — juste de
  /// quoi identifier lequel des piliers du wird est concerné, pas un
  /// affichage complet du texte religieux (hors sujet pour cet écran).
  final String pillarLabel;

  final int? durationSeconds;

  factory WirdRecitationDraft.fromRow(Map<String, dynamic> row) {
    final step = row['wird_steps'] as Map<String, dynamic>;
    final wird = step['wirds'] as Map<String, dynamic>;
    return WirdRecitationDraft(
      id: row['id'] as String,
      reciterName: row['reciter_name'] as String,
      audioPath: row['audio_path'] as String,
      contentVersion: row['content_version'] as int,
      durationSeconds: row['duration_seconds'] as int?,
      wirdNameFrench: wird['name_fr'] as String,
      pillarLabel: (step['transliteration'] as String?) ??
          (step['arabic_text'] as String),
    );
  }
}

/// Une ligne `wird_recitations` complète, tout statut confondu — pour
/// l'écran de gestion admin par pilier (`WirdRecitationsManagementScreen`).
/// Distincte de [WirdRecitation] (disciple, toujours valide+is_default
/// implicite) et de [WirdRecitationDraft] (brouillons à plat, tous wirds
/// confondus) : porte [wirdStepId], nécessaire ici pour uploader/démoter
/// au bon pilier.
class WirdRecitationEntry {
  const WirdRecitationEntry({
    required this.id,
    required this.wirdStepId,
    required this.reciterName,
    required this.audioPath,
    required this.contentVersion,
    required this.contentStatus,
    required this.isDefault,
    this.durationSeconds,
  });

  final String id;
  final String wirdStepId;
  final String reciterName;
  final String audioPath;
  final int contentVersion;

  /// 'brouillon' | 'valide' — voir la contrainte `check` de la colonne en base.
  final String contentStatus;
  final bool isDefault;
  final int? durationSeconds;

  factory WirdRecitationEntry.fromRow(Map<String, dynamic> row) {
    return WirdRecitationEntry(
      id: row['id'] as String,
      wirdStepId: row['wird_step_id'] as String,
      reciterName: row['reciter_name'] as String,
      audioPath: row['audio_path'] as String,
      contentVersion: row['content_version'] as int,
      contentStatus: row['content_status'] as String,
      isDefault: row['is_default'] as bool,
      durationSeconds: row['duration_seconds'] as int?,
    );
  }
}

/// Toutes les récitations d'un même pilier (`wird_step`), triées et prêtes
/// à afficher dans une section de `WirdRecitationsManagementScreen`.
/// [orderIndex] permet l'association avec `Wird.pillars[orderIndex - 1]`
/// (même convention que `buildRecitationsByPillarIndex`).
class WirdStepRecitations {
  const WirdStepRecitations({
    required this.wirdStepId,
    required this.orderIndex,
    required this.recitations,
  });

  final String wirdStepId;
  final int orderIndex;
  final List<WirdRecitationEntry> recitations;
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
