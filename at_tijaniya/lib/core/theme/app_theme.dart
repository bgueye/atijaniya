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

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.emerald,
        onPrimary: AppColors.offWhite,
        secondary: AppColors.gold,
        onSecondary: AppColors.ink,
        error: const Color(0xFFB3261E),
        onError: AppColors.offWhite,
        surface: surface,
        onSurface: onSurface,
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
          side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.2)),
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
