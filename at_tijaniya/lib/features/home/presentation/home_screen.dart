import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Accueil / Tableau de bord — statut du jour, accès rapide, prochain
/// horaire. Priorité P0. Contenu détaillé à brancher en Phase 3 sur le
/// module Wirds (historique, régularité).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.homeGreeting, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.homeTodayStatus, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
