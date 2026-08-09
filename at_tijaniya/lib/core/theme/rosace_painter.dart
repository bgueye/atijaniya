import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Rosace à huit branches — motif signature du design system (§03 de la
/// charte graphique) : deux cercles + étoile à huit pointes, sans le disque
/// de fond ni le texte du logo d'app. `CustomPainter` plutôt qu'un asset SVG
/// pour obtenir exactement le tracé de la maquette et pouvoir en varier la
/// couleur/épaisseur selon le contexte (filigrane discret, climax animé...).
///
/// Extrait de `figure_detail_screen.dart` (en-tête immersif d'une figure) et
/// réutilisé par l'animation de révélation de la silsila d'ijaza
/// (`docs/08-spec-animation-silsila.md` §5/§7) : un seul tracé, jamais
/// dupliqué ni redessiné différemment ailleurs (règle du design system —
/// jamais en pattern répété).
class RosacePainter extends CustomPainter {
  const RosacePainter({this.color = AppColors.gold, this.strokeWidth = 1.4});

  final Color color;
  final double strokeWidth;

  static const _starPoints = [
    Offset(100, 20),
    Offset(112, 80),
    Offset(172, 80),
    Offset(122, 112),
    Offset(140, 172),
    Offset(100, 132),
    Offset(60, 172),
    Offset(78, 112),
    Offset(28, 80),
    Offset(88, 80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 92 * scale, paint);
    canvas.drawCircle(center, 78 * scale, paint);
    canvas.drawPath(
      Path()..addPolygon([for (final point in _starPoints) point * scale], true),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RosacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
