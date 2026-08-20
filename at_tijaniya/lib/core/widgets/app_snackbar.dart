// At-Tijaniya — snackbar d'erreur partagé.
//
// Par défaut, Flutter/Material 3 rend un SnackBar avec `inverseSurface`/
// `onInverseSurface` — dans app_theme.dart ces rôles sont mappés sur
// AppColors.ink/parchment (fond noir, texte blanc), un rendu jugé trop dur
// pour un message d'erreur. `showErrorSnackBar` utilise à la place
// `colorScheme.error`/`onError` (déjà défini dans app_theme.dart), pour que
// les messages d'erreur restent cohérents avec la charte plutôt que le
// fallback Material générique.
import 'package:flutter/material.dart';

void showErrorSnackBar(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: colorScheme.error,
      content: Text(message, style: TextStyle(color: colorScheme.onError)),
    ));
}
