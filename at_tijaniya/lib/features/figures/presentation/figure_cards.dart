// Cartes de l'onglet Figures refait le 2026-11-02 (maquette
// `docs/maquettes/ecran-figures.html`) : image d'une figure (portrait, ou son
// nom arabe en Amiri à défaut — plus d'icône de personne générique), carte de
// grille en 4:5, carte-collection d'un foyer (mosaïque de ses figures).
//
// Contenu (CLAUDE.md) : noms et portraits viennent de la table `figures`, que
// la RLS ne renvoie qu'une fois validés ; rien n'est écrit ici.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../lineage/domain/lineage_models.dart' show Foyer;
import '../domain/figure_models.dart';
import 'figure_detail_screen.dart';

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

/// Nom d'un foyer dans l'onglet Figures : « Autre » y devient « Autres
/// foyers » (décision validée du 2026-11-02) ; ailleurs (lignée), « Autre »
/// reste juste.
String figuresFoyerLabel(Foyer foyer, AppLocalizations l10n) => switch (foyer) {
      Foyer.tivaouane => l10n.lineageFoyerTivaouane,
      Foyer.kaolack => l10n.lineageFoyerKaolack,
      Foyer.medinaBaye => l10n.lineageFoyerMedinaBaye,
      Foyer.omarienne => l10n.lineageFoyerOmarienne,
      Foyer.ainMadhi => l10n.lineageFoyerAinMadhi,
      Foyer.fes => l10n.lineageFoyerFes,
      Foyer.autre => l10n.figuresFoyerOthers,
    };

/// Nom de la figure dans la langue de l'interface (nom arabe en arabe).
String figureDisplayName(BuildContext context, Figure figure) =>
    _isArabic(context) ? figure.nameArabic : figure.nameFrench;

void openFigure(BuildContext context, Figure figure) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)));

/// Image d'une figure, qui remplit son cadre : son portrait (recadré vers le
/// haut, où est le visage), ou, sans portrait ou si l'image ne charge pas, son
/// nom arabe en Amiri sur un aplat doux — comme la carte typographique de la
/// figure de la semaine.
class FigureImage extends StatelessWidget {
  const FigureImage({super.key, required this.figure, this.arabicSize = 22});

  final Figure figure;
  final double arabicSize;

  @override
  Widget build(BuildContext context) {
    final url = figure.portraitUrl;
    final fallback = _ArabicNameImage(figure: figure, fontSize: arabicSize);
    if (url == null || url.isEmpty) return fallback;
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        cacheWidth: constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
            : null,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _ArabicNameImage extends StatelessWidget {
  const _ArabicNameImage({required this.figure, required this.fontSize});

  final Figure figure;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Deux tons doux en alternance, stables pour une même figure (somme des
    // codes de l'identifiant : `hashCode` penchait presque tout d'un côté).
    final warm = figure.id.codeUnits.fold<int>(0, (sum, c) => sum + c).isEven;
    return Container(
      color: warm ? AppColors.goldSoft : AppColors.emeraldSoft,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      // Décor : le nom est déjà dit par la légende de la carte.
      child: ExcludeSemantics(
        child: Text(
          figure.nameArabic,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sacredText(fontSize: fontSize, color: warm ? AppColors.ink : AppColors.emerald)
              .copyWith(height: 1.4),
        ),
      ),
    );
  }
}

/// Carte de la grille : image en 4:5, nom, et une ligne discrète (foyer).
class FigureGridCard extends StatelessWidget {
  const FigureGridCard({super.key, required this.figure, this.caption});

  final Figure figure;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final arabic = _isArabic(context);
    final caption = this.caption;
    return Semantics(
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openFigure(context, figure),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 4 / 5, child: FigureImage(figure: figure)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(
                      figureDisplayName(context, figure),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: arabic
                          ? AppTheme.sacredText(fontSize: 16, color: AppColors.ink).copyWith(height: 1.35)
                          // Noms de figures en Cormorant (kit, typographie).
                          : AppTheme.titleText(fontSize: 17, color: AppColors.ink, height: 1.15),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      ContentText(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille de portraits, deux colonnes (trois sur les grands écrans).
class FigureGrid extends StatelessWidget {
  const FigureGrid({super.key, required this.figures, required this.captionFor});

  final List<Figure> figures;
  final String? Function(Figure figure) captionFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 600 ? 3 : 2;
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final figure in figures)
            SizedBox(width: width, child: FigureGridCard(figure: figure, caption: captionFor(figure))),
        ],
      );
    });
  }
}

/// Carte-collection d'un foyer : une mosaïque de quatre de ses figures
/// (portraits d'abord), son nom et son nombre de figures. Ouvre la page du
/// foyer.
class FoyerCollectionCard extends StatelessWidget {
  const FoyerCollectionCard({
    super.key,
    required this.label,
    required this.figures,
    required this.onTap,
  });

  final String label;
  final List<Figure> figures;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final withPortrait = [
      for (final f in figures)
        if (f.portraitUrl != null && f.portraitUrl!.isNotEmpty) f
    ];
    final tiles = [...withPortrait, ...figures.where((f) => !withPortrait.contains(f))].take(4).toList();
    return SizedBox(
      width: 156,
      child: Semantics(
        button: true,
        label: '$label, ${l10n.figuresCount(figures.length)}',
        excludeSemantics: true,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final f in tiles) FigureImage(figure: f, arabicSize: 13),
                      for (var i = tiles.length; i < 4; i++) const ColoredBox(color: AppColors.parchment),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink)),
                      Text(l10n.figuresCount(figures.length),
                          style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
                    ],
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
