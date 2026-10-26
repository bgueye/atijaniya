import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import '../domain/zawiya_coordinates.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';

/// Création/édition d'une zawiya — réservé par RLS à un compte admin
/// (`zawiyas_admin_write`/`_update`, voir `canManageZawiyasProvider`) :
/// contrairement aux évènements Khadara, aucune exception mouqaddam ici.
///
/// `zawiya == null` → création ; sinon édition, préremplie synchroniquement
/// depuis l'objet déjà en mémoire (même pattern que `EventFormScreen`).
class ZawiyaFormScreen extends ConsumerStatefulWidget {
  const ZawiyaFormScreen({super.key, this.zawiya});

  final Zawiya? zawiya;

  @override
  ConsumerState<ZawiyaFormScreen> createState() => _ZawiyaFormScreenState();
}

class _ZawiyaFormScreenState extends ConsumerState<ZawiyaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  ZawiyaKind _kind = ZawiyaKind.zawiya;

  /// `zawiyas.coordinates_approximate` (audit Zawiyas du 2026-10-25, P2-2).
  bool _coordinatesApproximate = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final zawiya = widget.zawiya;
    if (zawiya != null) {
      _kind = zawiya.kind;
      _nameController.text = zawiya.name;
      _descriptionController.text = zawiya.description ?? '';
      _addressController.text = zawiya.addressText ?? '';
      _contactController.text = zawiya.contactInfo ?? '';
      _latitudeController.text = zawiya.latitude?.toString() ?? '';
      _longitudeController.text = zawiya.longitude?.toString() ?? '';
      _coordinatesApproximate = zawiya.coordinatesApproximate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  /// Message d'erreur d'un champ de coordonnée, ou `null` : nombre valide,
  /// dans les bornes, et les deux coordonnées ensemble ou aucune. La lecture
  /// est la même qu'à l'enregistrement (`parseZawiyaCoordinate`), chiffres
  /// arabo-indiens compris (audit Zawiyas du 2026-10-25, P2-9).
  String? _validateCoordinate(String? value, {required bool isLatitude, required AppLocalizations l10n}) {
    final other = isLatitude ? _longitudeController.text : _latitudeController.text;
    return switch (zawiyaCoordinateError(value ?? '', isLatitude: isLatitude, otherText: other)) {
      null => null,
      ZawiyaCoordinateError.invalid => l10n.zawiyaFormCoordinateInvalid,
      ZawiyaCoordinateError.outOfRange =>
        isLatitude ? l10n.zawiyaFormLatitudeOutOfRange : l10n.zawiyaFormLongitudeOutOfRange,
      ZawiyaCoordinateError.missingPair => l10n.zawiyaFormCoordinatesPairRequired,
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final descriptionText = _descriptionController.text.trim();
    final addressText = _addressController.text.trim();
    final contactText = _contactController.text.trim();

    try {
      final repo = ref.read(khadaraRepositoryProvider);
      final Zawiya saved;
      if (widget.zawiya == null) {
        saved = await repo.createZawiya(
          name: _nameController.text.trim(),
          kind: _kind,
          description: descriptionText.isEmpty ? null : descriptionText,
          latitude: parseZawiyaCoordinate(_latitudeController.text),
          longitude: parseZawiyaCoordinate(_longitudeController.text),
          addressText: addressText.isEmpty ? null : addressText,
          contactInfo: contactText.isEmpty ? null : contactText,
          coordinatesApproximate: _coordinatesApproximate,
        );
      } else {
        saved = await repo.updateZawiya(
          widget.zawiya!.id,
          name: _nameController.text.trim(),
          kind: _kind,
          description: descriptionText.isEmpty ? null : descriptionText,
          latitude: parseZawiyaCoordinate(_latitudeController.text),
          longitude: parseZawiyaCoordinate(_longitudeController.text),
          addressText: addressText.isEmpty ? null : addressText,
          contactInfo: contactText.isEmpty ? null : contactText,
          coordinatesApproximate: _coordinatesApproximate,
        );
      }
      ref.invalidate(zawiyasProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.zawiyaFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.zawiya != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              isEdit ? l10n.zawiyaFormEditTitle : l10n.zawiyaFormCreateTitle)),
      // `SafeArea` : évite que le bouton Enregistrer se retrouve masqué sous
      // la barre de navigation Android (3 boutons).
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration:
                      InputDecoration(labelText: l10n.zawiyaFormNameLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.zawiyaFormNameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ZawiyaKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.zawiyaFormKindLabel),
                  items: [
                    for (final kind in ZawiyaKind.values)
                      DropdownMenuItem<ZawiyaKind>(value: kind, child: Text(zawiyaKindLabel(kind, l10n))),
                  ],
                  onChanged: (value) => setState(() => _kind = value ?? ZawiyaKind.zawiya),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                      labelText: l10n.zawiyaFormDescriptionLabel),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration:
                      InputDecoration(labelText: l10n.zawiyaFormAddressLabel),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration:
                      InputDecoration(labelText: l10n.zawiyaFormContactLabel),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: InputDecoration(
                            labelText: l10n.zawiyaFormLatitudeLabel),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (value) => _validateCoordinate(value, isLatitude: true, l10n: l10n),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: InputDecoration(
                            labelText: l10n.zawiyaFormLongitudeLabel),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (value) => _validateCoordinate(value, isLatitude: false, l10n: l10n),
                      ),
                    ),
                  ],
                ),
                // Coordonnées connues à quelques kilomètres près : signalé
                // dans la fiche et devant les distances (P2-2).
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _coordinatesApproximate,
                  onChanged: (value) => setState(() => _coordinatesApproximate = value ?? false),
                  title: Text(l10n.zawiyaFormCoordinatesApproximate),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  ContentText(_errorMessage!,
                      style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.zawiyaFormSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
