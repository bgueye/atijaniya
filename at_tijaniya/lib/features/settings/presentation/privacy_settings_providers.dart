import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/privacy_settings_repository.dart';
import '../domain/privacy_settings_models.dart';

final privacySettingsRepositoryProvider =
    Provider<PrivacySettingsRepository>((ref) => const PrivacySettingsRepository());

/// Regarde `currentUserIdProvider` (réactif à `onAuthStateChange`, voir
/// `profile_providers.dart`) pour se refetcher à chaque
/// connexion/déconnexion plutôt que de rester figé sur son premier
/// résultat — même pattern que `myProfileProvider`/`myLineageProvider`.
final myPrivacySettingsProvider = FutureProvider<PrivacySettings>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(privacySettingsRepositoryProvider).fetchMyPrivacySettings();
});
