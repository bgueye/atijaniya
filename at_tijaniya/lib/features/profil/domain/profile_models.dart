/// Modèle du profil disciple (infos de base) — table Supabase `profiles`.
/// Priorité P0 (docs/03-architecture-ecrans.md, "Mon profil").
///
/// Champs volontairement exclus ici : lignée spirituelle et statut
/// Mouqaddam, gérés par des tables et écrans dédiés (données sensibles,
/// cf. CLAUDE.md) — jamais dupliqués dans ce modèle.
library;

class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.locale,
    this.zawiyaId,
    this.zawiyaName,
    this.bio,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String locale;
  final String? zawiyaId;

  /// Résolu via l'embedding PostgREST (`select('*, zawiyas(name)')`) — voir
  /// `ProfileRepository.fetchMyProfile`.
  final String? zawiyaName;
  final String? bio;

  factory Profile.fromRow(Map<String, dynamic> row) {
    final zawiyaRelation = row['zawiyas'] as Map<String, dynamic>?;
    return Profile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      locale: row['locale'] as String? ?? 'fr',
      zawiyaId: row['zawiya_id'] as String?,
      zawiyaName: zawiyaRelation?['name'] as String?,
      bio: row['bio'] as String?,
    );
  }
}
