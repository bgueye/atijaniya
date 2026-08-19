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

  // `_ReportDialogContent` possède et détruit son propre contrôleur — ne pas
  // le créer/disposer ici. Le `Future` de `showDialog` se résout dès l'appel
  // à `Navigator.pop`, *avant* la fin de l'animation de fermeture : le
  // `TextField` reste dans l'arbre pendant encore quelques frames. Disposer
  // le contrôleur immédiatement après l'`await` (comme avant) le détruit
  // pendant que ce `TextField` encore affiché essaie de s'en servir →
  // assertion framework `_dependents.isEmpty` et écran rouge. Reproduit et
  // confirmé en conditions réelles le 2026-08-19 (signalement d'un direct
  // Khadara) ; en confiant le contrôleur au cycle de vie du `State`, Flutter
  // ne le détruit qu'au démontage réel du dialogue (après l'animation).
  final reasonText = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _ReportDialogContent(l10n: l10n),
  );

  if (reasonText == null || !context.mounted) return;

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

class _ReportDialogContent extends StatefulWidget {
  const _ReportDialogContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.moderationReportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moderationReportDialogBody),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(labelText: l10n.moderationReportReasonLabel),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reasonController.text),
          child: Text(l10n.moderationReportSubmit),
        ),
      ],
    );
  }
}
