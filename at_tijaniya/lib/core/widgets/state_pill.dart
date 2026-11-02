// Kit de composants (docs/kit/components/StatePill) : pastille qui dit l'état
// d'une chose avant d'en proposer l'accès (« Fait ce matin », « Privée »,
// « À renseigner », nombre de non-lus).

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';

/// Variantes de la fiche. Les deux dernières ne s'emploient que sur
/// `zaytoune` (écrans de pratique, en-tête de l'accueil).
enum StatePillVariant {
  /// `emerald_soft` + `emerald`, précédée d'une coche.
  done,

  /// `gold_soft` + `ink` : à faire, à renseigner, date approximative.
  todo,

  /// `parchment` avec contour : état neutre (« Privée »).
  neutral,

  /// `emerald` + `off_white` : un nombre (non-lus, demandes).
  count,

  /// Fond sombre : blanc à 12 %, texte parchemin.
  onDark,

  /// Fond sombre : `gold_on_dark` + `zaytoune` (« En pause »).
  gold,
}

class StatePill extends StatelessWidget {
  const StatePill(String this._text, {super.key, this.variant = StatePillVariant.neutral, this.semanticsLabel})
      : _count = null;

  /// Pastille de nombre. [semanticsLabel] dit ce qui est compté (« 2
  /// messages non lus ») : « 2 » seul ne veut rien dire au lecteur d'écran.
  const StatePill.count(int this._count, {super.key, this.semanticsLabel})
      : _text = null,
        variant = StatePillVariant.count;

  /// Un mot ou deux. L'état se dit toujours en texte : la couleur seule ne
  /// suffit pas (daltonisme, lecteur d'écran).
  String get text => _text ?? '$_count';
  final String? _text;
  final int? _count;
  final StatePillVariant variant;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      StatePillVariant.done => (AppColors.emeraldSoft, AppColors.emerald, null),
      StatePillVariant.todo => (AppColors.goldSoft, AppColors.ink, null),
      StatePillVariant.neutral => (
          AppColors.parchment,
          AppColors.secondaryInk,
          AppColors.bronze.withValues(alpha: 0.3)
        ),
      StatePillVariant.count => (AppColors.emerald, AppColors.offWhite, null),
      StatePillVariant.onDark => (AppColors.offWhite.withValues(alpha: 0.12), AppColors.parchment, null),
      StatePillVariant.gold => (AppColors.goldOnDark, AppColors.zaytoune, null),
    };
    final isCount = variant == StatePillVariant.count;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground, height: 1.4);

    Widget label = ContentText(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    if (variant == StatePillVariant.done) {
      // Coche en icône plutôt qu'en caractère « ✓ » : Jost n'a pas ce glyphe,
      // il tombait sur une police de repli d'une autre graisse.
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 13, color: foreground),
          const SizedBox(width: 4),
          Flexible(child: label),
        ],
      );
    }

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Container(
        constraints: isCount ? const BoxConstraints(minWidth: 20) : null,
        padding: EdgeInsets.symmetric(horizontal: isCount ? 6 : 9, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border),
        ),
        child: isCount ? Center(widthFactor: 1, heightFactor: 1, child: label) : label,
      ),
    );
  }
}
