// At-Tijaniya — design tokens (Flutter)
// Généré à partir de design/design_tokens.yaml — à placer dans lib/core/theme/
// lors de l'initialisation du projet Flutter (Phase 2). Ne pas redéfinir de
// couleurs en dur ailleurs : toujours référencer AppColors.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Fonds immersifs, écrans de wird, en-têtes
  static const zaytoune = Color(0xFF0F3D2E);

  /// Actions principales, états actifs
  static const emerald = Color(0xFF1C6E4A);

  /// Accents, filets, éléments précieux
  static const gold = Color(0xFFC9A24B);

  /// Fonds doux d'accent, badges
  static const goldSoft = Color(0xFFF1E6C9);

  /// Fond principal, écrans de lecture
  static const parchment = Color(0xFFF7F2E7);

  /// Fonds doux d'accent sur zones claires
  static const emeraldSoft = Color(0xFFE4EEE8);

  /// Texte principal
  static const ink = Color(0xFF2B2620);

  /// Texte secondaire, bordures, légendes
  static const bronze = Color(0xFF8C7A5B);

  /// Cartes, surfaces sur fond ivoire
  static const offWhite = Color(0xFFFFFDF8);
}

class AppFonts {
  AppFonts._();

  /// H1, H2, noms de figures. Jamais en texte courant.
  static const titlesFr = 'CormorantGaramond';

  /// Textes religieux, noms propres arabes, titres de sections.
  /// JAMAIS pour les libellés d'interface génériques (boutons, menus).
  static const sacredAndArabic = 'Amiri';

  /// Boutons, menus, labels, corps de texte d'interface.
  static const ui = 'Jost';
}
