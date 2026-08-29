import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// À propos d'At-Tijaniya — positionnement institutionnel (non-affiliation,
/// statut du contenu religieux, badge "Parrainage confirmé", neutralité
/// entre foyers). Accessible en permanence depuis Paramètres généraux, ce
/// n'est pas un contenu d'onboarding vu une seule fois.
///
/// IMPORTANT (CLAUDE.md, docs/11-a-propos.md) : ce texte fait foi mot pour
/// mot — ne pas le paraphraser. Le paragraphe "Parrainage confirmé" doit
/// rester cohérent avec l'info-bulle du badge (CLAUDE.md, section "Libellé
/// UI du badge").
///
/// `SingleChildScrollView` + `Column`, pas `ListView` : ce contenu est fixe
/// et modeste, pas une liste — un `ListView` ne construit que les enfants
/// dans son cache extent, ce qui laissait les dernières sections absentes
/// de l'arbre de widgets (silencieusement, y compris pour les tests).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutScreenTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutIntro,
              style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 28),
            _AboutSection(
              title: l10n.aboutIndependenceSectionTitle,
              children: [
                Text(l10n.aboutIndependenceBody1, style: _bodyStyle),
                const SizedBox(height: 12),
                Text(l10n.aboutIndependenceBody2, style: _bodyStyle),
              ],
            ),
            _AboutSection(
              title: l10n.aboutSponsorshipSectionTitle,
              children: [
                Text(l10n.aboutSponsorshipBody1, style: _bodyStyle),
                const SizedBox(height: 12),
                Text(
                  l10n.aboutSponsorshipBodyBold,
                  style: _bodyStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(l10n.aboutSponsorshipBody2, style: _bodyStyle),
              ],
            ),
            _AboutSection(
              title: l10n.aboutNeutralitySectionTitle,
              children: [Text(l10n.aboutNeutralityBody, style: _bodyStyle)],
            ),
            _AboutSection(
              title: l10n.aboutContactSectionTitle,
              children: [
                SelectableText(l10n.aboutContactBody, style: _bodyStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(color: AppColors.ink, fontSize: 15, height: 1.5);

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
