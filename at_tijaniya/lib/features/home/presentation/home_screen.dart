import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';

/// Accueil / Tableau de bord — statut du jour, accès rapide, prochain
/// horaire. Priorité P0. Contenu détaillé à brancher en Phase 3 sur le
/// module Wirds (historique, régularité).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // `disciple` générique en mode invité (pas de session) ou tant que le
    // profil n'a pas encore été chargé — jamais d'appel à myProfileProvider
    // sans session réelle, qui échouerait (`currentUser!.id` dans
    // `ProfileRepository.fetchMyProfile`).
    final userId = ref.watch(currentUserIdProvider);
    final displayName = userId == null
        ? null
        : ref.watch(myProfileProvider).maybeWhen(data: (profile) => profile.displayName, orElse: () => null);
    final greeting = displayName != null ? '${l10n.homeGreetingPrefix} $displayName' : l10n.homeGreeting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.homeTodayStatus, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
