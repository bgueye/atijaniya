/// Modération a posteriori (Sprint 2, P3) — table Supabase `content_reports`,
/// générique pour les contenus signalables (docs/01 §6 : "modération
/// a posteriori suffit", pas de rôle modérateur ni de modération automatisée).
/// Publications et commentaires du fil ajoutés le 2026-10-04 (audit, S61) ;
/// messages de groupe et messages privés le 2026-10-11.
///
/// Pour ces deux derniers, la modération ne lit ni le groupe ni la
/// conversation : le serveur copie dans le signalement le texte du seul
/// message visé ([ContentReport.contentSnapshot]) et l'efface dès que le
/// signalement est clos — voir
/// `database/migrations/2026-10-11_report_group_posts_and_messages.sql`.
library;

enum ReportableContentType { liveStream, lineageConnectionRequest, post, postComment, groupPost, message }

String reportableContentTypeToDbValue(ReportableContentType type) {
  return switch (type) {
    ReportableContentType.liveStream => 'live_stream',
    ReportableContentType.lineageConnectionRequest => 'lineage_connection_request',
    ReportableContentType.post => 'post',
    ReportableContentType.postComment => 'post_comment',
    ReportableContentType.groupPost => 'group_post',
    ReportableContentType.message => 'message',
  };
}

ReportableContentType reportableContentTypeFromDbValue(String value) {
  return switch (value) {
    'live_stream' => ReportableContentType.liveStream,
    'lineage_connection_request' => ReportableContentType.lineageConnectionRequest,
    'post' => ReportableContentType.post,
    'post_comment' => ReportableContentType.postComment,
    'group_post' => ReportableContentType.groupPost,
    'message' => ReportableContentType.message,
    _ => throw ArgumentError('Type de contenu signalable inconnu : $value'),
  };
}

enum ReportStatus { pending, resolved, dismissed }

ReportStatus _reportStatusFromDb(String value) {
  return ReportStatus.values.firstWhere((s) => s.name == value, orElse: () => ReportStatus.pending);
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    this.reason,
    required this.status,
    required this.createdAt,
    this.contentSnapshot,
    this.contentAuthorId,
  });

  final String id;
  final String reporterId;
  final ReportableContentType contentType;
  final String contentId;
  final String? reason;
  final ReportStatus status;
  final DateTime createdAt;

  /// Copie du message signalé, faite par le serveur au moment du signalement
  /// — uniquement pour un message de groupe ou un message privé, que l'admin
  /// ne peut pas lire autrement. `null` pour les autres types et une fois le
  /// signalement clos.
  final String? contentSnapshot;

  /// Auteur du message signalé (mêmes types que [contentSnapshot]).
  final String? contentAuthorId;

  factory ContentReport.fromRow(Map<String, dynamic> row) {
    return ContentReport(
      id: row['id'] as String,
      reporterId: row['reporter_id'] as String,
      contentType: reportableContentTypeFromDbValue(row['content_type'] as String),
      contentId: row['content_id'] as String,
      reason: row['reason'] as String?,
      status: _reportStatusFromDb(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      contentSnapshot: row['content_snapshot'] as String?,
      contentAuthorId: row['content_author_id'] as String?,
    );
  }
}

/// Un signalement accompagné de l'aperçu minimal du contenu concerné, résolu
/// séparément par `ModerationRepository.fetchPendingReports` (le contenu et
/// son type variant, pas de FK embeddable générique côté PostgREST — même
/// limite que `posts.author_user_id`/`messages.sender_id` ailleurs dans
/// l'app). `preview` reste `null` si le contenu a déjà disparu entre-temps
/// (ex. compte supprimé) : l'écran l'affiche comme tel plutôt que de planter.
class ReportWithPreview {
  const ReportWithPreview({required this.report, this.preview});

  final ContentReport report;
  final String? preview;
}
