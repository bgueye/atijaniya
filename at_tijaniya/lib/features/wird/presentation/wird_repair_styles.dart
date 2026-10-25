/// Styles et aides partagés par les fichiers de « Rattraper son wird ».
/// Sortis de `wird_repair_screen.dart` (audit du 2026-10-25, P3-8), sans
/// changement de comportement.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import '../domain/wird_repair_models.dart';
import 'wird_display_name.dart';

bool repairIsArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

Wird repairValidatedWird(RepairWird wird) {
  final id = switch (wird) {
    RepairWird.lazim => 'lazim',
    RepairWird.wazifa => 'wazifa',
    RepairWird.hadra => 'hadratou_jouma',
    RepairWird.all => throw ArgumentError('pas de nom de wird pour les règles communes'),
  };
  return validatedWirds.firstWhere((w) => w.id == id);
}

/// Nom du wird tel que le guide validé le donne (`wirds_content.dart`), dans
/// la langue de l'interface — jamais un nom réécrit ici.
String repairWirdName(BuildContext context, RepairWird wird) => wirdDisplayName(context, repairValidatedWird(wird));

/// Texte d'interface courant : Jost, en encre (contraste AA sur parchemin).
TextStyle repairUiBody({double size = 15, FontWeight? weight, Color? color}) =>
    TextStyle(fontSize: size, height: 1.5, color: color ?? AppColors.ink, fontWeight: weight);

/// Texte secondaire (sources) : encre adoucie plutôt que bronze, voir
/// [AppColors.secondaryInk].
Color get repairSecondaryInk => AppColors.secondaryInk;

/// Style du contenu religieux : Amiri en arabe (texte religieux, règle du
/// design system), Jost en français, comme le reste du texte courant de
/// l'app. Amiri est un cran plus grand à taille égale de lecture.
TextStyle repairContentStyle(bool isArabic, {double size = 15, FontWeight? weight, Color? color}) {
  final c = color ?? AppColors.ink;
  if (isArabic) return AppTheme.sacredText(fontSize: size + 2, color: c).copyWith(fontWeight: weight);
  return TextStyle(fontSize: size, height: 1.5, color: c, fontWeight: weight);
}

/// Titre de section (lecture complète) : Cormorant en français, Amiri en
/// arabe — les deux polices de titre de la charte.
TextStyle repairTitleStyle(bool isArabic, {double size = 24, Color? color}) {
  final c = color ?? AppColors.ink;
  if (isArabic) return AppTheme.sacredText(fontSize: size, color: c).copyWith(fontWeight: FontWeight.w700, height: 1.4);
  return GoogleFonts.cormorantGaramond(fontSize: size + 2, fontWeight: FontWeight.w600, color: c, height: 1.15);
}
