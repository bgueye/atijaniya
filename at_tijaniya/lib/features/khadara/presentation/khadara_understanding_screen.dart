import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/khadara_understanding_content.dart';

/// Comprendre la Khadara — contenu pédagogique pour les nouveaux disciples.
/// Priorité P1 (docs/03-architecture-ecrans.md).
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : le contenu affiché ici provient exclusivement de
/// `lib/features/khadara/data/khadara_understanding_content.dart` (source
/// unique). Cette liste est actuellement vide car aucun contenu n'est
/// encore validé — voir la règle impérative en tête de ce fichier de
/// contenu. L'écran affiche alors un état vide honnête plutôt que du
/// contenu inventé.
class KhadaraUnderstandingScreen extends StatelessWidget {
  const KhadaraUnderstandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.khadaraUnderstandingTitle)),
      body: validatedKhadaraUnderstanding.isEmpty
          ? _EmptyState(
              title: l10n.khadaraUnderstandingEmptyTitle,
              body: l10n.khadaraUnderstandingEmptyBody,
              ctaLabel: l10n.khadaraUnderstandingCta,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final section in validatedKhadaraUnderstanding) _SectionTile(section: section),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body, required this.ctaLabel});

  final String title;
  final String body;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.menu_book_outlined, color: AppColors.bronze, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
            const SizedBox(height: 24),
            // Renvoie vers le calendrier/l'annuaire déjà fonctionnels de l'onglet
            // Khadara (cet écran est poussé par-dessus), plutôt que de laisser un
            // cul-de-sac tant que le contenu pédagogique n'est pas validé.
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(ctaLabel, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});

  final KhadaraUnderstandingSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(section.body, style: const TextStyle(color: AppColors.ink, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
