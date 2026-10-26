/// Accès aux données du fil d'actualité (Supabase — `posts`, `post_likes`,
/// `post_comments`, `profiles`). Le fil se lit sans compte : la RLS
/// (`posts_read_valid_or_admin`, `post_comments_read_all`) ne renvoie que
/// les publications validées et les contenus non masqués, sans ceux des
/// disciples que le compte a bloqués — sauf à l'admin, d'où les filtres
/// répétés ici (audit Communauté du 2026-10-26, P2-5). Compteurs servis par
/// la fonction `post_counts` (P2-9).
/// Les écritures (aimer, commenter, publier) exigent un `auth.uid()` réel
/// (`posts_author_create`, `post_likes_owner_only`,
/// `post_comments_author_create`).
library;

import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../moderation/data/blocks_repository.dart';
import '../domain/community_models.dart';

/// Retire de [rows] les lignes dont l'auteur ([authorKey]) est dans
/// [blockedIds]. Une ligne sans auteur (compte supprimé) est gardée.
List<Map<String, dynamic>> withoutBlockedAuthors(
  List<Map<String, dynamic>> rows,
  Set<String> blockedIds, {
  required String authorKey,
}) {
  if (blockedIds.isEmpty) return rows;
  return rows.where((row) => !blockedIds.contains(row[authorKey])).toList();
}

class CommunityRepository {
  const CommunityRepository();

  /// Les [limit] publications les plus récentes (audit Communauté du
  /// 2026-10-26, P2-9 : le fil était chargé en entier). Compteurs servis par
  /// la fonction `post_counts` : l'app chargeait toutes les lignes de
  /// `post_likes` et `post_comments` pour les compter, et les compteurs
  /// devenaient faux au-delà du plafond de 1 000 lignes de PostgREST.
  Future<List<CommunityPost>> fetchFeed({required int limit}) async {
    // .eq('content_status', 'valide') en plus de la RLS : même défense en
    // profondeur que FiguresRepository.fetchFigures() — un compte admin ne
    // doit jamais voir un brouillon dans le fil public.
    //
    // Masquage et blocage (audit Communauté du 2026-10-26, P2-5) : la RLS les
    // applique à tous sauf à l'admin, qui lit tout pour pouvoir modérer. Le
    // fil n'est pas l'écran de modération : un contenu masqué, ou écrit par
    // un disciple qu'il a bloqué, y restait affiché sans repère, et l'admin
    // pouvait croire que « Masquer » n'avait pas fonctionné.
    // Blocages filtrés par la requête, pour que la page compte bien [limit]
    // publications ; une publication sans auteur (compte supprimé) reste.
    final blockedIds = await const BlocksRepository().fetchBlockedUserIds();
    var query = SupabaseConfig.client
        .from('posts')
        .select('*, zawiyas(name), profiles(display_name)')
        .eq('content_status', 'valide')
        .isFilter('hidden_at', null);
    if (blockedIds.isNotEmpty) {
      query = query.or('author_user_id.is.null,author_user_id.not.in.(${blockedIds.join(',')})');
    }
    final postRows = await query.order('created_at', ascending: false).range(0, limit - 1);

    final postIds = postRows.map((row) => row['id'] as String).toList();
    final counts = await _fetchCounts(postIds);

    return postRows.map((row) {
      final count = counts[row['id'] as String];
      return CommunityPost.fromRow(
        row,
        likeCount: count?.likes ?? 0,
        commentCount: count?.comments ?? 0,
        isLikedByMe: count?.likedByMe ?? false,
      );
    }).toList();
  }

  /// Une publication du fil, pour l'ouvrir depuis une notification (P3-8).
  /// `null` si elle n'est plus visible (supprimée, masquée, auteur bloqué).
  Future<CommunityPost?> fetchPost(String id) async {
    final row = await SupabaseConfig.client
        .from('posts')
        .select('*, zawiyas(name), profiles(display_name)')
        .eq('id', id)
        .eq('content_status', 'valide')
        .isFilter('hidden_at', null)
        .maybeSingle();
    if (row == null) return null;
    final count = (await _fetchCounts([id]))[id];
    if (count == null) return null;
    return CommunityPost.fromRow(row,
        likeCount: count.likes, commentCount: count.comments, isLikedByMe: count.likedByMe);
  }

  /// Notification « nouveau commentaire » de cette publication marquée lue,
  /// à l'ouverture de la publication par son auteur (P3-8). Au mieux.
  Future<void> markPostCommentNotificationsRead(String postId) async {
    await SupabaseConfig.client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('type', 'post_comment')
        .eq('payload->>post_id', postId)
        .isFilter('read_at', null);
  }

  /// « J'aime », commentaires et « j'aime » du compte connecté, calculés par
  /// le serveur (`post_counts`) — fonctionne aussi sans compte.
  Future<Map<String, ({int likes, int comments, bool likedByMe})>> _fetchCounts(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    final rows = await SupabaseConfig.client.rpc('post_counts', params: {'p_post_ids': postIds}) as List<dynamic>;
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['post_id'] as String: (
          likes: row['like_count'] as int,
          comments: row['comment_count'] as int,
          likedByMe: row['liked_by_me'] as bool,
        ),
    };
  }

  /// Réservé en V1 aux comptes rattachés à une zawiya (`profiles.zawiya_id`
  /// non nul) pour ne pas ouvrir la modération à tous les disciples dès
  /// cette itération. Depuis l'audit du 2026-10-04 (S04), la RLS
  /// `posts_author_create` l'impose aussi côté serveur : [zawiyaId] doit
  /// être la zawiya du profil de l'auteur, sinon l'insertion est refusée —
  /// `canCreatePostProvider` n'est plus qu'un reflet côté écran.
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
    // Même filtre que `fetchFeed` : masqués et auteurs bloqués exclus,
    // y compris pour l'admin.
    final blockedIds = await const BlocksRepository().fetchBlockedUserIds();
    final allRows = await SupabaseConfig.client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .isFilter('hidden_at', null)
        .order('created_at', ascending: true);
    final rows = withoutBlockedAuthors(allRows, blockedIds, authorKey: 'user_id');

    final authorIds = rows.map((row) => row['user_id'] as String).toSet();
    final names = await _fetchDisplayNames(authorIds);

    return rows.map((row) => CommunityComment.fromRow(row, authorDisplayName: names[row['user_id']])).toList();
  }

  Future<Map<String, String>> _fetchDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {for (final row in rows) row['user_id'] as String: row['display_name'] as String};
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
  /// (`auth.uid() = author_user_id`) : un disciple ne peut retirer que sa
  /// propre publication. Seule exception admin, depuis l'audit du 2026-10-26
  /// (P2-3) : une publication dont le compte a été supprimé
  /// (`posts_admin_delete_orphan`), suppression journalisée. `post_likes`/`post_comments` référencent
  /// `posts.id` avec `on delete cascade` (`database/schema.sql`), donc
  /// aucune violation de clé étrangère possible à ce niveau.
  ///
  /// [mediaUrl] : image de la publication, retirée du bucket public une fois
  /// la ligne supprimée (audit du 2026-10-04, S63).
  Future<void> deletePost(String id, {String? mediaUrl}) async {
    await SupabaseConfig.client.from('posts').delete().eq('id', id);
    await ImageUploadService().removeByPublicUrl(bucket: 'post-media', url: mediaUrl);
  }

  /// Réservé à l'auteur par la RLS `posts_author_update` (migration
  /// `add_posts_author_update_policy`, 2026-08-20) — même restriction
  /// propriétaire-only que `deletePost`, aucune exception admin.
  /// [mediaUrl] : `null` retire l'image existante, une valeur non nulle la
  /// remplace ; pas de flux de review à réinitialiser (`posts.content_status`
  /// reste `valide`, voir la note dans `createPost`).
  ///
  /// [previousMediaUrl] : image avant modification — retirée du bucket
  /// public si elle a été remplacée ou enlevée (audit du 2026-10-04, S63).
  Future<void> updatePost(String id, String contentText, {String? mediaUrl, String? previousMediaUrl}) async {
    await SupabaseConfig.client.from('posts').update({
      'content_text': contentText,
      'media_url': mediaUrl,
    }).eq('id', id);
    if (previousMediaUrl != mediaUrl) {
      await ImageUploadService().removeByPublicUrl(bucket: 'post-media', url: previousMediaUrl);
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

  /// Réservé à l'auteur du commentaire par la RLS `post_comments_author_delete`
  /// (`auth.uid() = user_id`), déjà présente en base mais jamais exposée
  /// côté app avant l'audit CRUD du 2026-08-20.
  Future<void> deleteComment(String id) async {
    await SupabaseConfig.client.from('post_comments').delete().eq('id', id);
  }
}
