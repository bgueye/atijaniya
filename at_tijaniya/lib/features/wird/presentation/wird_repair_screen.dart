import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import '../domain/wird_repair_models.dart';
import 'wird_display_name.dart';
import 'wird_repair_providers.dart';

/// « Rattraper son wird » : que faire après un oubli, une erreur ou une
/// interruption. Ouvert depuis une carte de `WirdListScreen`.
///
/// Contenu religieux venu de Supabase (voir `wird_repair_models.dart`) :
/// l'écran n'affiche que ce que la base renvoie, sans rien compléter. Un
/// disciple ne reçoit que le contenu validé ; l'admin voit aussi le
/// brouillon, signalé par un bandeau en tête de page.
///
/// Deux façons de lire, au choix de l'app bar :
/// - **par situation** (par défaut) : le disciple choisit son wird, voit tout
///   de suite s'il se rattrape, puis filtre les cas par type de situation.
///   C'est la question qu'il se pose en ouvrant la page. Les cas du wird
///   choisi viennent d'abord, les règles communes ensuite sous un seul
///   intertitre : avant l'audit de présentation du 2026-10-18, les 14 règles
///   communes passaient devant, et « Lazim oublié » n'arrivait qu'après ;
/// - **tout lire** : toutes les sections à la suite (principes communs, puis
///   chaque wird), pour qui veut apprendre les règles plutôt que résoudre un
///   cas précis.
///
/// Écran d'information, pas de pratique : fond ivoire (le vert zaytoune est
/// réservé aux écrans de wird et de khadara en direct, CLAUDE.md).
class WirdRepairScreen extends ConsumerStatefulWidget {
  const WirdRepairScreen({super.key});

  @override
  ConsumerState<WirdRepairScreen> createState() => _WirdRepairScreenState();
}

class _WirdRepairScreenState extends ConsumerState<WirdRepairScreen> {
  RepairWird _wird = RepairWird.lazim;

  /// Type de situation choisi ; `null` : tous les types.
  RepairKind? _kind;
  bool _readAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contentAsync = ref.watch(wirdRepairContentProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wirdRepairTitle),
        actions: [
          // Bascule entre les deux modes de lecture. Masquée tant que le
          // contenu n'est pas chargé : elle n'aurait rien à basculer.
          if (contentAsync.valueOrNull?.isEmpty == false)
            TextButton(
              onPressed: () => setState(() => _readAll = !_readAll),
              child: Text(_readAll ? l10n.wirdRepairBySituation : l10n.wirdRepairReadAll),
            ),
        ],
      ),
      // `SafeArea` : sans elle, la fin de la page passait sous la barre de
      // navigation Android (3 boutons) — même défaut déjà corrigé sur
      // `FigureFormScreen`, `AboutScreen` et « Comprendre la Zawiya ».
      body: SafeArea(
        child: contentAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => _Message(
            icon: Icons.wifi_off,
            text: l10n.wirdRepairLoadError,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(wirdRepairContentProvider),
              child: Text(l10n.wirdRepairRetry),
            ),
          ),
          data: (content) {
            // Arrivé ici sans contenu (lien ouvert juste avant une dépublication,
            // par exemple) : on le dit, sans rien inventer.
            if (content.isEmpty) return _Message(icon: Icons.hourglass_empty, text: l10n.wirdRepairUnavailable);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (content.hasDrafts) ...[_DraftBanner(text: l10n.wirdRepairDraftBanner), const SizedBox(height: 16)],
                // Encre et non bronze : le bronze ne passe pas le contraste AA
                // en texte courant (design_tokens.yaml, 3,72:1).
                Text(l10n.wirdRepairIntro, style: _uiBody(size: 14)),
                const SizedBox(height: 20),
                if (_readAll) ..._buildReadAll(context, content) else ..._buildBySituation(context, content),
                const SizedBox(height: 28),
                _AskMoqaddamPanel(notes: content.notesFor(RepairWird.all, RepairNoteType.askMoqaddam)),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBySituation(BuildContext context, WirdRepairContent content) {
    final l10n = AppLocalizations.of(context)!;
    final own = content.casesOnlyFor(_wird, kind: _kind);
    final common = content.casesOnlyFor(RepairWird.all, kind: _kind);
    return [
      _Label(l10n.wirdRepairWhichWird),
      const SizedBox(height: 4),
      _WirdTabs(selected: _wird, onSelected: (wird) => setState(() => _wird = wird)),
      const SizedBox(height: 16),
      // Le fondu ne joue qu'au changement de wird : il montre au disciple
      // que la réponse affichée a changé avec son choix.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _WirdSummary(key: ValueKey(_wird), wird: _wird, content: content),
      ),
      const SizedBox(height: 28),
      _Label(l10n.wirdRepairWhatHappened),
      const SizedBox(height: 10),
      _KindChips(
        selected: _kind,
        // Nombre de cas par type, pour le wird choisi (ses cas et les règles
        // communes) : le disciple voit d'avance où chercher.
        countFor: (kind) => content.casesFor(_wird, kind: kind).length,
        onSelected: (kind) => setState(() => _kind = kind),
      ),
      const SizedBox(height: 16),
      if (own.isEmpty && common.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.wirdRepairEmpty, textAlign: TextAlign.center, style: _uiBody(size: 14.5)),
        )
      else ...[
        if (own.isNotEmpty) _CaseList(cases: own),
        if (common.isNotEmpty) ...[
          if (own.isNotEmpty) const SizedBox(height: 24),
          // Un seul intertitre pour toutes les règles communes, plutôt que la
          // mention « Vaut pour tous les wirds » répétée sur chaque cas.
          _GroupHeading(icon: Icons.all_inclusive, text: l10n.wirdRepairCommonGroup),
          const SizedBox(height: 10),
          _CaseList(cases: common),
        ],
      ],
    ];
  }

  List<Widget> _buildReadAll(BuildContext context, WirdRepairContent content) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = _isArabic(context);
    final widgets = <Widget>[];
    for (final wird in RepairWird.values) {
      final cases = content.casesOnlyFor(wird);
      final intro = content.noteFor(wird, RepairNoteType.intro);
      if (cases.isEmpty && intro == null) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 32));
      widgets.add(_SectionTitle(wird == RepairWird.all ? l10n.wirdRepairCommonSection : _wirdName(context, wird)));
      // La réponse rapide sous le nom du wird : sans elle, la lecture
      // complète ne disait plus d'emblée si le wird se rattrape.
      final answer = content.noteFor(wird, RepairNoteType.quickAnswer);
      if (answer != null) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(_QuickAnswer(note: answer, size: 20));
      }
      if (intro != null) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(ContentText(intro.textFor(isArabic), style: _contentStyle(isArabic, size: 14.5)));
      }
      final timings = content.notesFor(wird, RepairNoteType.timing);
      if (timings.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
        widgets.add(_TimingTable(notes: timings));
      }
      final warning = content.noteFor(wird, RepairNoteType.warning);
      if (warning != null) {
        widgets.add(const SizedBox(height: 14));
        widgets.add(_WarningBand(text: warning.textFor(isArabic)));
      }
      if (cases.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_CaseList(cases: cases));
      }
    }
    return widgets;
  }
}

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

Wird _validatedWird(RepairWird wird) {
  final id = switch (wird) {
    RepairWird.lazim => 'lazim',
    RepairWird.wazifa => 'wazifa',
    RepairWird.hadra => 'hadratou_jouma',
    RepairWird.all => throw ArgumentError('pas de nom de wird pour les règles communes'),
  };
  return validatedWirds.firstWhere((w) => w.id == id);
}

/// Nom du wird tel que le guide validé le donne (`wirds_content.dart`), dans
/// la langue de l'interface — jamais un nom réécrit ici.
String _wirdName(BuildContext context, RepairWird wird) => wirdDisplayName(context, _validatedWird(wird));

/// Texte d'interface courant : Jost, en encre (contraste AA sur parchemin).
TextStyle _uiBody({double size = 15, FontWeight? weight, Color? color}) =>
    TextStyle(fontSize: size, height: 1.5, color: color ?? AppColors.ink, fontWeight: weight);

/// Texte secondaire (sources) : encre adoucie plutôt que bronze, voir
/// [AppColors.secondaryInk].
Color get _secondaryInk => AppColors.secondaryInk;

/// Style du contenu religieux : Amiri en arabe (texte religieux, règle du
/// design system), Jost en français, comme le reste du texte courant de
/// l'app. Amiri est un cran plus grand à taille égale de lecture.
TextStyle _contentStyle(bool isArabic, {double size = 15, FontWeight? weight, Color? color}) {
  final c = color ?? AppColors.ink;
  if (isArabic) return AppTheme.sacredText(fontSize: size + 2, color: c).copyWith(fontWeight: weight);
  return TextStyle(fontSize: size, height: 1.5, color: c, fontWeight: weight);
}

/// Titre de section (lecture complète) : Cormorant en français, Amiri en
/// arabe — les deux polices de titre de la charte.
TextStyle _titleStyle(bool isArabic, {double size = 24, Color? color}) {
  final c = color ?? AppColors.ink;
  if (isArabic) return AppTheme.sacredText(fontSize: size, color: c).copyWith(fontWeight: FontWeight.w700, height: 1.4);
  return GoogleFonts.cormorantGaramond(fontSize: size + 2, fontWeight: FontWeight.w600, color: c, height: 1.15);
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ContentText(text, style: _titleStyle(_isArabic(context)));
}

/// Intertitre d'un groupe de cas, avec un filet d'or qui le sépare du groupe
/// précédent.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.6)),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.emerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: _uiBody(size: 15.5, weight: FontWeight.w600, color: AppColors.emerald)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Choix du wird : trois onglets à parts égales, soulignés d'un filet d'or
/// quand ils sont choisis. Plutôt qu'un `SegmentedButton`, dont les segments
/// tronquaient « Hadratou-l-Jouma » sur un téléphone étroit : ici le nom peut
/// passer sur deux lignes.
///
/// Sous le nom, l'autre langue en petit (nom arabe dans l'app en français, nom
/// français dans l'app en arabe) : la charte présente un wird par ses deux
/// noms (docs/02, « Carte wird »).
class _WirdTabs extends StatelessWidget {
  const _WirdTabs({required this.selected, required this.onSelected});

  final RepairWird selected;
  final ValueChanged<RepairWird> onSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
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
    final validated = _validatedWird(wird);
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
                _wirdName(context, wird),
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
class _QuickAnswer extends StatelessWidget {
  const _QuickAnswer({required this.note, this.size = 32});

  final WirdRepairNote note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
    final negative = note.isNegativeAnswer;
    final color = negative ? AppColors.ink : AppColors.emerald;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(negative ? Icons.do_not_disturb_on_outlined : Icons.history, color: color, size: size * 0.8),
        SizedBox(width: size * 0.3),
        Expanded(child: ContentText(note.textFor(isArabic), style: _titleStyle(isArabic, size: size, color: color))),
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
class _WirdSummary extends StatelessWidget {
  const _WirdSummary({super.key, required this.wird, required this.content});

  final RepairWird wird;
  final WirdRepairContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = _isArabic(context);
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
                  _QuickAnswer(note: answer),
                  const SizedBox(height: 10),
                  Container(width: 36, height: 2, color: AppColors.gold),
                  const SizedBox(height: 12),
                ],
                if (intro != null) ContentText(intro.textFor(isArabic), style: _contentStyle(isArabic, size: 14.5)),
                if (timings.isNotEmpty || warning != null) const SizedBox(height: 6),
                if (timings.isNotEmpty)
                  _Collapsible(
                    icon: Icons.schedule,
                    color: AppColors.emerald,
                    label: l10n.wirdRepairSchedule,
                    child: _TimingTable(notes: timings),
                  ),
                if (warning != null)
                  _Collapsible(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.ink,
                    label: l10n.wirdRepairWarningLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: _WarningBand(text: warning.textFor(isArabic)),
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
class _TimingTable extends StatelessWidget {
  const _TimingTable({required this.notes});

  final List<WirdRepairNote> notes;

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
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
                    style: _contentStyle(isArabic, size: 14, weight: FontWeight.w600, color: AppColors.emerald),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: ContentText(notes[i].textFor(isArabic), style: _contentStyle(isArabic, size: 14.5))),
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
class _WarningBand extends StatelessWidget {
  const _WarningBand({required this.text});

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
          child: ContentText(text, style: _contentStyle(_isArabic(context), size: 14.5)),
        ),
      ),
    );
  }
}

/// Filtres par type de situation, avec le nombre de cas de chacun pour le
/// wird choisi. Libellés courts (« Erreur », « Empêchement ») : les
/// libellés longs faisaient trois rangées de puces. Un type sans aucun cas
/// reste visible mais grisé : le disciple voit qu'il n'y a rien plutôt que
/// de chercher une puce disparue.
class _KindChips extends StatelessWidget {
  const _KindChips({required this.selected, required this.countFor, required this.onSelected});

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
class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases});

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
    final isArabic = _isArabic(context);
    final source = repairCase.sourceFor(isArabic);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentText(repairCase.situationFor(isArabic), style: _contentStyle(isArabic, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          ContentText(repairCase.actionFor(isArabic), style: _contentStyle(isArabic, size: 14.5)),
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 8),
            ContentText(
              l10n.wirdRepairSource(source),
              // Pas d'italique en arabe : l'écriture arabe n'en a pas, et
              // Flutter penchait artificiellement l'Amiri.
              style: TextStyle(
                fontSize: isArabic ? 13 : 12.5,
                fontStyle: isArabic ? FontStyle.normal : FontStyle.italic,
                color: _secondaryInk,
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
class _AskMoqaddamPanel extends StatelessWidget {
  const _AskMoqaddamPanel({required this.notes});

  final List<WirdRepairNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isArabic = _isArabic(context);
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
                    Expanded(child: ContentText(note.textFor(isArabic), style: _contentStyle(isArabic, size: 14.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, color: AppColors.ink, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: _uiBody(size: 14.5)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
