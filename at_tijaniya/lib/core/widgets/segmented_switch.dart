// Kit de composants (docs/kit/components/SegmentedControl) : bascule entre
// deux ou trois vues d'un même écran (Lieux / Agenda, Fil / Groupes /
// Messages). Le `SegmentedButton` de Material a un rendu trop éloigné de la
// maquette (contour, coche, rayons) pour être seulement thémé.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'state_pill.dart';

/// Une vue de [SegmentedSwitch].
class SegmentedSwitchItem<T> {
  const SegmentedSwitchItem({required this.value, required this.label, this.count, this.unread, this.unreadLabel});

  final T value;
  final String label;

  /// Nombre discret après le libellé (« Lieux 34 »).
  final int? count;

  /// Non-lus, affichés en [StatePill] `count`. Prime sur [count].
  final int? unread;

  /// Ce que [unread] compte, pour le lecteur d'écran (« 2 messages non lus »).
  final String? unreadLabel;
}

class SegmentedSwitch<T> extends StatelessWidget {
  const SegmentedSwitch({super.key, required this.items, required this.selected, required this.onChanged})
      // Trois vues au plus (fiche du kit) : au-delà, l'écran est à revoir,
      // pas le composant à étirer.
      : assert(items.length >= 2 && items.length <= 3, 'SegmentedSwitch : deux ou trois vues.');

  final List<SegmentedSwitchItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(child: _Segment(item: item, active: item.value == selected, onTap: () => onChanged(item.value))),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.item, required this.active, required this.onTap});

  final SegmentedSwitchItem<T> item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = item.count;
    final unread = item.unread;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? AppColors.offWhite : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        // Ombre très légère de la maquette sur la vue active : seule
        // exception au « des filets, pas des ombres », car c'est elle qui
        // fait lire la vue comme « posée » sur la gouttière.
        elevation: active ? 0.6 : 0,
        shadowColor: AppColors.ink.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            // 42 visibles + 3 de gouttière de part et d'autre : 48 dp.
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: active ? AppColors.ink : AppColors.secondaryInk,
                        fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (unread != null && unread > 0) ...[
                    const SizedBox(width: 6),
                    StatePill.count(unread, semanticsLabel: item.unreadLabel),
                  ] else if (count != null) ...[
                    const SizedBox(width: 4),
                    Text('$count', style: TextStyle(fontSize: 14, color: AppColors.secondaryInk)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
