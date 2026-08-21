/// Review admin des récitations audio en brouillon — seul écran de l'app
/// permettant d'écouter un brouillon avant publication et de le faire
/// passer à `content_status = 'valide'`
/// (docs/decision-gestion-audio-wirds.md §7). Accessible uniquement depuis
/// `WirdListScreen` quand `isAdminProvider` vaut `true` (voir
/// `profile_providers.dart`) ; la RLS `wird_recitations_admin_update`
/// refuse de toute façon l'écriture à tout autre compte, même si cet écran
/// était atteint par erreur.
///
/// "Mouqaddam vérifié" n'accorde aucun droit ici — seul `profiles.is_admin`
/// compte, même principe que `FiguresReviewScreen`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_recitation.dart';
import 'wird_recitation_providers.dart';
import 'wird_recitations_management_screen.dart';

class WirdRecitationsReviewScreen extends ConsumerWidget {
  const WirdRecitationsReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final draftsAsync = ref.watch(draftWirdRecitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wirdRecitationsReviewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music_outlined),
            tooltip: l10n.wirdRecitationsReviewManageButton,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const WirdRecitationsManagementScreen()),
            ),
          ),
        ],
      ),
      body: draftsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(
                  l10n.wirdRecitationsReviewLoadError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(draftWirdRecitationsProvider),
                  child: Text(l10n.wirdRecitationsReviewRetry),
                ),
              ],
            ),
          ),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.wirdRecitationsReviewEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _DraftCard(draft: drafts[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({required this.draft, required this.l10n});

  final WirdRecitationDraft draft;
  final AppLocalizations l10n;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isLoadingPreview = false;
  String? _previewError;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  /// Écoute d'un brouillon — jamais via `WirdRecitationDownloadStore` (le
  /// cache "disciple", réservé au contenu déjà validé) : téléchargement
  /// direct vers un fichier temporaire, propre à cette prévisualisation.
  Future<void> _togglePreview() async {
    if (_previewPlayer.playing) {
      await _previewPlayer.pause();
      return;
    }
    if (_previewPlayer.duration != null) {
      await _previewPlayer.play();
      return;
    }
    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });
    try {
      final bytes = await ref
          .read(wirdRecitationRepositoryProvider)
          .downloadAudioBytes(widget.draft.audioPath);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wird_recitation_review_preview.audio');
      await file.writeAsBytes(bytes, flush: true);
      await _previewPlayer.setFilePath(file.path);
      await _previewPlayer.play();
    } catch (_) {
      if (mounted) {
        setState(
            () => _previewError = widget.l10n.wirdRecitationsReviewPreviewError);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _confirmAndValidate(BuildContext context) async {
    final l10n = widget.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.wirdRecitationsReviewConfirmTitle),
        content: Text(l10n.wirdRecitationsReviewConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.wirdRecitationsReviewCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.wirdRecitationsReviewConfirmAction,
                style: TextStyle(color: AppColors.emerald)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(wirdRecitationRepositoryProvider)
        .validateRecitation(widget.draft.id);
    ref.invalidate(draftWirdRecitationsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(l10n.wirdRecitationsReviewSuccess)));
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final l10n = widget.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.wirdRecitationsReviewDeleteConfirmTitle),
        content: Text(l10n.wirdRecitationsReviewDeleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.wirdRecitationsReviewCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.wirdRecitationsReviewDelete,
                style: TextStyle(color: AppColors.bronze)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(wirdRecitationRepositoryProvider).deleteRecitation(
            recitationId: widget.draft.id,
            audioPath: widget.draft.audioPath,
          );
      ref.invalidate(draftWirdRecitationsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.wirdRecitationsReviewDeleteSuccess)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.wirdRecitationsReviewDeleteError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _isLoadingPreview
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.emerald),
                      ),
                    )
                  : StreamBuilder<PlayerState>(
                      stream: _previewPlayer.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: AppColors.emerald,
                          ),
                          onPressed: _togglePreview,
                        );
                      },
                    ),
              title: Text('${draft.wirdNameFrench} — ${draft.pillarLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(draft.reciterName),
            ),
            if (_previewError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_previewError!,
                    style:
                        TextStyle(color: AppColors.bronze, fontSize: 12)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmAndDelete(context),
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.bronze),
                  label: Text(widget.l10n.wirdRecitationsReviewDelete,
                      style: TextStyle(color: AppColors.bronze)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmAndValidate(context),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(widget.l10n.wirdRecitationsReviewValidate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
