/// « Rattraper son wird » : choix du wird, réponse rapide et résumé (horaires,
/// mise en garde). Sortis de `wird_repair_screen.dart` (audit du 2026-10-25,
/// P3-8), sans changement de comportement.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_repair_models.dart';
import 'wird_repair_styles.dart';

/// Choix du wird : trois onglets à parts égales, soulignés d'un filet d'or
/// quand ils sont choisis. Plutôt qu'un `SegmentedButton`, dont les segments
/// tronquaient « Hadratou-l-Jouma » sur un téléphone étroit : ici le nom peut
/// passer sur deux lignes.
///
/// Sous le nom, l'autre langue en petit (nom arabe dans l'app en français, nom
/// français dans l'app en arabe) : la charte présente un wird par ses deux
/// noms (docs/02, « Carte wird »).
class RepairWirdTabs extends StatelessWidget {
  const RepairWirdTabs({super.key, required this.selected, required this.onSelected});

  final RepairWird selected;
  final ValueChanged<RepairWird> onSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = repairIsArabic(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bronze.withValues(alpha: 0.25))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final wird in const [RepairWird.lazim, RepairWird.wazifa, RepairWird.hadra])
            Expanded(child: _tab(context, wird, isArabic)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, RepairWird wird, bool isArabic) {
    final isSelected = wird == selected;
    final color = isSelected ? AppColors.emerald : AppColors.ink.withValues(alpha: 0.7);
    final validated = repairValidatedWird(wird);
    final other = isArabic ? validated.nameFrench : validated.nameArabic;
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: () => onSelected(wird),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isSelected ? AppColors.gold : Colors.transparent, width: 2.5),
            ),
          ),
          child: Column(
            children: [
              Text(
                repairWirdName(context, wird),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: isArabic
                    ? AppTheme.sacredText(fontSize: 17, color: color)
                        .copyWith(height: 1.3, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)
                    : TextStyle(fontSize: 15, color: color, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
              ),
              const SizedBox(height: 2),
              // Le nom dans l'autre langue, en petit : repère, pas libellé.
              ContentText(
                other,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isArabic
                    ? TextStyle(fontSize: 12, color: color)
                    : AppTheme.sacredText(fontSize: 14, color: color).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La réponse rapide (« Se rattrape » / « Ne se rattrape pas »). La réponse
/// négative a son propre pictogramme et l'encre au lieu de l'émeraude : les
/// deux réponses avaient le même dessin, et on ne les distinguait qu'en
/// lisant (audit du 2026-10-18). Pas de rouge : il est réservé aux erreurs
/// et aux actions destructrices (charte).
class RepairQuickAnswer extends StatelessWidget {
  const RepairQuickAnswer({super.key, required this.note, this.size = 32});

  final WirdRepairNote note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isArabic = repairIsArabic(context);
    final negative = note.isNegativeAnswer;
    final color = negative ? AppColors.ink : AppColors.emerald;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(negative ? Icons.do_not_disturb_on_outlined : Icons.history, color: color, size: size * 0.8),
        SizedBox(width: size * 0.3),
        Expanded(child: ContentText(note.textFor(isArabic), style: repairTitleStyle(isArabic, size: size, color: color))),
      ],
    );
  }
}

/// Ce qu'il faut savoir d'un wird avant d'entrer dans les cas : s'il se
/// rattrape (en grand — c'est la réponse que le disciple cherche d'abord),
/// son introduction, puis ses horaires et la mise en garde éventuelle,
/// repliés. La mise en garde était un bandeau de cinq lignes au-dessus des
/// filtres : avec elle, le premier cas n'apparaissait qu'au deuxième écran
/// (audit du 2026-10-18). La lecture complète, elle, la montre dépliée.
class RepairWirdSummary extends StatelessWidget {
  const RepairWirdSummary({super.key, required this.wird, required this.content});

  final RepairWird wird;
  final WirdRepairContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    final answer = content.noteFor(wird, RepairNoteType.quickAnswer);
    final intro = content.noteFor(wird, RepairNoteType.intro);
    final timings = content.notesFor(wird, RepairNoteType.timing);
    final warning = content.noteFor(wird, RepairNoteType.warning);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Seule rosace de l'écran, en filigrane (design_tokens.yaml :
          // une occurrence par écran, faible opacité, jamais en motif).
          PositionedDirectional(
            top: -18,
            end: -18,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: SizedBox.square(
                  dimension: 120,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.gold, strokeWidth: 1.2)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (answer != null) ...[
                  RepairQuickAnswer(note: answer),
                  const SizedBox(height: 10),
                  Container(width: 36, height: 2, color: AppColors.gold),
                  const SizedBox(height: 12),
                ],
                if (intro != null) ContentText(intro.textFor(isArabic), style: repairContentStyle(isArabic, size: 14.5)),
                if (timings.isNotEmpty || warning != null) const SizedBox(height: 6),
                if (timings.isNotEmpty)
                  _Collapsible(
                    icon: Icons.schedule,
                    color: AppColors.emerald,
                    label: l10n.wirdRepairSchedule,
                    child: RepairTimingTable(notes: timings),
                  ),
                if (warning != null)
                  _Collapsible(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.ink,
                    label: l10n.wirdRepairWarningLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: RepairWarningBand(text: warning.textFor(isArabic)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne repliable (horaires, mise en garde). Repliée par défaut dans la vue
/// par situation : dépliés, les horaires du Lazim occupaient plus d'un écran
/// et repoussaient les cas loin en dessous (constaté sur émulateur le
/// 2026-10-17). Zone de toucher d'au moins 48 dp de haut (accessibilité).
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.icon, required this.color, required this.label, required this.child});

  final IconData icon;
  final Color color;
  final String label;
  final Widget child;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: widget.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: widget.color),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: widget.color),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: AlignmentDirectional.topStart,
          child: _open ? widget.child : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Horaires : une ligne par moment (Matin, Soir, Avancer…), libellé à part et
/// texte à côté, séparés par un filet. Plus lisible qu'un paragraphe quand il
/// faut retrouver « jusqu'à quand puis-je faire le soir ? ».
class RepairTimingTable extends StatelessWidget {
  const RepairTimingTable({super.key, required this.notes});

  final List<WirdRepairNote> notes;

  @override
  Widget build(BuildContext context) {
    final isArabic = repairIsArabic(context);
    // La colonne des libellés suit la taille de texte choisie par l'utilisateur
    // (réglage Android) : à largeur fixe, « Avancer » se coupait en grand texte.
    final labelWidth = MediaQuery.textScalerOf(context).scale(76);
    return Column(
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.18)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: ContentText(
                    notes[i].labelFor(isArabic) ?? '',
                    style: repairContentStyle(isArabic, size: 14, weight: FontWeight.w600, color: AppColors.emerald),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: ContentText(notes[i].textFor(isArabic), style: repairContentStyle(isArabic, size: 14.5))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Mise en garde : bandeau doré avec un filet sur le bord de début (à gauche
/// en français, à droite en arabe — `BorderDirectional` suit le sens de
/// lecture). Une première version posait le filet dans une `Row` sous
/// `IntrinsicHeight` : en arabe, la hauteur estimée du texte Amiri laissait
/// une ligne vide sous le bandeau (vu sur émulateur le 2026-10-17).
class RepairWarningBand extends StatelessWidget {
  const RepairWarningBand({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // L'arrondi vient du `ClipRRect` : une bordure qui n'a qu'un côté ne peut
    // pas porter elle-même de `borderRadius`.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          border: BorderDirectional(start: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: ContentText(text, style: repairContentStyle(repairIsArabic(context), size: 14.5)),
        ),
      ),
    );
  }
}
