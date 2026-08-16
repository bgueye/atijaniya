/// Gestion admin complète des récitations audio des piliers — ajout
/// (upload) et suppression, organisé par wird puis par pilier. Complète
/// `WirdRecitationsReviewScreen` (triage à plat des brouillons, qui garde
/// son rôle de relecture rapide) plutôt que de le remplacer : accessible
/// uniquement depuis son app bar, jamais directement depuis
/// `WirdListScreen` (une seule entrée admin visible, pas deux quasi
/// redondantes). Même garde-fou que le reste du module : cet écran ne
/// modifie jamais le texte d'un pilier (`wirds_content.dart` reste la
/// source unique, CLAUDE.md) — uniquement l'audio associé.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wird_audio_picker_service.dart';
import '../data/wird_recitation_repository.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';
import 'wird_recitation_providers.dart';

class WirdRecitationsManagementScreen extends ConsumerWidget {
  const WirdRecitationsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stepsAsync = ref.watch(allWirdStepRecitationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wirdRecitationsManageTitle)),
      body: stepsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.wirdRecitationsManageLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(allWirdStepRecitationsProvider),
                  child: Text(l10n.wirdRecitationsReviewRetry),
                ),
              ],
            ),
          ),
        ),
        data: (stepsByWird) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final wird in validatedWirds) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(wird.nameFrench,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 18)),
              ),
              for (final step
                  in stepsByWird[wird.id] ?? const <WirdStepRecitations>[])
                if (step.orderIndex - 1 < wird.pillars.length)
                  _PillarCard(
                    wird: wird,
                    pillar: wird.pillars[step.orderIndex - 1],
                    step: step,
                    l10n: l10n,
                  ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillarCard extends ConsumerWidget {
  const _PillarCard(
      {required this.wird,
      required this.pillar,
      required this.step,
      required this.l10n});

  final Wird wird;
  final WirdPillar pillar;
  final WirdStepRecitations step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pillar.transliteration,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (step.recitations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.wirdRecitationsManageEmpty,
                    style:
                        const TextStyle(color: AppColors.bronze, fontSize: 13)),
              )
            else
              for (final entry in step.recitations)
                _RecitationEntryTile(entry: entry, l10n: l10n),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openUploadSheet(context, ref),
                icon: const Icon(Icons.upload_file,
                    size: 18, color: AppColors.emerald),
                label: Text(l10n.wirdRecitationsManageAddButton,
                    style: const TextStyle(color: AppColors.emerald)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUploadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _UploadRecitationSheet(wird: wird, step: step, l10n: l10n),
    );
  }
}

class _RecitationEntryTile extends ConsumerStatefulWidget {
  const _RecitationEntryTile({required this.entry, required this.l10n});

  final WirdRecitationEntry entry;
  final AppLocalizations l10n;

  @override
  ConsumerState<_RecitationEntryTile> createState() =>
      _RecitationEntryTileState();
}

class _RecitationEntryTileState extends ConsumerState<_RecitationEntryTile> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isLoadingPreview = false;
  String? _previewError;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  /// Même logique que `WirdRecitationsReviewScreen._DraftCard._togglePreview` :
  /// fichier temporaire dédié, jamais le cache disciple.
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
          .downloadAudioBytes(widget.entry.audioPath);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wird_recitation_manage_preview.audio');
      await file.writeAsBytes(bytes, flush: true);
      await _previewPlayer.setFilePath(file.path);
      await _previewPlayer.play();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _previewError = widget.l10n.wirdRecitationsReviewPreviewError);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _validate() async {
    await ref
        .read(wirdRecitationRepositoryProvider)
        .validateRecitation(widget.entry.id);
    ref.invalidate(allWirdStepRecitationsProvider);
  }

  Future<void> _confirmAndDelete() async {
    final l10n = widget.l10n;
    final isLiveDefault =
        widget.entry.contentStatus == 'valide' && widget.entry.isDefault;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.wirdRecitationsManageDeleteConfirmTitle),
        content: Text(isLiveDefault
            ? l10n.wirdRecitationsManageDeleteConfirmBodyLive
            : l10n.wirdRecitationsManageDeleteConfirmBodyDraft),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.wirdRecitationsReviewCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.wirdRecitationsReviewDelete,
                style: const TextStyle(color: AppColors.bronze)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(wirdRecitationRepositoryProvider).deleteRecitation(
            recitationId: widget.entry.id,
            audioPath: widget.entry.audioPath,
          );
      ref.invalidate(allWirdStepRecitationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.wirdRecitationsManageDeleteSuccess)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.wirdRecitationsManageDeleteError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isDraft = entry.contentStatus == 'brouillon';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isLoadingPreview
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.emerald)),
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
                          color: AppColors.emerald),
                      onPressed: _togglePreview,
                    );
                  },
                ),
          title: Text('${entry.reciterName} · v${entry.contentVersion}'),
          subtitle: Text(
            isDraft
                ? widget.l10n.wirdRecitationsManageStatusDraft
                : widget.l10n.wirdRecitationsManageStatusValidated,
            style: TextStyle(
                color: isDraft ? AppColors.bronze : AppColors.emerald,
                fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDraft)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppColors.emerald),
                  tooltip: widget.l10n.wirdRecitationsManageValidate,
                  onPressed: _validate,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.bronze),
                tooltip: widget.l10n.wirdRecitationsReviewDelete,
                onPressed: _confirmAndDelete,
              ),
            ],
          ),
        ),
        if (_previewError != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(_previewError!,
                style: const TextStyle(color: AppColors.bronze, fontSize: 12)),
          ),
      ],
    );
  }
}

class _UploadRecitationSheet extends ConsumerStatefulWidget {
  const _UploadRecitationSheet(
      {required this.wird, required this.step, required this.l10n});

  final Wird wird;
  final WirdStepRecitations step;
  final AppLocalizations l10n;

  @override
  ConsumerState<_UploadRecitationSheet> createState() =>
      _UploadRecitationSheetState();
}

class _UploadRecitationSheetState
    extends ConsumerState<_UploadRecitationSheet> {
  final _reciterController =
      TextEditingController(text: 'Récitation de référence');
  final _picker = WirdAudioPickerService();

  PlatformFile? _pickedFile;
  String? _pickedFileName;
  bool _uploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reciterController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await _picker.pickAudioFile();
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _pickedFileName = file.name;
    });
  }

  Future<void> _submit() async {
    final file = _pickedFile;
    if (file == null) return;
    final bytes = file.bytes;
    final extension = wirdAudioExtensionFromPath(file.name);
    if (bytes == null || extension == null) {
      setState(
          () => _errorMessage = widget.l10n.wirdRecitationsManageUploadError);
      return;
    }

    setState(() {
      _uploading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(wirdRecitationRepositoryProvider).uploadRecitation(
            wirdStepId: widget.step.wirdStepId,
            wirdKey: widget.wird.id,
            orderIndex: widget.step.orderIndex,
            contentVersion: nextContentVersionFor(widget.step.recitations),
            reciterName: _reciterController.text.trim().isEmpty
                ? 'Récitation de référence'
                : _reciterController.text.trim(),
            bytes: bytes,
            extension: extension,
          );
      ref.invalidate(allWirdStepRecitationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(widget.l10n.wirdRecitationsManageUploadSuccess)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorMessage = widget.l10n.wirdRecitationsManageUploadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SafeArea(
      // `bottom: true` (défaut) évite que "Téléverser" se retrouve sous la
      // barre de navigation système (3 boutons) — `viewInsets.bottom` seul
      // ne couvre que le clavier, jamais la zone système.
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _reciterController,
              decoration: InputDecoration(
                  labelText: l10n.wirdRecitationsManageUploadReciterLabel),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.audio_file),
              label: Text(
                  _pickedFileName ?? l10n.wirdRecitationsManageUploadPickFile),
            ),
            if (_pickedFileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.wirdRecitationsManageUploadFileChosen(_pickedFileName!),
                  style: const TextStyle(fontSize: 12, color: AppColors.bronze),
                ),
              ),
            const SizedBox(height: 8),
            Text(l10n.wirdRecitationsManageUploadHint,
                style: const TextStyle(fontSize: 12, color: AppColors.bronze)),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!,
                    style:
                        const TextStyle(color: AppColors.bronze, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_pickedFile == null || _uploading) ? null : _submit,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l10n.wirdRecitationsManageUploadSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
