import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => const ProfileRepository());

/// Flux des changements de session (connexion, déconnexion, rafraîchissement
/// de session au démarrage). `onAuthStateChange` est un `ReplaySubject`
/// côté gotrue : un nouvel abonné reçoit immédiatement le dernier état
/// connu, pas d'attente sur le premier `watch`.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

/// `null` en l'absence de session réelle (mode invité). Se recalcule à
/// chaque connexion/déconnexion (voir `authStateChangesProvider`) — un
/// `Provider` simple basé uniquement sur `currentUser` resterait figé sur
/// sa première valeur pour toute la durée de vie de l'app, y compris après
/// une déconnexion. `ProfilScreen` s'en sert pour afficher un état
/// "connectez-vous" plutôt que de tenter un appel réseau voué à l'échec.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (state) => state.session?.user.id,
    loading: () => SupabaseConfig.client.auth.currentUser?.id,
    error: (error, stackTrace) => SupabaseConfig.client.auth.currentUser?.id,
  );
});

final myProfileProvider = FutureProvider<Profile>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});
