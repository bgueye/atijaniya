/// Feuille de modification d'une publication, ouverte depuis son détail
/// (`post_detail_screen.dart`). Sortie de cet écran lors de l'audit
/// Communauté du 2026-10-26 (P3-9), qui dépassait 800 lignes ; comportement
/// inchangé.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/validation/text_limits.dart';
import '../../../l10n/app_localizations.dart';
import 'community_providers.dart';

/// Résultat retourné par `EditPostSheet` une fois l'enregistrement réussi —
/// permet à `PostDetailScreen` de mettre à jour son état local sans recharger
/// la publication depuis le serveur.
class EditPostResult {
  const EditPostResult({required this.contentText, required this.mediaUrl});

  final String contentText;
  final String? mediaUrl;
}

/// Modale d'édition d'une publication — même structure que `_CreatePostSheet`
/// (communaute_screen.dart), mais pré-remplie et appuyée sur `updatePost`
/// plutôt que `createPost`. [initialMediaUrl] non nul affiche l'image déjà
/// jointe avec une option de retrait, cohérent avec le fait qu'une
/// publication existante peut avoir été créée avec ou sans image.
class EditPostSheet extends ConsumerStatefulWidget {
  const EditPostSheet({
    super.key,
    required this.postId,
    required this.initialContentText,
    required this.initialMediaUrl,
  });

  final String postId;
  final String initialContentText;
  final String? initialMediaUrl;

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _contentController = TextEditingController(text: widget.initialContentText);
  final _imageUploadService = ImageUploadService();
  bool _saving = false;

  // Distingue "garder l'image existante" (_pickedImageBytes null,
  // _removeExistingImage false) de "en choisir une nouvelle"
  // (_pickedImageBytes non null) et de "la retirer" (_removeExistingImage
  // true) — trois états nécessaires puisqu'une image déjà en ligne n'a pas
  // de bytes locaux à afficher directement via Image.memory.
  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  bool _removeExistingImage = false;

  /// Message d'échec, affiché dans la feuille : la `SnackBar` utilisée
  /// jusqu'ici s'affichait sous la feuille modale, donc invisible.
  String? _error;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final file = await _imageUploadService.pickImage(source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = imageExtensionFromPath(file.path);
      _removeExistingImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExtension = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    String? uploadedUrl;
    try {
      String? mediaUrl = widget.initialMediaUrl;
      if (_pickedImageBytes != null) {
        final userId = SupabaseConfig.client.auth.currentUser!.id;
        mediaUrl = await _imageUploadService.uploadImage(
          bucket: 'post-media',
          path: '$userId/${DateTime.now().microsecondsSinceEpoch}.$_pickedImageExtension',
          bytes: _pickedImageBytes!,
          contentType: imageContentTypeForExtension(_pickedImageExtension!),
        );
        uploadedUrl = mediaUrl;
      } else if (_removeExistingImage) {
        mediaUrl = null;
      }
      final contentText = _contentController.text.trim();
      await ref.read(communityRepositoryProvider).updatePost(
            widget.postId,
            contentText,
            mediaUrl: mediaUrl,
            previousMediaUrl: widget.initialMediaUrl,
          );
      if (mounted) {
        Navigator.of(context).pop(EditPostResult(contentText: contentText, mediaUrl: mediaUrl));
      }
    } catch (error) {
      // Nouvelle image téléversée mais publication non modifiée : retirée du
      // bucket public, comme à la création (audit du 2026-10-26, P1).
      await _imageUploadService.removeByPublicUrl(bucket: 'post-media', url: uploadedUrl);
      if (mounted) {
        setState(() => _error = isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityEditPostError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showExistingImage = _pickedImageBytes == null && !_removeExistingImage && widget.initialMediaUrl != null;

    // Mêmes choix (SafeArea + SingleChildScrollView) que _CreatePostSheet :
    // évite que le bouton "Enregistrer" se retrouve masqué sous la nav-bar
    // Android une fois une image affichée.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityEditPostTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLength: TextLimits.post,
                decoration: InputDecoration(labelText: l10n.communityEditPostContentLabel),
                maxLines: 5,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.communityEditPostContentRequired : null,
              ),
              const SizedBox(height: 12),
              if (_pickedImageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedImageBytes!, width: double.infinity, fit: BoxFit.fitWidth),
                ),
                const SizedBox(height: 8),
              ] else if (showExistingImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.initialMediaUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    // Voir la même note dans event_detail_screen.dart.
                    cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                    // Contrairement aux autres aperçus de ce fichier, celui-ci
                    // n'avait pas de repli en cas d'échec réseau — alignement
                    // sur le même pattern que ligne ~244 et communaute_screen.dart.
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _pickedImageBytes != null || showExistingImage ? l10n.imagePickerChange : l10n.imagePickerAdd,
                      ),
                    ),
                  ),
                  if (_pickedImageBytes != null || showExistingImage) ...[
                    const SizedBox(width: 8),
                    IconButton(
                        tooltip: AppLocalizations.of(context)!.a11yRemove,
                        icon: Icon(Icons.close, color: AppColors.bronze),
                        onPressed: _clearImage),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    // Émeraude : un indicateur blanc était invisible sur le gris du
                    // bouton désactivé (audit Communauté du 2026-10-26, P3-5).
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                      )
                    : Text(l10n.communityEditPostSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
