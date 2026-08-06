import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';

/// Formulaire d'édition des infos de base du profil (nom, bio, zawiya) —
/// ouvert en bottom sheet depuis `ProfilScreen`. La lignée spirituelle et le
/// statut Mouqaddam ont leurs propres écrans dédiés (données sensibles, cf.
/// CLAUDE.md) : ce formulaire ne les touche jamais.
Future<void> showEditProfileSheet(BuildContext context, Profile profile) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.offWhite,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _EditProfileForm(profile: profile),
  );
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.profile.displayName);
  late final _bioController = TextEditingController(text: widget.profile.bio ?? '');
  late String? _zawiyaId = widget.profile.zawiyaId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            displayName: _nameController.text.trim(),
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
            zawiyaId: _zawiyaId,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.profileUpdateError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final zawiyas = ref.watch(zawiyasProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profileEditTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.profileDisplayNameLabel),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.profileDisplayNameRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: InputDecoration(labelText: l10n.profileBioLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            zawiyas.when(
              loading: () => const LinearProgressIndicator(color: AppColors.emerald),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: _zawiyaId,
                decoration: InputDecoration(labelText: l10n.profileZawiyaLabel),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l10n.profileZawiyaNone)),
                  ...list.map((z) => DropdownMenuItem<String?>(value: z.id, child: Text(z.name))),
                ],
                onChanged: (value) => setState(() => _zawiyaId = value),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.profileSave),
            ),
          ],
        ),
      ),
    );
  }
}
