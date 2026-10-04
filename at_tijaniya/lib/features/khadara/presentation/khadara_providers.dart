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
  // Lié au compte connecté (audit du 2026-10-04, S40/S41) : sans cette
  // dépendance, le résultat restait en cache après une déconnexion et le
  // compte suivant voyait les données du précédent.
  ref.watch(currentUserIdProvider);
  return const GuidePageRepository().fetchBySlug('comprendre-zawiya');
});

final upcomingEventsProvider = FutureProvider<List<KhadaraEvent>>((ref) {
  return ref.watch(khadaraRepositoryProvider).fetchUpcomingEvents();
});

final zawiyasProvider = FutureProvider<List<Zawiya>>((ref) {
  return ref.watch(khadaraRepositoryProvider).fetchZawiyas();
});

/// Zawiyas proposées quand il s'agit de s'y rattacher (profil, groupe) —
/// dérivé de [zawiyasProvider] sans requête supplémentaire, voir
/// `attachableZawiyas` pour la règle. L'annuaire et le formulaire d'évènement
/// continuent d'utiliser [zawiyasProvider] : un évènement peut se tenir dans
/// un lieu saint ou une mosquée.
final attachableZawiyasProvider = FutureProvider<List<Zawiya>>((ref) async {
  return attachableZawiyas(await ref.watch(zawiyasProvider.future));
});

/// Évènements à venir pour une zawiya donnée — dérivé de
/// [upcomingEventsProvider] plutôt qu'une requête réseau séparée, affiché
/// sur `ZawiyaDetailScreen`.
final eventsForZawiyaProvider = Provider.family<AsyncValue<List<KhadaraEvent>>, String>((ref, zawiyaId) {
  final events = ref.watch(upcomingEventsProvider);
  return events.whenData((list) => list.where((e) => e.zawiyaId == zawiyaId).toList());
});

/// `true` si le compte peut créer un évènement Khadara — admin, ou
/// mouqaddam confirmé à qui l'admin a attribué une zawiya
/// (`mouqaddam_status.managed_zawiya_id`, plus `profiles.zawiya_id` depuis
/// l'audit du 2026-10-04). `false` par défaut (invité, chargement, erreur,
/// mouqaddam sans zawiya attribuée). Même
/// forme que `isAdminProvider`/`canCreatePostProvider`. Exception
/// volontaire et scopée à Khadara au statut mouqaddam qui, normalement,
/// n'accorde aucun droit technique (voir CLAUDE.md) — décision explicite
/// du porteur de projet, ne pas généraliser ailleurs.
final canCreateEventProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  return ref.watch(myManagedZawiyaIdProvider) != null;
});

/// `true` si le compte peut créer/modifier/supprimer une zawiya — reflet
/// direct de `zawiyas_admin_write`/`_update`/`_delete` (`is_admin`
/// uniquement, aucune exception mouqaddam contrairement aux évènements).
final canManageZawiyasProvider = Provider<bool>((ref) => ref.watch(isAdminProvider));
