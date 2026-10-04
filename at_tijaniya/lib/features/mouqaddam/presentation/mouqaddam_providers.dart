import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/mouqaddam_repository.dart';
import '../domain/mouqaddam_models.dart';

final mouqaddamRepositoryProvider = Provider<MouqaddamRepository>((ref) => const MouqaddamRepository());

/// Se recalcule à chaque connexion/déconnexion (voir `currentUserIdProvider`
/// dans `profile_providers.dart` — même bug déjà corrigé une fois sur ce
/// pattern, pas la peine de le reproduire ici).
final myMouqaddamStatusProvider = FutureProvider<MouqaddamStatus>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(mouqaddamRepositoryProvider).fetchMyStatus();
});

/// `false` par défaut (invité, chargement, ou erreur) — jamais d'exception
/// propagée juste pour savoir si les écrans "Demandes de parrainage"/"Ma
/// silsila d'ijaza" doivent être proposés sur `ProfilScreen`.
final isVerifiedMouqaddamProvider = Provider<bool>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return false;
  return ref.watch(myMouqaddamStatusProvider).maybeWhen(data: (status) => status.isVerified, orElse: () => false);
});

/// Zawiya dont le compte connecté peut gérer les évènements — `null` s'il
/// n'est pas mouqaddam confirmé, si l'admin ne lui a rien attribué, ou
/// pendant le chargement. Reflet client de `my_managed_zawiya()` côté base,
/// qui reste la source de vérité (RLS des évènements).
final myManagedZawiyaIdProvider = Provider<String?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return null;
  return ref.watch(myMouqaddamStatusProvider).maybeWhen(
        data: (status) => status.isVerified ? status.managedZawiyaId : null,
        orElse: () => null,
      );
});

final myLatestSponsorshipRequestProvider = FutureProvider<SponsorshipRequest?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(mouqaddamRepositoryProvider).fetchMyLatestRequest();
});

final receivedSponsorshipRequestsProvider = FutureProvider<List<SponsorshipRequest>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(mouqaddamRepositoryProvider).fetchReceivedRequests();
});

final myIjazaChainProvider = FutureProvider<List<IjazaChainLink>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(mouqaddamRepositoryProvider).fetchMyIjazaChain();
});
