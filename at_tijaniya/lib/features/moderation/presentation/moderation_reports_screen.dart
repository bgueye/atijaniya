import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/moderation_models.dart';
import 'moderation_providers.dart';

/// Écran admin de modération a posteriori (Sprint 2, P3) : file des
/// signalements en attente sur les directs Khadara et les demandes de mise
/// en relation par lignée spirituelle, seuls contenus signalables en V1
/// (docs/01-perimetre-fonctionnel.md §6). Accessible uniquement depuis
/// `ProfilScreen` quand `isAdminProvider` vaut `true` — même garde-fou que
/// les autres écrans admin de l'app, la RLS `content_reports_admin_read`/
/// `_update` refuse de toute façon tout autre compte.
class ModerationReportsScreen extends ConsumerWidget {
  const ModerationReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(pendingReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationScreenTitle)),
      body: reportsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.moderationLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(pendingReportsProvider),
                  child: Text(l10n.moderationRetry),
                ),
              ],
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.moderationEmptyState, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReportCard(item: reports[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.item, required this.l10n});

  final ReportWithPreview item;
  final AppLocalizations l10n;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  String _typeLabel() {
    final l10n = widget.l10n;
    return switch (widget.item.report.contentType) {
      ReportableContentType.liveStream => l10n.moderationTypeLiveStream,
      ReportableContentType.lineageConnectionRequest => l10n.moderationTypeLineageRequest,
    };
  }

  Future<void> _resolve({required bool takeAction}) async {
    final l10n = widget.l10n;
    if (takeAction) {
      final confirmed = await _confirmAction(context);
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(moderationRepositoryProvider).resolveReport(
            reportId: widget.item.report.id,
            contentType: widget.item.report.contentType,
            contentId: widget.item.report.contentId,
            takeAction: takeAction,
          );
      ref.invalidate(pendingReportsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.moderationResolveSuccess)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.moderationResolveError)));
      }
    }
  }

  Future<bool?> _confirmAction(BuildContext context) {
    final l10n = widget.l10n;
    final isStream = widget.item.report.contentType == ReportableContentType.liveStream;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isStream ? l10n.moderationConfirmHideStreamTitle : l10n.moderationConfirmBlockRequestTitle),
        content: Text(isStream ? l10n.moderationConfirmHideStreamBody : l10n.moderationConfirmBlockRequestBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              isStream ? l10n.moderationHideStreamAction : l10n.moderationBlockRequestAction,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final report = widget.item.report;
    final isStream = report.contentType == ReportableContentType.liveStream;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_typeLabel(), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.emerald)),
            const SizedBox(height: 4),
            Text(widget.item.preview ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
            if (report.reason != null && report.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.moderationReasonPrefix(report.reason!),
                style: TextStyle(color: AppColors.bronze, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _resolve(takeAction: false),
                  child: Text(l10n.moderationDismissAction),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _resolve(takeAction: true),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: Text(isStream ? l10n.moderationHideStreamAction : l10n.moderationBlockRequestAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
