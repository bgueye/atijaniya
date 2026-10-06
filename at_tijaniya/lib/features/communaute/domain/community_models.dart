/// Modèles du fil d'actualité communautaire (P1, docs/03-architecture-ecrans.md
/// : "Publications communauté + zawiyas suivies" / "Contenu, commentaires,
/// likes").
///
/// Comme le module Khadara, ce contenu vient des tables Supabase
/// (`posts`, `post_likes`, `post_comments`) et non d'un fichier statique —
/// voir `community_repository.dart`.
library;

class CommunityPost {
  const CommunityPost({
    required this.id,
    this.authorUserId,
    this.authorZawiyaId,
    this.authorDisplayName,
    this.authorZawiyaName,
    required this.contentText,
    this.mediaUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.isLikedByMe = false,
  });

  final String id;
  final String? authorUserId;
  final String? authorZawiyaId;

  /// Résolu via l'embedding PostgREST (`profiles(display_name)`), FK directe
  /// `posts.author_user_id -> profiles.user_id` — voir `CommunityRepository`.
  final String? authorDisplayName;

  /// Résolu via l'embedding PostgREST (`zawiyas(name)`), FK directe.
  final String? authorZawiyaName;

  final String contentText;
  final String? mediaUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  /// Résolu par `CommunityRepository.fetchFeed` via une requête `post_likes`
  /// filtrée sur l'utilisateur courant — `false` par défaut (invité).
  final bool isLikedByMe;

  /// Nom affiché : « disciple · zawiya » (décision du porteur de projet du
  /// 2026-10-06). La zawiya seule était affichée en priorité, alors que le
  /// rattachement est déclaré par le disciple lui-même : une publication
  /// pouvait passer pour une parole officielle de la zawiya. La zawiya seule
  /// ne subsiste que pour une publication dont le compte a été supprimé,
  /// puis un repli générique si rien n'est connu.
  String authorLabel(String fallback) {
    final name = authorDisplayName;
    final zawiya = authorZawiyaName;
    if (name != null && zawiya != null) return '$name · $zawiya';
    return name ?? zawiya ?? fallback;
  }

  factory CommunityPost.fromRow(
    Map<String, dynamic> row, {
    required int likeCount,
    required int commentCount,
    bool isLikedByMe = false,
  }) {
    final zawiyaRelation = row['zawiyas'] as Map<String, dynamic>?;
    final profileRelation = row['profiles'] as Map<String, dynamic>?;
    return CommunityPost(
      id: row['id'] as String,
      authorUserId: row['author_user_id'] as String?,
      authorZawiyaId: row['author_zawiya_id'] as String?,
      authorDisplayName: profileRelation?['display_name'] as String?,
      authorZawiyaName: zawiyaRelation?['name'] as String?,
      contentText: row['content_text'] as String,
      mediaUrl: row['media_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      likeCount: likeCount,
      commentCount: commentCount,
      isLikedByMe: isLikedByMe,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.userId,
    this.authorDisplayName,
    required this.contentText,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? authorDisplayName;
  final String contentText;
  final DateTime createdAt;

  factory CommunityComment.fromRow(Map<String, dynamic> row, {String? authorDisplayName}) {
    return CommunityComment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      authorDisplayName: authorDisplayName,
      contentText: row['content_text'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
