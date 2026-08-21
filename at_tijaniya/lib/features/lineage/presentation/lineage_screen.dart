import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/lineage_models.dart';
import 'lineage_matches_screen.dart';
import 'lineage_providers.dart';

/// Renseigner ma lignée spirituelle — foyer, nom du moqaddam, année de
/// transmission, zawiya/lieu de transmission (optionnel). Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1) : donnée strictement
/// privée (RLS `lineage_owner_only` — `for all using (auth.uid() =
/// user_id)`, aucune lecture inter-utilisateurs possible côté client).
/// Volontairement absents de cet écran : tout mécanisme de
/// suggestion/recherche inter-utilisateurs (nécessiterait une fonction
/// Postgres `SECURITY DEFINER` dédiée, inexistante dans le schéma actuel —
/// changement de backend, pas de code Flutter) et le toggle "Me rendre
/// visible aux disciples de mon moqaddam" (appartient à l'écran séparé
/// "Paramètres de confidentialité", pas encore construit).
class LineageScreen extends ConsumerStatefulWidget {
  const LineageScreen({super.key});

  @override
  ConsumerState<LineageScreen> createState() => _LineageScreenState();
}

class _LineageScreenState extends ConsumerState<LineageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _moqaddamNameController = TextEditingController();
  final _foyerAutreController = TextEditingController();
  final _yearController = TextEditingController();
  final _zawiyaController = TextEditingController();

  Foyer _foyer = Foyer.tivaouane;
  bool _initialized = false;
  bool _saving = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _moqaddamNameController.dispose();
    _foyerAutreController.dispose();
    _yearController.dispose();
    _zawiyaController.dispose();
    super.dispose();
  }

  /// Pré-remplit le formulaire une seule fois, à la première réception
  /// d'une déclaration existante — appelé depuis le builder `data` de
  /// `myLineageProvider`, avant construction des champs du même passage de
  /// build, donc sans besoin de `setState`.
  void _applyExisting(LineageDeclaration? lineage) {
    if (_initialized || lineage == null) return;
    _initialized = true;
    _foyer = lineage.foyer;
    _moqaddamNameController.text = lineage.moqaddamNameText;
    _foyerAutreController.text = lineage.foyerAutreText ?? '';
    _yearController.text = lineage.transmissionYear?.toString() ?? '';
    _zawiyaController.text = lineage.zawiyaText ?? '';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final yearText = _yearController.text.trim();
      final zawiyaText = _zawiyaController.text.trim();
      await ref.read(lineageRepositoryProvider).saveMyLineage(
            foyer: _foyer,
            foyerAutreText: _foyer == Foyer.autre
                ? _foyerAutreController.text.trim()
                : null,
            moqaddamNameText: _moqaddamNameController.text.trim(),
            transmissionYear: yearText.isEmpty ? null : int.parse(yearText),
            zawiyaText: zawiyaText.isEmpty ? null : zawiyaText,
          );
      ref.invalidate(myLineageProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.lineageSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lineageDeleteConfirmTitle),
        content: Text(l10n.lineageDeleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lineageDeleteConfirmAction,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref.read(lineageRepositoryProvider).deleteMyLineage();
      // `_initialized` reste à `true` (ne pas le remettre à `false`) : le
      // formulaire vient d'être vidé explicitement par l'utilisateur, et
      // `myLineageProvider` peut renvoyer brièvement l'ancienne valeur mise
      // en cache pendant son rafraîchissement (`AsyncValue.when` a
      // `skipLoadingOnRefresh: true` par défaut) — sans ce garde,
      // `_applyExisting` la réappliquerait et réafficherait les données
      // qu'on vient de supprimer.
      _formKey.currentState?.reset();
      _moqaddamNameController.clear();
      _foyerAutreController.clear();
      _yearController.clear();
      _zawiyaController.clear();
      ref.invalidate(myLineageProvider);
      if (mounted) {
        setState(() {
          _foyer = Foyer.tivaouane;
          _infoMessage = l10n.lineageDeleteSuccess;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.lineageSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final lineageAsync = ref.watch(myLineageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lineageTitle)),
      // `SafeArea` : évite que le bouton Enregistrer se retrouve masqué sous
      // la barre de navigation Android (3 boutons).
      body: SafeArea(
        child: lineageAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    l10n.lineageLoadError,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.bronze),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(myLineageProvider),
                    child: Text(l10n.lineageRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (lineage) {
            _applyExisting(lineage);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lineage != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const LineageMatchesScreen()),
                        ),
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: Text(l10n.lineageFindDisciplesCta),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Card(
                      color: AppColors.goldSoft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: AppColors.bronze),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.lineagePrivacyNote,
                                style: const TextStyle(
                                    color: AppColors.ink, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<Foyer>(
                      initialValue: _foyer,
                      decoration:
                          InputDecoration(labelText: l10n.lineageFoyerLabel),
                      items: [
                        for (final foyer in Foyer.values)
                          DropdownMenuItem(
                              value: foyer,
                              child: Text(_foyerLabel(foyer, l10n))),
                      ],
                      onChanged: (value) =>
                          setState(() => _foyer = value ?? Foyer.tivaouane),
                    ),
                    if (_foyer == Foyer.autre) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _foyerAutreController,
                        decoration: InputDecoration(
                            labelText: l10n.lineageFoyerAutreLabel),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? l10n.lineageFoyerAutreRequired
                                : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _moqaddamNameController,
                      decoration: InputDecoration(
                          labelText: l10n.lineageMoqaddamNameLabel),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? l10n.lineageMoqaddamNameRequired
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _yearController,
                      decoration:
                          InputDecoration(labelText: l10n.lineageYearLabel),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final year = int.tryParse(text);
                        if (year == null || year < 1900 || year > 2100) {
                          return l10n.lineageYearInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _zawiyaController,
                      decoration:
                          InputDecoration(labelText: l10n.lineageZawiyaLabel),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ],
                    if (_infoMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_infoMessage!,
                          style: TextStyle(color: AppColors.emerald)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.lineageSave),
                    ),
                    if (lineage != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent),
                        child: Text(l10n.lineageDelete),
                      ),
                    ],
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
