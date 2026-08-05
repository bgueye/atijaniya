import 'package:flutter_riverpod/flutter_riverpod.dart';

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
