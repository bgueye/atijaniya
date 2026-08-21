import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups_repository.dart';
import '../domain/group_models.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) => const GroupsRepository());

final groupsProvider = FutureProvider<List<Group>>((ref) {
  return ref.watch(groupsRepositoryProvider).fetchGroups();
});

/// `.autoDispose` (Sprint 4, audit perf) : consultée depuis
/// `GroupDetailScreen`, poussé/dépilé par groupe — sans ça, chaque groupe
/// visité au fil d'une session laisse ses messages en cache indéfiniment.
final groupPostsProvider = FutureProvider.autoDispose.family<List<GroupPost>, String>((ref, groupId) {
  return ref.watch(groupsRepositoryProvider).fetchGroupPosts(groupId);
});
