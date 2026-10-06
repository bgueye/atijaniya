import 'package:flutter/material.dart';

/// Chevron de fin de ligne (« ouvrir », « aller à ») qui suit le sens de
/// lecture : il pointe vers la droite en français, vers la gauche en arabe.
///
/// `Icons.chevron_right` n'est pas inversé automatiquement par Flutter en
/// RTL : en arabe, il pointait vers l'intérieur de la carte. Quelques écrans
/// l'avaient corrigé un par un avec `Transform.flip` ; ce widget remplace
/// les autres occurrences (suite de l'audit du 2026-10-04).
class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({super.key, this.color, this.size});

  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(isRtl ? Icons.chevron_left : Icons.chevron_right, color: color, size: size);
  }
}
