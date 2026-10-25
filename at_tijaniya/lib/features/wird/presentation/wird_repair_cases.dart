/// « Rattraper son wird » : filtres par type de situation, liste des cas et
/// questions à poser au moqaddam. Sortis de `wird_repair_screen.dart` (audit
/// du 2026-10-25, P3-8), sans changement de comportement.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_repair_models.dart';
import 'wird_repair_styles.dart';

/// Filtres par type de situation, avec le nombre de cas de chacun pour le
/// wird choisi. Libellés courts (« Erreur », « Empêchement ») : les
/// libellés longs faisaient trois rangées de puces. Un type sans aucun cas
/// reste visible mais grisé : le disciple voit qu'il n'y a rien plutôt que
/// de chercher une puce disparue.
class RepairKindChips extends StatelessWidget {
  const RepairKindChips({super.key, required this.selected, required this.countFor, required this.onSelected});

  final RepairKind? selected;
  final int Function(RepairKind? kind) countFor;
  final ValueChanged<RepairKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(RepairKind?, String)>[
      (null, l10n.wirdRepairKindAll),
      (RepairKind.manque, l10n.wirdRepairKindManque),
      (RepairKind.erreur, l10n.wirdRepairKindErreur),
      (RepairKind.interruption, l10n.wirdRepairKindInterruption),
      (RepairKind.empechement, l10n.wirdRepairKindEmpechement),
    ];
    // `Wrap` plutôt qu'une ligne défilante : les cinq choix restent tous
    // visibles, sans qu'un disciple manque celui qui dépasse de l'écran.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (kind, label) in options) _chip(kind, label, countFor(kind)),
      ],
    );
  }

  Widget _chip(RepairKind? kind, String label, int count) {
    final isSelected = kind == selected;
    final enabled = count > 0 || isSelected;
    final textColor = isSelected ? AppColors.emerald : AppColors.ink;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: (isSelected ? AppColors.emerald : AppColors.ink).withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: enabled ? (_) => onSelected(kind) : null,
      selectedColor: AppColors.emeraldSoft,
      backgroundColor: AppColors.offWhite,
      disabledColor: AppColors.parchment,
      side: BorderSide(color: isSelected ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: enabled ? textColor : AppColors.ink.withValues(alpha: 0.45),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

/// Les cas, dans une seule surface séparée par des filets plutôt qu'une pile
/// de cartes : ils se lisent comme une liste continue de questions-réponses.
class RepairCaseList extends StatelessWidget {
  const RepairCaseList({super.key, required this.cases});

  final List<WirdRepairCase> cases;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        // `stretch` : sans lui, un cas court (« لا يعيده. ») prenait la largeur
        // de son texte et se retrouvait centré dans la carte au lieu d'être
        // rangé sur le bord de lecture (vu sur émulateur le 2026-10-17).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cases.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.bronze.withValues(alpha: 0.18)),
            _CaseTile(repairCase: cases[i]),
          ],
        ],
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.repairCase});

  final WirdRepairCase repairCase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    final source = repairCase.sourceFor(isArabic);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentText(repairCase.situationFor(isArabic), style: repairContentStyle(isArabic, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          ContentText(repairCase.actionFor(isArabic), style: repairContentStyle(isArabic, size: 14.5)),
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 8),
            ContentText(
              l10n.wirdRepairSource(source),
              // Pas d'italique en arabe : l'écriture arabe n'en a pas, et
              // Flutter penchait artificiellement l'Amiri.
              style: TextStyle(
                fontSize: isArabic ? 13 : 12.5,
                fontStyle: isArabic ? FontStyle.normal : FontStyle.italic,
                color: repairSecondaryInk,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ce que les sources ne tranchent pas : renvoyé au moqaddam plutôt que
/// complété par l'app.
class RepairAskMoqaddamPanel extends StatelessWidget {
  const RepairAskMoqaddamPanel({super.key, required this.notes});

  final List<WirdRepairNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.emerald, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.wirdRepairAskMoqaddam,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.emerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: isArabic ? 13 : 9),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: ContentText(note.textFor(isArabic), style: repairContentStyle(isArabic, size: 14.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
