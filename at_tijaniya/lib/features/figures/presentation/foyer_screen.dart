// Page d'un foyer (onglet Figures refait le 2026-11-02, maquette
// `docs/maquettes/ecran-figures.html`) : ses chiffres, puis deux vues — la
// grille de ses figures (par défaut, décision validée : plusieurs foyers ont
// très peu de liens de silsila) et l'arbre de sa silsila historique, tiré des
// liens validés en base (`historical_silsila_links`).
//
// La silsila n'est pas une généalogie : les liens sont historiques (maître →
// disciple) et incomplets. La légende le dit, sous l'arbre (décision validée).
// Pas de chiffre « rendez-vous » : l'app ne sait pas à quel foyer appartient
// une zawiya ou un évènement (décision validée).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../../lineage/domain/lineage_models.dart' show Foyer;
import '../domain/figure_foyers.dart';
import '../domain/figure_models.dart';
import '../domain/figure_search.dart';
import 'figure_cards.dart';
import 'figures_providers.dart';

enum FoyerView { grid, silsila }

class FoyerScreen extends ConsumerStatefulWidget {
  const FoyerScreen({super.key, required this.foyer, this.initialView = FoyerView.grid});

  final Foyer foyer;
  final FoyerView initialView;

  @override
  ConsumerState<FoyerScreen> createState() => _FoyerScreenState();
}

class _FoyerScreenState extends ConsumerState<FoyerScreen> {
  late FoyerView _view = widget.initialView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = figuresFoyerLabel(widget.foyer, l10n);
    final allAsync = ref.watch(figuresProvider);
    final all = allAsync.valueOrNull ?? const <Figure>[];
    final linksAsync = ref.watch(silsilaLinksProvider);
    final links = linksAsync.valueOrNull;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final inFoyer = all.where((f) => f.foyer == widget.foyer).toList();
    final figures = isArabic ? sortFiguresByArabicName(inFoyer) : inFoyer;
    final portraits = figures.where((f) => f.portraitUrl != null && f.portraitUrl!.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Eyebrow(l10n.lineageFoyerLabel),
            Semantics(
              header: true,
              // Titre en Cormorant en français, en Amiri (titre arabe) en arabe :
              // Cormorant n'a pas de lettres arabes.
              child: Text(
                label,
                style: isArabic
                    ? AppTheme.sacredText(fontSize: 26, color: AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w700, height: 1.4)
                    : AppTheme.titleText(fontSize: 28, color: AppColors.ink, height: 1.2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatTile(value: '${figures.length}', label: l10n.figuresStatFigures)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(value: '$portraits', label: l10n.figuresStatPortraits)),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: links == null ? '–' : '${foyerSilsilaLinkCount(widget.foyer, all, links)}',
                    label: l10n.figuresStatLinks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedSwitch<FoyerView>(
              items: [
                SegmentedSwitchItem(value: FoyerView.grid, label: l10n.figuresViewGrid),
                SegmentedSwitchItem(value: FoyerView.silsila, label: l10n.figuresViewSilsila),
              ],
              selected: _view,
              onChanged: (view) => setState(() => _view = view),
            ),
            const SizedBox(height: 14),
            // Liste des figures pas encore lue, ou illisible : le dire, au
            // lieu de « 0 figures » et d'une grille vide (audit du
            // 2026-11-03).
            if (!allAsync.hasValue && allAsync.hasError)
              Notice.fromError(
                allAsync.error!,
                message: l10n.figuresLoadError,
                onRetry: () => ref.invalidate(figuresProvider),
              )
            else if (!allAsync.hasValue)
              Center(child: CircularProgressIndicator(color: AppColors.emerald))
            else if (_view == FoyerView.grid)
              FigureGrid(figures: figures, captionFor: (_) => null)
            else if (links == null)
              linksAsync.hasError
                  ? Notice.fromError(
                      linksAsync.error!,
                      message: l10n.figuresLoadError,
                      onRetry: () => ref.invalidate(silsilaLinksProvider),
                    )
                  : Center(child: CircularProgressIndicator(color: AppColors.emerald))
            else
              _SilsilaTree(nodes: buildFoyerSilsilaTree(widget.foyer, all, links)),
          ],
        ),
      ),
    );
  }
}

/// Arbre de silsila du foyer : un nœud par figure, en retrait selon sa
/// profondeur, relié à son maître par un filet. Le maître venu d'un autre
/// foyer est encadré en pointillés. En arabe, le retrait part de la droite
/// (directionnel). Toucher un nœud ouvre la fiche.
class _SilsilaTree extends StatelessWidget {
  const _SilsilaTree({required this.nodes});

  final List<FoyerSilsilaNode> nodes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (nodes.isEmpty) return Notice.info(l10n.figuresSilsilaEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in nodes) _TreeNode(node: node),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 15, color: AppColors.bronze),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.figuresSilsilaLegend,
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.secondaryInk)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({required this.node});

  final FoyerSilsilaNode node;

  static const _step = 22.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final figure = node.figure;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final String? note;
    if (node.external) {
      note = figure.foyer == null ? null : l10n.figuresSilsilaExternal(figuresFoyerLabel(figure.foyer!, l10n));
    } else if (node.showMaster && node.master != null) {
      note = l10n.figuresSilsilaDiscipleOf(figureDisplayName(context, node.master!));
    } else {
      note = null;
    }

    // Sans portrait, un rond uni : le nom arabe en 9 px dans 34 dp n'en
    // montrait que des fragments (audit du 2026-11-03). Le nom est écrit à
    // côté.
    final hasPortrait = figure.portraitUrl != null && figure.portraitUrl!.isNotEmpty;
    final avatar = ClipOval(
      child: SizedBox(
        width: 34,
        height: 34,
        child: hasPortrait
            ? FigureImage(figure: figure, arabicSize: 9)
            : ColoredBox(
                color: AppColors.emeraldSoft,
                child: Icon(Icons.person_outline, size: 18, color: AppColors.emerald),
              ),
      ),
    );
    // Lu d'un seul tenant, avec le maître : le retrait de l'arbre ne
    // s'entend pas au lecteur d'écran (audit du 2026-11-03).
    final master = node.master;
    final spoken = [
      figureDisplayName(context, figure),
      if (note != null) note else if (master != null) l10n.figuresSilsilaDiscipleOf(figureDisplayName(context, master)),
    ].join(', ');
    final content = InkWell(
      onTap: () => openFigure(context, figure),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              node.external
                  ? Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.6)),
                      ),
                      child: Icon(Icons.north_east, size: 16, color: AppColors.bronze),
                    )
                  : avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(
                      figureDisplayName(context, figure),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: arabic
                          ? AppTheme.sacredText(fontSize: 15.5, color: AppColors.ink).copyWith(height: 1.35)
                          : const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3),
                    ),
                    if (note != null) ContentText(note, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: () => openFigure(context, figure),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: node.depth * _step, bottom: 4),
        child: Row(
          children: [
            // Filet vers le maître : un trait court, du côté du début de ligne.
            if (node.depth > 0) Container(width: 12, height: 1.5, color: AppColors.bronze.withValues(alpha: 0.45)),
            Expanded(
              child: node.external
                  ? DashedBorder(radius: 12, child: content)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
                      ),
                      child: content,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
