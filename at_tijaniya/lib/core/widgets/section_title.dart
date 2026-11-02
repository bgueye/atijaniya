// Kit de composants (docs/kit/components/SectionTitle) : titre de section en
// Cormorant, avec un lien facultatif à droite (« Tout voir »).
//
// Déplacé de `features/home/presentation/home_section_title.dart`
// (`HomeSectionTitle`, refonte de l'accueil du 2026-11-01) pour servir à tous
// les écrans refaits d'après les maquettes : il remplace les intitulés en
// petites capitales grises.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.text, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsetsDirectional.fromSTEB(18, 24, 8, 4),
    this.onDark = false,
  });

  /// Sur `zaytoune` (écrans de pratique) : titre en blanc cassé, lien en or.
  final bool onDark;

  final String text;

  /// Libellé du lien (« Tout voir »). Le lien n'apparaît que si
  /// [actionLabel] et [onAction] sont fournis tous les deux.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// `space-24` au-dessus, `space-4` en dessous (fiche du kit). Le retrait de
  /// 18 au début aligne le titre sur le contenu des cartes (gouttière 16 +
  /// filet) ; la fin, réduite à 8, laisse la zone tactile du lien déborder
  /// dans la gouttière sans décaler son texte.
  final EdgeInsetsGeometry padding;

  /// Style du titre selon la langue : `titre-section` (Cormorant 22) en
  /// français, `titre-arabe` (Amiri 20, 700) en arabe — les deux polices de
  /// titre de la charte (design_tokens.yaml § typography).
  static TextStyle styleFor(BuildContext context, {bool onDark = false}) {
    final color = onDark ? AppColors.offWhite : AppColors.ink;
    return Localizations.localeOf(context).languageCode == 'ar'
        ? AppTheme.sacredText(fontSize: 20, color: color).copyWith(fontWeight: FontWeight.w700, height: 1.4)
        : AppTheme.titleText(fontSize: 22, color: color, height: 1.15);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // Annoncé comme titre au lecteur d'écran (audit de l'accueil
            // P2-6) : permet de naviguer de section en section.
            child: Semantics(header: true, child: Text(text, style: styleFor(context, onDark: onDark))),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: onDark ? AppColors.goldOnDark : AppColors.emerald),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
