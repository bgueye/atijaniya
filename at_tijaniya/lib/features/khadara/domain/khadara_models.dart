/// Modèles du module Khadara — calendrier des évènements et annuaire des
/// zawiyas (P1, docs/03-architecture-ecrans.md).
///
/// Contrairement aux modules Wirds/Figures, ce contenu n'est pas un corpus
/// statique validé par un moqaddam : il provient des tables Supabase
/// `zawiyas` et `events` (docs/06-architecture-backend.md), alimentées au
/// fil de l'eau par les administrateurs/organisateurs — voir
/// `khadara_repository.dart`.
library;

enum KhadaraEventType { ziyara, hadra, other }

KhadaraEventType khadaraEventTypeFromString(String? value) {
  return KhadaraEventType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => KhadaraEventType.other,
  );
}

class Zawiya {
  const Zawiya({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.addressText,
    this.contactInfo,
  });

  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? addressText;
  final String? contactInfo;

  bool get hasLocation => latitude != null && longitude != null;

  factory Zawiya.fromRow(Map<String, dynamic> row) {
    return Zawiya(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      addressText: row['address_text'] as String?,
      contactInfo: row['contact_info'] as String?,
    );
  }
}

class KhadaraEvent {
  const KhadaraEvent({
    required this.id,
    this.zawiyaId,
    this.zawiyaName,
    required this.title,
    this.description,
    required this.type,
    required this.startsAt,
    this.endsAt,
    this.latitude,
    this.longitude,
    this.createdBy,
  });

  final String id;
  final String? zawiyaId;

  /// Résolu via l'embedding PostgREST (`select('*, zawiyas(name)')`) — voir
  /// `KhadaraRepository.fetchUpcomingEvents`.
  final String? zawiyaName;
  final String title;
  final String? description;
  final KhadaraEventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? latitude;
  final double? longitude;

  /// Auteur de l'évènement (`events.created_by`, nullable — un évènement
  /// "système" créé avant cette fonctionnalité peut ne pas en avoir).
  /// Détermine, avec `canManageEvent`, qui peut modifier/supprimer.
  final String? createdBy;

  bool get hasLocation => latitude != null && longitude != null;

  factory KhadaraEvent.fromRow(Map<String, dynamic> row) {
    final zawiyaRelation = row['zawiyas'] as Map<String, dynamic>?;
    return KhadaraEvent(
      id: row['id'] as String,
      zawiyaId: row['zawiya_id'] as String?,
      zawiyaName: zawiyaRelation?['name'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      type: khadaraEventTypeFromString(row['event_type'] as String?),
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      endsAt: row['ends_at'] != null ? DateTime.parse(row['ends_at'] as String).toLocal() : null,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      createdBy: row['created_by'] as String?,
    );
  }
}

/// Un compte peut modifier/supprimer un évènement s'il est administrateur,
/// ou s'il en est l'auteur (`events.created_by`) — reflet côté client des
/// RLS `events_owner_or_admin_update`/`_delete` ; la RLS reste la source de
/// vérité en cas de désaccord (ex. profil rechargé après une modification
/// serveur). Logique pure, testable sans Riverpod ni Supabase — même esprit
/// que `classifyAuthError` (`auth/domain/auth_error_message.dart`).
bool canManageEvent(KhadaraEvent event, {required String? userId, required bool isAdmin}) {
  if (isAdmin) return true;
  return userId != null && userId == event.createdBy;
}

/// Direct (`live_streams`) — "Lecteur natif + agrégation de flux externes"
/// (P2, docs/03-architecture-ecrans.md). Le "natif" (diffusion depuis le
/// téléphone via l'app) nécessite un prestataire de streaming jamais
/// choisi (`docs/06-architecture-backend.md`, "à trancher séparément") —
/// `LiveStreamSourceType.native` reste donc un cas honnête "pas encore
/// disponible" côté UI (`start_live_stream_screen.dart`), jamais un vrai
/// flux capturé. Seule l'agrégation (YouTube/Facebook/autre lien externe)
/// est fonctionnelle dans cet incrément.
enum LiveStreamSourceType { native, youtube, facebook, other }

LiveStreamSourceType liveStreamSourceTypeFromString(String value) {
  return LiveStreamSourceType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => LiveStreamSourceType.other,
  );
}

enum LiveStreamStatus { scheduled, live, ended }

LiveStreamStatus liveStreamStatusFromString(String value) {
  return LiveStreamStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => LiveStreamStatus.scheduled,
  );
}

class LiveStream {
  const LiveStream({
    required this.id,
    this.eventId,
    this.eventTitle,
    this.groupId,
    this.groupName,
    required this.sourceType,
    this.externalUrl,
    required this.status,
    this.startedBy,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? eventId;

  /// Résolu via l'embedding PostgREST (`select('*, events(title)')`).
  final String? eventTitle;

  /// Rattachement alternatif à un groupe plutôt qu'à un évènement (jamais
  /// les deux à la fois — invariant applicatif, voir
  /// `LiveStreamRepository.startLiveStream`). Un direct de groupe est
  /// réservé aux membres du groupe côté RLS (migration
  /// `add_group_scoped_live_streams`) : `fromRow` n'a donc jamais besoin de
  /// filtrer lui-même, Postgres ne renvoie déjà que ce que l'appelant est
  /// autorisé à voir.
  final String? groupId;

  /// Résolu via l'embedding PostgREST (`select('*, groups(name)')`).
  final String? groupName;
  final LiveStreamSourceType sourceType;
  final String? externalUrl;
  final LiveStreamStatus status;
  final String? startedBy;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isLive => status == LiveStreamStatus.live;

  /// Titre à afficher pour ce direct — évènement, groupe, ou repli
  /// générique fourni par l'appelant (aucun des deux ne devrait manquer en
  /// pratique, mais reste défensif).
  String displayTitle(String fallback) => eventTitle ?? groupName ?? fallback;

  factory LiveStream.fromRow(Map<String, dynamic> row) {
    final eventRelation = row['events'] as Map<String, dynamic>?;
    final groupRelation = row['groups'] as Map<String, dynamic>?;
    return LiveStream(
      id: row['id'] as String,
      eventId: row['event_id'] as String?,
      eventTitle: eventRelation?['title'] as String?,
      groupId: row['group_id'] as String?,
      groupName: groupRelation?['name'] as String?,
      sourceType: liveStreamSourceTypeFromString(row['source_type'] as String),
      externalUrl: row['external_url'] as String?,
      status: liveStreamStatusFromString(row['status'] as String),
      startedBy: row['started_by'] as String?,
      startedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String).toLocal() : null,
      endedAt: row['ended_at'] != null ? DateTime.parse(row['ended_at'] as String).toLocal() : null,
    );
  }
}

/// Rediffusion (`stream_replays`) d'un direct terminé — "Directs passés,
/// lecture différée" (P2). Pas de lecteur vidéo intégré dans cet
/// incrément (même logique que l'absence de carte interactive côté
/// évènements) : `video_url` s'ouvre dans l'app externe correspondante
/// (YouTube, Facebook...) via `url_launcher`.
class StreamReplay {
  const StreamReplay({
    required this.id,
    required this.streamId,
    this.eventTitle,
    this.groupName,
    required this.videoUrl,
    this.durationSeconds,
    required this.createdAt,
  });

  final String id;
  final String streamId;

  /// Résolu via l'embedding PostgREST à travers `live_streams.event_id`
  /// (`select('*, live_streams(events(title), groups(name)))')`).
  final String? eventTitle;

  /// Résolu à travers `live_streams.group_id` — voir `LiveStream.groupId`
  /// pour la règle de confidentialité (RLS filtre déjà côté serveur).
  final String? groupName;
  final String videoUrl;
  final int? durationSeconds;
  final DateTime createdAt;

  String displayTitle(String fallback) => eventTitle ?? groupName ?? fallback;

  factory StreamReplay.fromRow(Map<String, dynamic> row) {
    final streamRelation = row['live_streams'] as Map<String, dynamic>?;
    final eventRelation = streamRelation?['events'] as Map<String, dynamic>?;
    final groupRelation = streamRelation?['groups'] as Map<String, dynamic>?;
    return StreamReplay(
      id: row['id'] as String,
      streamId: row['stream_id'] as String,
      eventTitle: eventRelation?['title'] as String?,
      groupName: groupRelation?['name'] as String?,
      videoUrl: row['video_url'] as String,
      durationSeconds: row['duration_seconds'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

/// Message du chat en direct (`live_chat_messages`) — pas de Supabase
/// Realtime dans cet incrément (aucun précédent dans l'app, même choix que
/// la Messagerie privée : liste rafraîchie, ici via un polling léger tant
/// que l'écran Direct est ouvert plutôt qu'un simple "tirer pour
/// rafraîchir", pour rester crédible sur un fil qui se veut "en direct").
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.streamId,
    required this.userId,
    this.senderName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String streamId;
  final String userId;

  /// Résolu séparément via `profiles` (pas de FK directe embeddable, même
  /// limite que `posts.author_user_id`/`messages.sender_id`).
  final String? senderName;
  final String message;
  final DateTime createdAt;

  factory LiveChatMessage.fromRow(Map<String, dynamic> row) {
    return LiveChatMessage(
      id: row['id'] as String,
      streamId: row['stream_id'] as String,
      userId: row['user_id'] as String,
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  LiveChatMessage withSenderName(String? senderName) {
    return LiveChatMessage(
      id: id,
      streamId: streamId,
      userId: userId,
      senderName: senderName,
      message: message,
      createdAt: createdAt,
    );
  }
}
