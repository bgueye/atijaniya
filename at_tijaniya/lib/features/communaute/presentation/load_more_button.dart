import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Taille d'une page du fil et d'une tranche de discussion (audit
/// Communauté du 2026-10-26, P2-9) : le fil, une discussion de groupe et une
/// conversation étaient chargés en entier, puis rechargés en entier toutes
/// les 5 à 6 secondes pour les deux dernières.
const communityPageSize = 20;
const discussionPageSize = 50;

/// « Voir plus » en bout de liste : charge la page suivante. [loading] :
/// rechargement en cours, l'indicateur remplace le bouton.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                ),
              )
            : TextButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
