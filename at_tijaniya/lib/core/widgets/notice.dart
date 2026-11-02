// Kit de composants (docs/kit/components/Notice) : message d'état dans le
// corps d'un écran — liste vide, information, section hors ligne ou en
// erreur. Réunit deux traitements qui existaient séparément : `EmptyNotice`
// (information, depuis l'audit design pré-publication) et la carte d'erreur
// de `HomeNetworkSection` (audit de l'accueil du 2026-10-26, P2-2).

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../network/network_errors.dart';
import '../theme/app_colors.dart';
import 'content_text.dart';

class Notice extends StatelessWidget {
  /// Information ou liste vide : `emerald_soft`, icône `emerald`, texte
  /// `ink` en 12,5 (« Aucun évènement annoncé pour le moment. »).
  const Notice.info(this.message, {super.key, this.icon = Icons.info_outline})
      : onRetry = null,
        offline = false,
        _isError = false;

  /// Section qui n'a pas pu se charger : carte `off_white`, icône `bronze`
  /// (`wifi_off` hors ligne, `error_outline` sinon), « Réessayer ».
  ///
  /// Une section en erreur n'empêche jamais le reste de l'écran de
  /// s'afficher : ce composant remplace la section, pas l'écran.
  const Notice.error(this.message, {super.key, this.onRetry, this.offline = false})
      : icon = null,
        _isError = true;

  /// Erreur d'après l'exception reçue : hors ligne (message commun « Pas de
  /// connexion internet… ») si c'en est une, sinon [message], propre à la
  /// section.
  factory Notice.fromError(Object error, {Key? key, required String message, VoidCallback? onRetry}) {
    return Notice.error(message, key: key, onRetry: onRetry, offline: isNetworkError(error));
  }

  final String message;
  final IconData? icon;

  /// Action « Réessayer ». Sans elle, pas de bouton.
  final VoidCallback? onRetry;

  /// Hors ligne : icône `wifi_off` et message commun, quel que soit
  /// [message] — le disciple doit savoir que le problème vient de sa
  /// connexion, pas de l'app.
  final bool offline;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    if (!_isError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.emerald, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: ContentText(message, style: const TextStyle(color: AppColors.ink, fontSize: 12.5, height: 1.4)),
            ),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(14, 6, onRetry == null ? 14 : 4, 6),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bronze.withValues(alpha: AppColors.highContrastEnabled ? 0.75 : 0.2)),
      ),
      child: Row(
        children: [
          Icon(offline ? Icons.wifi_off : Icons.error_outline, color: AppColors.bronze, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              offline ? l10n.khadaraOfflineError : message,
              style: TextStyle(color: AppColors.secondaryInk, fontSize: 13, height: 1.4),
            ),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
