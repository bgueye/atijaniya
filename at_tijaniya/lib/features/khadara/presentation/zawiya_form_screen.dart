import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'khadara_providers.dart';

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

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final zawiya = widget.zawiya;
    if (zawiya != null) {
      _nameController.text = zawiya.name;
      _descriptionController.text = zawiya.description ?? '';
      _addressController.text = zawiya.addressText ?? '';
      _contactController.text = zawiya.contactInfo ?? '';
      _latitudeController.text = zawiya.latitude?.toString() ?? '';
      _longitudeController.text = zawiya.longitude?.toString() ?? '';
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

  /// `null` pour un champ vide (optionnel) ; sinon la valeur parsée, jamais
  /// levée d'exception ici — la validation du format est faite par le
  /// `validator` du champ, cette méthode n'est appelée qu'après validation.
  double? _parseOptionalDouble(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.parse(trimmed.replaceAll(',', '.'));
  }

  String? _validateOptionalDouble(String? value, AppLocalizations l10n) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.')) == null ? l10n.zawiyaFormCoordinateInvalid : null;
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
          description: descriptionText.isEmpty ? null : descriptionText,
          latitude: _parseOptionalDouble(_latitudeController.text),
          longitude: _parseOptionalDouble(_longitudeController.text),
          addressText: addressText.isEmpty ? null : addressText,
          contactInfo: contactText.isEmpty ? null : contactText,
        );
      } else {
        saved = await repo.updateZawiya(
          widget.zawiya!.id,
          name: _nameController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          latitude: _parseOptionalDouble(_latitudeController.text),
          longitude: _parseOptionalDouble(_longitudeController.text),
          addressText: addressText.isEmpty ? null : addressText,
          contactInfo: contactText.isEmpty ? null : contactText,
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
      appBar: AppBar(title: Text(isEdit ? l10n.zawiyaFormEditTitle : l10n.zawiyaFormCreateTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.zawiyaFormNameLabel),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.zawiyaFormNameRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.zawiyaFormDescriptionLabel),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: l10n.zawiyaFormAddressLabel),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(labelText: l10n.zawiyaFormContactLabel),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: InputDecoration(labelText: l10n.zawiyaFormLatitudeLabel),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) => _validateOptionalDouble(value, l10n),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: InputDecoration(labelText: l10n.zawiyaFormLongitudeLabel),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) => _validateOptionalDouble(value, l10n),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.zawiyaFormSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
