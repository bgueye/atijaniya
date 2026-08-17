import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Icônes sur-mesure des 5 onglets de la barre de navigation principale
/// (`home_shell.dart`) — remplacent les glyphes Material génériques
/// (livre, silhouettes...) par un vocabulaire visuel propre à la pratique
/// tijanie : chapelet, mihrab, minaret, chaîne de transmission, lien entre
/// disciples. `CustomPainter` plutôt qu'un pack d'icônes tiers, même
/// principe que `RosacePainter` — aucune dépendance ajoutée, tracé fin
/// cohérent avec `design/design_tokens.yaml` (pas de couleur codée en dur
/// ici : la couleur suit l'`IconTheme` ambiant, exactement comme un
/// `Icon` Material, pour hériter automatiquement de la teinte
/// sélectionné/non-sélectionné déjà gérée par `BottomNavigationBar`).
enum AppNavIconType { home, wird, khadara, figures, communaute }

class AppNavIcon extends StatelessWidget {
  const AppNavIcon(this.type, {super.key});

  final AppNavIconType type;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? 24.0;
    final color = iconTheme.color ?? const Color(0xFF2B2620);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _painterFor(type, color)),
    );
  }

  CustomPainter _painterFor(AppNavIconType type, Color color) {
    return switch (type) {
      AppNavIconType.home => _MihrabPainter(color: color),
      AppNavIconType.wird => _TasbihPainter(color: color),
      AppNavIconType.khadara => _MosquePainter(color: color),
      AppNavIconType.figures => _PortraitMedallionPainter(color: color),
      AppNavIconType.communaute => _DisciplesPairPainter(color: color),
    };
  }
}

/// Grille de dessin commune, 24x24 (convention Material), mise à l'échelle
/// de la taille réellement demandée par l'`IconTheme` ambiant.
abstract class _NavIconPainter extends CustomPainter {
  const _NavIconPainter({required this.color});

  final Color color;

  static const _baseStrokeWidth = 1.6;

  Paint strokePaint(double scale) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _baseStrokeWidth * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint fillPaint() => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  bool shouldRepaint(covariant _NavIconPainter oldDelegate) => oldDelegate.color != color;
}

/// Accueil — arc de mihrab (niche indiquant la qibla) plutôt qu'une maison
/// générique : l'accueil est le point d'orientation personnel du disciple
/// dans l'app, écho volontaire au rôle du mihrab dans une mosquée.
class _MihrabPainter extends _NavIconPainter {
  const _MihrabPainter({required super.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(5 * scale, 20 * scale)
      ..lineTo(5 * scale, 12 * scale)
      ..quadraticBezierTo(5 * scale, 4.6 * scale, 12 * scale, 4.6 * scale)
      ..quadraticBezierTo(19 * scale, 4.6 * scale, 19 * scale, 12 * scale)
      ..lineTo(19 * scale, 20 * scale);
    canvas.drawPath(path, strokePaint(scale));
    // Seuil de la niche.
    canvas.drawLine(Offset(5 * scale, 20 * scale), Offset(19 * scale, 20 * scale), strokePaint(scale));
  }
}

/// Wird — chapelet (tasbih/misbaha) : anneau de grains avec le grain-imam
/// et le pompon en pendentif, sa forme la plus reconnaissable.
class _TasbihPainter extends _NavIconPainter {
  const _TasbihPainter({required super.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    const center = Offset(12, 10.6);
    const rx = 7.0;
    const ry = 5.8;
    final fill = fillPaint();

    // Anneau de grains — laisse un vide en bas (90°) pour le point
    // d'attache du pompon, comme un vrai chapelet.
    const beadCount = 11;
    const sweepStart = 108.0;
    const sweepEnd = 432.0;
    for (var i = 0; i < beadCount; i++) {
      final angleDeg = sweepStart + (sweepEnd - sweepStart) * i / (beadCount - 1);
      final angle = angleDeg * math.pi / 180;
      final point = Offset(
        (center.dx + rx * math.cos(angle)) * scale,
        (center.dy + ry * math.sin(angle)) * scale,
      );
      canvas.drawCircle(point, 1.05 * scale, fill);
    }

    // Grain-imam, légèrement plus gros, au point de jonction de l'anneau.
    final imamBead = Offset(center.dx * scale, (center.dy + ry) * scale);
    canvas.drawCircle(imamBead, 1.5 * scale, fill);

    // Pompon : fil puis grain terminal.
    final tasselEnd = Offset(12 * scale, 20 * scale);
    canvas.drawLine(
      Offset(12 * scale, (center.dy + ry + 1.5) * scale),
      tasselEnd,
      strokePaint(scale)..strokeWidth = 1.3 * scale,
    );
    canvas.drawCircle(Offset(12 * scale, 21.1 * scale), 1.15 * scale, fill);
  }
}

/// Khadara — silhouette de mosquée (dôme central + deux minarets + porte en
/// arc) : demandé explicitement par le porteur de projet (2026-08-17) à la
/// place du minaret seul, plus directement lisible comme "lieu de
/// rassemblement" que "tour".
class _MosquePainter extends _NavIconPainter {
  const _MosquePainter({required super.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = strokePaint(scale);

    // Corps + dôme du bâtiment central.
    final dome = Path()
      ..moveTo(7 * scale, 20 * scale)
      ..lineTo(7 * scale, 14 * scale)
      ..arcToPoint(Offset(17 * scale, 14 * scale), radius: Radius.circular(6 * scale))
      ..lineTo(17 * scale, 20 * scale);
    canvas.drawPath(dome, paint);
    // Amortissement du dôme.
    canvas.drawLine(Offset(12 * scale, 8 * scale), Offset(12 * scale, 6.2 * scale), paint);
    canvas.drawCircle(Offset(12 * scale, 5.6 * scale), 0.75 * scale, fillPaint());

    // Porte en arc, au centre.
    final door = Path()
      ..moveTo(10.6 * scale, 20 * scale)
      ..lineTo(10.6 * scale, 17.4 * scale)
      ..arcToPoint(Offset(13.4 * scale, 17.4 * scale), radius: Radius.circular(1.4 * scale))
      ..lineTo(13.4 * scale, 20 * scale);
    canvas.drawPath(door, paint);

    // Deux minarets, de part et d'autre.
    for (final x in [4.3, 19.7]) {
      canvas.drawLine(Offset(x * scale, 20 * scale), Offset(x * scale, 11.6 * scale), paint);
      canvas.drawCircle(Offset(x * scale, 11 * scale), 0.65 * scale, fillPaint());
    }

    // Base commune.
    canvas.drawLine(Offset(3 * scale, 20 * scale), Offset(21 * scale, 20 * scale), paint);
  }
}

/// Figures — médaillon-portrait : un buste dans un cercle, écho des motifs
/// circulaires déjà présents dans l'identité de l'app (rosace, sceau) —
/// remplace la chaîne à maillons (2026-08-17, jugée peu lisible et trop
/// proche du chapelet de Wird) par quelque chose qui se lit directement
/// comme "une figure/personnage historique", pas une généalogie abstraite.
class _PortraitMedallionPainter extends _NavIconPainter {
  const _PortraitMedallionPainter({required super.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;

    canvas.drawCircle(Offset(12 * scale, 12 * scale), 8.4 * scale, strokePaint(scale));

    final fill = fillPaint();
    canvas.drawCircle(Offset(12 * scale, 9 * scale), 2.0 * scale, fill);
    final bust = RRect.fromLTRBAndCorners(
      8.3 * scale,
      13.0 * scale,
      15.7 * scale,
      18.5 * scale,
      topLeft: Radius.circular(3.7 * scale),
      topRight: Radius.circular(3.7 * scale),
    );
    canvas.drawRRect(bust, fill);
  }
}

/// Communauté — deux disciples côte à côte : tête en anneau (trait fin,
/// comme le reste du jeu d'icônes) et buste en dôme plein, pour rester
/// lisible à la taille d'un onglet (24dp) — un simple fil de liaison entre
/// les deux têtes se lisait comme des lunettes à cette échelle, retiré au
/// profit de cette silhouette double, plus sobre et plus juste.
class _DisciplesPairPainter extends _NavIconPainter {
  const _DisciplesPairPainter({required super.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = strokePaint(scale);
    final fill = fillPaint();

    for (final cx in [7.6, 16.4]) {
      canvas.drawCircle(Offset(cx * scale, 8.2 * scale), 2.1 * scale, paint);
      final body = RRect.fromLTRBAndCorners(
        (cx - 3.1) * scale,
        13.0 * scale,
        (cx + 3.1) * scale,
        20.0 * scale,
        topLeft: Radius.circular(3.1 * scale),
        topRight: Radius.circular(3.1 * scale),
      );
      canvas.drawRRect(body, fill);
    }
  }
}
