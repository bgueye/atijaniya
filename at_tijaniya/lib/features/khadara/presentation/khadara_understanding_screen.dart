import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/draft_banner.dart';
import '../../../core/widgets/message_page.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/app_localizations.dart';
import '../data/khadara_understanding_content.dart';
import 'khadara_providers.dart';
import '../../../core/widgets/content_text.dart';

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
          // États du kit (`Notice`, mise au thème du kit, 2026-11-04) : l'erreur
          // était en texte bronze (sous le seuil AA) ou sans « Réessayer ».
          error: (err, st) => NoticeBody(
            Notice.fromError(
              err,
              message: l10n.khadaraLoadError,
              onRetry: () => ref.invalidate(khadaraUnderstandingPageProvider),
            ),
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
                // Bandeau « brouillon » partagé (`DraftBanner`) : celui d'ici
                // était en texte bronze, sous le seuil AA.
                if (guidePage.contentStatus != 'valide') ...[
                  DraftBanner(l10n.khadaraUnderstandingDraftBanner),
                  const SizedBox(height: 12),
                ],
                for (final section in sections) _SectionTile(section: section),
              ],
            );
          },
        ),
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
    // Page du kit (`MessagePage`) : rond or doux et texte bronze
    // auparavant (mise au thème du kit, 2026-11-04).
    return MessagePage(
      icon: Icons.menu_book_outlined,
      title: title,
      body: body,
      // Renvoie vers le calendrier/l'annuaire déjà fonctionnels de l'onglet
      // Zawiyas (cet écran est poussé par-dessus), plutôt que de laisser un
      // cul-de-sac tant que le contenu pédagogique n'est pas validé.
      action: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.event_outlined, size: 18),
        label: ContentText(ctaLabel, textAlign: TextAlign.center),
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
            ContentText(section.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
            const SizedBox(height: 8),
            ContentText(
              section.body,
              style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
