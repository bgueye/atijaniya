import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Création/édition d'une citation attribuée à une figure — réservé par RLS
/// à un compte admin (`figure_quotes_admin_write`/`_admin_update`, ajoutées
/// le 2026-08-16, voir `database/schema.sql`). Ne retourne pas la citation
/// enregistrée (contrairement à `ZawiyaFormScreen`/`FigureFormScreen`) : le
/// parent (`FigureDetailScreen`) recharge la figure entière via
/// `fetchFigureById` après un `pop(true)`, plus simple qu'une reconstruction
/// locale de la liste des citations.
///
/// `citation == null` → création ; sinon édition, préremplie depuis l'objet
/// déjà en mémoire.
class FigureCitationFormScreen extends ConsumerStatefulWidget {
  const FigureCitationFormScreen(
      {super.key, required this.figureId, this.citation});

  final String figureId;
  final FigureCitation? citation;

  @override
  ConsumerState<FigureCitationFormScreen> createState() =>
      _FigureCitationFormScreenState();
}

class _FigureCitationFormScreenState
    extends ConsumerState<FigureCitationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _arabicController = TextEditingController();
  final _frenchController = TextEditingController();
  final _sourceController = TextEditingController();

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final citation = widget.citation;
    if (citation != null) {
      _arabicController.text = citation.arabic ?? '';
      _frenchController.text = citation.translation;
      _sourceController.text = citation.source == '—' ? '' : citation.source;
    }
  }

  @override
  void dispose() {
    _arabicController.dispose();
    _frenchController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final arabicText = _arabicController.text.trim();
    final frenchText = _frenchController.text.trim();
    final sourceText = _sourceController.text.trim();

    try {
      final repo = ref.read(figuresRepositoryProvider);
      if (widget.citation == null) {
        await repo.createCitation(
          figureId: widget.figureId,
          textArabic: arabicText.isEmpty ? null : arabicText,
          textFrench: frenchText.isEmpty ? null : frenchText,
          sourceNote: sourceText.isEmpty ? null : sourceText,
        );
      } else {
        await repo.updateCitation(
          widget.citation!.id!,
          textArabic: arabicText.isEmpty ? null : arabicText,
          textFrench: frenchText.isEmpty ? null : frenchText,
          sourceNote: sourceText.isEmpty ? null : sourceText,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = l10n.figureCitationFormSaveError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.citation != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit
              ? l10n.figureCitationFormEditTitle
              : l10n.figureCitationFormCreateTitle)),
      // `SafeArea` : sans elle, le bouton Enregistrer peut se retrouver
      // masqué sous la barre de navigation Android (3 boutons) — le même
      // défaut que celui corrigé sur le bottom sheet d'upload audio des
      // wirds, généralisé à tous les formulaires plein écran de l'app.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _arabicController,
                  decoration: InputDecoration(
                      labelText: l10n.figureCitationFormArabicLabel),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _frenchController,
                  decoration: InputDecoration(
                      labelText: l10n.figureCitationFormFrenchLabel),
                  maxLines: 3,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) &&
                              _arabicController.text.trim().isEmpty
                          ? l10n.figureCitationFormTextRequired
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                      labelText: l10n.figureCitationFormSourceLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.figureCitationFormSourceRequired
                      : null,
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
                      : Text(l10n.figureCitationFormSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
