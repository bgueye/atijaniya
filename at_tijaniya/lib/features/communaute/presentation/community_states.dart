import 'package:flutter/material.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// États d'erreur et vides partagés par les écrans de l'onglet Communauté
/// (audit Communauté du 2026-10-26, P3-3). Chaque écran avait sa copie : le
/// hors ligne n'était distingué nulle part, la discussion de groupe et les
/// directs passés n'offraient pas « Réessayer », et les états vides se
/// contentaient de « Aucun… pour le moment » sans dire comment commencer.

/// Erreur de chargement : message de connexion si [error] est une erreur
/// réseau, sinon [message] ; toujours un bouton « Réessayer ».
class CommunityErrorState extends StatelessWidget {
  const CommunityErrorState({super.key, required this.error, required this.message, required this.onRetry});

  final Object error;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final offline = isNetworkError(error);
    return _CenteredState(
      icon: offline ? Icons.wifi_off : Icons.error_outline,
      message: offline ? l10n.khadaraOfflineError : message,
      action: OutlinedButton(onPressed: onRetry, child: Text(l10n.communityRetry)),
    );
  }
}

/// Liste vide : [message] dit comment commencer, [actionLabel] / [onAction]
/// proposent de le faire tout de suite.
class CommunityEmptyState extends StatelessWidget {
  const CommunityEmptyState({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: icon,
      message: message,
      action: actionLabel == null ? null : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
    );
  }
}

/// Centré dans la hauteur disponible mais défilable : « tirer pour
/// actualiser » doit marcher aussi sur un état vide ou d'erreur.
class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.bronze, size: 32),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
