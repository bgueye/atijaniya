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
  const RosacePainter({Color? color, this.strokeWidth = 1.4}) : _color = color;

  // `AppColors.gold` n'est plus une constante de compilation (mode contraste
  // renforcé, voir app_colors.dart) : la valeur par défaut d'un paramètre
  // doit l'être, donc résolue ici plutôt qu'en valeur par défaut directe.
  final Color? _color;
  Color get color => _color ?? AppColors.gold;
  final double strokeWidth;

  static const _starPoints = [
    Offset(100.00, 26.00),
    Offset(111.48, 72.28),
    Offset(152.33, 47.67),
    Offset(127.72, 88.52),
    Offset(174.00, 100.00),
    Offset(127.72, 111.48),
    Offset(152.33, 152.33),
    Offset(111.48, 127.72),
    Offset(100.00, 174.00),
    Offset(88.52, 127.72),
    Offset(47.67, 152.33),
    Offset(72.28, 111.48),
    Offset(26.00, 100.00),
    Offset(72.28, 88.52),
    Offset(47.67, 47.67),
    Offset(88.52, 72.28),
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
