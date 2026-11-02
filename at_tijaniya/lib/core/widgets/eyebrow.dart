// Kit de composants (docs/kit/components/Eyebrow) : petite étiquette en
// capitales au-dessus d'un titre (« PROCHAINE ÉTAPE », « FONDATEUR DE LA
// TARIQA »). Le style était recopié à la main dans `home_header.dart` et
// `home_discover_section.dart`, avec des tailles et interlettrages qui
// avaient fini par diverger (10,5/1 ; 10,5/1,2 ; 11/1,1).

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';

/// Étiquette `etiquette` du kit : Jost 10,5, 500, capitales, interlettrage
/// 1,2 px. Jamais seule : toujours suivie d'un titre.
///
/// [text] est fourni déjà traduit ; le composant le met en capitales. En arabe,
/// `toUpperCase` est sans effet (l'écriture arabe n'a pas de casse), ce qui
/// est voulu. Le texte passe par [ContentText] : une étiquette peut contenir un
/// contenu dans une autre langue que l'interface (titre de section des
/// bienfaits, seulement en français dans l'interface arabe).
///
/// Pas d'Amiri, même en arabe : c'est un libellé d'interface (règle stricte
/// de la charte).
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.onDark = false, this.maxLines, this.color});

  final String text;

  /// Sur fond `zaytoune` : or `gold_on_dark` au lieu de l'encre secondaire.
  final bool onDark;

  /// Lignes au plus (points de suspension au-delà). `null` : pas de limite.
  final int? maxLines;

  /// Couleur imposée, pour les rares cas où ni l'encre secondaire ni l'or
  /// sombre ne conviennent. À éviter : la couleur a un sens dans le kit.
  final Color? color;

  /// Style de l'étiquette, exposé pour les textes qui doivent s'aligner sur
  /// elle sans être une étiquette (mesure de hauteur, tests).
  static TextStyle style({bool onDark = false}) => TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: onDark ? AppColors.goldOnDark : AppColors.secondaryInk,
      );

  @override
  Widget build(BuildContext context) {
    final base = style(onDark: onDark);
    return ContentText(
      text.toUpperCase(),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: color == null ? base : base.copyWith(color: color),
    );
  }
}
