import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wirds_content.dart';
import '../data/wird_recitation_repository.dart';
import '../domain/wird_recitation.dart';

final wirdRecitationRepositoryProvider = Provider<WirdRecitationRepository>(
    (ref) => const WirdRecitationRepository());

/// Récitations en brouillon, pour l'écran de review admin
/// (`WirdRecitationsReviewScreen`) — voir la note sur `is_admin` dans
/// `WirdRecitationRepository.fetchDraftRecitations`.
final draftWirdRecitationsProvider =
    FutureProvider<List<WirdRecitationDraft>>((ref) {
  return ref.watch(wirdRecitationRepositoryProvider).fetchDraftRecitations();
});

/// Toutes les récitations (tout statut) des 3 wirds, groupées par pilier —
/// pour `WirdRecitationsManagementScreen`. Un seul `Future.wait` sur
/// `validatedWirds` plutôt qu'un provider `.family` : seulement 3 wirds
/// connus statiquement, pas besoin de la complexité d'un family ici.
final allWirdStepRecitationsProvider =
    FutureProvider<Map<String, List<WirdStepRecitations>>>((ref) async {
  final repository = ref.watch(wirdRecitationRepositoryProvider);
  final entries = await Future.wait(
    validatedWirds.map((wird) async => MapEntry(
        wird.id, await repository.fetchAllRecitationsForWird(wird.id))),
  );
  return Map.fromEntries(entries);
});
