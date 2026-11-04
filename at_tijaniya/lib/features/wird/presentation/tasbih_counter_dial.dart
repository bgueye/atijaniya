// Compteur à l'échelle du nombre à atteindre (refonte du 2026-11-02, maquette
// `docs/maquettes/ecran-pratique.html`, point 3). Remplace l'anneau de 33
// perles (`tasbih_beads_ring.dart`, supprimé), qui représentait une proportion : pour
// 30 répétitions, la première perle s'allumait à 1/30 et l'on croyait
// compter des perles ; pour la Fatiha (1 fois), un anneau entier pour un seul
// toucher.
//
// - jusqu'à 50 : une perle par récitation (Istighfar ×30, Jawharatoul Kamal
//   ×12, les ×3 de la Hadra) ;
// - jusqu'à 100 : une graduation par récitation, plus longue à chaque
//   dizaine, et un repère sur la dernière comptée ;
// - au-delà : un arc par centaine (×600, ×1000), qui se remplit.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum TasbihDialKind { beads, ticks, hundreds }

/// Forme du compteur pour un nombre à atteindre.
TasbihDialKind dialKindFor(int target) => target <= 50
    ? TasbihDialKind.beads
    : target <= 100
        ? TasbihDialKind.ticks
        : TasbihDialKind.hundreds;

class TasbihCounterDial extends StatelessWidget {
  const TasbihCounterDial({
    super.key,
    required this.count,
    required this.target,
    required this.size,
    required this.child,
    this.complete = false,
  });

  final int count;
  final int target;
  final double size;
  final bool complete;

  /// Contenu du centre (le décompte).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Décor : le décompte au centre porte l'information.
          ExcludeSemantics(
            child: CustomPaint(
              size: Size.square(size),
              painter: _DialPainter(count: complete ? target : count, target: target),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.count, required this.target});

  final int count;
  final int target;

  static final _off = AppColors.parchment.withValues(alpha: 0.18);
  static const _on = AppColors.goldOnDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (target <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    switch (dialKindFor(target)) {
      case TasbihDialKind.beads:
        _beads(canvas, center, radius);
      case TasbihDialKind.ticks:
        _ticks(canvas, center, radius);
      case TasbihDialKind.hundreds:
        _hundreds(canvas, center, radius);
    }
  }

  /// Angle de la position [i] sur [n], en partant du haut, dans le sens des
  /// aiguilles d'une montre.
  double _angle(double i, int n) => -math.pi / 2 + i * 2 * math.pi / n;

  void _beads(Canvas canvas, Offset center, double radius) {
    // Perles d'autant plus grosses qu'elles sont peu nombreuses, sans se
    // toucher ; une seule perle (pilier récité une fois) reste raisonnable.
    final gap = 2 * math.pi * radius / target;
    final beadRadius = math.min(9.0, gap * 0.32).clamp(3.0, 9.0);
    for (var i = 0; i < target; i++) {
      final a = _angle(i.toDouble(), target);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      final on = i < count;
      canvas.drawCircle(p, on ? beadRadius : beadRadius * 0.8, Paint()..color = on ? _on : _off);
    }
  }

  void _ticks(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < target; i++) {
      final a = _angle(i.toDouble(), target);
      final ten = i % 10 == 9;
      final inner = radius - (ten ? 12 : 7);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * inner,
        center + dir * radius,
        Paint()
          ..color = i < count ? _on : _off
          ..strokeWidth = ten ? 2.6 : 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
    // Repère de la dernière récitation comptée, juste à l'extérieur.
    if (count > 0 && count < target) {
      final a = _angle(count - 0.5, target);
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * (radius + 8),
        3.5,
        Paint()..color = AppColors.goldSoft,
      );
    }
  }

  /// Au-delà, un anneau continu remplace les centaines : chaque segment
  /// devient plus court que son écart, et passé environ 89 centaines la
  /// longueur devenait négative, l'anneau se dessinait à l'envers (audit du
  /// 2026-11-03 ; le wird libre n'a pas de plafond).
  static const maxHundredSegments = 24;

  void _hundreds(Canvas canvas, Offset center, double radius) {
    final segments = (target / 100).ceil();
    final rect = Rect.fromCircle(center: center, radius: radius - 4);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    if (segments > maxHundredSegments) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, base..color = _off);
      final done = (count / target).clamp(0.0, 1.0);
      if (done > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * done, false, base..color = _on);
      return;
    }
    const gap = 0.07;
    final sweep = 2 * math.pi / segments;
    for (var s = 0; s < segments; s++) {
      final start = -math.pi / 2 + s * sweep + gap / 2;
      final length = sweep - gap;
      canvas.drawArc(rect, start, length, false, base..color = _off);
      // Part de cette centaine déjà récitée (la dernière centaine peut être
      // incomplète si le nombre n'est pas un multiple de 100).
      final size = math.min(100, target - s * 100);
      final done = (count - s * 100).clamp(0, size) / size;
      if (done > 0) canvas.drawArc(rect, start, length * done, false, base..color = _on);
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) => oldDelegate.count != count || oldDelegate.target != target;
}
