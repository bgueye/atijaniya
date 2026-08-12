import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../data/khadara_repository.dart';
import '../domain/khadara_models.dart';

final khadaraRepositoryProvider = Provider<KhadaraRepository>((ref) => const KhadaraRepository());

final upcomingEventsProvider = FutureProvider<List<KhadaraEvent>>((ref) {
  return ref.watch(khadaraRepositoryProvider).fetchUpcomingEvents();
});

final zawiyasProvider = FutureProvider<List<Zawiya>>((ref) {
  return ref.watch(khadaraRepositoryProvider).fetchZawiyas();
});

/// Évènements à venir pour une zawiya donnée — dérivé de
/// [upcomingEventsProvider] plutôt qu'une requête réseau séparée, affiché
/// sur `ZawiyaDetailScreen`.
final eventsForZawiyaProvider = Provider.family<AsyncValue<List<KhadaraEvent>>, String>((ref, zawiyaId) {
  final events = ref.watch(upcomingEventsProvider);
  return events.whenData((list) => list.where((e) => e.zawiyaId == zawiyaId).toList());
});

/// `true` si le compte peut créer un évènement Khadara — admin, ou
/// mouqaddam vérifié rattaché à une zawiya (`profiles.zawiya_id`). `false`
/// par défaut (invité, chargement, erreur, mouqaddam sans zawiya). Même
/// forme que `isAdminProvider`/`canCreatePostProvider`. Exception
/// volontaire et scopée à Khadara au statut mouqaddam qui, normalement,
/// n'accorde aucun droit technique (voir CLAUDE.md) — décision explicite
/// du porteur de projet, ne pas généraliser ailleurs.
final canCreateEventProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  if (!ref.watch(isVerifiedMouqaddamProvider)) return false;
  return ref.watch(myProfileProvider).maybeWhen(data: (profile) => profile.zawiyaId != null, orElse: () => false);
});
