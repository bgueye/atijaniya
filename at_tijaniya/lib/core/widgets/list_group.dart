// Kit de composants (docs/kit/components/ListGroup) : lignes regroupées dans
// une seule carte (réglages, sections du Profil, menu d'un écran de détail).
// Chaque ligne : puce d'icône, titre, sous-titre facultatif, élément de fin.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';
import 'directional_chevron.dart';

/// Ton de la puce d'icône (34 px), d'après la nature de la ligne.
enum ListGroupTone {
  /// `emerald_soft` + `emerald` : une action.
  action,

  /// `gold_soft` + `ink` : contenu religieux ou don.
  sacred,

  /// `parchment` + `bronze` : réglage neutre.
  neutral,
}

/// Une ligne de [ListGroup].
class ListGroupItem {
  const ListGroupItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone = ListGroupTone.action,
    this.showChevron,
  });

  final IconData icon;
  final String title;

  /// Pour une donnée sensible, son état (« Renseignée »), jamais son
  /// contenu (le nom du moqaddam n'apparaît pas dans une liste).
  final String? subtitle;

  /// Élément de fin : `StatePill`, interrupteur, compteur. Un réglage simple
  /// (langue, contraste) se change ici, sans écran intermédiaire.
  final Widget? trailing;
  final VoidCallback? onTap;
  final ListGroupTone tone;

  /// Chevron de fin. Par défaut : affiché quand la ligne mène quelque part
  /// ([onTap]) et n'a pas d'autre élément de fin.
  final bool? showChevron;
}

class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.items});

  final List<ListGroupItem> items;

  @override
  Widget build(BuildContext context) {
    // `Card` reprend le `cardTheme` (blanc cassé, filet bronze à 20 %, rayon
    // 16, et leur version renforcée) : rien à redéfinir ici.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // `min` : la carte prend la hauteur de ses lignes, sans s'étirer dans un
      // parent borné (vu sur capture le 2026-11-02).
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              // Filet aligné sur le texte, pas sur la puce : la puce reste le
              // repère visuel de chaque ligne. Retrait directionnel : le
              // `indent` d'un `Divider` est toujours à gauche, et le filet
              // partait du mauvais côté en arabe (vu sur capture).
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 60),
                child: Divider(height: 1, thickness: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
              ),
            _ListGroupRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ListGroupRow extends StatelessWidget {
  const _ListGroupRow({required this.item});

  final ListGroupItem item;

  @override
  Widget build(BuildContext context) {
    final (chipBackground, chipForeground) = switch (item.tone) {
      ListGroupTone.action => (AppColors.emeraldSoft, AppColors.emerald),
      ListGroupTone.sacred => (AppColors.goldSoft, AppColors.ink),
      ListGroupTone.neutral => (AppColors.parchment, AppColors.bronze),
    };
    final chevron = item.showChevron ?? (item.onTap != null && item.trailing == null);
    final subtitle = item.subtitle;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: chipBackground, borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icon, size: 18, color: chipForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContentText(item.title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    ContentText(subtitle,
                        style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk, height: 1.35)),
                ],
              ),
            ),
            if (item.trailing != null) ...[const SizedBox(width: 8), item.trailing!],
            if (chevron) ...[const SizedBox(width: 4), DirectionalChevron(color: AppColors.bronze)],
          ],
        ),
      ),
    );

    if (item.onTap == null) return row;
    return InkWell(onTap: item.onTap, child: row);
  }
}
