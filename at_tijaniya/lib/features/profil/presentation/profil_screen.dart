import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/profile_models.dart';
import 'edit_profile_sheet.dart';
import 'profile_providers.dart';

/// Mon profil — infos de base, zawiya, "Ma lignée spirituelle". Priorité P0
/// (docs/03-architecture-ecrans.md).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md) : le nom du moqaddam et le statut
/// "Mouqaddam vérifié" sont privés par défaut, opt-in strict, jamais
/// d'annuaire public. Ne jamais construire ici de liste/recherche publique
/// sur ces champs.
///
/// Comme le module Communauté, la lecture/l'édition du profil ont besoin
/// d'un `auth.uid()` réel, indisponible tant que l'authentification n'est
/// pas branchée côté app (TODO dans `auth_screen.dart`) : cet écran affiche
/// donc un état "connectez-vous" explicite plutôt qu'un échec silencieux —
/// se réactivera automatiquement une fois l'auth branchée, aucun changement
/// nécessaire ici.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: userId == null ? _SignInRequired(l10n: l10n) : const _ProfileBody(),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, color: AppColors.bronze, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.profileSignInRequired,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.bronze),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(myProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(
                l10n.profileLoadError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.bronze),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: Text(l10n.profileRetry),
              ),
            ],
          ),
        ),
      ),
      data: (profile) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(profile: profile, l10n: l10n),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
              title: Text(l10n.profileMyLineage),
              trailing: const Icon(Icons.lock_outline, size: 18, color: AppColors.bronze),
              onTap: () {
                // TODO(Phase 3, P1) : écran "Renseigner ma lignée spirituelle"
                // (foyer, nom du moqaddam avec suggestions, année, zawiya optionnelle).
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.profileSettings),
              onTap: () {
                // TODO(Phase 3, P0) : Paramètres généraux (langue, notifications,
                // confidentialité — incl. visibilité de la lignée et du statut mouqaddam).
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(l10n.profileSignOut, style: const TextStyle(color: Colors.redAccent)),
            onTap: () => _confirmSignOut(context, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSignOutConfirmTitle),
        content: Text(l10n.profileSignOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profileSignOutConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseConfig.client.auth.signOut();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.l10n});

  final Profile profile;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.emeraldSoft,
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person_outline, color: AppColors.emerald, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.displayName, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        profile.zawiyaName ?? l10n.profileZawiyaNoneLabel,
                        style: const TextStyle(color: AppColors.bronze, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.profileEditTooltip,
                  onPressed: () => showEditProfileSheet(context, profile),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(profile.bio ?? l10n.profileNoBio, style: const TextStyle(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
