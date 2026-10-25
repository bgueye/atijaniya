import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../lineage/domain/lineage_models.dart' show Foyer;
import '../../lineage/presentation/foyer_label.dart';
import '../domain/figure_models.dart';
import '../domain/figure_search.dart';
import 'featured_figure_admin_screen.dart';
import 'figure_detail_screen.dart';
import 'figure_form_screen.dart';
import 'figure_portrait.dart';
import 'figures_providers.dart';
import 'figures_review_screen.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/content_text.dart';

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
///
/// Filtre par foyer en tête de liste depuis le 2026-10-18 : avant, le foyer
/// d'une figure était saisi par l'admin mais invisible pour le disciple, et
/// 46 fiches sur 70 étaient en « Autre ». Seuls les foyers présents dans la
/// liste sont proposés.
///
/// Recherche par nom au-dessus du filtre depuis l'audit Figures du
/// 2026-10-25 (P2-1) : il fallait douze défilements pour atteindre certaines
/// fiches. Elle se combine au foyer choisi ; la logique (normalisation,
/// variantes de translittération) est dans `figure_search.dart`.
class FiguresScreen extends ConsumerStatefulWidget {
  const FiguresScreen({super.key});

  @override
  ConsumerState<FiguresScreen> createState() => _FiguresScreenState();
}

class _FiguresScreenState extends ConsumerState<FiguresScreen> {
  /// Foyer choisi ; `null` : tous.
  Foyer? _foyer;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                    const SizedBox(height: 12),
                    Text(l10n.figuresLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(figuresProvider),
                      child: Text(l10n.figuresRetry),
                    ),
                  ],
                ),
              ),
            ),
            data: (allFigures) {
              if (allFigures.isEmpty) {
                return _EmptyState(title: l10n.figuresEmptyTitle, body: l10n.figuresEmptyBody);
              }
              final foyers = foyersPresentIn(allFigures);
              // Un foyer choisi qui n'existe plus dans la liste (fiche
              // modifiée entre-temps) revient à « Tous » plutôt qu'à une
              // liste vide sans puce sélectionnée.
              final foyer = foyers.contains(_foyer) ? _foyer : null;
              final query = _searchController.text.trim();
              final figures = searchFigures(filterFiguresByFoyer(allFigures, foyer), query);
              final founders = figures.where((f) => f.category == FigureCategory.founder).toList();
              final families = figures.where((f) => f.category == FigureCategory.religiousFamily).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // Inutile de filtrer quand toutes les fiches ont le même
                  // foyer (ou aucun).
                  if (foyers.length > 1) ...[
                    _FoyerFilter(
                      foyers: foyers,
                      selected: foyer,
                      onSelected: (value) => setState(() => _foyer = value),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (figures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      // Une recherche sans résultat le dit, avec la saisie,
                      // plutôt que de laisser croire que le foyer est vide.
                      child: Text(
                        query.isNotEmpty ? l10n.figuresSearchNoResult(query) : l10n.figuresNoneForFoyer,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryInk),
                      ),
                    ),
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

/// Champ de recherche par nom, avec un bouton pour l'effacer dès qu'il
/// contient du texte. [onChanged] reconstruit la liste à chaque frappe : les
/// figures sont en mémoire, aucune requête n'est envoyée.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.figuresSearchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.figuresSearchClear,
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
    );
  }
}

/// Puces de foyer, sur plusieurs lignes au besoin : avec jusqu'à huit choix,
/// une seule ligne (comme le filtre des zawiyas, qui n'en a que quatre)
/// obligerait à réduire le texte ou à faire défiler, et un foyer caché hors
/// de l'écran serait manqué.
class _FoyerFilter extends StatelessWidget {
  const _FoyerFilter({required this.foyers, required this.selected, required this.onSelected});

  final List<Foyer> foyers;
  final Foyer? selected;
  final ValueChanged<Foyer?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(Foyer?, String)>[
      (null, l10n.figuresFoyerFilterAll),
      for (final foyer in foyers) (foyer, foyerLabel(foyer, l10n)),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (foyer, label) in options)
          ChoiceChip(
            label: Text(label),
            // Puce non sélectionnée : le thème y met `onSurfaceVariant`, le
            // bronze (3,72:1 sur parchemin, sous le seuil AA) ; `secondaryInk`
            // le remplace ici (audit Figures du 2026-10-25, P2-4). La puce
            // choisie garde la couleur du thème.
            labelStyle: foyer == selected ? null : TextStyle(color: AppColors.secondaryInk),
            selected: foyer == selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onSelected(foyer),
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
            Icon(Icons.auto_stories_outlined, color: AppColors.bronze, size: 40),
            const SizedBox(height: 16),
            ContentText(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ContentText(body, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
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
      // `header: true` : annoncé comme titre par les lecteurs d'écran (audit
      // Figures du 2026-10-25, P2-2).
      child: Semantics(
        header: true,
        child: ContentText(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
        ),
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

  static final _placeholder = Icon(Icons.person_outline, color: AppColors.emerald);

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
                ),
                // Bordure en avant-plan : elle reste visible par-dessus la
                // photo, comme du temps de l'ancienne `DecorationImage`.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                ),
                // Portrait introuvable ou absent : même icône (voir
                // `FigurePortrait`).
                child: figure.portraitUrl == null
                    ? _placeholder
                    : FigurePortrait(
                        url: figure.portraitUrl!,
                        size: 56,
                        borderRadius: 12,
                        errorPlaceholder: _placeholder,
                      ),
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
                    ContentText(
                      figure.nameFrench,
                      // 2 lignes plutôt qu'1 : un nom tronqué à 1 ligne
                      // masquait parfois l'épithète qui différencie deux
                      // figures proches (ex. deux "Cheikh Ahmed Tidiane Sy")
                      // — constaté à l'audit design pré-publication Play
                      // Store, alors que des cartes similaires (Khadara)
                      // passaient déjà à la ligne sans souci.
                      maxLines: 2,
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
              DirectionalChevron(size: 16, color: AppColors.bronze.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
