// At-Tijaniya — thème Flutter généré à partir de design/design_tokens.yaml.
// Ne pas redéfinir de couleurs en dur dans les écrans : toujours passer par
// AppColors (voir app_colors.dart) ou par Theme.of(context).
//
// Typographie servie via google_fonts (Jost / Amiri / Cormorant Garamond) —
// voir la note dans pubspec.yaml sur le passage à des fonts bundlées avant
// publication sur les stores.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Thème "standard" — fond ivoire parchemin. Utilisé sur tous les écrans
  /// sauf les écrans de pratique (Wird, Khadara en direct), qui utilisent
  /// [immersive].
  static ThemeData get standard => _base(
        surface: AppColors.parchment,
        onSurface: AppColors.ink,
        brightness: Brightness.light,
      );

  /// Thème "immersif" — fond vert zaytoune, réservé aux écrans de pratique
  /// (§ règle impérative du design system : jamais utilisé ailleurs).
  static ThemeData get immersive => _base(
        surface: AppColors.zaytoune,
        onSurface: AppColors.parchment,
        brightness: Brightness.dark,
      );

  static ThemeData _base({
    required Color surface,
    required Color onSurface,
    required Brightness brightness,
  }) {
    final uiTextTheme = GoogleFonts.jostTextTheme();
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      // Rôles Material 3 non couverts par les 8 champs "historiques"
      // (primary/secondary/error/surface + leurs "on*") : laissés non
      // renseignés, ils retombent sur des valeurs par défaut génériques
      // (ex. Chip/SegmentedButton utilisent alors surfaceContainerLow/
      // onSurfaceVariant/outline, qui héritent silencieusement de
      // surface/onSurface — sans rapport avec la palette de marque). Explicités
      // ici pour que tout nouveau composant M3 (Chip, Slider, Switch, Menu,
      // Dialog, SnackBar...) rende avec les couleurs zaytoune/emerald/gold/
      // bronze plutôt qu'un fallback Material générique.
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.emerald,
        onPrimary: AppColors.offWhite,
        primaryContainer: isLight ? AppColors.emeraldSoft : AppColors.emerald.withValues(alpha: 0.25),
        onPrimaryContainer: isLight ? AppColors.ink : AppColors.parchment,
        secondary: AppColors.gold,
        onSecondary: AppColors.ink,
        secondaryContainer: isLight ? AppColors.goldSoft : AppColors.gold,
        onSecondaryContainer: AppColors.ink,
        // Bronze porte déjà le rôle "texte secondaire, bordures, légendes"
        // dans design_tokens.yaml — mapping naturel vers tertiary plutôt
        // qu'une nouvelle teinte inventée.
        tertiary: AppColors.bronze,
        onTertiary: isLight ? AppColors.offWhite : AppColors.ink,
        tertiaryContainer: isLight ? AppColors.goldSoft : AppColors.bronze.withValues(alpha: 0.3),
        onTertiaryContainer: isLight ? AppColors.ink : AppColors.parchment,
        error: const Color(0xFFB3261E),
        onError: AppColors.offWhite,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerLowest: isLight ? AppColors.offWhite : AppColors.zaytoune,
        surfaceContainerLow: isLight ? AppColors.offWhite : AppColors.zaytoune,
        surfaceContainer: isLight ? AppColors.offWhite : AppColors.emerald.withValues(alpha: 0.12),
        surfaceContainerHigh: isLight ? AppColors.goldSoft : AppColors.emerald.withValues(alpha: 0.20),
        surfaceContainerHighest: isLight ? AppColors.goldSoft : AppColors.emerald.withValues(alpha: 0.28),
        onSurfaceVariant: AppColors.bronze,
        // Un bronze plus foncé seul ne suffit pas si le trait reste
        // translucide à 20-40% (il se redilue visuellement dans la
        // surface, voir design_tokens.yaml § high_contrast_mode) : l'alpha
        // monte aussi en mode renforcé pour que les bordures restent
        // perceptibles, pas seulement le texte.
        outline: AppColors.bronze.withValues(alpha: AppColors.highContrastEnabled ? 0.75 : 0.4),
        outlineVariant: AppColors.bronze.withValues(alpha: AppColors.highContrastEnabled ? 0.55 : 0.2),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: isLight ? AppColors.ink : AppColors.parchment,
        onInverseSurface: isLight ? AppColors.parchment : AppColors.ink,
        inversePrimary: AppColors.gold,
        // Évite le voile de teinte automatique M3 (primary appliqué en
        // surimpression sur les surfaces élevées) : les couleurs de surface
        // sont déjà choisies explicitement ci-dessus et par `cardTheme`.
        surfaceTint: Colors.transparent,
      ),
      // Interface générique -> Jost, jamais Amiri (règle stricte du design system).
      textTheme: uiTextTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.offWhite,
          textStyle: GoogleFonts.jost(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? AppColors.offWhite : AppColors.zaytoune,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // Même raison que `outline`/`outlineVariant` ci-dessus : alpha
          // renforcé en plus de la couleur, sinon le contour de carte reste
          // trop faible pour aider à percevoir les limites de la carte.
          side: BorderSide(
            color: AppColors.bronze.withValues(alpha: AppColors.highContrastEnabled ? 0.75 : 0.2),
            width: AppColors.highContrastEnabled ? 1.5 : 1.0,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.offWhite,
        selectedItemColor: AppColors.emerald,
        unselectedItemColor: AppColors.bronze,
        selectedLabelStyle: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.jost(fontSize: 12),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Style réservé aux textes religieux et titres arabes (Amiri).
  /// JAMAIS pour un libellé d'interface générique (bouton, menu, onglet).
  static TextStyle sacredText({double fontSize = 20, Color? color}) {
    return GoogleFonts.amiri(fontSize: fontSize, color: color, height: 1.8);
  }
}
