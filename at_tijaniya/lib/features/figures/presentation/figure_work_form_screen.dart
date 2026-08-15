import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Création/édition d'une œuvre attribuée à une figure — réservé par RLS à
/// un compte admin (`figure_works_admin_write`/`_admin_update`, ajoutées le
/// 2026-08-16, voir `database/schema.sql`). Même principe que
/// `FigureCitationFormScreen` : ne retourne pas l'œuvre enregistrée, le
/// parent recharge la figure entière via `fetchFigureById` après un
/// `pop(true)`.
///
/// `work == null` → création, ajoutée à la fin de la liste ([nextOrderIndex]
/// fourni par l'appelant, `figure.works?.length ?? 0`) ; sinon édition
/// (l'ordre d'une œuvre existante n'est pas modifiable depuis ce
/// formulaire — pas de réordonnancement en V1).
class FigureWorkFormScreen extends ConsumerStatefulWidget {
  const FigureWorkFormScreen({super.key, required this.figureId, this.work, this.nextOrderIndex = 0});

  final String figureId;
  final FigureWork? work;
  final int nextOrderIndex;

  @override
  ConsumerState<FigureWorkFormScreen> createState() => _FigureWorkFormScreenState();
}

class _FigureWorkFormScreenState extends ConsumerState<FigureWorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final work = widget.work;
    if (work != null) {
      _titleController.text = work.title;
      _descriptionController.text = work.description ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final descriptionText = _descriptionController.text.trim();

    try {
      final repo = ref.read(figuresRepositoryProvider);
      if (widget.work == null) {
        await repo.createWork(
          figureId: widget.figureId,
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          orderIndex: widget.nextOrderIndex,
        );
      } else {
        await repo.updateWork(
          widget.work!.id!,
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.figureWorkFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.work != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.figureWorkFormEditTitle : l10n.figureWorkFormCreateTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.figureWorkFormTitleLabel),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.figureWorkFormTitleRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.figureWorkFormDescriptionLabel),
                maxLines: 4,
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
                    : Text(l10n.figureWorkFormSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
