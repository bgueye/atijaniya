import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/khadara_understanding_content.dart';
import 'khadara_providers.dart';

/// Comprendre la Zawiya — contenu pédagogique pour les nouveaux disciples
/// qui parcourent l'annuaire des zawiyas de l'onglet Khadara (pas le
/// déroulement de la Hadaratou-l-Jouma, qui relève du module Wirds).
/// Priorité P1 (docs/03-architecture-ecrans.md).
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : le contenu vient de `khadaraUnderstandingPageProvider` (table
/// `guide_pages`, slug `comprendre-zawiya`). La RLS ne laisse remonter une
/// ligne à un disciple que si `content_status = 'valide'` — pas de filtre à
/// dupliquer ici. Un admin peut en revanche voir un brouillon non publié
/// (mention explicite affichée) pour le relire avant validation.
class KhadaraUnderstandingScreen extends ConsumerWidget {
  const KhadaraUnderstandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final page = ref.watch(khadaraUnderstandingPageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.khadaraUnderstandingTitle)),
      // `SafeArea` : même défaut déjà vu sur `FigureFormScreen`/`AboutScreen`
      // — sans elle, le bas du contenu se retrouve masqué sous la barre de
      // navigation Android (3 boutons).
      body: SafeArea(
        child: page.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (err, st) => Center(
            child: Text(l10n.khadaraLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (guidePage) {
            if (guidePage == null) {
              return _EmptyState(
                title: l10n.khadaraUnderstandingEmptyTitle,
                body: l10n.khadaraUnderstandingEmptyBody,
                ctaLabel: l10n.khadaraUnderstandingCta,
              );
            }
            final sections = parseGuidePageSections(guidePage.bodyMarkdown);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (guidePage.contentStatus != 'valide') _DraftBanner(label: l10n.khadaraUnderstandingDraftBanner),
                for (final section in sections) _SectionTile(section: section),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: AppColors.bronze, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: AppColors.bronze))),
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
              child: Icon(Icons.menu_book_outlined, color: AppColors.bronze, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
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
            Text(
              section.body,
              style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
