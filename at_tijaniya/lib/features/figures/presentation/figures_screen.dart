// Onglet Figures — refait le 2026-11-02 d'après la maquette de référence
// `docs/maquettes/ecran-figures.html`, décisions validées dans
// `docs/maquettes/README.md` :
// - le fondateur en tête, dans sa propre carte (sans année de naissance : les
//   années ne s'affichent pas hors de la fiche tant qu'elles ne sont pas
//   corrigées en base) ;
// - les foyers en cartes-collections, dans l'ordre historique, le foyer du
//   disciple en premier s'il est renseigné, « Autres foyers » en dernier ;
// - une grille de portraits ; sans portrait, le nom arabe sert d'image ;
// - la page d'un foyer (`foyer_screen.dart`), avec sa silsila ;
// - l'administration en une ligne, en bas.
//
// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01 § 8) : les figures
// viennent de la table `figures`, que la RLS ne renvoie qu'une fois validées.
// Si aucune n'existe, l'écran le dit plutôt que d'inventer un contenu.
//
// Recherche par nom (audit Figures du 2026-10-25, P2-1) inchangée : français
// et arabe, translittérations tolérées (`figure_search.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/list_group.dart';
import '../../../core/widgets/list_search_field.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../lineage/presentation/lineage_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/figure_foyers.dart';
import '../domain/figure_models.dart';
import '../domain/figure_search.dart';
import 'featured_figure_admin_screen.dart';
import 'figure_cards.dart';
import 'figure_form_screen.dart';
import 'figures_providers.dart';
import 'figures_review_screen.dart';
import 'foyer_screen.dart';

/// Nombre de figures de l'aperçu « Toutes les figures » sur la page
/// principale ; le reste s'affiche à la demande (la grille entière défilerait
/// longtemps : l'entrée naturelle, ce sont les foyers).
const _previewCount = 6;

class FiguresScreen extends ConsumerStatefulWidget {
  const FiguresScreen({super.key});

  @override
  ConsumerState<FiguresScreen> createState() => _FiguresScreenState();
}

class _FiguresScreenState extends ConsumerState<FiguresScreen> {
  final _searchController = TextEditingController();
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final figuresAsync = ref.watch(figuresProvider);
    final allFigures = figuresAsync.valueOrNull;

    if (allFigures == null) {
      if (figuresAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Notice.fromError(
            figuresAsync.error!,
            message: l10n.figuresLoadError,
            onRetry: () => ref.invalidate(figuresProvider),
          ),
        );
      }
      return Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (allFigures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Notice.info('${l10n.figuresEmptyTitle}\n${l10n.figuresEmptyBody}'),
      );
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // Liens de silsila : seulement pour le nombre de disciples du fondateur ;
    // sans eux, la carte du fondateur s'affiche sans ce chiffre.
    final links = ref.watch(silsilaLinksProvider).valueOrNull;
    // Foyer du disciple, lu dans sa lignée : ne sert qu'à l'ordre des foyers
    // sur son téléphone, rien n'est montré à personne.
    final userId = ref.watch(currentUserIdProvider);
    final userFoyer = userId == null ? null : ref.watch(myLineageProvider).valueOrNull?.foyer;
    final query = _searchController.text.trim();
    String? captionFor(Figure f) => f.foyer == null ? null : figuresFoyerLabel(f.foyer!, l10n);
    List<Figure> sorted(List<Figure> list) => isArabic ? sortFiguresByArabicName(list) : list;

    final founders = allFigures.where((f) => f.category == FigureCategory.founder).toList();
    final foyers = orderedFoyers(allFigures, userFoyer: userFoyer);

    final children = <Widget>[
      ListSearchField(
        controller: _searchController,
        onChanged: () => setState(() {}),
        hint: l10n.figuresSearchHint,
        clearTooltip: l10n.figuresSearchClear,
      ),
    ];

    if (query.isNotEmpty) {
      // Recherche : les résultats en grille, sans le reste de la page.
      final results = sorted(searchFigures(allFigures, query));
      children.addAll([
        SectionTitle(l10n.figuresSearchResults, padding: const EdgeInsetsDirectional.fromSTEB(2, 20, 0, 8)),
        if (results.isEmpty)
          Notice.info(l10n.figuresSearchNoResult(query))
        else
          FigureGrid(figures: results, captionFor: captionFor),
      ]);
    } else {
      final everyone = sorted(allFigures);
      final shown = _showAll ? everyone : everyone.take(_previewCount).toList();
      children.addAll([
        for (final founder in founders) ...[
          const SizedBox(height: 14),
          _FounderCard(
            figure: founder,
            disciples: links == null ? null : discipleCount(founder.id, links),
            foyer: founder.foyer == null ? null : figuresFoyerLabel(founder.foyer!, l10n),
          ),
        ],
        if (foyers.isNotEmpty) ...[
          SectionTitle(
            l10n.figuresFoyersTitle,
            padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8),
          ),
          SizedBox(
            height: 156 + 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: foyers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final foyer = foyers[i];
                return FoyerCollectionCard(
                  label: figuresFoyerLabel(foyer, l10n),
                  figures: allFigures.where((f) => f.foyer == foyer).toList(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FoyerScreen(foyer: foyer))),
                );
              },
            ),
          ),
        ],
        SectionTitle(
          l10n.figuresAllTitle,
          padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8),
        ),
        FigureGrid(figures: shown, captionFor: captionFor),
        if (everyone.length > _previewCount)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? l10n.figuresShowLess : l10n.figuresShowAll(everyone.length)),
            ),
          ),
      ]);
    }

    if (ref.watch(isAdminProvider)) {
      children.addAll([const SizedBox(height: 20), const _AdminLine()]);
    }

    // Tirer pour actualiser (audit Figures du 2026-10-25, P3-3) : la liste
    // reste en cache toute la session ; elle reste affichée pendant le
    // rechargement.
    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        ref.invalidate(silsilaLinksProvider);
        // La liste en place reste affichée pendant le rechargement.
        final _ = await ref.refresh(figuresProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: children,
      ),
    );
  }
}

/// Carte du fondateur de la Tariqa : portrait, nom arabe en Amiri, nom
/// français en Cormorant, foyer et nombre de disciples rattachés dans l'app.
/// Pas d'année de naissance (décision validée du 2026-11-02).
class _FounderCard extends StatelessWidget {
  const _FounderCard({required this.figure, required this.disciples, required this.foyer});

  final Figure figure;
  final int? disciples;
  final String? foyer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disciples = this.disciples;
    return Semantics(
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openFigure(context, figure),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 112, child: FigureImage(figure: figure, arabicSize: 18)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(l10n.figuresFounderEyebrow),
                        const SizedBox(height: 4),
                        Text(
                          figure.nameArabic,
                          textDirection: TextDirection.rtl,
                          style: AppTheme.sacredText(fontSize: 22, color: AppColors.emerald).copyWith(height: 1.4),
                        ),
                        ContentText(
                          figure.nameFrench,
                          style: AppTheme.titleText(fontSize: 21, color: AppColors.ink, height: 1.15),
                        ),
                        if (foyer != null) ...[
                          const SizedBox(height: 4),
                          Text(foyer!, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                        ],
                        if (disciples != null && disciples > 0) ...[
                          const SizedBox(height: 8),
                          StatePill(l10n.figuresFounderDisciples(disciples), variant: StatePillVariant.done),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Administration, admin seulement : une ligne en bas (à valider, créer,
/// figure de la semaine), au lieu de trois boutons en haut. Le statut de
/// mouqaddam n'accorde aucun droit ici.
class _AdminLine extends ConsumerWidget {
  const _AdminLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final drafts = ref.watch(draftFiguresProvider).valueOrNull?.length;
    void open(BuildContext sheetContext, Widget screen) {
      Navigator.of(sheetContext).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
        InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: AppColors.offWhite,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ListGroup(items: [
                  ListGroupItem(
                    icon: Icons.fact_check_outlined,
                    tone: ListGroupTone.sacred,
                    title: l10n.figuresReviewButton,
                    trailing: drafts != null && drafts > 0 ? StatePill.count(drafts) : null,
                    showChevron: true,
                    onTap: () => open(sheetContext, const FiguresReviewScreen()),
                  ),
                  ListGroupItem(
                    icon: Icons.add,
                    tone: ListGroupTone.sacred,
                    title: l10n.figuresCreateButton,
                    onTap: () => open(sheetContext, const FigureFormScreen()),
                  ),
                  ListGroupItem(
                    icon: Icons.push_pin_outlined,
                    tone: ListGroupTone.sacred,
                    title: l10n.featuredFigureAdminButton,
                    onTap: () => open(sheetContext, const FeaturedFigureAdminScreen()),
                  ),
                ]),
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.figuresAdminLine, style: TextStyle(fontSize: 13, color: AppColors.secondaryInk)),
                ),
                if (drafts != null && drafts > 0) ...[StatePill.count(drafts), const SizedBox(width: 4)],
                DirectionalChevron(color: AppColors.bronze, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
