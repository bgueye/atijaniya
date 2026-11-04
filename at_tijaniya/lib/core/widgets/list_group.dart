// Kit de composants (docs/kit/components/ListGroup) : lignes regroupées dans
// une seule carte (réglages, sections du Profil, menu d'un écran de détail).
// Chaque ligne : puce d'icône, titre, sous-titre facultatif, élément de fin.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';
import 'directional_chevron.dart';
import 'state_pill.dart';

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
    this.fixedTrailing = false,
    this.mergeSemantics = false,
  });

  /// Réglage à bascule (contraste, chiffres de pratique) : toute la ligne
  /// change la valeur, et le lecteur d'écran l'annonce en un seul élément,
  /// titre et état compris (« Contraste renforcé, commutateur, activé »).
  /// Audit du 2026-11-03 : l'interrupteur seul était annoncé, sans dire ce
  /// qu'il réglait, et seul lui réagissait au toucher.
  ListGroupItem.toggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    this.tone = ListGroupTone.neutral,
  })  : trailing = Switch(value: value, onChanged: onChanged),
        onTap = (() => onChanged(!value)),
        showChevron = false,
        fixedTrailing = true,
        mergeSemantics = true;

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

  /// `true` : l'élément de fin garde sa largeur (commande compacte, comme le
  /// choix FR / عربي de la langue) au lieu d'être borné à 55 % de la ligne. Réservé aux éléments courts, sinon la ligne déborde.
  final bool fixedTrailing;

  /// `true` : la ligne et son élément de fin forment un seul élément pour le
  /// lecteur d'écran. Seulement pour un élément de fin unique (interrupteur),
  /// jamais pour plusieurs boutons, qui deviendraient inaccessibles.
  final bool mergeSemantics;
}

class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.items, this.framed = true});

  final List<ListGroupItem> items;

  /// `false` : les lignes sans la carte, pour un cadre fourni par le
  /// consommateur (cadre pointillé de l'administration sur le Profil).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    // `min` : la carte prend la hauteur de ses lignes, sans s'étirer dans un
    // parent borné (vu sur capture le 2026-11-02).
    final rows = Column(
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
    );
    if (!framed) return rows;
    // `Card` reprend le `cardTheme` (blanc cassé, filet bronze à 20 %, rayon
    // 16, et leur version renforcée) : rien à redéfinir ici.
    return Card(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, child: rows);
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
    // Chevron sur une ligne qui s'ouvre, même quand une pastille d'état la
    // termine (audit du 2026-11-03 : « Ma lignée spirituelle » ou
    // « Visibilité de ma lignée » ne montraient pas qu'elles s'ouvrent, alors
    // que « Disciples bloqués » le montrait). Pas pour une commande (choix de
    // langue, interrupteur), qui fait déjà son travail sur place.
    final chevron = item.showChevron ?? (item.onTap != null && (item.trailing == null || item.trailing is StatePill));
    final subtitle = item.subtitle;

    final row = LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
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
              // Élément de fin à sa largeur naturelle, bornée à 55 % de la ligne :
              // une valeur longue se coupe au lieu de pousser la ligne hors de
              // l'écran, et une valeur moyenne (« Visible des condisciples ») tient
              // en entier, le titre passant à la ligne (vu sur le Profil,
              // 2026-11-02).
              if (item.trailing != null) ...[
                const SizedBox(width: 8),
                if (item.fixedTrailing)
                  item.trailing!
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                    child: item.trailing!,
                  ),
              ],
              if (chevron) ...[const SizedBox(width: 4), DirectionalChevron(color: AppColors.bronze)],
            ],
          ),
        ),
      ),
    );
    final Widget result = item.onTap == null ? row : InkWell(onTap: item.onTap, child: row);
    return item.mergeSemantics ? MergeSemantics(child: result) : result;
  }
}
