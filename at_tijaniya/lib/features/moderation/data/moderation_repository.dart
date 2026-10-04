/// Accès aux données de la modération a posteriori (Supabase —
/// `content_reports`). Un compte authentifié peut signaler un contenu qu'il
/// voit et dont il n'est pas l'auteur (policy
/// `content_reports_authenticated_create` + `can_report_content()`), seul un
/// admin peut lister les signalements (`content_reports_admin_read`) et les
/// traiter, uniquement via la fonction serveur `resolve_report()`.
///
/// Traiter un signalement marque le contenu visé (`hidden_at` sur
/// `live_streams`, `posts`, `post_comments` ; `blocked_at` +
/// `status='declined'` sur `lineage_connection_requests`) plutôt que de le
/// supprimer — ces colonnes sont filtrées au niveau RLS
/// (`database/schema.sql`, section 11), donc aucun autre repository n'a
/// besoin d'être modifié pour respecter le masquage.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/moderation_models.dart';

class ModerationRepository {
  const ModerationRepository();

  Future<void> reportContent({
    required ReportableContentType type,
    required String contentId,
    String? reason,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('content_reports').insert({
      'reporter_id': userId,
      'content_type': reportableContentTypeToDbValue(type),
      'content_id': contentId,
      'reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
    });
  }

  /// Signalements en attente — écran admin `ModerationReportsScreen`. Les
  /// aperçus sont résolus en deux lots (un par type de contenu) plutôt qu'un
  /// par un, pour éviter une requête réseau par ligne.
  Future<List<ReportWithPreview>> fetchPendingReports() async {
    final rows = await SupabaseConfig.client
        .from('content_reports')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final reports = rows.map((row) => ContentReport.fromRow(row)).toList();

    final streamIds = reports
        .where((r) => r.contentType == ReportableContentType.liveStream)
        .map((r) => r.contentId)
        .toSet();
    final requestIds = reports
        .where((r) => r.contentType == ReportableContentType.lineageConnectionRequest)
        .map((r) => r.contentId)
        .toSet();

    final postIds =
        reports.where((r) => r.contentType == ReportableContentType.post).map((r) => r.contentId).toSet();
    final commentIds =
        reports.where((r) => r.contentType == ReportableContentType.postComment).map((r) => r.contentId).toSet();

    final streamPreviews = await _fetchStreamPreviews(streamIds);
    final requestPreviews = await _fetchLineageRequestPreviews(requestIds);
    final postPreviews = await _fetchTextPreviews('posts', postIds);
    final commentPreviews = await _fetchTextPreviews('post_comments', commentIds);

    return reports.map((report) {
      final preview = switch (report.contentType) {
        ReportableContentType.liveStream => streamPreviews[report.contentId],
        ReportableContentType.lineageConnectionRequest => requestPreviews[report.contentId],
        ReportableContentType.post => postPreviews[report.contentId],
        ReportableContentType.postComment => commentPreviews[report.contentId],
      };
      return ReportWithPreview(report: report, preview: preview);
    }).toList();
  }

  /// Aperçu du texte d'une publication ou d'un commentaire signalé — l'admin
  /// doit lire le contenu pour décider, tronqué pour rester une carte.
  Future<Map<String, String>> _fetchTextPreviews(String table, Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseConfig.client.from(table).select('id, content_text').inFilter('id', ids.toList());
    return {
      for (final row in rows)
        row['id'] as String: _truncate(row['content_text'] as String? ?? '—'),
    };
  }

  static String _truncate(String text) => text.length <= 280 ? text : '${text.substring(0, 280)}…';

  Future<Map<String, String>> _fetchStreamPreviews(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('live_streams')
        .select('id, external_url, events(title), groups(name)')
        .inFilter('id', ids.toList());
    return {
      for (final row in rows)
        row['id'] as String:
            (row['events'] as Map<String, dynamic>?)?['title'] as String? ??
                (row['groups'] as Map<String, dynamic>?)?['name'] as String? ??
                row['external_url'] as String? ??
                '—',
    };
  }

  Future<Map<String, String>> _fetchLineageRequestPreviews(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('lineage_connection_requests')
        .select('id, requester_id, recipient_id')
        .inFilter('id', ids.toList());
    final userIds = {
      for (final row in rows) ...[row['requester_id'] as String, row['recipient_id'] as String],
    };
    final names = await _fetchDisplayNames(userIds);
    return {
      for (final row in rows)
        row['id'] as String:
            '${names[row['requester_id']] ?? '—'} → ${names[row['recipient_id']] ?? '—'}',
    };
  }

  Future<Map<String, String>> _fetchDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {for (final row in rows) row['user_id'] as String: row['display_name'] as String};
  }

  /// Traite un signalement — `takeAction: true` masque/bloque le contenu visé
  /// en plus de marquer le signalement `resolved` ; `false` le marque
  /// `dismissed` sans toucher au contenu.
  ///
  /// Tout se passe dans la fonction serveur `resolve_report()` (audit du
  /// 2026-10-04, S60) : auparavant deux requêtes client successives, donc un
  /// contenu masqué pouvait garder son signalement en attente, et un direct
  /// de groupe dont l'admin n'était pas membre passait « traité » sans être
  /// masqué. La fonction clôt aussi d'un coup tous les signalements en
  /// attente du même contenu.
  Future<void> resolveReport({required String reportId, required bool takeAction}) async {
    await SupabaseConfig.client.rpc('resolve_report', params: {
      'p_report_id': reportId,
      'p_take_action': takeAction,
    });
  }
}
