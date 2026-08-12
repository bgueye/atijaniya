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

  /// Nom affiché : zawiya auteure en priorité, sinon le disciple, sinon un
  /// repli générique (compte supprimé, profil introuvable...).
  String authorLabel(String fallback) => authorZawiyaName ?? authorDisplayName ?? fallback;

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
