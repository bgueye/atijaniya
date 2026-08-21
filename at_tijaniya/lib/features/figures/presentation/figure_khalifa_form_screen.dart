import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Ajout/édition d'un maillon dans la chaîne de succession des khalifas
/// d'une figure fondatrice — réservé par RLS à un compte admin
/// (`figure_zawiya_khalifas_admin_write`/`_update`). Contrairement à
/// `FigureSilsilaFormScreen` (au plus un maillon par figure, `upsert`), une
/// figure fondatrice peut avoir plusieurs khalifas : ce formulaire ajoute un
/// nouveau maillon à la chaîne ou modifie le rang/la période d'un maillon
/// existant ([existingLink] non nul) — changer QUI est le khalife d'un
/// maillon existant n'est volontairement pas permis (retirer puis
/// rajouter), d'où le figure-picker désactivé en édition.
class FigureKhalifaFormScreen extends ConsumerStatefulWidget {
  const FigureKhalifaFormScreen({super.key, required this.founderFigure, this.existingLink});

  final Figure founderFigure;

  /// `null` pour ajouter un nouveau khalife à la chaîne.
  final FigureKhalifaLink? existingLink;

  @override
  ConsumerState<FigureKhalifaFormScreen> createState() => _FigureKhalifaFormScreenState();
}

class _FigureKhalifaFormScreenState extends ConsumerState<FigureKhalifaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIndexController = TextEditingController();
  final _periodController = TextEditingController();
  String? _khalifaFigureId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final link = widget.existingLink;
    if (link != null) {
      _khalifaFigureId = link.khalifaFigureId;
      _orderIndexController.text = link.orderIndex.toString();
      _periodController.text = link.periodText ?? '';
    }
  }

  @override
  void dispose() {
    _orderIndexController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  /// Pré-remplit le rang suggéré (rang le plus élevé de la chaîne + 1) —
  /// jamais pour un maillon déjà existant, dont le rang enregistré prime
  /// toujours sur une suggestion. Même esprit que `_onParentChanged` dans
  /// `FigureSilsilaFormScreen`, en plus simple (pas de recherche par figure
  /// parente, juste le rang maximal actuel de la chaîne).
  void _suggestOrderIndex(List<FigureKhalifaLink> chain) {
    if (widget.existingLink != null || _orderIndexController.text.trim().isNotEmpty) return;
    var maxOrder = 0;
    for (final link in chain) {
      if (link.orderIndex > maxOrder) maxOrder = link.orderIndex;
    }
    _orderIndexController.text = (maxOrder + 1).toString();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final orderIndex = int.parse(_orderIndexController.text.trim());
      final periodText = _periodController.text.trim().isEmpty ? null : _periodController.text.trim();
      final repo = ref.read(figuresRepositoryProvider);
      if (widget.existingLink == null) {
        await repo.addKhalifaLink(
          founderFigureId: widget.founderFigure.id,
          khalifaFigureId: _khalifaFigureId!,
          orderIndex: orderIndex,
          periodText: periodText,
        );
      } else {
        await repo.updateKhalifaLink(widget.existingLink!.id, orderIndex: orderIndex, periodText: periodText);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.figureKhalifaFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final figuresAsync = ref.watch(figuresProvider);
    final chainAsync = ref.watch(khalifaChainProvider(widget.founderFigure.id));
    final isEdit = widget.existingLink != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.figureKhalifaFormEditTitle : l10n.figureKhalifaFormCreateTitle)),
      body: SafeArea(
        child: figuresAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Text(l10n.figuresLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (figures) {
            final chain = chainAsync.valueOrNull ?? const <FigureKhalifaLink>[];
            _suggestOrderIndex(chain);
            final usedKhalifaIds = {for (final link in chain) link.khalifaFigureId};
            final candidates = figures
                .where((f) => f.id != widget.founderFigure.id && !usedKhalifaIds.contains(f.id))
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEdit)
                      InputDecorator(
                        decoration: InputDecoration(labelText: l10n.figureKhalifaFormFigureLabel),
                        child: Text(widget.existingLink!.khalifaNameFr),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        initialValue: _khalifaFigureId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.figureKhalifaFormFigureLabel,
                          hintText: l10n.figureKhalifaFormFigureNone,
                        ),
                        items: [
                          for (final candidate in candidates)
                            DropdownMenuItem<String?>(
                              value: candidate.id,
                              child: Text(candidate.nameFrench, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        validator: (value) => value == null ? l10n.figureKhalifaFormFigureNone : null,
                        onChanged: (value) => setState(() => _khalifaFigureId = value),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _orderIndexController,
                      decoration: InputDecoration(
                        labelText: l10n.figureKhalifaFormOrderLabel,
                        helperText: l10n.figureKhalifaFormOrderHint,
                        helperMaxLines: 3,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return l10n.figureKhalifaFormOrderRequired;
                        return int.tryParse(trimmed) == null ? l10n.figureKhalifaFormOrderInvalid : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _periodController,
                      decoration: InputDecoration(
                        labelText: l10n.figureKhalifaFormPeriodLabel,
                        helperText: l10n.figureKhalifaFormPeriodHint,
                      ),
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
                          : Text(l10n.figureKhalifaFormSave),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
