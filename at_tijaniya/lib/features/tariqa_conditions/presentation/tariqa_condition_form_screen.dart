import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/tariqa_condition_models.dart';
import 'tariqa_conditions_providers.dart';

/// Correction d'une condition de la tariqa existante — réservé par RLS à un
/// compte admin (`tariqa_conditions_admin_update`, voir `isAdminProvider`
/// côté `TariqaConditionsScreen`).
///
/// Contrairement à `FigureFormScreen`, pas de mode création : le corpus des
/// 23 chouroutes est figé (`order_index between 1 and 23` unique,
/// `database/schema.sql`) — cet écran ne fait que corriger le texte d'une
/// condition déjà en base, jamais en ajouter ni en retirer.
class TariqaConditionFormScreen extends ConsumerStatefulWidget {
  const TariqaConditionFormScreen({super.key, required this.condition});

  final TariqaCondition condition;

  @override
  ConsumerState<TariqaConditionFormScreen> createState() => _TariqaConditionFormScreenState();
}

class _TariqaConditionFormScreenState extends ConsumerState<TariqaConditionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textFrController;
  late final TextEditingController _textArController;
  late final TextEditingController _sourceNoteController;

  late TariqaConditionCategory _category;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final condition = widget.condition;
    _textFrController = TextEditingController(text: condition.textFr);
    _textArController = TextEditingController(text: condition.textAr ?? '');
    _sourceNoteController = TextEditingController(text: condition.sourceNote ?? '');
    _category = condition.category;
  }

  @override
  void dispose() {
    _textFrController.dispose();
    _textArController.dispose();
    _sourceNoteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final textAr = _textArController.text.trim();
    final sourceNote = _sourceNoteController.text.trim();

    try {
      final repo = ref.read(tariqaConditionsRepositoryProvider);
      await repo.updateCondition(
        widget.condition.id,
        category: _category,
        textFr: _textFrController.text.trim(),
        textAr: textAr.isEmpty ? null : textAr,
        sourceNote: sourceNote.isEmpty ? null : sourceNote,
      );
      ref.invalidate(tariqaConditionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.tariqaConditionFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _categoryLabel(TariqaConditionCategory category, AppLocalizations l10n) {
    switch (category) {
      case TariqaConditionCategory.validiteTalqin:
        return l10n.tariqaConditionsCategoryValiditeTalqin;
      case TariqaConditionCategory.compagnonnage:
        return l10n.tariqaConditionsCategoryCompagnonnage;
      case TariqaConditionCategory.conditionsGenerales:
        return l10n.tariqaConditionsCategoryConditionsGenerales;
      case TariqaConditionCategory.validiteRecitation:
        return l10n.tariqaConditionsCategoryValiditeRecitation;
      case TariqaConditionCategory.conditionsComplementaires:
        return l10n.tariqaConditionsCategoryConditionsComplementaires;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tariqaConditionEditTitle)),
      // `SafeArea` : évite que le bouton Enregistrer se retrouve masqué sous
      // la barre de navigation Android (3 boutons), même précaution que
      // `FigureFormScreen`.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<TariqaConditionCategory>(
                  initialValue: _category,
                  decoration: InputDecoration(labelText: l10n.tariqaConditionFormCategoryLabel),
                  items: [
                    for (final category in TariqaConditionCategory.values)
                      DropdownMenuItem(value: category, child: Text(_categoryLabel(category, l10n))),
                  ],
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _textFrController,
                  decoration: InputDecoration(labelText: l10n.tariqaConditionFormTextFrLabel),
                  maxLines: 4,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? l10n.tariqaConditionFormTextFrRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _textArController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: l10n.tariqaConditionFormTextArLabel),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourceNoteController,
                  decoration: InputDecoration(labelText: l10n.tariqaConditionFormSourceNoteLabel),
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
                      : Text(l10n.tariqaConditionFormSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
