/// Accès aux données du fil d'actualité (Supabase — `posts`, `post_likes`,
/// `post_comments`, `profiles`). Lecture publique côté RLS pour les
/// publications déjà validées (`posts_read_valid_or_admin` :
/// `content_status = 'valide' or is_admin(...)`, `post_likes_read_all`,
/// `post_comments_read_all` : `using (true)`) : fonctionne en mode invité.
/// Les écritures (aimer, commenter, publier) exigent en revanche un
/// `auth.uid()` réel (`posts_author_create`, `post_likes_owner_only`,
/// `post_comments_author_create`).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/community_models.dart';

class CommunityRepository {
  const CommunityRepository();

  Future<List<CommunityPost>> fetchFeed() async {
    // .eq('content_status', 'valide') en plus de la RLS : même défense en
    // profondeur que FiguresRepository.fetchFigures() — un compte admin ne
    // doit jamais voir un brouillon dans le fil public.
    final postRows = await SupabaseConfig.client
        .from('posts')
        .select('*, zawiyas(name), profiles(display_name)')
        .eq('content_status', 'valide')
        .order('created_at', ascending: false);

    final postIds = postRows.map((row) => row['id'] as String).toList();

    final likeCounts = await _fetchCountsByPost('post_likes', postIds);
    final commentCounts = await _fetchCountsByPost('post_comments', postIds);
    final myLikedIds = await _fetchMyLikedPostIds(postIds);

    return postRows.map((row) {
      final id = row['id'] as String;
      return CommunityPost.fromRow(
        row,
        likeCount: likeCounts[id] ?? 0,
        commentCount: commentCounts[id] ?? 0,
        isLikedByMe: myLikedIds.contains(id),
      );
    }).toList();
  }

  /// Ensemble vide en mode invité (pas de requête inutile) — `post_likes` a
  /// une RLS de lecture publique (`using (true)`), mais filtrer sur
  /// `auth.uid()` sans utilisateur connecté n'a pas de sens ici.
  Future<Set<String>> _fetchMyLikedPostIds(List<String> postIds) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null || postIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    return rows.map((row) => row['post_id'] as String).toSet();
  }

  /// Réservé en V1 aux comptes rattachés à une zawiya (`profiles.zawiya_id`
  /// non nul, vérifié côté écran — `canCreatePostProvider`) pour ne pas
  /// ouvrir la modération à tous les disciples dès cette itération ; la RLS
  /// `posts_author_create` elle-même n'impose que `auth.uid() = author_user_id`,
  /// donc cette restriction n'est aujourd'hui appliquée que côté client.
  ///
  /// [mediaUrl] : URL publique d'une image déjà téléversée par l'appelant
  /// vers le bucket `post-media` (voir `ImageUploadService`,
  /// `_CreatePostSheet`) — cette méthode ne fait que l'enregistrer, `null`
  /// si aucune image n'a été jointe.
  Future<void> createPost(String contentText, {String? zawiyaId, String? mediaUrl}) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('posts').insert({
      'author_user_id': userId,
      'author_zawiya_id': zawiyaId,
      'content_text': contentText,
      'media_url': mediaUrl,
    });
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final rows = await SupabaseConfig.client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

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

  Future<void> toggleLike(String postId, {required bool currentlyLiked}) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    if (currentlyLiked) {
      await SupabaseConfig.client.from('post_likes').delete().match({'post_id': postId, 'user_id': userId});
    } else {
      await SupabaseConfig.client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  /// Réservé à l'auteur de la publication par la RLS `posts_author_delete`
  /// (`auth.uid() = author_user_id`) — contrairement aux zawiyas/figures,
  /// aucune exception admin n'existe ici : un disciple ne peut retirer que
  /// sa propre publication. `post_likes`/`post_comments` référencent
  /// `posts.id` avec `on delete cascade` (`database/schema.sql`), donc
  /// aucune violation de clé étrangère possible à ce niveau.
  Future<void> deletePost(String id) async {
    await SupabaseConfig.client.from('posts').delete().eq('id', id);
  }

  /// Réservé à l'auteur par la RLS `posts_author_update` (migration
  /// `add_posts_author_update_policy`, 2026-08-20) — même restriction
  /// propriétaire-only que `deletePost`, aucune exception admin.
  /// [mediaUrl] : `null` retire l'image existante, une valeur non nulle la
  /// remplace ; pas de flux de review à réinitialiser (`posts.content_status`
  /// reste `valide`, voir la note dans `createPost`).
  Future<void> updatePost(String id, String contentText, {String? mediaUrl}) async {
    await SupabaseConfig.client.from('posts').update({
      'content_text': contentText,
      'media_url': mediaUrl,
    }).eq('id', id);
  }

  Future<void> addComment(String postId, String contentText) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content_text': contentText,
    });
  }

  /// Réservé à l'auteur du commentaire par la RLS `post_comments_author_delete`
  /// (`auth.uid() = user_id`), déjà présente en base mais jamais exposée
  /// côté app avant l'audit CRUD du 2026-08-20.
  Future<void> deleteComment(String id) async {
    await SupabaseConfig.client.from('post_comments').delete().eq('id', id);
  }
}
