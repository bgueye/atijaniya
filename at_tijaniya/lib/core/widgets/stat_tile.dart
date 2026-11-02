// Kit de composants (docs/kit/components/StatTile) : un nombre en grand et ce
// qu'il compte (« 7 jours de suite », « 34 lieux »), par rangées de deux ou
// trois. Jamais de chiffre décoratif : chaque nombre vient des données.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'content_text.dart';

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.dark = false});

  /// Le nombre, déjà formaté par le consommateur (chiffres latins, comme le
  /// reste de l'app).
  final String value;

  /// Ce que le nombre compte, en minuscules : « jours de suite ».
  final String label;

  /// Variante `zaytoune` pour le chiffre le plus important d'une rangée, et
  /// seulement lui : sur un écran de pratique ou l'accueil (règle du
  /// zaytoune, CLAUDE.md § Design system).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // « 7 jours de suite » lu d'un seul tenant.
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? AppColors.zaytoune : AppColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? AppColors.zaytoune : AppColors.bronze.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textDirection: TextDirection.ltr,
              style:
                  AppTheme.titleText(fontSize: 28, color: dark ? AppColors.goldOnDark : AppColors.emerald, height: 1),
            ),
            const SizedBox(height: 2),
            ContentText(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: dark ? AppColors.secondaryOnDark : AppColors.secondaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
