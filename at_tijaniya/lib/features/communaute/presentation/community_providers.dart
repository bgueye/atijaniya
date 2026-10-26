import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'load_more_button.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => const CommunityRepository());

/// Nombre de publications chargées dans le fil, augmenté d'une page par
/// « Voir plus » (audit Communauté du 2026-10-26, P2-9). Revient à une page
/// au changement de compte.
final communityFeedLimitProvider = StateProvider<int>((ref) {
  ref.watch(currentUserIdProvider);
  return communityPageSize;
});

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  // Lié au compte connecté (audit du 2026-10-04, S40/S41) : sans cette
  // dépendance, le résultat restait en cache après une déconnexion et le
  // compte suivant voyait les données du précédent.
  ref.watch(currentUserIdProvider);
  return ref.watch(communityRepositoryProvider).fetchFeed(limit: ref.watch(communityFeedLimitProvider));
});

/// `false` par défaut (invité, profil sans zawiya, chargement, erreur) —
/// création du fil réservée en V1 aux comptes rattachés à une zawiya (voir
/// `CommunityRepository.createPost`). Même pattern que `isAdminProvider`.
final canCreatePostProvider = Provider<bool>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return false;
  return ref.watch(myProfileProvider).maybeWhen(data: (profile) => profile.zawiyaId != null, orElse: () => false);
});

/// `.autoDispose` (Sprint 4, audit perf) : consultée depuis
/// `PostDetailScreen`, poussé/dépilé par publication — sans ça, chaque
/// publication ouverte au fil d'une session laisse ses commentaires en
/// cache indéfiniment.
final postCommentsProvider = FutureProvider.autoDispose.family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).fetchComments(postId);
});
