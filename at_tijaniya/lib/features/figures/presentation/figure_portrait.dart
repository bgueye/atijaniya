import 'package:flutter/material.dart';

/// Portrait d'une figure dans un cadre carré, rond ([circle]) ou à coins
/// arrondis ([borderRadius]) — liste des figures et en-tête de la fiche.
///
/// Remplace une `DecorationImage(NetworkImage(...))` qui n'avait aucun repli
/// (audit Figures du 2026-10-25, P2-5) : si l'URL ne répondait plus (fichier
/// retiré du bucket, réseau coupé avant la mise en cache), l'erreur n'allait
/// qu'au journal et la case restait vide. [errorPlaceholder], l'icône déjà
/// affichée pour une figure sans portrait, prend désormais sa place.
///
/// Décodage à la taille du cadre (`cacheWidth`) : une photo en pleine
/// résolution n'est pas gardée en mémoire pour 56 ou 72 px. La largeur seule
/// garde les proportions de la photo ; `ResizeImage` avec largeur et hauteur
/// la déformait avant le recadrage.
class FigurePortrait extends StatelessWidget {
  const FigurePortrait({
    super.key,
    required this.url,
    required this.size,
    required this.errorPlaceholder,
    this.circle = false,
    this.borderRadius = 0,
  });

  final String url;
  final double size;
  final Widget errorPlaceholder;
  final bool circle;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      // Le visage est presque toujours dans le haut d'une photo de portrait :
      // un recadrage centré le coupait souvent.
      alignment: Alignment.topCenter,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (context, error, stackTrace) => Center(child: errorPlaceholder),
    );
    return circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: image);
  }
}
