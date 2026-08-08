import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Chapelet dynamique affiché autour du compteur — remplace l'arc de
/// progression Material par une visualisation de perles inspirée des
/// applications de dhikr existantes (ex. Muslim Pro).
///
/// Toujours 33 perles (taille classique d'un chapelet/misbaha), quel que
/// soit `target` : les perles représentent la progression proportionnelle
/// vers `target`, pas une correspondance perle-par-répétition — seul
/// moyen de rester lisible aussi bien pour un pilier à 12 répétitions que
/// pour Hadratou-l-Jouma (1600). La perle 0, légèrement plus grande, joue
/// le rôle de la perle séparatrice ("imam") d'un vrai chapelet.
class TasbihBeadsRing extends StatelessWidget {
  const TasbihBeadsRing({
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
  final Widget child;
  final bool complete;

  static const _beadCount = 33;

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    final filled = complete ? _beadCount : (progress * _beadCount).floor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < _beadCount; i++)
            _Bead(
              index: i,
              beadCount: _beadCount,
              ringDiameter: size,
              filled: i < filled,
              isNext: !complete && i == filled,
              isMarker: i == 0,
            ),
          child,
        ],
      ),
    );
  }
}

class _Bead extends StatelessWidget {
  const _Bead({
    required this.index,
    required this.beadCount,
    required this.ringDiameter,
    required this.filled,
    required this.isNext,
    required this.isMarker,
  });

  final int index;
  final int beadCount;
  final double ringDiameter;
  final bool filled;
  final bool isNext;
  final bool isMarker;

  @override
  Widget build(BuildContext context) {
    // Départ en haut (-pi/2), sens horaire — convention universelle d'un
    // compteur circulaire, indépendante de la direction RTL/LTR du texte.
    final angle = -pi / 2 + (2 * pi * index / beadCount);
    final radius = ringDiameter / 2 - 12;
    final dx = radius * cos(angle);
    final dy = radius * sin(angle);
    final baseSize = isMarker ? 16.0 : 11.0;
    final beadSize = isNext ? baseSize + 4 : baseSize;

    return Positioned(
      left: ringDiameter / 2 + dx - beadSize / 2,
      top: ringDiameter / 2 + dy - beadSize / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: beadSize,
        height: beadSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.gold : AppColors.parchment.withValues(alpha: isMarker ? 0.3 : 0.16),
          border: isNext ? Border.all(color: AppColors.gold, width: 2) : null,
          boxShadow: filled
              ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }
}
