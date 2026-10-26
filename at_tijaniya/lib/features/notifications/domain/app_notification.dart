/// Notification in-app (table Supabase `notifications`) — direct Khadara
/// démarré (`stream_live`), signalement de contenu à traiter
/// (`content_report`, admin uniquement), message privé reçu
/// (`direct_message`) ou commentaire sur sa publication (`post_comment`,
/// audit Communauté du 2026-10-26, P3-8), fan-out fait côté base par les
/// triggers `notify_stream_live`/`notify_content_report`
/// (`database/schema.sql`, sections 5 et 10). Ce fichier ne fait que lire
/// ce que la base a déjà écrit, jamais d'écriture de fan-out côté client.
library;

enum AppNotificationType {
  streamLive,
  contentReport,
  directMessage,
  postComment,

  /// Type non reconnu par cette version de l'app — évite de planter sur une
  /// valeur ajoutée plus tard côté base sans mise à jour du client.
  unknown,
}

AppNotificationType _typeFromDb(String value) {
  return switch (value) {
    'stream_live' => AppNotificationType.streamLive,
    'content_report' => AppNotificationType.contentReport,
    'direct_message' => AppNotificationType.directMessage,
    'post_comment' => AppNotificationType.postComment,
    _ => AppNotificationType.unknown,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final AppNotificationType type;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  String? get streamId => payload['stream_id'] as String?;
  String? get reportId => payload['report_id'] as String?;
  String? get conversationId => payload['conversation_id'] as String?;
  String? get postId => payload['post_id'] as String?;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      type: _typeFromDb(row['type'] as String),
      payload: (row['payload'] as Map<String, dynamic>?) ?? const {},
      readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String).toLocal(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
