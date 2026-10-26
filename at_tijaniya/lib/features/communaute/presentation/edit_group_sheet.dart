/// Feuille de modification d'un groupe, ouverte depuis son détail
/// (`group_detail_screen.dart`). Sortie de cet écran lors de l'audit
/// Communauté du 2026-10-26 (P3-9), qui dépassait 900 lignes ; comportement
/// inchangé.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/text_limits.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../domain/group_models.dart';
import 'groups_providers.dart';

/// Résultat retourné par `EditGroupSheet` une fois l'enregistrement réussi
/// — `GroupsRepository.updateGroup` ne renvoie pas la ligne mise à jour
/// (contrairement à `KhadaraRepository.updateZawiya`), donc l'appelant
/// reconstruit l'objet `Group` localement à partir de ce résultat.
class EditGroupResult {
  const EditGroupResult({
    required this.name,
    required this.description,
    required this.zawiyaId,
    required this.zawiyaName,
    required this.regionText,
  });

  final String name;
  final String? description;
  final String? zawiyaId;
  final String? zawiyaName;
  final String? regionText;
}

/// Modale d'édition d'un groupe — mêmes champs que `_CreateGroupSheet`
/// (communaute_screen.dart), pré-remplis, appuyée sur `updateGroup` plutôt
/// que `createGroup`.
class EditGroupSheet extends ConsumerStatefulWidget {
  const EditGroupSheet({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.group.name);
  late final _descriptionController = TextEditingController(text: widget.group.description ?? '');
  late final _regionController = TextEditingController(text: widget.group.regionText ?? '');
  late String? _zawiyaId = widget.group.zawiyaId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Zawiya> zawiyas) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      final regionText = _regionController.text.trim().isEmpty ? null : _regionController.text.trim();
      await ref.read(groupsRepositoryProvider).updateGroup(
            widget.group.id,
            name: name,
            description: description,
            zawiyaId: _zawiyaId,
            regionText: regionText,
          );
      String? zawiyaName;
      for (final zawiya in zawiyas) {
        if (zawiya.id == _zawiyaId) {
          zawiyaName = zawiya.name;
          break;
        }
      }
      if (mounted) {
        Navigator.of(context).pop(EditGroupResult(
          name: name,
          description: description,
          zawiyaId: _zawiyaId,
          zawiyaName: zawiyaName,
          regionText: regionText,
        ));
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, l10n.communityGroupsEditError);
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

    // Mêmes choix (SafeArea + SingleChildScrollView) que _EditPostSheet
    // (post_detail_screen.dart) : évite que le bouton Enregistrer se
    // retrouve masqué sous la nav-bar Android, et surtout que le formulaire
    // déborde (overflow) une fois le clavier affiché avec une description
    // longue.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityGroupsEditTitle, style: Theme.of(context).textTheme.titleLarge),
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
              ElevatedButton(
                onPressed: _saving ? null : () => _submit(zawiyas.valueOrNull ?? const []),
                child: _saving
                    // Émeraude : un indicateur blanc était invisible sur le gris du
                    // bouton désactivé (audit Communauté du 2026-10-26, P3-5).
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                      )
                    : Text(l10n.communityGroupsEditSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
