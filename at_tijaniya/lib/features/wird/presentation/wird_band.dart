// Kit de composants (docs/kit/components/WirdBand) : bandeau d'identité d'un
// wird — sa couleur, son nom français, sa fréquence, son nom arabe — en tête
// de sa carte (écran Wird), de son guide et de l'écran de fin. Spécifique au
// module Wird, d'où sa place ici plutôt que dans `core/widgets`.
//
// Couleur fixe par wird (décision du 2026-11-01, docs/maquettes/README.md) :
// Lazim `zaytoune`, Wazifa `emerald`, Hadratou-l-Jouma `gold_soft` avec
// texte `ink`. Aucun nouveau jeton.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';

/// Couleurs d'un bandeau : fond, texte principal, texte secondaire, nom
/// arabe. Exposées pour que la carte qui porte le bandeau (ombre, filet)
/// et les tests s'y accordent.
typedef WirdBandColors = ({Color background, Color foreground, Color secondary, Color arabic});

WirdBandColors wirdBandColors(String wirdId) {
  return switch (wirdId) {
    'lazim' => (
        background: AppColors.zaytoune,
        foreground: AppColors.offWhite,
        secondary: AppColors.secondaryOnDark,
        arabic: AppColors.goldOnDark,
      ),
    // Hadratou-l-Jouma : seul bandeau clair, tout en encre (le brun #6d5520
    // de la maquette n'est pas un jeton, voir docs/kit/README.md).
    'hadratou_jouma' => (
        background: AppColors.goldSoft,
        foreground: AppColors.ink,
        secondary: AppColors.secondaryInk,
        arabic: AppColors.ink,
      ),
    // Wazifa, et tout wird qui viendrait s'ajouter au corpus sans décision
    // de couleur.
    _ => (
        background: AppColors.emerald,
        foreground: AppColors.offWhite,
        secondary: AppColors.secondaryOnDark,
        arabic: AppColors.goldOnDark,
      ),
  };
}

class WirdBand extends StatelessWidget {
  const WirdBand({super.key, required this.wird, this.state});

  /// Wird du corpus validé : ses noms viennent de `nameFrench` et
  /// `nameArabic`, jamais d'un texte écrit ici.
  final Wird wird;

  /// État du jour, en `StatePill` (`onDark`, `gold` ou `done` sur un bandeau
  /// sombre ; `todo` ou `done` sur celui de la Hadratou-l-Jouma).
  final Widget? state;

  @override
  Widget build(BuildContext context) {
    final arabicUi = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final colors = wirdBandColors(wird.id);
    final frequency = wird.frequency == WirdFrequency.daily ? l10n.wirdFrequencyDaily : l10n.homeWirdSubtitleWeeklyInfo;
    final state = this.state;

    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre annoncé dans la langue de l'interface : en arabe, le
                // lecteur d'écran disait le nom français (audit du
                // 2026-11-03). Le nom arabe, à côté, n'est alors pas relu.
                Semantics(
                  header: true,
                  label: arabicUi ? wird.nameArabic : wird.nameFrench,
                  excludeSemantics: true,
                  child: ContentText(
                    wird.nameFrench,
                    style: AppTheme.titleText(fontSize: 22, color: colors.foreground, height: 1.05),
                  ),
                ),
                const SizedBox(height: 2),
                Text(frequency, style: TextStyle(fontSize: 12, color: colors.secondary)),
                if (state != null) ...[const SizedBox(height: 8), state],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Nom arabe en Amiri, en signature du bandeau : il vient du corpus
          // validé et s'écrit toujours de droite à gauche, quelle que soit la
          // langue de l'interface. En arabe, la rangée s'inverse et le nom
          // passe à gauche, comme dans la maquette.
          // Jamais coupé : un nom religieux ne finit pas en points de
          // suspension, même à texte agrandi (audit du 2026-11-03).
          Flexible(
            child: ExcludeSemantics(
              excluding: arabicUi,
              child: Text(
                wird.nameArabic,
                textDirection: TextDirection.rtl,
                style: AppTheme.sacredText(fontSize: 30, color: colors.arabic).copyWith(height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
