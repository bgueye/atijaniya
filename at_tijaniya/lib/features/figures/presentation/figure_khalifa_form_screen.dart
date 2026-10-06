import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/numerals.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart' show Zawiya;
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Libellé pluriel d'un rôle de succession ("Khalifes", "Mokaddems",
/// "Imams") — partagé entre ce formulaire et l'onglet Zawiya de
/// `FigureDetailScreen`, qui s'en sert comme titre de chaque succession.
String successionRoleLabel(AppLocalizations l10n, SuccessionRole role) {
  return switch (role) {
    SuccessionRole.khalife => l10n.figureSuccessionRoleKhalife,
    SuccessionRole.mokaddem => l10n.figureSuccessionRoleMokaddem,
    SuccessionRole.imam => l10n.figureSuccessionRoleImam,
  };
}

/// Ajout/édition d'un maillon dans une succession (khalifes, mokaddems ou
/// imams d'une zawiya) — réservé par RLS à un compte admin
/// (`figure_zawiya_khalifas_admin_write`/`_update`). Trois usages :
/// - [succession] nul : démarre une nouvelle succession dont
///   [founderFigureId] est la figure fondatrice ; l'admin choisit la zawiya
///   (parmi celles déjà rattachées à cette figure) et le rôle ;
/// - [succession] non nul, [existingLink] nul : ajoute un maillon à cette
///   succession, zawiya et rôle étant alors fixés ;
/// - [existingLink] non nul : modifie le rang, la période ou le drapeau de
///   lacune d'un maillon existant. Changer QUI est le maillon, sa zawiya ou
///   son rôle n'est volontairement pas permis (retirer puis rajouter), d'où
///   les champs correspondants en lecture seule.
class FigureKhalifaFormScreen extends ConsumerStatefulWidget {
  const FigureKhalifaFormScreen({
    super.key,
    required this.founderFigureId,
    this.succession,
    this.existingLink,
  }) : assert(existingLink == null || succession != null, 'Un maillon existant appartient à une succession.');

  /// Figure fondatrice : celle de [succession] si elle est fournie, sinon la
  /// figure consultée, qui devient fondatrice de la nouvelle succession.
  final String founderFigureId;

  /// `null` pour démarrer une nouvelle succession.
  final ZawiyaSuccession? succession;

  /// `null` pour ajouter un nouveau maillon.
  final FigureKhalifaLink? existingLink;

  @override
  ConsumerState<FigureKhalifaFormScreen> createState() => _FigureKhalifaFormScreenState();
}

class _FigureKhalifaFormScreenState extends ConsumerState<FigureKhalifaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIndexController = TextEditingController();
  final _periodController = TextEditingController();
  String? _khalifaFigureId;
  String? _zawiyaId;
  SuccessionRole _role = SuccessionRole.khalife;
  bool _followsGap = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final succession = widget.succession;
    if (succession != null) {
      _zawiyaId = succession.zawiyaId;
      _role = succession.role;
    }
    final link = widget.existingLink;
    if (link != null) {
      _khalifaFigureId = link.khalifaFigureId;
      _orderIndexController.text = link.orderIndex.toString();
      _periodController.text = link.periodText ?? '';
      _followsGap = link.followsGap;
    } else {
      // Rang suggéré : le plus élevé de la succession + 1 (donc 1 pour une
      // nouvelle succession) — jamais pour un maillon existant, dont le rang
      // enregistré prime toujours sur une suggestion.
      var maxOrder = 0;
      for (final existing in succession?.links ?? const <FigureKhalifaLink>[]) {
        if (existing.orderIndex > maxOrder) maxOrder = existing.orderIndex;
      }
      _orderIndexController.text = (maxOrder + 1).toString();
    }
  }

  @override
  void dispose() {
    _orderIndexController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final orderIndex = parseLocalizedInt(_orderIndexController.text.trim())!;
      final periodText = _periodController.text.trim().isEmpty ? null : _periodController.text.trim();
      final repo = ref.read(figuresRepositoryProvider);
      if (widget.existingLink == null) {
        await repo.addKhalifaLink(
          founderFigureId: widget.founderFigureId,
          zawiyaId: _zawiyaId!,
          role: _role,
          khalifaFigureId: _khalifaFigureId!,
          orderIndex: orderIndex,
          periodText: periodText,
          followsGap: _followsGap,
        );
      } else {
        await repo.updateKhalifaLink(
          widget.existingLink!.id,
          orderIndex: orderIndex,
          periodText: periodText,
          followsGap: _followsGap,
        );
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
    final isEdit = widget.existingLink != null;
    final succession = widget.succession;
    // Zawiyas proposées pour une nouvelle succession : uniquement celles déjà
    // rattachées à la figure fondatrice (sous-section "Zawiyas rattachées"),
    // pour qu'une succession ne puisse pas pointer vers une zawiya sans lien
    // affiché avec son fondateur.
    final List<Zawiya> linkedZawiyas = succession == null
        ? ref.watch(linkedZawiyasForFigureProvider(widget.founderFigureId)).valueOrNull ?? const <Zawiya>[]
        : const <Zawiya>[];

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.figureKhalifaFormEditTitle : l10n.figureKhalifaFormCreateTitle)),
      body: SafeArea(
        child: figuresAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Text(l10n.figuresLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (figures) {
            final usedKhalifaIds = {
              for (final link in succession?.links ?? const <FigureKhalifaLink>[]) link.khalifaFigureId,
            };
            final candidates = figures
                .where((f) => f.id != widget.founderFigureId && !usedKhalifaIds.contains(f.id))
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (succession != null) ...[
                      InputDecorator(
                        decoration: InputDecoration(labelText: l10n.figureSuccessionFormZawiyaLabel),
                        child: Text(succession.zawiyaName),
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: InputDecoration(labelText: l10n.figureSuccessionFormRoleLabel),
                        child: Text(successionRoleLabel(l10n, succession.role)),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String?>(
                        initialValue: _zawiyaId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.figureSuccessionFormZawiyaLabel,
                          hintText: l10n.figureSuccessionFormZawiyaNone,
                          helperText: linkedZawiyas.isEmpty ? l10n.figureSuccessionFormZawiyaEmpty : null,
                          helperMaxLines: 3,
                        ),
                        items: [
                          for (final zawiya in linkedZawiyas)
                            DropdownMenuItem<String?>(
                              value: zawiya.id,
                              child: Text(zawiya.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        validator: (value) => value == null ? l10n.figureSuccessionFormZawiyaNone : null,
                        onChanged: (value) => setState(() => _zawiyaId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SuccessionRole>(
                        initialValue: _role,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.figureSuccessionFormRoleLabel),
                        items: [
                          for (final role in SuccessionRole.values)
                            DropdownMenuItem<SuccessionRole>(
                              value: role,
                              child: Text(successionRoleLabel(l10n, role)),
                            ),
                        ],
                        onChanged: (value) => setState(() => _role = value ?? SuccessionRole.khalife),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                        return parseLocalizedInt(trimmed) == null ? l10n.figureKhalifaFormOrderInvalid : null;
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _followsGap,
                      title: Text(l10n.figureSuccessionFormGapLabel),
                      onChanged: (value) => setState(() => _followsGap = value),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
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
