/// Accès aux données de la modération a posteriori (Supabase —
/// `content_reports`). Policy RLS : n'importe quel compte authentifié peut
/// signaler (`content_reports_authenticated_create`), seul un admin peut
/// lister/traiter les signalements (`content_reports_admin_read`/`_update`).
///
/// Traiter un signalement marque le contenu visé (`hidden_at` sur
/// `live_streams`, `blocked_at` + `status='declined'` sur
/// `lineage_connection_requests`) plutôt que de le supprimer — ces deux
/// colonnes sont filtrées au niveau RLS (`database/schema.sql`, section 11),
/// donc aucun autre repository n'a besoin d'être modifié pour respecter le
/// masquage.
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

    final streamPreviews = await _fetchStreamPreviews(streamIds);
    final requestPreviews = await _fetchLineageRequestPreviews(requestIds);

    return reports.map((report) {
      final preview = report.contentType == ReportableContentType.liveStream
          ? streamPreviews[report.contentId]
          : requestPreviews[report.contentId];
      return ReportWithPreview(report: report, preview: preview);
    }).toList();
  }

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
  Future<void> resolveReport({
    required String reportId,
    required ReportableContentType contentType,
    required String contentId,
    required bool takeAction,
  }) async {
    if (takeAction) {
      switch (contentType) {
        case ReportableContentType.liveStream:
          await SupabaseConfig.client
              .from('live_streams')
              .update({'hidden_at': DateTime.now().toUtc().toIso8601String(), 'status': 'ended'}).eq(
                  'id', contentId);
        case ReportableContentType.lineageConnectionRequest:
          await SupabaseConfig.client.from('lineage_connection_requests').update({
            'status': 'declined',
            'blocked_at': DateTime.now().toUtc().toIso8601String(),
            'decided_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', contentId);
      }
    }
    final adminId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('content_reports').update({
      'status': takeAction ? 'resolved' : 'dismissed',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
      'resolved_by': adminId,
    }).eq('id', reportId);
  }
}
