// Titre de section de l'accueil (refonte du 2026-11-01) : Cormorant Garamond,
// police des titres de la charte, à la place des petites capitales grises.
// Annoncé comme titre au lecteur d'écran (audit de l'accueil P2-6).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.text, {super.key, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 24, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              // Cormorant en français, Amiri en arabe : les deux polices de
              // titre de la charte (design_tokens.yaml § typography).
              child: Text(
                text,
                style: Localizations.localeOf(context).languageCode == 'ar'
                    ? AppTheme.sacredText(fontSize: 20, color: AppColors.ink).copyWith(fontWeight: FontWeight.w700, height: 1.4)
                    : AppTheme.titleText(fontSize: 22, color: AppColors.ink, height: 1.15),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.emerald),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }
}
