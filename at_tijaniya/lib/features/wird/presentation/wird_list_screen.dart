import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import 'free_wird_screen.dart';
import 'wird_detail_screen.dart';
import 'wird_recitations_review_screen.dart';

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
        ],
        for (final wird in validatedWirds) ...[
          _WirdCard(wird: wird),
          const SizedBox(height: 12),
        ],
        _FreeWirdCard(l10n: l10n),
        const SizedBox(height: 12),
        _TariqaConditionsCard(l10n: l10n),
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
        leading: const Icon(Icons.fact_check_outlined, color: AppColors.emerald),
        title: Text(l10n.wirdRecitationsReviewButton, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WirdRecitationsReviewScreen()),
        ),
      ),
    );
  }
}

class _WirdCard extends StatelessWidget {
  const _WirdCard({required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(wird.nameFrench, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          wird.frequency == WirdFrequency.daily ? 'Quotidien' : 'Hebdomadaire — vendredi',
          style: const TextStyle(color: AppColors.bronze),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)),
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
        leading: const Icon(Icons.tune, color: AppColors.emerald),
        title: Text(l10n.wirdFreeTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.wirdFreeSubtitle, style: const TextStyle(color: AppColors.bronze)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FreeWirdScreen()),
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
        leading: const Icon(Icons.rule_outlined, color: AppColors.emerald),
        title: Text(l10n.tariqaConditionsCardTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.tariqaConditionsCardSubtitle, style: const TextStyle(color: AppColors.bronze)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TariqaConditionsScreen()),
        ),
      ),
    );
  }
}
