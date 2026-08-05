import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Module Figures et enseignements — priorité P1. Placeholder.
///
/// IMPORTANT (CLAUDE.md) : les biographies ne sont pas encore validées
/// (docs/01-perimetre-fonctionnel.md § 8) — ne pas générer/coder en dur de
/// contenu biographique ici tant qu'il n'a pas été fourni comme "validé".
class FiguresScreen extends StatelessWidget {
  const FiguresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.figuresComingSoonTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.figuresComingSoonBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
