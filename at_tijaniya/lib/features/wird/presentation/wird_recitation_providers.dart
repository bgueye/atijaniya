import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_recitation_repository.dart';
import '../domain/wird_recitation.dart';

final wirdRecitationRepositoryProvider = Provider<WirdRecitationRepository>((ref) => const WirdRecitationRepository());

/// Récitations en brouillon, pour l'écran de review admin
/// (`WirdRecitationsReviewScreen`) — voir la note sur `is_admin` dans
/// `WirdRecitationRepository.fetchDraftRecitations`.
final draftWirdRecitationsProvider = FutureProvider<List<WirdRecitationDraft>>((ref) {
  return ref.watch(wirdRecitationRepositoryProvider).fetchDraftRecitations();
});
