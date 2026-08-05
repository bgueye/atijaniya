import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_repository.dart';
import '../domain/community_models.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => const CommunityRepository());

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityRepositoryProvider).fetchFeed();
});

final postCommentsProvider = FutureProvider.family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).fetchComments(postId);
});
