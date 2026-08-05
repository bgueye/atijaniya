import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/figures_content.dart';
import '../domain/figure_models.dart';
import 'figure_detail_screen.dart';

/// Liste des figures — fondateurs et familles religieuses. Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : le contenu affiché ici provient exclusivement de
/// `lib/features/figures/data/figures_content.dart` (source unique). Cette
/// liste est actuellement vide car aucune biographie n'est encore validée —
/// voir la règle impérative en tête de ce fichier de contenu. L'écran
/// affiche alors un état vide honnête plutôt que du contenu inventé.
class FiguresScreen extends StatelessWidget {
  const FiguresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final founders = validatedFigures.where((f) => f.category == FigureCategory.founder).toList();
    final families = validatedFigures.where((f) => f.category == FigureCategory.religiousFamily).toList();

    if (founders.isEmpty && families.isEmpty) {
      return _EmptyState(title: l10n.figuresEmptyTitle, body: l10n.figuresEmptyBody);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (founders.isNotEmpty) ...[
          _SectionHeader(title: l10n.figuresSectionFounders),
          for (final figure in founders) _FigureTile(figure: figure),
          const SizedBox(height: 16),
        ],
        if (families.isNotEmpty) ...[
          _SectionHeader(title: l10n.figuresSectionFamilies),
          for (final figure in families) _FigureTile(figure: figure),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, color: AppColors.bronze, size: 40),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
      ),
    );
  }
}

class _FigureTile extends StatelessWidget {
  const _FigureTile({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(figure.nameFrench, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: figure.summary != null
            ? Text(figure.summary!, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Text(
          figure.nameArabic,
          textDirection: TextDirection.rtl,
          style: AppTheme.sacredText(fontSize: 18, color: AppColors.emerald),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
        ),
      ),
    );
  }
}
