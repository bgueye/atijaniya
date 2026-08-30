import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Notice compacte pour un état vide sur fond clair (ivoire parchemin) —
/// remplace un `Text` brut par un traitement cohérent avec les autres
/// notices informatives de l'app (ex. `_ScopeNote` dans
/// `wird_reminders_screen.dart`). Introduit après l'audit design
/// pré-publication Play Store : les états vides étaient jusque-là traités
/// différemment selon l'écran (texte brut sans mise en forme sur certains,
/// pill avec bordure sur d'autres).
class EmptyNotice extends StatelessWidget {
  const EmptyNotice({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emerald, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
