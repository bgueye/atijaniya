import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Mon profil — infos de base, zawiya, "Ma lignée spirituelle". Priorité P0
/// pour l'écran lui-même ; le formulaire de lignée est P1 (docs/03-...).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md) : le nom du moqaddam et le statut
/// "Mouqaddam vérifié" sont privés par défaut, opt-in strict, jamais
/// d'annuaire public. Ne jamais construire ici de liste/recherche publique
/// sur ces champs.
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
            title: Text(l10n.profileMyLineage),
            trailing: const Icon(Icons.lock_outline, size: 18, color: AppColors.bronze),
            onTap: () {
              // TODO(Phase 3, P1) : écran "Renseigner ma lignée spirituelle"
              // (foyer, nom du moqaddam avec suggestions, année, zawiya optionnelle).
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.profileSettings),
            onTap: () {
              // TODO(Phase 3, P0) : Paramètres généraux (langue, notifications,
              // confidentialité — incl. visibilité de la lignée et du statut mouqaddam).
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(l10n.profileSignOut, style: const TextStyle(color: Colors.redAccent)),
            onTap: () {
              // TODO : SupabaseConfig.client.auth.signOut()
            },
          ),
        ],
      ),
    );
  }
}
