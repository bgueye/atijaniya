/// Blocage d'un disciple (Supabase — `user_blocks`, 2026-10-11).
///
/// Tous les effets sont appliqués par le serveur
/// (`database/migrations/2026-10-11_user_blocks.sql`) : plus aucun message
/// privé ni mise en relation entre les deux disciples, et celui qui bloque ne
/// voit plus ce que l'autre a écrit (messages privés, messages de groupe,
/// publications, commentaires). Ce dépôt ne fait qu'ajouter, retirer et lister
/// les blocages du compte connecté — la RLS ne lui montre que les siens. La
/// personne bloquée n'en est jamais informée.
library;

import '../../../core/supabase/supabase_config.dart';

/// Un disciple bloqué par le compte connecté.
class BlockedUser {
  const BlockedUser({required this.userId, this.displayName});

  final String userId;

  /// `null` si le profil n'est plus lisible (compte supprimé entre-temps).
  final String? displayName;
}

class BlocksRepository {
  const BlocksRepository();

  Future<void> blockUser(String userId) async {
    final me = SupabaseConfig.client.auth.currentUser!.id;
    // `upsert` : bloquer deux fois le même disciple n'est pas une erreur.
    await SupabaseConfig.client
        .from('user_blocks')
        .upsert({'blocker_id': me, 'blocked_id': userId}, onConflict: 'blocker_id,blocked_id', ignoreDuplicates: true);
  }

  Future<void> unblockUser(String userId) async {
    final me = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('user_blocks').delete().match({'blocker_id': me, 'blocked_id': userId});
  }

  /// Identifiants des disciples bloqués — vide hors connexion.
  Future<Set<String>> fetchBlockedUserIds() async {
    if (SupabaseConfig.client.auth.currentUser == null) return {};
    final rows = await SupabaseConfig.client.from('user_blocks').select('blocked_id');
    return rows.map((row) => row['blocked_id'] as String).toSet();
  }

  /// Disciples bloqués avec leur nom, du plus récent au plus ancien — écran
  /// « Disciples bloqués » des réglages de confidentialité.
  Future<List<BlockedUser>> fetchBlockedUsers() async {
    if (SupabaseConfig.client.auth.currentUser == null) return [];
    final rows =
        await SupabaseConfig.client.from('user_blocks').select('blocked_id').order('created_at', ascending: false);
    final ids = rows.map((row) => row['blocked_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles =
        await SupabaseConfig.client.from('profiles').select('user_id, display_name').inFilter('user_id', ids);
    final names = {for (final row in profiles) row['user_id'] as String: row['display_name'] as String?};
    return [for (final id in ids) BlockedUser(userId: id, displayName: names[id])];
  }
}
