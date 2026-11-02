// Kit de composants (docs/kit/components/FilterChips) : rangée de filtres à
// choix unique, défilable horizontalement. Déplacé de
// `home_discover_section.dart` (`_FilterChip`, refonte de l'accueil du
// 2026-11-01) pour servir aussi aux annuaires (Zawiyas) et au fil
// (Communauté).
//
// `JustifiedChoiceChips` reste pour les filtres répartis sur deux lignes
// (foyers, types de lieux) : ce composant-ci ne passe jamais à la ligne.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Une option de [FilterChips].
class FilterChipItem<T> {
  const FilterChipItem({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Nombre affiché après le libellé (« Zawiyas 34 »), facultatif.
  final int? count;
}

/// Rangée de filtres. Le consommateur fournit les options et l'option
/// choisie ; il masque lui-même une option vide plutôt que de la griser
/// (règle de la fiche), sauf quand le disciple doit voir qu'il n'y a rien.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 6),
  });

  final List<FilterChipItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Gouttière de 16 de chaque côté : la rangée défile jusqu'au bord de
  /// l'écran, mais le premier et le dernier filtre restent alignés sur le
  /// contenu.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            FilterPill(
              label: items[i].label,
              count: items[i].count,
              selected: items[i].value == selected,
              onTap: () => onSelected(items[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une pastille de filtre seule, pour les rares cas où la rangée ne convient
/// pas. Pastille visible de 32 px dans une zone tactile de 48 dp.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap, this.count});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    // Choisie : encre pleine, texte blanc cassé. Autres : contour bronze à
    // 35 %, texte en encre secondaire (le bronze serait sous le seuil AA).
    final foreground = selected ? AppColors.offWhite : AppColors.secondaryInk;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          // Cible tactile de 48 dp même si la pastille n'en fait que 32.
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppColors.ink : AppColors.bronze.withValues(alpha: 0.35)),
              ),
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (count != null)
                      TextSpan(
                        text: ' $count',
                        // Le nombre reste un peu en retrait du libellé, comme
                        // dans la maquette (« Zawiyas 34 »).
                        style: TextStyle(color: foreground.withValues(alpha: selected ? 0.75 : 0.85)),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
