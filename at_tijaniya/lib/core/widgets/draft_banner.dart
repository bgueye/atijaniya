// Bandeau « brouillon » : prévient l'admin qu'une page affiche aussi du
// contenu religieux encore en brouillon, qu'un disciple ne voit pas (la RLS ne
// lui renvoie que le contenu `valide`).
//
// Sorti le 2026-11-04 (mise au thème du kit) de « Rattraper son wird » et des
// « Bienfaits de la Tariqa », qui en avaient chacun une copie identique.
// Pas de fiche dans le kit : c'est un message réservé à l'administration,
// construit avec les jetons du kit (or doux, filet d'or, texte en encre —
// jamais en bronze, sous le seuil AA).

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';

class DraftBanner extends StatelessWidget {
  const DraftBanner(this.text, {super.key});

  /// Message déjà traduit (« Cette page contient du contenu en brouillon… »).
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, color: AppColors.ink, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: ContentText(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
