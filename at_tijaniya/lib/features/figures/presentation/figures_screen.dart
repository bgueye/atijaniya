import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'featured_figure_admin_screen.dart';
import 'figure_detail_screen.dart';
import 'figure_form_screen.dart';
import 'figures_providers.dart';
import 'figures_review_screen.dart';
import '../../profil/presentation/profile_providers.dart';

/// Liste des figures — fondateurs et familles religieuses. Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : contrairement au module Wirds, ce contenu provient de la table
/// Supabase `figures` (voir `figure_models.dart`) — la RLS ne renvoie que
/// les lignes `content_status = 'valide'`, filtrées côté serveur. Si aucune
/// figure validée n'existe encore, l'écran affiche un état vide honnête
/// plutôt qu'un contenu inventé.
///
/// Bouton "Contenu à valider" affiché uniquement si `isAdminProvider` vaut
/// `true` — seul chemin de l'app vers `FiguresReviewScreen` (relecture des
/// brouillons avant publication). "Mouqaddam vérifié" n'accorde aucun droit
/// ici, voir la note dans `figures_review_screen.dart`.
class FiguresScreen extends ConsumerWidget {
  const FiguresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final figuresAsync = ref.watch(figuresProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Column(
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FiguresReviewScreen()),
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(l10n.figuresReviewButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FigureFormScreen()),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.figuresCreateButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeaturedFigureAdminScreen()),
                  ),
                  icon: const Icon(Icons.push_pin_outlined, size: 18),
                  label: Text(l10n.featuredFigureAdminButton),
                ),
              ],
            ),
          ),
        Expanded(
          child: figuresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                    const SizedBox(height: 12),
                    Text(l10n.figuresLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(figuresProvider),
                      child: Text(l10n.figuresRetry),
                    ),
                  ],
                ),
              ),
            ),
            data: (figures) {
              final founders = figures.where((f) => f.category == FigureCategory.founder).toList();
              final families = figures.where((f) => f.category == FigureCategory.religiousFamily).toList();

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
            },
          ),
        ),
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

/// Carte figure — portrait + nom FR + nom AR uniquement (le résumé reste sur
/// `FigureDetailScreen`). Chaque nom tient sur sa propre ligne avec ellipsis :
/// contrairement à l'ancien `ListTile` (titre + sous-titre + nom arabe en
/// `trailing` sans largeur contrainte), un nom long ne peut plus déborder ni
/// écraser le reste de la carte. Nom FR en Cormorant Garamond — police dédiée
/// "noms de figures" du design system (design/design_tokens.yaml), jamais
/// utilisée jusqu'ici sur cet écran.
class _FigureTile extends StatelessWidget {
  const _FigureTile({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.emeraldSoft,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  // alignment: topCenter — voir figure_detail_screen.dart, même raison.
                  image: figure.portraitUrl != null
                      ? DecorationImage(
                          image: NetworkImage(figure.portraitUrl!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : null,
                ),
                child: figure.portraitUrl == null
                    ? const Icon(Icons.person_outline, color: AppColors.emerald)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  // stretch (pas start) : sans ça chaque Text se dimensionne à
                  // sa propre largeur (shrink-wrap) et `textAlign: right` sur
                  // le nom arabe ci-dessous n'a alors aucun effet visible —
                  // il n'y a jamais de largeur excédentaire à droite pour
                  // aligner le texte dedans.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      figure.nameFrench,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      figure.nameArabic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.sacredText(fontSize: 16, color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: AppColors.bronze.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
