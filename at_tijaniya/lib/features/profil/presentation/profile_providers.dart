import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => const ProfileRepository());

/// `null` en l'absence de session réelle (mode invité, ou tant que
/// l'authentification n'est pas branchée — voir `profile_repository.dart`).
/// `ProfilScreen` s'en sert pour afficher un état "connectez-vous" plutôt
/// que de tenter un appel réseau voué à l'échec.
final currentUserIdProvider = Provider<String?>((ref) {
  return SupabaseConfig.client.auth.currentUser?.id;
});

final myProfileProvider = FutureProvider<Profile>((ref) {
  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});
