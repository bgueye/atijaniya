import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups_repository.dart';
import '../domain/group_models.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) => const GroupsRepository());

final groupsProvider = FutureProvider<List<Group>>((ref) {
  return ref.watch(groupsRepositoryProvider).fetchGroups();
});

final groupPostsProvider = FutureProvider.family<List<GroupPost>, String>((ref, groupId) {
  return ref.watch(groupsRepositoryProvider).fetchGroupPosts(groupId);
});
