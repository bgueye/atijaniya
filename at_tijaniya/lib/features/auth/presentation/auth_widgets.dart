// Éléments communs aux écrans du parcours d'entrée (refonte du 2026-11-03,
// maquette `docs/maquettes/parcours-entree.html`) : style des titres, bouton
// « Afficher » / « Masquer » d'un mot de passe, et règles du mot de passe
// cochées pendant la saisie (création de compte et nouveau mot de passe).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Titre d'un écran du parcours d'entrée : Cormorant en français ; Amiri en
/// arabe, puisque Cormorant n'a pas de glyphes arabes (même règle que les
/// titres des fiches de détail ; Amiri est permise pour les titres arabes).
TextStyle entryTitleStyle(BuildContext context, {double fontSize = 26, Color? color}) {
  final ink = color ?? AppColors.ink;
  if (Localizations.localeOf(context).languageCode == 'ar') {
    return AppTheme.sacredText(fontSize: fontSize * 0.85, color: ink)
        .copyWith(height: 1.45, fontWeight: FontWeight.w700);
  }
  return AppTheme.titleText(fontSize: fontSize, color: ink, height: 1.15);
}

/// « Afficher » / « Masquer » en toutes lettres dans le champ, au lieu d'une
/// icône d'œil (maquette). L'infobulle et le lecteur d'écran gardent le
/// libellé complet de l'action réelle (« Afficher le mot de passe », audit
/// du 2026-10-27, P3-3).
class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({super.key, required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Tooltip(
        message: obscured ? l10n.a11yShowPassword : l10n.a11yHidePassword,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: obscured ? l10n.a11yShowPassword : l10n.a11yHidePassword,
          excludeSemantics: true,
          onTap: onPressed,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emerald,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(obscured ? l10n.authShowPassword : l10n.authHidePassword),
          ),
        ),
      ),
    );
  }
}

/// Une règle et son état.
typedef PasswordRule = ({String label, bool met});

/// Règles d'un nouveau mot de passe, pour [password] :
/// - « 8 caractères minimum », la seule qui bloque (même seuil que le
///   validateur et que la configuration Supabase) ;
/// - « Des lettres et au moins un chiffre (conseillé) », un simple conseil.
List<PasswordRule> newPasswordRules(String password, AppLocalizations l10n) => [
      (label: l10n.authPasswordMinCharsHint, met: password.length >= 8),
      (
        label: l10n.authPasswordRuleLetters,
        met: RegExp(r'\d').hasMatch(password) && RegExp(r'[^\d\s]').hasMatch(password),
      ),
    ];

/// Liste de règles cochées en direct, sous le champ concerné, au lieu d'une
/// erreur après coup (maquette). Une règle remplie passe en émeraude avec sa
/// coche ; son état est dit au lecteur d'écran.
class PasswordRulesList extends StatelessWidget {
  const PasswordRulesList({super.key, required this.rules});

  final List<PasswordRule> rules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in rules)
            Semantics(
              label: '${rule.label}, ${rule.met ? l10n.authRuleMet : l10n.authRuleUnmet}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rule.met ? AppColors.emerald : Colors.transparent,
                        border: Border.all(
                          color: rule.met ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.5),
                          width: 1.4,
                        ),
                      ),
                      child: rule.met ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        rule.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: rule.met ? AppColors.emerald : AppColors.secondaryInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
