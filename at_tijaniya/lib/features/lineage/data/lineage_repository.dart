/// Accès aux données de la lignée spirituelle (Supabase — table
/// `lineage_declarations`). Policy RLS `lineage_owner_only` : `for all
/// using (auth.uid() = user_id)` — chaque disciple ne voit et ne modifie
/// jamais que sa propre ligne, RLS l'impose déjà côté base. Une seule ligne
/// par utilisateur (clé primaire `user_id`), d'où l'usage d'`upsert` plutôt
/// que insert/update séparés.
///
/// `moqaddam_name_normalized` n'apparaît jamais dans les payloads envoyés
/// ici : c'est maintenu par le trigger serveur `normalize_moqaddam_name`
/// (CLAUDE.md).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/lineage_models.dart';

class LineageRepository {
  const LineageRepository();

  /// `null` si le disciple n'a pas encore renseigné sa lignée.
  Future<LineageDeclaration?> fetchMyLineage() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('lineage_declarations')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : LineageDeclaration.fromRow(row);
  }

  Future<void> saveMyLineage({
    required Foyer foyer,
    String? foyerAutreText,
    required String moqaddamNameText,
    int? transmissionYear,
    String? zawiyaText,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('lineage_declarations').upsert({
      'user_id': userId,
      'foyer': foyerToDbValue(foyer),
      'foyer_autre_text': foyerAutreText,
      'moqaddam_name_text': moqaddamNameText,
      'transmission_year': transmissionYear,
      'zawiya_text': zawiyaText,
    });
  }

  Future<void> deleteMyLineage() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('lineage_declarations').delete().eq('user_id', userId);
  }

  /// "Retrouver mes condisciples" — RPC `SECURITY DEFINER` : `lineage_owner_only`
  /// interdit toute lecture inter-utilisateurs directe sur
  /// `lineage_declarations`, comme documenté en tête de ce fichier avant ce
  /// workflow.
  Future<List<LineageMatch>> searchMatches() async {
    final rows = await SupabaseConfig.client.rpc('search_lineage_matches');
    return (rows as List).map((row) => LineageMatch.fromRow(row as Map<String, dynamic>)).toList();
  }

  /// Toutes mes demandes de mise en relation, dans les deux sens (RLS
  /// `lineage_requests_participants_only` couvre déjà les deux) — au
  /// screen de distinguer reçues/envoyées selon `requesterId`/`recipientId`.
  Future<List<LineageConnectionRequest>> fetchMyConnectionRequests() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final rows = await SupabaseConfig.client
        .from('lineage_connection_requests')
        .select()
        .or('requester_id.eq.$userId,recipient_id.eq.$userId')
        .order('created_at', ascending: false);

    final requests = rows.map((row) => LineageConnectionRequest.fromRow(row)).toList();
    final otherIds = requests.map((r) => r.requesterId == userId ? r.recipientId : r.requesterId).toSet();
    final names = await _fetchDisplayNames(otherIds);
    return requests.map((r) {
      final otherId = r.requesterId == userId ? r.recipientId : r.requesterId;
      return r.withOtherUserName(names[otherId]);
    }).toList();
  }

  Future<void> sendConnectionRequest(String recipientUserId) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('lineage_connection_requests').insert({
      'requester_id': userId,
      'recipient_id': recipientUserId,
      'status': 'pending',
    });
  }

  /// RLS `lineage_requests_recipient_decides` : seul le destinataire peut
  /// mettre à jour sa propre demande reçue — accepter/refuser ne modifie
  /// jamais d'autre table (contrairement au parrainage Mouqaddam), donc pas
  /// besoin d'une fonction `SECURITY DEFINER` ici.
  Future<void> respondToConnectionRequest({required String requestId, required bool accept}) async {
    await SupabaseConfig.client
        .from('lineage_connection_requests')
        .update({'status': accept ? 'accepted' : 'declined', 'decided_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', requestId);
  }

  Future<Map<String, String>> _fetchDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {for (final row in rows) row['user_id'] as String: row['display_name'] as String};
  }
}
