import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../data/guide_page_repository.dart';
import '../data/khadara_repository.dart';
import '../domain/khadara_models.dart';

final khadaraRepositoryProvider = Provider<KhadaraRepository>((ref) => const KhadaraRepository());

/// Page "Comprendre la Zawiya" (`guide_pages`, slug `comprendre-zawiya`) —
/// explique ce qu'est une zawiya pour quelqu'un qui parcourt l'annuaire de
/// l'onglet Khadara (pas le déroulement de la Hadaratou-l-Jouma, qui relève
/// du module Wirds). Reste `null` pour un disciple tant que la page n'est
/// pas `valide` côté RLS — `KhadaraUnderstandingScreen` retombe alors sur
/// son état vide.
final khadaraUnderstandingPageProvider = FutureProvider<GuidePage?>((ref) {
  return const GuidePageRepository().fetchBySlug('comprendre-zawiya');
});

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

/// `true` si le compte peut créer/modifier/supprimer une zawiya — reflet
/// direct de `zawiyas_admin_write`/`_update`/`_delete` (`is_admin`
/// uniquement, aucune exception mouqaddam contrairement aux évènements).
final canManageZawiyasProvider = Provider<bool>((ref) => ref.watch(isAdminProvider));
