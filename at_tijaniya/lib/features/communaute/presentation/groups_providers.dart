import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups_repository.dart';
import '../domain/group_models.dart';
import '../../profil/presentation/profile_providers.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) => const GroupsRepository());

final groupsProvider = FutureProvider<List<Group>>((ref) {
  // Lié au compte connecté (audit du 2026-10-04, S40/S41) : sans cette
  // dépendance, le résultat restait en cache après une déconnexion et le
  // compte suivant voyait les données du précédent.
  ref.watch(currentUserIdProvider);
  return ref.watch(groupsRepositoryProvider).fetchGroups();
});

/// `.autoDispose` (Sprint 4, audit perf) : consultée depuis
/// `GroupDetailScreen`, poussé/dépilé par groupe — sans ça, chaque groupe
/// visité au fil d'une session laisse ses messages en cache indéfiniment.
final groupPostsProvider = FutureProvider.autoDispose.family<List<GroupPost>, String>((ref, groupId) {
  ref.watch(currentUserIdProvider); // lié au compte, voir plus haut
  return ref.watch(groupsRepositoryProvider).fetchGroupPosts(groupId);
});
