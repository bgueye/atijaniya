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

  /// Insère le groupe puis inscrit automatiquement son créateur — le schéma
  /// n'a pas de colonne "auteur" sur `groups` (n'importe quel disciple
  /// connecté peut en créer un, même policy ouverte que pour les
  /// publications), donc pas d'inscription automatique possible côté
  /// serveur (pas de trigger dédié) : sans cette étape, le créateur se
  /// retrouverait devant son propre groupe fraîchement créé sans pouvoir en
  /// voir les discussions.
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
        })
        .select('id')
        .single();
    await SupabaseConfig.client.from('group_memberships').insert({
      'group_id': inserted['id'] as String,
      'user_id': userId,
    });
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
