// Bordure pointillée : ce qui est à part, en retrait du reste de l'écran —
// le wird libre (outil personnel, écran Wird) et le cadre d'administration
// (Profil, admin seulement). Une seule façon de la dessiner pour les deux.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, this.radius = 16, this.color});

  final Widget child;
  final double radius;

  /// Par défaut, bronze à 45 % (lisible sans être appuyé).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color ?? AppColors.bronze.withValues(alpha: 0.45), radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.75));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color || oldDelegate.radius != radius;
}
