// Kit de composants (docs/kit/components/Button) : les deux variantes que le
// thème ne couvre pas. Les autres passent par les widgets Material, thémés
// dans `AppTheme` :
// - `primary` : `FilledButton` (pilule émeraude) — une seule par écran ;
// - `block` : `ElevatedButton` en pleine largeur (rayon 12), fin de formulaire ;
// - `tonal` : `FilledButton.tonal` avec `style: AppButtonStyles.tonal`
//   (`emerald_soft`) — le `colorScheme` donnerait sinon le `gold_soft` de
//   `secondaryContainer` ;
// - `outline` : `OutlinedButton` (pilule, contour émeraude) ;
// - `text` : `TextButton` (« Fermer », « Tout voir »).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Styles de bouton du kit que le thème ne peut pas porter.
abstract final class AppButtonStyles {
  /// Action secondaire mise en avant (« Tasbih libre » quand tout est fait) :
  /// `emerald_soft` + `emerald`, en pilule (forme du thème). Getter : la
  /// teinte émeraude change avec le mode contraste renforcé.
  static ButtonStyle get tonal =>
      FilledButton.styleFrom(backgroundColor: AppColors.emeraldSoft, foregroundColor: AppColors.emerald);

  /// Coins du bouton `block` (rayon 12), partagés par ses alternatives.
  static const _blockShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));

  /// Alternative en pleine largeur posée à côté d'un bouton `block`
  /// (« Retrouver mes condisciples » au-dessus du formulaire de lignée) :
  /// contour émeraude du thème, mais coins de 12 au lieu de la pilule. Vu sur
  /// émulateur le 2026-11-05 : une pilule pleine largeur juste au-dessus ou
  /// au-dessous d'un `block` à coins de 12 faisait deux formes sur une même
  /// colonne de boutons.
  static ButtonStyle get blockOutline => OutlinedButton.styleFrom(shape: _blockShape);

  /// Action destructrice en pleine largeur à côté d'un bouton `block`
  /// (« Supprimer mes informations », « Quitter le groupe ») : texte **et**
  /// contour en `danger`, coins de 12. Avant, seul le texte passait en
  /// `danger` et le contour restait émeraude (thème), un mélange vert-rouge
  /// qui brouillait le sens de l'action.
  static ButtonStyle get blockOutlineDanger => OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
        shape: _blockShape,
      );

  /// Action destructrice en pilule dans une carte (« Refuser », « Décliner »,
  /// action d'un signalement) : même correction du contour, forme du thème.
  static ButtonStyle get outlineDanger => OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      );
}

/// Lien d'action irréversible (« Supprimer mon compte ») : texte `danger` en
/// 13, séparé des autres actions par le consommateur. L'action elle-même
/// doit demander confirmation avant d'agir — ce bouton ne le fait pas à sa
/// place, le message de confirmation dépendant de ce qui est supprimé.
class DangerLinkButton extends StatelessWidget {
  const DangerLinkButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Le `textStyle` d'un bouton remplace celui du thème au lieu de s'y
    // fusionner : un simple `TextStyle(fontSize: 13)` faisait retomber le
    // libellé sur la police système (vu sur capture). On repart donc du
    // libellé du thème (Jost 14, 500), réduit à 13 en graisse normale.
    final themed = Theme.of(context).textButtonTheme.style?.textStyle?.resolve(const {});
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.danger,
      textStyle: (themed ?? GoogleFonts.jost()).copyWith(fontSize: 13, fontWeight: FontWeight.w400),
    );
    final icon = this.icon;
    if (icon == null) return TextButton(onPressed: onPressed, style: style, child: Text(label));
    return TextButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: Text(label));
  }
}

/// Action de pratique en bas d'un écran `zaytoune` (« Terminer le Lazim ») :
/// aplat `gold_on_dark`, texte `zaytoune`, pleine largeur, rayon 16. Jamais
/// sur fond clair (l'or y tomberait sous le seuil de contraste).
class PracticeButton extends StatelessWidget {
  const PracticeButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.goldOnDark,
          foregroundColor: AppColors.zaytoune,
          disabledBackgroundColor: AppColors.goldOnDark.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.zaytoune.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          minimumSize: const Size(64, 52),
        ),
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Flexible(child: Text(label))],
              ),
      ),
    );
  }
}
