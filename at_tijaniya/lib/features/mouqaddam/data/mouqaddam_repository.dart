/// Accès aux données du workflow Mouqaddam (Supabase — `mouqaddam_status`,
/// `mouqaddam_sponsorships`, `mouqaddam_manual_chain_links`, et les
/// fonctions `SECURITY DEFINER` `get_ijaza_chain`, `respond_to_sponsorship`,
/// `search_available_sponsors`, migration
/// `add_mouqaddam_workflow_rls_and_functions`).
///
/// Ces trois fonctions existent précisément parce que la RLS "propriétaire
/// uniquement" de `mouqaddam_sponsorships`/`privacy_settings` empêcherait
/// sinon toute reconstruction de chaîne ou recherche inter-utilisateurs
/// (voir le commentaire en tête de la migration) : jamais de requête directe
/// sur ces tables pour un utilisateur autre que soi-même dans ce fichier.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/mouqaddam_models.dart';

class MouqaddamRepository {
  const MouqaddamRepository();

  Future<MouqaddamStatus> fetchMyStatus() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client.from('mouqaddam_status').select().eq('user_id', userId).single();
    return MouqaddamStatus.fromRow(row);
  }

  /// La demande la plus récente du disciple connecté, quel que soit son
  /// statut (`pending`/`accepted`/`rejected`) — `null` si aucune n'a jamais
  /// été soumise. `BecomeMouqaddamScreen` s'en sert pour afficher l'état
  /// courant plutôt qu'un formulaire vide à chaque ouverture.
  ///
  /// `sponsor_user_id is not null` exclut la ligne d'amorçage éventuelle
  /// d'un mouqaddam fondateur (`sponsor_user_id = NULL`, `status =
  /// 'accepted'`, insérée manuellement en base — jamais via ce formulaire,
  /// voir `docs/06-architecture-backend.md`) : ce n'est pas une "demande"
  /// au sens de cet écran, et `SponsorshipRequest.fromRow` échouerait de
  /// toute façon sur son `sponsor_user_id` nul (`sponsorUserId` non
  /// nullable dans le modèle).
  Future<SponsorshipRequest?> fetchMyLatestRequest() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('mouqaddam_sponsorships')
        .select()
        .eq('candidate_user_id', userId)
        .not('sponsor_user_id', 'is', null)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    var request = SponsorshipRequest.fromRow(row);
    final names = await _fetchDisplayNames({request.sponsorUserId});
    return request.withNames(sponsorName: names[request.sponsorUserId]);
  }

  Future<void> requestSponsorship({required String sponsorUserId, int? ijazaYear}) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('mouqaddam_sponsorships').insert({
      'candidate_user_id': userId,
      'sponsor_user_id': sponsorUserId,
      'ijaza_year': ijazaYear,
      'status': 'pending',
    });
  }

  Future<void> cancelMyPendingRequest(String requestId) async {
    await SupabaseConfig.client.from('mouqaddam_sponsorships').delete().eq('id', requestId);
  }

  Future<List<AvailableSponsor>> searchAvailableSponsors(String? query) async {
    final rows = await SupabaseConfig.client.rpc(
      'search_available_sponsors',
      params: {'p_query': (query == null || query.trim().isEmpty) ? null : query.trim()},
    );
    return (rows as List).map((row) => AvailableSponsor.fromRow(row as Map<String, dynamic>)).toList();
  }

  /// Demandes reçues en attente ("Demandes de parrainage") — le disciple
  /// connecté doit être le parrain sollicité (`sponsor_user_id`), imposé de
  /// toute façon par la RLS `sponsorship_participants_only`.
  Future<List<SponsorshipRequest>> fetchReceivedRequests() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final rows = await SupabaseConfig.client
        .from('mouqaddam_sponsorships')
        .select()
        .eq('sponsor_user_id', userId)
        .eq('status', 'pending')
        .order('requested_at', ascending: true);

    final requests = rows.map((row) => SponsorshipRequest.fromRow(row)).toList();
    final names = await _fetchDisplayNames(requests.map((r) => r.candidateUserId).toSet());
    return requests.map((r) => r.withNames(candidateName: names[r.candidateUserId])).toList();
  }

  Future<void> respondToSponsorship({required String requestId, required bool accept}) async {
    await SupabaseConfig.client.rpc(
      'respond_to_sponsorship',
      params: {'p_sponsorship_id': requestId, 'p_accept': accept},
    );
  }

  Future<List<IjazaChainLink>> fetchMyIjazaChain() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final rows = await SupabaseConfig.client.rpc('get_ijaza_chain', params: {'p_mouqaddam_id': userId});
    final links = (rows as List).map((row) => IjazaChainLink.fromRow(row as Map<String, dynamic>)).toList();

    final names = await _fetchDisplayNames(
      links.where((l) => !l.isManual && l.userId != null).map((l) => l.userId!).toSet(),
    );
    return links.map((l) => l.isManual ? l : l.withResolvedName(names[l.userId])).toList();
  }

  /// Ajoute le maillon suivant du complément manuel (au-delà de l'app),
  /// toujours à la suite des maillons déjà saisis par ce mouqaddam — RLS
  /// `manual_chain_links_owner_write` : insertion uniquement, jamais de
  /// modification ni de suppression une fois enregistré.
  ///
  /// `isUltimateSource` : coché par l'utilisateur lui-même quand ce maillon
  /// est Cheikh Ahmed Tijani (option A, `docs/08-spec-animation-silsila.md`
  /// §6) — l'appelant (`ijaza_chain_screen.dart`) doit empêcher tout ajout
  /// ultérieur une fois ce flag posé sur le dernier maillon.
  Future<void> addManualChainLink({
    required String nameText,
    String? yearText,
    bool isUltimateSource = false,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final lastRow = await SupabaseConfig.client
        .from('mouqaddam_manual_chain_links')
        .select('order_index')
        .eq('mouqaddam_user_id', userId)
        .order('order_index', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextOrderIndex = (lastRow?['order_index'] as int? ?? 0) + 1;

    await SupabaseConfig.client.from('mouqaddam_manual_chain_links').insert({
      'mouqaddam_user_id': userId,
      'order_index': nextOrderIndex,
      'name_text': nameText,
      'year_text': yearText,
      'is_ultimate_source': isUltimateSource,
    });
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
