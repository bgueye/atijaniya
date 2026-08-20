/// Accès aux données du module Groupes (Supabase — `groups`,
/// `group_memberships`, `group_posts`). Contrairement au fil d'actualité,
/// certaines lectures sont volontairement restreintes par RLS :
/// - `groups`/`group_memberships` : lecture publique (`using (true)`),
///   fonctionne en mode invité (liste des groupes + comptage de membres).
/// - `group_posts` : lecture ET écriture réservées aux membres du groupe
///   (`group_posts_members_read`/`members_write`, vérifiées via un `exists`
///   sur `group_memberships`) — `fetchGroupPosts` ne doit être appelé que
///   pour un groupe dont l'utilisateur est membre (voir
///   `group_detail_screen.dart`), sinon la requête renverrait silencieusement
///   une liste vide plutôt qu'une erreur, ce qui serait trompeur affiché tel
///   quel comme "aucune discussion".
/// - Rejoindre/quitter/créer/poster exigent tous un `auth.uid()` réel
///   (`group_memberships_self_join`/`self_leave`, `groups_authenticated_create`,
///   `group_posts_members_write`).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/group_models.dart';

class GroupsRepository {
  const GroupsRepository();

  Future<List<Group>> fetchGroups() async {
    final rows = await SupabaseConfig.client
        .from('groups')
        .select('*, zawiyas(name)')
        .order('created_at', ascending: false);

    final groupIds = rows.map((row) => row['id'] as String).toList();
    final memberCounts = await _fetchMemberCounts(groupIds);
    final myMemberships = await _fetchMyMemberships();

    return rows.map((row) {
      final id = row['id'] as String;
      return Group.fromRow(row, memberCount: memberCounts[id] ?? 0, isMember: myMemberships.contains(id));
    }).toList();
  }

  /// Insère le groupe puis inscrit automatiquement son créateur — la
  /// policy `groups_authenticated_create` reste ouverte à tout disciple
  /// connecté (n'importe qui peut créer un groupe), donc pas d'inscription
  /// automatique possible côté serveur (pas de trigger dédié) : sans cette
  /// étape, le créateur se retrouverait devant son propre groupe
  /// fraîchement créé sans pouvoir en voir les discussions.
  ///
  /// [created_by_user_id] (migration
  /// `add_groups_owner_column_and_update_delete_policies`, 2026-08-20) sert
  /// uniquement à déterminer qui peut modifier/supprimer ce groupe ensuite
  /// (`groups_creator_or_admin_update`/`_delete`) — les groupes créés avant
  /// cette migration ont cette colonne à `null` et ne restent modifiables
  /// que par un admin.
  Future<void> createGroup({
    required String name,
    String? description,
    String? zawiyaId,
    String? regionText,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final inserted = await SupabaseConfig.client
        .from('groups')
        .insert({
          'name': name,
          'description': description,
          'zawiya_id': zawiyaId,
          'region_text': regionText,
          'created_by_user_id': userId,
        })
        .select('id')
        .single();
    await SupabaseConfig.client.from('group_memberships').insert({
      'group_id': inserted['id'] as String,
      'user_id': userId,
    });
  }

  /// Réservé au créateur du groupe ou à un admin par la RLS
  /// `groups_creator_or_admin_update`. Ne renvoie pas le groupe complet
  /// (contrairement à `KhadaraRepository.updateZawiya`) : `memberCount` et
  /// `isMember` ne sont pas des colonnes de `groups`, l'appelant reconstruit
  /// l'objet localement (voir `_EditGroupSheet`).
  Future<void> updateGroup(
    String id, {
    required String name,
    String? description,
    String? zawiyaId,
    String? regionText,
  }) async {
    await SupabaseConfig.client.from('groups').update({
      'name': name,
      'description': description,
      'zawiya_id': zawiyaId,
      'region_text': regionText,
    }).eq('id', id);
  }

  /// Réservé au créateur du groupe ou à un admin par la RLS
  /// `groups_creator_or_admin_delete`. Peut lever une `PostgrestException`
  /// (code `23503`) si un direct est encore rattaché à ce groupe
  /// (`live_streams.group_id`, sans `on delete cascade`) — volontairement
  /// non catchée ici, voir `classifyGroupDeleteError` (`group_errors.dart`)
  /// côté appelant. `group_memberships`/`group_posts` ne peuvent jamais
  /// bloquer (cascade).
  Future<void> deleteGroup(String id) async {
    await SupabaseConfig.client.from('groups').delete().eq('id', id);
  }

  Future<void> joinGroup(String groupId) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('group_memberships').insert({'group_id': groupId, 'user_id': userId});
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client
        .from('group_memberships')
        .delete()
        .match({'group_id': groupId, 'user_id': userId});
  }

  Future<List<GroupPost>> fetchGroupPosts(String groupId) async {
    final rows = await SupabaseConfig.client
        .from('group_posts')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true);

    final authorIds = rows.map((row) => row['author_user_id'] as String).toSet();
    final names = await _fetchDisplayNames(authorIds);

    return rows.map((row) => GroupPost.fromRow(row, authorDisplayName: names[row['author_user_id']])).toList();
  }

  Future<void> addGroupPost(String groupId, String contentText) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('group_posts').insert({
      'group_id': groupId,
      'author_user_id': userId,
      'content_text': contentText,
    });
  }

  /// Réservé à l'auteur du message par la RLS `group_posts_author_update`
  /// (migration `add_group_posts_author_update_delete_policies`,
  /// 2026-08-20) — aucune exception admin, même restriction propriétaire-only
  /// que `CommunityRepository.updatePost`.
  Future<void> updateGroupPost(String id, String contentText) async {
    await SupabaseConfig.client.from('group_posts').update({'content_text': contentText}).eq('id', id);
  }

  /// Réservé à l'auteur du message par la RLS `group_posts_author_delete`.
  Future<void> deleteGroupPost(String id) async {
    await SupabaseConfig.client.from('group_posts').delete().eq('id', id);
  }

  Future<Map<String, int>> _fetchMemberCounts(List<String> groupIds) async {
    if (groupIds.isEmpty) return {};
    final rows = await SupabaseConfig.client.from('group_memberships').select('group_id').inFilter('group_id', groupIds);
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row['group_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// Ensemble des groupes dont l'utilisateur courant est déjà membre —
  /// aucune requête en mode invité (`currentUser` nul), donc `isMember`
  /// vaut `false` pour tous les groupes plutôt que d'échouer.
  Future<Set<String>> _fetchMyMemberships() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await SupabaseConfig.client.from('group_memberships').select('group_id').eq('user_id', userId);
    return rows.map((row) => row['group_id'] as String).toSet();
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
