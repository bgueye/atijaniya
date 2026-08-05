/// Accès aux données du fil d'actualité (Supabase — `posts`, `post_likes`,
/// `post_comments`, `profiles`). Lecture publique côté RLS
/// (`posts_read_all`, `post_likes_read_all`, `post_comments_read_all` :
/// `using (true)`) : fonctionne en mode invité. Les écritures (aimer,
/// commenter, publier) exigent en revanche un `auth.uid()` réel
/// (`posts_author_create`, `post_likes_owner_only`,
/// `post_comments_author_create`) — indisponible tant que l'authentification
/// Supabase n'est pas branchée côté app (voir TODO dans `auth_screen.dart`).
/// Les méthodes d'écriture ci-dessous sont donc prêtes mais non exposées
/// dans l'UI pour l'instant (voir `communaute_screen.dart`).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/community_models.dart';

class CommunityRepository {
  const CommunityRepository();

  Future<List<CommunityPost>> fetchFeed() async {
    final postRows = await SupabaseConfig.client
        .from('posts')
        .select('*, zawiyas(name)')
        .order('created_at', ascending: false);

    final postIds = postRows.map((row) => row['id'] as String).toList();
    final authorIds = postRows.map((row) => row['author_user_id'] as String?).whereType<String>().toSet();

    final names = await _fetchDisplayNames(authorIds);
    final likeCounts = await _fetchCountsByPost('post_likes', postIds);
    final commentCounts = await _fetchCountsByPost('post_comments', postIds);

    return postRows.map((row) {
      final id = row['id'] as String;
      return CommunityPost.fromRow(
        row,
        authorDisplayName: names[row['author_user_id']],
        likeCount: likeCounts[id] ?? 0,
        commentCount: commentCounts[id] ?? 0,
      );
    }).toList();
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final rows = await SupabaseConfig.client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at');

    final authorIds = rows.map((row) => row['user_id'] as String).toSet();
    final names = await _fetchDisplayNames(authorIds);

    return rows
        .map((row) => CommunityComment.fromRow(row, authorDisplayName: names[row['user_id']]))
        .toList();
  }

  Future<Map<String, String>> _fetchDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {for (final row in rows) row['user_id'] as String: row['display_name'] as String};
  }

  Future<Map<String, int>> _fetchCountsByPost(String table, List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final rows = await SupabaseConfig.client.from(table).select('post_id').inFilter('post_id', postIds);
    final counts = <String, int>{};
    for (final row in rows) {
      final id = row['post_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// Prêt pour quand l'authentification sera branchée — non appelé par l'UI
  /// tant qu'il n'y a pas de session réelle (voir le commentaire en tête de
  /// fichier).
  Future<void> toggleLike(String postId, {required bool currentlyLiked}) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    if (currentlyLiked) {
      await SupabaseConfig.client.from('post_likes').delete().match({'post_id': postId, 'user_id': userId});
    } else {
      await SupabaseConfig.client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  Future<void> addComment(String postId, String contentText) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content_text': contentText,
    });
  }
}
