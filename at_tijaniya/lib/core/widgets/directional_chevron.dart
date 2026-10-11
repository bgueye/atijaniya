import 'package:flutter/material.dart';

/// Chevron de fin de ligne (« ouvrir », « aller à ») qui suit le sens de
/// lecture : il pointe vers la droite en français, vers la gauche en arabe.
///
/// `Icons.chevron_right` est déclaré avec `matchTextDirection: true` : Flutter
/// le retourne tout seul en arabe. Ce widget a d'abord fait l'inverse — il
/// choisissait `chevron_left` en arabe, que Flutter retournait à son tour, et
/// le chevron pointait de nouveau vers l'intérieur de la carte. Erreur
/// introduite à la suite de l'audit du 2026-10-04 et vue seulement à l'écran,
/// lors de la passe visuelle du 2026-10-11. Ne jamais ajouter ici de
/// `Transform.flip` ni de choix d'icône selon la langue.
class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({super.key, this.color, this.size});

  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chevron_right, color: color, size: size);
  }
}
