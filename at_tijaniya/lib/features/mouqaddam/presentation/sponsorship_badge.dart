import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Badge « Parrainage confirmé » (CLAUDE.md, « Libellé UI du badge »).
///
/// En base le statut reste `mouqaddam_status.status = 'verified'`, mais ce
/// mot ne s'affiche jamais : il laisserait entendre une reconnaissance
/// religieuse officielle que l'application n'a ni la légitimité ni
/// l'intention de délivrer. Le badge est donc indissociable de son
/// explication — un tap ouvre toujours le texte qui précise ce qu'il atteste
/// et ce qu'il n'est pas. Ne pas afficher le libellé seul ailleurs : passer
/// par ce widget.
///
/// Ajouté lors de l'audit du 2026-10-04 (point S67) : la règle existait,
/// mais ni le badge ni l'explication n'étaient implémentés.
class SponsorshipBadge extends StatelessWidget {
  const SponsorshipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.sponsorshipBadgeLabel,
      hint: l10n.sponsorshipBadgeExplanationTitle,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.sponsorshipBadgeLabel),
            content: Text(l10n.sponsorshipBadgeExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
              ),
            ],
          ),
        ),
        // Zone tactile d'au moins 48 px de haut, même si le badge est petit.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 8, 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.emerald),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.sponsorshipBadgeLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline, size: 14, color: AppColors.emerald),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
