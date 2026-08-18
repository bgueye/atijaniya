import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/moderation_repository.dart';
import '../domain/moderation_models.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) => const ModerationRepository());

/// Signalements en attente — écran admin uniquement (RLS l'impose déjà côté
/// serveur). Regarde `currentUserIdProvider` comme le reste de l'app pour se
/// refetcher à chaque connexion/déconnexion.
final pendingReportsProvider = FutureProvider<List<ReportWithPreview>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(moderationRepositoryProvider).fetchPendingReports();
});
