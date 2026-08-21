import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Édition de la position d'une figure dans la silsila historique — sa
/// figure parente et son rang. Réservé par RLS à un compte admin
/// (`silsila_links_admin_write`/`_update`).
///
/// Contrairement à `FigureCitationFormScreen`/`FigureWorkFormScreen`, il
/// n'existe qu'au plus un maillon par figure (`unique(figure_id)`,
/// `database/schema.sql`) : ce formulaire crée ou remplace ce maillon
/// unique plutôt que d'ajouter un élément à une liste — voir
/// `FiguresRepository.setSilsilaLink` (`upsert`).
class FigureSilsilaFormScreen extends ConsumerStatefulWidget {
  const FigureSilsilaFormScreen({super.key, required this.figure, this.existingLink});

  final Figure figure;

  /// `null` si cette figure n'a pas encore de maillon — l'écran propose
  /// alors d'en créer un plutôt que d'en modifier un existant.
  final FigureSilsilaLink? existingLink;

  @override
  ConsumerState<FigureSilsilaFormScreen> createState() => _FigureSilsilaFormScreenState();
}

class _FigureSilsilaFormScreenState extends ConsumerState<FigureSilsilaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIndexController = TextEditingController();
  String? _parentFigureId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final link = widget.existingLink;
    if (link != null) {
      _parentFigureId = link.parentFigureId;
      _orderIndexController.text = link.orderIndex.toString();
    }
  }

  @override
  void dispose() {
    _orderIndexController.dispose();
    super.dispose();
  }

  /// Pré-remplit le rang suggéré (rang de la figure parente + 1) quand
  /// l'admin choisit une figure parente et n'a pas encore saisi de rang —
  /// jamais pour un maillon déjà existant ([widget.existingLink] non nul),
  /// dont le rang enregistré prime toujours sur une suggestion.
  void _onParentChanged(String? parentId, List<FigureSilsilaLink> allLinks) {
    setState(() {
      _parentFigureId = parentId;
      if (widget.existingLink != null || parentId == null || _orderIndexController.text.trim().isNotEmpty) return;
      for (final link in allLinks) {
        if (link.figureId == parentId) {
          _orderIndexController.text = (link.orderIndex + 1).toString();
          break;
        }
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(figuresRepositoryProvider).setSilsilaLink(
            figureId: widget.figure.id,
            parentFigureId: _parentFigureId,
            orderIndex: int.parse(_orderIndexController.text.trim()),
          );
      ref.invalidate(silsilaLinksProvider);
      ref.invalidate(historicalSilsilaChainProvider(widget.figure.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.figureSilsilaFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final figuresAsync = ref.watch(figuresProvider);
    final linksAsync = ref.watch(silsilaLinksProvider);
    final isEdit = widget.existingLink != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.figureSilsilaFormEditTitle : l10n.figureSilsilaFormCreateTitle)),
      body: SafeArea(
        child: figuresAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Text(l10n.figuresLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (figures) {
            final allLinks = linksAsync.valueOrNull ?? const <FigureSilsilaLink>[];
            final candidates = figures.where((f) => f.id != widget.figure.id).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.figureSilsilaFormIntro, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String?>(
                      initialValue: _parentFigureId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.figureSilsilaFormParentLabel),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.figureSilsilaFormParentNone, overflow: TextOverflow.ellipsis),
                        ),
                        for (final candidate in candidates)
                          DropdownMenuItem<String?>(
                            value: candidate.id,
                            child: Text(candidate.nameFrench, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => _onParentChanged(value, allLinks),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _orderIndexController,
                      decoration: InputDecoration(
                        labelText: l10n.figureSilsilaFormOrderLabel,
                        helperText: l10n.figureSilsilaFormOrderHint,
                        helperMaxLines: 3,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return l10n.figureSilsilaFormOrderRequired;
                        return int.tryParse(trimmed) == null ? l10n.figureSilsilaFormOrderInvalid : null;
                      },
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
                          : Text(l10n.figureSilsilaFormSave),
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
