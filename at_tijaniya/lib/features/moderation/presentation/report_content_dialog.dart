import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/moderation_errors.dart';
import '../domain/moderation_models.dart';
import 'moderation_providers.dart';

/// Signaler un direct Khadara ou une demande de mise en relation par lignée
/// spirituelle — dialogue réutilisable, appelé depuis `LiveStreamScreen` et
/// `LineageMatchesScreen` (Sprint 2, P3). Raison libre optionnelle, pas de
/// liste de motifs prédéfinis : le volume attendu en V1 ne justifie pas cette
/// complexité (l'admin lit le texte libre depuis l'écran de modération).
Future<void> showReportContentDialog(
  BuildContext context,
  WidgetRef ref, {
  required ReportableContentType contentType,
  required String contentId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final reasonController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.moderationReportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moderationReportDialogBody),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(labelText: l10n.moderationReportReasonLabel),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.moderationReportSubmit),
        ),
      ],
    ),
  );

  final reasonText = reasonController.text;
  reasonController.dispose();
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(moderationRepositoryProvider).reportContent(
          type: contentType,
          contentId: contentId,
          reason: reasonText,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.moderationReportSuccess)));
    }
  } catch (error) {
    final kind = classifyReportError(error);
    final message = kind == ReportErrorKind.alreadyReported ? l10n.moderationReportAlreadyReported : l10n.moderationReportError;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
