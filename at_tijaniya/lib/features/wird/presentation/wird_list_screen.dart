import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_screen.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import 'free_wird_screen.dart';
import 'wird_detail_screen.dart';
import 'wird_repair_providers.dart';
import 'wird_repair_screen.dart';
import 'wird_recitations_management_screen.dart';
import 'wird_recitations_review_screen.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/content_text.dart';

/// Liste des Wirds — Lazim, Wazifa, Hadratou-l-Jouma, puis le Wird libre.
/// Priorité P0 pour les trois premiers ; le Wird libre (compteur paramétré
/// par le disciple, `free_wird_screen.dart`) est un ajout complémentaire,
/// distinct du corpus validé.
///
/// Contenu des trois premiers issu de `data/wirds_content.dart` (corpus
/// validé) — voir la règle impérative en tête de ce fichier et de
/// `CLAUDE.md`. Le Wird libre n'a pas de contenu fixe : voir
/// `free_wird_session.dart`.
class WirdListScreen extends ConsumerWidget {
  const WirdListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = ref.watch(isAdminProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isAdmin) ...[
          _RecitationsReviewCard(l10n: l10n),
          const SizedBox(height: 12),
          _RecitationsManageCard(l10n: l10n),
          const SizedBox(height: 12),
        ],
        for (final wird in validatedWirds) ...[
          _WirdCard(wird: wird),
          const SizedBox(height: 12),
        ],
        _FreeWirdCard(l10n: l10n),
        // Les pages pour comprendre et rattraper sa pratique, regroupées sous
        // un intertitre : parmi les cartes de wird, elles ne se distinguaient
        // pas (audit de présentation du 2026-10-18). « Rattraper son wird »
        // en tête : c'est là que le disciple qui vient de manquer le sien la
        // cherchera.
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
          child: Text(
            l10n.wirdListUnderstandHeading,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ),
        const _WirdRepairCard(),
        _TariqaConditionsCard(l10n: l10n),
        // À côté des Conditions de la Tariqa : la page des Bienfaits rattache
        // justement chaque bienfait à sa condition.
        const _TariqaBenefitsCard(),
      ],
    );
  }
}

/// Accès à `WirdRecitationsReviewScreen` (§7) — visible uniquement pour un
/// compte `is_admin`, même principe que le bouton "Contenu à valider" de
/// `FiguresScreen`. "Mouqaddam vérifié" n'accorde aucun droit ici.
class _RecitationsReviewCard extends StatelessWidget {
  const _RecitationsReviewCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.fact_check_outlined, color: AppColors.emerald),
        title: Text(l10n.wirdRecitationsReviewButton, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: DirectionalChevron(color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WirdRecitationsReviewScreen()),
        ),
      ),
    );
  }
}

/// Accès à `WirdRecitationsManagementScreen` — ajouter/supprimer un audio de
/// pilier, par wird puis par pilier. Carte séparée de
/// `_RecitationsReviewCard` plutôt qu'un simple lien caché dans l'app bar de
/// cet écran (essayé en premier, jugé peu découvrable à l'usage) : les deux
/// tâches (trier les brouillons à plat / gérer un pilier précis) restent
/// distinctes, mais doivent être aussi visibles l'une que l'autre pour un
/// admin.
class _RecitationsManageCard extends StatelessWidget {
  const _RecitationsManageCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.library_music_outlined, color: AppColors.emerald),
        title: Text(l10n.wirdRecitationsManageTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.wirdRecitationsManageCardSubtitle, style: TextStyle(color: AppColors.bronze)),
        trailing: DirectionalChevron(color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WirdRecitationsManagementScreen()),
        ),
      ),
    );
  }
}

/// Icône par wird, choisie sur son trait distinctif plutôt qu'une icône
/// générique répétée trois fois — voir les `conditionsNote` du corpus validé
/// (`wirds_content.dart`) : Lazim se distingue par son rythme matin/soir,
/// Wazifa par sa forme de récitation (idéalement en assemblée), Hadratou-
/// l-Jouma par son caractère collectif et hebdomadaire (vendredi).
IconData _iconForWird(String id) {
  return switch (id) {
    'lazim' => Icons.wb_twilight,
    'wazifa' => Icons.auto_stories,
    'hadratou_jouma' => Icons.groups,
    _ => Icons.self_improvement,
  };
}

class _WirdCard extends StatelessWidget {
  const _WirdCard({required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Seul écran du module Wird où le nom arabe validé (`nameArabic`) sert
    // de titre en locale `ar`, plutôt que la translittération `nameFrench`
    // utilisée partout ailleurs (app bar du guide, Tasbih, Historique,
    // Rappels) — c'est le premier écran vu par le disciple sur ce module,
    // avant même d'ouvrir un wird.
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_iconForWird(wird.id), color: AppColors.emerald),
        title: ContentText(
          isArabic ? wird.nameArabic : wird.nameFrench,
          style: isArabic
              ? AppTheme.sacredText(fontSize: 18, color: AppColors.ink)
              : const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          wird.frequency == WirdFrequency.daily ? l10n.wirdFrequencyDaily : l10n.homeWirdSubtitleWeeklyInfo,
          style: TextStyle(color: AppColors.bronze),
        ),
        trailing: DirectionalChevron(color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)),
        ),
      ),
    );
  }
}

/// Accès à « Rattraper son wird ». Affichée seulement s'il y a du contenu à
/// montrer : pour un disciple, tant que le moqaddam référent n'a rien validé,
/// la RLS ne renvoie rien et la carte n'existe pas — pas de page vide ni de
/// « bientôt disponible ». L'admin la voit dès le brouillon, avec une mention
/// qui le lui rappelle. Pendant le chargement ou en cas d'erreur réseau, elle
/// reste masquée plutôt que d'occuper la place d'une carte inutilisable.
class _WirdRepairCard extends ConsumerWidget {
  const _WirdRepairCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final content = ref.watch(wirdRepairContentProvider).valueOrNull;
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(Icons.restore, color: AppColors.emerald),
          title: Text(l10n.wirdRepairCardTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            content.hasDrafts
                ? '${l10n.wirdRepairCardSubtitle} (${l10n.wirdRepairDraftTag})'
                : l10n.wirdRepairCardSubtitle,
            style: TextStyle(color: AppColors.bronze),
          ),
          trailing: DirectionalChevron(color: AppColors.bronze),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WirdRepairScreen()),
          ),
        ),
      ),
    );
  }
}

class _FreeWirdCard extends StatelessWidget {
  const _FreeWirdCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.tune, color: AppColors.emerald),
        title: Text(l10n.wirdFreeTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.wirdFreeSubtitle, style: TextStyle(color: AppColors.bronze)),
        trailing: DirectionalChevron(color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FreeWirdScreen()),
        ),
      ),
    );
  }
}

/// Accès à « Bienfaits de la Tijaniyya ». Masquée tant qu'il n'y a rien à
/// montrer : pour un disciple, tant que le moqaddam référent n'a pas validé
/// le contenu ; l'admin, qui lit le brouillon, la voit avec la mention
/// « Brouillon ».
class _TariqaBenefitsCard extends ConsumerWidget {
  const _TariqaBenefitsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rows = ref.watch(tariqaBenefitsRowsProvider).valueOrNull;
    if (rows == null || rows.sections.isEmpty) return const SizedBox.shrink();
    final hasDrafts = [...rows.sections, ...rows.cards].any((row) => row['content_status'] != 'valide');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(Icons.spa_outlined, color: AppColors.emerald),
          title: Text(l10n.tariqaBenefitsCardTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            hasDrafts
                ? '${l10n.tariqaBenefitsCardSubtitle} (${l10n.wirdRepairDraftTag})'
                : l10n.tariqaBenefitsCardSubtitle,
            style: TextStyle(color: AppColors.bronze),
          ),
          trailing: DirectionalChevron(color: AppColors.bronze),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TariqaBenefitsScreen()),
          ),
        ),
      ),
    );
  }
}

class _TariqaConditionsCard extends StatelessWidget {
  const _TariqaConditionsCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.rule_outlined, color: AppColors.emerald),
        title: Text(l10n.tariqaConditionsCardTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.tariqaConditionsCardSubtitle, style: TextStyle(color: AppColors.bronze)),
        trailing: DirectionalChevron(color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TariqaConditionsScreen()),
        ),
      ),
    );
  }
}
