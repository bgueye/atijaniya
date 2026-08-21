// At-Tijaniya — design tokens (Flutter)
// Généré à partir de design/design_tokens.yaml — à placer dans lib/core/theme/
// lors de l'initialisation du projet Flutter (Phase 2). Ne pas redéfinir de
// couleurs en dur ailleurs : toujours référencer AppColors.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// État du mode contraste renforcé (`design/design_tokens.yaml` §
  /// accessibility.high_contrast_mode) — actionné uniquement par
  /// `ContrastController` (`core/theme/contrast_controller.dart`) au tout
  /// début du rebuild de `AtTijaniyaApp`, jamais à modifier ailleurs sous
  /// peine d'incohérence entre l'état persisté et le rendu. `bronze`/
  /// `emerald`/`gold` ci-dessous sont les 3 seules couleurs dynamiques :
  /// ce sont les seules à échouer ou friser le seuil de contraste AA sur
  /// fond clair (audit WCAG, voir design_tokens.yaml) — `ink` et les fonds
  /// (parchment/off_white/gold_soft/emerald_soft/zaytoune) restent
  /// `static const` inchangés, déjà largement conformes.
  static bool _highContrast = false;
  static bool get highContrastEnabled => _highContrast;
  static void setHighContrast(bool value) => _highContrast = value;

  /// Fonds immersifs, écrans de wird, en-têtes
  static const zaytoune = Color(0xFF0F3D2E);

  /// Actions principales, états actifs. 5,57:1 sur parchemin (AA, pas AAA)
  /// — voir `_emeraldHighContrast`.
  static Color get emerald => _highContrast ? _emeraldHighContrast : _emeraldStandard;
  static const _emeraldStandard = Color(0xFF1C6E4A);
  static const _emeraldHighContrast = Color(0xFF0F4A32);

  /// Accents, filets, éléments précieux. 2,15:1 sur parchemin utilisé comme
  /// texte — voir `_goldHighContrast`.
  static Color get gold => _highContrast ? _goldHighContrast : _goldStandard;
  static const _goldStandard = Color(0xFFC9A24B);
  static const _goldHighContrast = Color(0xFF8A6A1E);

  /// Fonds doux d'accent, badges
  static const goldSoft = Color(0xFFF1E6C9);

  /// Fond principal, écrans de lecture
  static const parchment = Color(0xFFF7F2E7);

  /// Fonds doux d'accent sur zones claires
  static const emeraldSoft = Color(0xFFE4EEE8);

  /// Texte principal
  static const ink = Color(0xFF2B2620);

  /// Texte secondaire, bordures, légendes. Échoue l'AA texte normal sur
  /// fond clair (3,72:1 sur parchemin, 4,09:1 sur off_white — seuil 4,5:1) :
  /// c'est la couleur qui motive le mode contraste renforcé.
  static Color get bronze => _highContrast ? _bronzeHighContrast : _bronzeStandard;
  static const _bronzeStandard = Color(0xFF8C7A5B);
  static const _bronzeHighContrast = Color(0xFF4A3F2E);

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
