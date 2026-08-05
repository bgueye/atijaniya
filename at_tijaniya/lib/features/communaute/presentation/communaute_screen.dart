import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Module Communauté — priorité P1/P2. Placeholder pour le fil d'actualité ;
/// la lignée spirituelle et le statut Mouqaddam vivent dans des écrans dédiés
/// accessibles depuis le profil (données sensibles, cf. CLAUDE.md).
class CommunauteScreen extends StatelessWidget {
  const CommunauteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.communityComingSoonTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.communityComingSoonBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
