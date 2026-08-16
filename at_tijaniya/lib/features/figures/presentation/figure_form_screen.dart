import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../lineage/domain/lineage_models.dart' show Foyer;
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Création/édition d'une figure — réservé par RLS à un compte admin
/// (`figures_admin_write`/`_update`, voir `isAdminProvider`).
///
/// `figure == null` → création ; sinon édition, préremplie synchroniquement
/// depuis l'objet déjà en mémoire (même pattern que `EventFormScreen`/
/// `ZawiyaFormScreen`). Important : la biographie est préremplie depuis
/// `figure.bioText` (texte brut), jamais reconstruite depuis
/// `figure.biography` (déjà découpé/filtré pour l'affichage) — sinon la
/// section "SOURCES CONSULTÉES" et la mise en forme d'origine seraient
/// silencieusement perdues à l'enregistrement.
class FigureFormScreen extends ConsumerStatefulWidget {
  const FigureFormScreen({super.key, this.figure});

  final Figure? figure;

  @override
  ConsumerState<FigureFormScreen> createState() => _FigureFormScreenState();
}

class _FigureFormScreenState extends ConsumerState<FigureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameArabicController = TextEditingController();
  final _nameFrenchController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _bioTextController = TextEditingController();

  FigureCategory _category = FigureCategory.religiousFamily;
  Foyer? _foyer;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final figure = widget.figure;
    if (figure != null) {
      _nameArabicController.text = figure.nameArabic;
      _nameFrenchController.text = figure.nameFrench;
      _birthYearController.text = figure.birthYearHijri?.toString() ?? '';
      _bioTextController.text = figure.bioText ?? '';
      _category = figure.category;
      _foyer = figure.foyer;
    }
  }

  @override
  void dispose() {
    _nameArabicController.dispose();
    _nameFrenchController.dispose();
    _birthYearController.dispose();
    _bioTextController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final bioText = _bioTextController.text.trim();
    final birthYearText = _birthYearController.text.trim();

    try {
      final repo = ref.read(figuresRepositoryProvider);
      final Figure saved;
      if (widget.figure == null) {
        saved = await repo.createFigure(
          nameArabic: _nameArabicController.text.trim(),
          nameFrench: _nameFrenchController.text.trim(),
          category: _category,
          foyer: _foyer,
          birthYearHijri:
              birthYearText.isEmpty ? null : int.parse(birthYearText),
          bioText: bioText.isEmpty ? null : bioText,
        );
      } else {
        saved = await repo.updateFigure(
          widget.figure!.id,
          nameArabic: _nameArabicController.text.trim(),
          nameFrench: _nameFrenchController.text.trim(),
          category: _category,
          foyer: _foyer,
          birthYearHijri:
              birthYearText.isEmpty ? null : int.parse(birthYearText),
          bioText: bioText.isEmpty ? null : bioText,
        );
      }
      ref.invalidate(figuresProvider);
      ref.invalidate(draftFiguresProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.figureFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _categoryLabel(FigureCategory category, AppLocalizations l10n) {
    return category == FigureCategory.founder
        ? l10n.figureFormCategoryFounder
        : l10n.figureFormCategoryFamily;
  }

  String _foyerLabel(Foyer foyer, AppLocalizations l10n) {
    switch (foyer) {
      case Foyer.tivaouane:
        return l10n.lineageFoyerTivaouane;
      case Foyer.kaolack:
        return l10n.lineageFoyerKaolack;
      case Foyer.medinaBaye:
        return l10n.lineageFoyerMedinaBaye;
      case Foyer.autre:
        return l10n.lineageFoyerAutre;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.figure != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              isEdit ? l10n.figureFormEditTitle : l10n.figureFormCreateTitle)),
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
                  controller: _nameArabicController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                      labelText: l10n.figureFormNameArabicLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.figureFormNameArabicRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameFrenchController,
                  decoration: InputDecoration(
                      labelText: l10n.figureFormNameFrenchLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.figureFormNameFrenchRequired
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FigureCategory>(
                  initialValue: _category,
                  decoration:
                      InputDecoration(labelText: l10n.figureFormCategoryLabel),
                  items: [
                    for (final category in FigureCategory.values)
                      DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category, l10n))),
                  ],
                  onChanged: (value) => setState(() =>
                      _category = value ?? FigureCategory.religiousFamily),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Foyer?>(
                  initialValue: _foyer,
                  decoration:
                      InputDecoration(labelText: l10n.figureFormFoyerLabel),
                  items: [
                    DropdownMenuItem<Foyer?>(
                        value: null, child: Text(l10n.figureFormFoyerNone)),
                    for (final foyer in Foyer.values)
                      DropdownMenuItem<Foyer?>(
                          value: foyer, child: Text(_foyerLabel(foyer, l10n))),
                  ],
                  onChanged: (value) => setState(() => _foyer = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthYearController,
                  decoration: InputDecoration(
                      labelText: l10n.figureFormBirthYearHijriLabel),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    return int.tryParse(trimmed) == null
                        ? l10n.figureFormBirthYearHijriInvalid
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioTextController,
                  decoration: InputDecoration(
                    labelText: l10n.figureFormBioTextLabel,
                    helperText: l10n.figureFormBioTextHint,
                    helperMaxLines: 3,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.redAccent)),
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
                      : Text(l10n.figureFormSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
