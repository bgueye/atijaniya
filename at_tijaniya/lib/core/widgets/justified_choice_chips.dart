import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Puces de filtre sur une ou deux lignes justifiées : chaque ligne va d'un
/// bord à l'autre, chaque puce s'élargissant en proportion de sa largeur
/// naturelle. Retour à la ligne libre (`Wrap`) quand le nombre de lignes
/// demandé ne suffit pas (texte très agrandi, écran étroit), plutôt que des
/// libellés tronqués ou des puces rapetissées.
///
/// Écrit pour le filtre par foyer de l'onglet Figures (deux lignes, demande du
/// porteur de projet du 2026-10-25), partagé avec le filtre par type de lieu
/// de l'onglet Zawiyas (une ligne ; audit Zawiyas du 2026-10-25, P2-7, où un
/// `FittedBox` et une densité compacte ramenaient la zone tactile à 33 dp).
/// Zone tactile de 48 dp dans tous les cas.
class JustifiedChoiceChips<T> extends StatelessWidget {
  const JustifiedChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.rows = 1,
  }) : assert(rows == 1 || rows == 2, 'Une ou deux lignes seulement.');

  /// Valeur et libellé traduit de chaque puce, dans l'ordre d'affichage.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Nombre de lignes visées : 1 ou 2.
  final int rows;

  /// Écart entre deux puces, en largeur comme entre deux lignes.
  static const _spacing = 6.0;

  /// Marges horizontales de la puce, resserrées pour que huit foyers tiennent
  /// sur deux lignes d'un téléphone (411 dp).
  static const _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 8);
  static const _labelPadding = EdgeInsets.symmetric(horizontal: 4);

  /// Ce que la puce ajoute autour de son texte : marges et bordure (1 dp de
  /// chaque côté). Mesuré en test : 22 dp, quel que soit le libellé.
  static final _chrome = _padding.horizontal + _labelPadding.horizontal + 2;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    // Puce non sélectionnée : `secondaryInk` et non le bronze (3,72:1 sur
    // parchemin, sous le seuil AA ; audit Figures du 2026-10-25, P2-4). Puce
    // choisie : l'encre, sur son fond `goldSoft`. Styles explicites dans les
    // deux cas, pour mesurer le texte exactement comme il sera affiché.
    TextStyle styleFor(bool isSelected) =>
        baseStyle.copyWith(color: isSelected ? AppColors.ink : AppColors.secondaryInk);

    // [labelWidth] : largeur imposée au libellé, centré dedans, pour étirer
    // la puce dessinée. Une largeur donnée à la seule `ChoiceChip` ne l'étire
    // pas : seule sa zone tactile s'élargit, la puce visible reste à sa
    // taille et se centre (constaté sur émulateur).
    Widget chip(T value, String label, {double? labelWidth}) => ChoiceChip(
          label: labelWidth == null
              ? Text(label, maxLines: 1)
              : SizedBox(width: labelWidth, child: Text(label, maxLines: 1, textAlign: TextAlign.center)),
          labelStyle: styleFor(value == selected),
          padding: _padding,
          labelPadding: _labelPadding,
          selected: value == selected,
          showCheckmark: false,
          // Ni `visualDensity: compact` ni `materialTapTargetSize:
          // shrinkWrap` : chacun rognait la zone tactile (34 dp, 40 avec la
          // seule densité compacte). Elle garde ses 48 dp.
          onSelected: (_) => onSelected(value),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Largeur naturelle de chaque puce : son texte, mesuré avec le style
        // et la taille de texte réels (réglage d'accessibilité compris), plus
        // ce que la puce ajoute autour.
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final widths = [
          for (final (value, label) in options)
            () {
              final painter = TextPainter(
                text: TextSpan(text: label, style: styleFor(value == selected)),
                textDirection: direction,
                textScaler: textScaler,
                maxLines: 1,
              )..layout();
              final width = painter.width.ceilToDouble() + _chrome;
              painter.dispose();
              return width;
            }(),
        ];
        final rowStarts = rows == 1
            ? (_rowWidth(widths, 0, widths.length) <= constraints.maxWidth ? [0] : null)
            : switch (splitChipsInTwoRows(widths, constraints.maxWidth, spacing: _spacing)) {
                final split? => [0, split],
                null => null,
              };

        // Repli : ne tient pas sur le nombre de lignes demandé.
        if (rowStarts == null) {
          return Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            children: [for (final (value, label) in options) chip(value, label)],
          );
        }

        Widget row(int start, int end) => Row(
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i != start) const SizedBox(width: _spacing),
                  Expanded(
                    flex: (widths[i] * 10).round(),
                    // Arrondi à l'inférieur : un libellé d'une fraction de
                    // pixel trop large ferait déborder la ligne.
                    child: LayoutBuilder(
                      builder: (context, cell) => chip(
                        options[i].$1,
                        options[i].$2,
                        labelWidth: (cell.maxWidth - _chrome).floorToDouble(),
                      ),
                    ),
                  ),
                ],
              ],
            );
        final ends = [...rowStarts.skip(1), options.length];
        return Column(
          children: [
            for (var r = 0; r < rowStarts.length; r++) ...[
              if (r != 0) const SizedBox(height: _spacing),
              row(rowStarts[r], ends[r]),
            ],
          ],
        );
      },
    );
  }

  static double _rowWidth(List<double> widths, int start, int end) {
    var total = _spacing * (end - start - 1);
    for (var i = start; i < end; i++) {
      total += widths[i];
    }
    return total;
  }
}

/// Coupure de puces en deux lignes. Renvoie l'index de la première puce de
/// la seconde ligne, ou `null` si les puces ne tiennent pas en deux lignes de
/// [available].
///
/// [widths] : largeur naturelle de chaque puce, dans l'ordre d'affichage, qui
/// est conservé. [spacing] : écart entre deux puces d'une même ligne. Parmi les
/// coupures possibles, celle dont la ligne la plus longue est la plus courte :
/// deux lignes de longueur voisine, que la justification étire alors
/// d'autant, sans qu'une puce paraisse démesurée à côté des autres.
int? splitChipsInTwoRows(List<double> widths, double available, {double spacing = 0}) {
  double rowWidth(int start, int end) {
    var total = spacing * (end - start - 1);
    for (var i = start; i < end; i++) {
      total += widths[i];
    }
    return total;
  }

  int? best;
  var bestLongest = double.infinity;
  for (var split = 1; split < widths.length; split++) {
    final first = rowWidth(0, split);
    final second = rowWidth(split, widths.length);
    if (first > available || second > available) continue;
    final longest = first > second ? first : second;
    if (longest < bestLongest) {
      bestLongest = longest;
      best = split;
    }
  }
  return best;
}
