import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => const CommunityRepository());

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityRepositoryProvider).fetchFeed();
});

/// `false` par défaut (invité, profil sans zawiya, chargement, erreur) —
/// création du fil réservée en V1 aux comptes rattachés à une zawiya (voir
/// `CommunityRepository.createPost`). Même pattern que `isAdminProvider`.
final canCreatePostProvider = Provider<bool>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return false;
  return ref.watch(myProfileProvider).maybeWhen(data: (profile) => profile.zawiyaId != null, orElse: () => false);
});

final postCommentsProvider = FutureProvider.family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).fetchComments(postId);
});
