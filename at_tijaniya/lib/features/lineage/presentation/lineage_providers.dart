import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/lineage_repository.dart';
import '../domain/lineage_models.dart';

final lineageRepositoryProvider = Provider<LineageRepository>((ref) => const LineageRepository());

/// `null` si le disciple n'a pas encore renseigné sa lignée. Regarde
/// `currentUserIdProvider` (réactif à `onAuthStateChange`, voir
/// `profile_providers.dart`) pour se refetcher à chaque
/// connexion/déconnexion plutôt que de rester figé sur son premier résultat.
final myLineageProvider = FutureProvider<LineageDeclaration?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(lineageRepositoryProvider).fetchMyLineage();
});

final lineageMatchesProvider = FutureProvider<List<LineageMatch>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(lineageRepositoryProvider).searchMatches();
});

final myConnectionRequestsProvider = FutureProvider<List<LineageConnectionRequest>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(lineageRepositoryProvider).fetchMyConnectionRequests();
});
