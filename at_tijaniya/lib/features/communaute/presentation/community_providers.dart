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

/// Zawiya de rattachement du disciple connecté, `null` sinon (invité,
/// profil sans zawiya, chargement, erreur). Sert au filtre « Ma zawiya » et
/// aux rendez-vous intercalés dans le fil (refonte du 2026-11-02).
final myCommunityZawiyaProvider = Provider<({String id, String? name})?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final profile = ref.watch(myProfileProvider).valueOrNull;
  final id = profile?.zawiyaId;
  return id == null ? null : (id: id, name: profile!.zawiyaName);
});

/// Filtre du fil : `true` pour « Ma zawiya », `false` pour toute la
/// communauté. Revient à toute la communauté au changement de compte.
final communityFeedMineOnlyProvider = StateProvider<bool>((ref) {
  ref.watch(currentUserIdProvider);
  return false;
});

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  // Lié au compte connecté (audit du 2026-10-04, S40/S41) : sans cette
  // dépendance, le résultat restait en cache après une déconnexion et le
  // compte suivant voyait les données du précédent.
  ref.watch(currentUserIdProvider);
  // « Ma zawiya » n'a de sens que pour un disciple rattaché : sans zawiya, le
  // filtre est ignoré (et masqué à l'écran).
  final zawiya = ref.watch(myCommunityZawiyaProvider);
  final mineOnly = ref.watch(communityFeedMineOnlyProvider) && zawiya != null;
  return ref
      .watch(communityRepositoryProvider)
      .fetchFeed(limit: ref.watch(communityFeedLimitProvider), zawiyaId: mineOnly ? zawiya.id : null);
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
