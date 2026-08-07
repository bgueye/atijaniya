/// Modèles du module Groupes (P2, docs/03-architecture-ecrans.md : "Liste
/// par zawiya/région + fil de discussion"). Même principe que
/// `community_models.dart` : le contenu vient des tables Supabase `groups`,
/// `group_memberships`, `group_posts` — voir `groups_repository.dart`.
library;

class Group {
  const Group({
    required this.id,
    required this.name,
    this.description,
    this.zawiyaId,
    this.zawiyaName,
    this.regionText,
    required this.createdAt,
    required this.memberCount,
    required this.isMember,
  });

  final String id;
  final String name;
  final String? description;
  final String? zawiyaId;

  /// Résolu via l'embedding PostgREST (`zawiyas(name)`), FK directe — voir
  /// `GroupsRepository.fetchGroups()`.
  final String? zawiyaName;
  final String? regionText;
  final DateTime createdAt;
  final int memberCount;

  /// `false` sans session réelle (aucune requête d'appartenance n'est faite
  /// en mode invité) — voir `GroupsRepository.fetchGroups()`.
  final bool isMember;

  /// Lieu affiché : zawiya en priorité, sinon la région en texte libre,
  /// sinon rien.
  String? get locationLabel => zawiyaName ?? regionText;

  /// Utilisé pour la mise à jour optimiste de `memberCount`/`isMember`
  /// après rejoindre/quitter un groupe — voir `group_detail_screen.dart`.
  Group copyWith({int? memberCount, bool? isMember}) {
    return Group(
      id: id,
      name: name,
      description: description,
      zawiyaId: zawiyaId,
      zawiyaName: zawiyaName,
      regionText: regionText,
      createdAt: createdAt,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
    );
  }

  factory Group.fromRow(
    Map<String, dynamic> row, {
    required int memberCount,
    required bool isMember,
  }) {
    final zawiyaRelation = row['zawiyas'] as Map<String, dynamic>?;
    return Group(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      zawiyaId: row['zawiya_id'] as String?,
      zawiyaName: zawiyaRelation?['name'] as String?,
      regionText: row['region_text'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      memberCount: memberCount,
      isMember: isMember,
    );
  }
}

class GroupPost {
  const GroupPost({
    required this.id,
    required this.groupId,
    required this.authorUserId,
    this.authorDisplayName,
    required this.contentText,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String authorUserId;
  final String? authorDisplayName;
  final String contentText;
  final DateTime createdAt;

  factory GroupPost.fromRow(Map<String, dynamic> row, {String? authorDisplayName}) {
    return GroupPost(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      authorUserId: row['author_user_id'] as String,
      authorDisplayName: authorDisplayName,
      contentText: row['content_text'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
