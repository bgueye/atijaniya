import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import 'free_wird_screen.dart';
import 'wird_detail_screen.dart';

/// Liste des Wirds — Lazim, Wazifa, Hadratou-l-Jouma, puis le Wird libre.
/// Priorité P0 pour les trois premiers ; le Wird libre (compteur paramétré
/// par le disciple, `free_wird_screen.dart`) est un ajout complémentaire,
/// distinct du corpus validé.
///
/// Contenu des trois premiers issu de `data/wirds_content.dart` (corpus
/// validé) — voir la règle impérative en tête de ce fichier et de
/// `CLAUDE.md`. Le Wird libre n'a pas de contenu fixe : voir
/// `free_wird_session.dart`.
class WirdListScreen extends StatelessWidget {
  const WirdListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final wird in validatedWirds) ...[
          _WirdCard(wird: wird),
          const SizedBox(height: 12),
        ],
        _FreeWirdCard(l10n: l10n),
      ],
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
