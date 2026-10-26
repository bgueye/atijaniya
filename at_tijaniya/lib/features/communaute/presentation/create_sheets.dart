/// Feuilles de création d'une publication et d'un groupe, ouvertes depuis
/// l'onglet Communauté (`communaute_screen.dart`). Sorties de cet écran lors
/// de l'audit Communauté du 2026-10-26 (P3-9), qui dépassait 800 lignes ;
/// comportement inchangé.
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
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_providers.dart';
import 'community_providers.dart';
import 'groups_providers.dart';

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key, required this.zawiyaId, this.zawiyaName});

  final String zawiyaId;
  final String? zawiyaName;

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imageUploadService = ImageUploadService();
  bool _saving = false;

  /// Message d'échec de l'envoi, affiché dans la feuille : une `SnackBar`
  /// s'afficherait sous la feuille modale, donc invisible.
  String? _error;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;

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
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExtension = null;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    String? mediaUrl;
    try {
      if (_pickedImageBytes != null) {
        final userId = SupabaseConfig.client.auth.currentUser!.id;
        mediaUrl = await _imageUploadService.uploadImage(
          bucket: 'post-media',
          path: '$userId/${DateTime.now().microsecondsSinceEpoch}.$_pickedImageExtension',
          bytes: _pickedImageBytes!,
          contentType: imageContentTypeForExtension(_pickedImageExtension!),
        );
      }
      await ref.read(communityRepositoryProvider).createPost(
            _contentController.text.trim(),
            zawiyaId: widget.zawiyaId,
            mediaUrl: mediaUrl,
          );
      ref.invalidate(communityFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Audit du 2026-10-26 (P1) : l'échec (réseau coupé, refus du serveur)
      // restait muet, le bouton se réactivait et le disciple croyait avoir
      // publié. Le texte reste dans le champ. L'image déjà téléversée est
      // retirée : elle restait sinon dans le bucket public, et chaque
      // nouvelle tentative en ajoutait une.
      await _imageUploadService.removeByPublicUrl(bucket: 'post-media', url: mediaUrl);
      if (mounted) {
        setState(() => _error = isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityCreatePostError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // `SafeArea` : évite que le bouton Publier se retrouve masqué sous la
    // barre de navigation Android (3 boutons) — `viewInsets.bottom` seul ne
    // couvre que le clavier, jamais la zone système.
    // `SingleChildScrollView` : une fois une image ajoutée, le contenu peut
    // dépasser la hauteur du bottom sheet (contraint à l'écran) ; sans lui,
    // le `Column` déborde silencieusement et les boutons "Changer l'image"
    // / "Publier" se retrouvent hors champ, masqués sous la nav-bar Android.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityCreatePostTitle, style: Theme.of(context).textTheme.titleLarge),
              if (widget.zawiyaName != null) ...[
                const SizedBox(height: 4),
                Text(
                  // « Publié au nom de votre zawiya » contredisait l'affichage
                  // « disciple · zawiya » décidé le 2026-10-06 (audit
                  // Communauté du 2026-10-26, P3-4).
                  l10n.communityCreatePostZawiyaShown(widget.zawiyaName!),
                  style: TextStyle(color: AppColors.secondaryInk, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLength: TextLimits.post,
                decoration: InputDecoration(labelText: l10n.communityCreatePostContentLabel),
                maxLines: 5,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.communityCreatePostContentRequired : null,
              ),
              const SizedBox(height: 12),
              if (_pickedImageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedImageBytes!, width: double.infinity, fit: BoxFit.fitWidth),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_pickedImageBytes != null ? l10n.imagePickerChange : l10n.imagePickerAdd),
                    ),
                  ),
                  if (_pickedImageBytes != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.a11yRemove,
                      icon: Icon(Icons.close, color: AppColors.bronze),
                      onPressed: _clearImage,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) _SheetError(_error!),
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
                    : Text(l10n.communityCreatePostSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _regionController = TextEditingController();
  String? _zawiyaId;
  bool _saving = false;

  /// Message d'échec de la création, affiché dans la feuille (voir
  /// `_CreatePostSheetState._error`).
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(groupsRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            zawiyaId: _zawiyaId,
            regionText: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
          );
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Audit du 2026-10-26 (P1) : l'échec restait muet, comme pour la
      // publication. Les champs gardent leur saisie.
      if (mounted) {
        setState(() => _error = isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityGroupsCreateError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Rattachement : uniquement les zawiyas proprement dites, pas les lieux
    // saints ni les mosquées de l'annuaire (voir `attachableZawiyas`).
    final zawiyas = ref.watch(attachableZawiyasProvider);

    // `SafeArea` : évite que le bouton Créer se retrouve masqué sous la
    // barre de navigation Android (3 boutons) — `viewInsets.bottom` seul ne
    // couvre que le clavier, jamais la zone système. `SingleChildScrollView`
    // (même choix que CreatePostSheet) : évite un overflow du formulaire
    // une fois le clavier affiché avec une description longue.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityGroupsCreateTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                maxLength: TextLimits.groupName,
                decoration: InputDecoration(labelText: l10n.communityGroupsNameLabel),
                validator: (value) => (value == null || value.trim().isEmpty) ? l10n.communityGroupsNameRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLength: TextLimits.groupDescription,
                decoration: InputDecoration(labelText: l10n.communityGroupsDescriptionLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              zawiyas.when(
                loading: () => LinearProgressIndicator(color: AppColors.emerald),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (list) => DropdownButtonFormField<String?>(
                  // `isExpanded` + ellipsis : sans eux la liste prend la largeur du
                  // nom le plus long et déborde ("right overflowed") avec les noms de
                  // zawiyas ajoutés fin septembre — constaté sur téléphone le 2026-10-01.
                  isExpanded: true,
                  initialValue: _zawiyaId,
                  decoration: InputDecoration(labelText: l10n.communityGroupsZawiyaLabel),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('—')),
                    ...list.map((z) => DropdownMenuItem<String?>(
                        value: z.id, child: ContentText(z.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() => _zawiyaId = value),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                maxLength: TextLimits.groupRegion,
                decoration: InputDecoration(labelText: l10n.communityGroupsRegionLabel),
              ),
              const SizedBox(height: 24),
              if (_error != null) _SheetError(_error!),
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
                    : Text(l10n.communityGroupsCreateSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Échec d'un envoi, affiché au-dessus du bouton d'une feuille modale et
/// annoncé au lecteur d'écran.
class _SheetError extends StatelessWidget {
  const _SheetError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(message, style: const TextStyle(color: AppColors.danger)),
      ),
    );
  }
}
