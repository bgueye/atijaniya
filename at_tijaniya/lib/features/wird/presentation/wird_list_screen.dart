import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import 'wird_detail_screen.dart';

/// Liste des Wirds — Lazim, Wazifa, Hadratou-l-Jouma. Priorité P0.
///
/// Contenu listé issu de `data/wirds_content.dart` (corpus validé) — voir
/// la règle impérative en tête de ce fichier et de `CLAUDE.md`.
class WirdListScreen extends StatelessWidget {
  const WirdListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: validatedWirds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final wird = validatedWirds[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(wird.nameFrench, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              wird.frequency == WirdFrequency.daily ? 'Quotidien' : 'Hebdomadaire — vendredi',
              style: const TextStyle(color: AppColors.bronze),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)),
            ),
          ),
        );
      },
    );
  }
}
