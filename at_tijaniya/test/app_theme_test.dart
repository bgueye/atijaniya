// Couleur du texte secondaire dans le thème (audit Figures du 2026-10-25,
// P2-4 étendu à toute l'app) : plus de bronze pour du texte à lire, sous le
// seuil AA sur fond clair comme sur zaytoune. Voir design_tokens.yaml
// § secondary_ink et § secondary_on_dark.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/theme/app_theme.dart';

void main() {
  tearDown(() => AppColors.setHighContrast(false));

  testWidgets('thème standard : texte secondaire et onglets non sélectionnés en encre secondaire', (tester) async {
    final theme = AppTheme.standard;
    expect(theme.colorScheme.onSurfaceVariant, AppColors.secondaryInk);
    expect(theme.bottomNavigationBarTheme.unselectedItemColor, AppColors.secondaryInk);
    expect(theme.colorScheme.onSurfaceVariant, isNot(AppColors.bronze));
  });

  testWidgets('thème immersif (zaytoune) : texte secondaire en parchemin atténué', (tester) async {
    expect(AppTheme.immersive.colorScheme.onSurfaceVariant, AppColors.secondaryOnDark);
  });

  testWidgets('mode renforcé : l\'encre secondaire passe au bronze renforcé, plus contrasté', (tester) async {
    final standard = AppColors.secondaryInk;
    AppColors.setHighContrast(true);
    // Le bronze, en mode renforcé, est le #4A3F2E de design_tokens.yaml.
    expect(AppColors.secondaryInk, AppColors.bronze);
    expect(AppColors.secondaryInk, const Color(0xFF4A3F2E));
    expect(AppColors.secondaryInk, isNot(standard));
    expect(AppTheme.standard.colorScheme.onSurfaceVariant, const Color(0xFF4A3F2E));
  });
}
