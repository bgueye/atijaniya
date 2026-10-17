import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wirds_content.dart';
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
///   C'est la question qu'il se pose en ouvrant la page ;
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
      body: contentAsync.when(
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
              ContentText(l10n.wirdRepairIntro, style: TextStyle(color: AppColors.bronze, fontSize: 14, height: 1.45)),
              const SizedBox(height: 20),
              if (_readAll) ..._buildReadAll(context, content) else ..._buildBySituation(context, content),
              const SizedBox(height: 28),
              _AskMoqaddamPanel(notes: content.notesFor(RepairWird.all, RepairNoteType.askMoqaddam)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBySituation(BuildContext context, WirdRepairContent content) {
    final l10n = AppLocalizations.of(context)!;
    final cases = content.casesFor(_wird, kind: _kind);
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
      _KindChips(selected: _kind, onSelected: (kind) => setState(() => _kind = kind)),
      const SizedBox(height: 16),
      if (cases.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.wirdRepairEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
        )
      else
        // Les règles communes sont signalées : sans cela, le disciple qui a
        // choisi la Wazifa se demanderait pourquoi un cas parle du wird en
        // général.
        _CaseList(cases: cases, markCommon: true),
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
      if (intro != null) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(ContentText(intro.textFor(isArabic), style: _contentStyle(isArabic, color: AppColors.bronze)));
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
        // Chaque section porte déjà son wird : pas besoin de marquer les
        // règles communes, elles ont leur propre section.
        widgets.add(_CaseList(cases: cases, markCommon: false));
      }
    }
    return widgets;
  }
}

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

/// Nom du wird tel que le guide validé le donne (`wirds_content.dart`), dans
/// la langue de l'interface — jamais un nom réécrit ici.
String _wirdName(BuildContext context, RepairWird wird) {
  final id = switch (wird) {
    RepairWird.lazim => 'lazim',
    RepairWird.wazifa => 'wazifa',
    RepairWird.hadra => 'hadratou_jouma',
    RepairWird.all => throw ArgumentError('pas de nom de wird pour les règles communes'),
  };
  return wirdDisplayName(context, validatedWirds.firstWhere((w) => w.id == id));
}

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

/// Choix du wird : trois onglets à parts égales, soulignés d'un filet d'or
/// quand ils sont choisis. Plutôt qu'un `SegmentedButton`, dont les segments
/// tronquaient « Hadratou-l-Jouma » sur un téléphone étroit : ici le nom peut
/// passer sur deux lignes.
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
        children: [
          for (final wird in const [RepairWird.lazim, RepairWird.wazifa, RepairWird.hadra])
            Expanded(
              child: Semantics(
                selected: wird == selected,
                button: true,
                child: InkWell(
                  onTap: () => onSelected(wird),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: wird == selected ? AppColors.gold : Colors.transparent, width: 2.5),
                      ),
                    ),
                    child: Text(
                      _wirdName(context, wird),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: isArabic
                          ? AppTheme.sacredText(
                              fontSize: 17,
                              color: wird == selected ? AppColors.emerald : AppColors.bronze,
                            ).copyWith(height: 1.3, fontWeight: wird == selected ? FontWeight.w700 : FontWeight.w400)
                          : TextStyle(
                              fontSize: 15,
                              color: wird == selected ? AppColors.emerald : AppColors.bronze,
                              fontWeight: wird == selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ce qu'il faut savoir d'un wird avant d'entrer dans les cas : s'il se
/// rattrape (en grand — c'est la réponse que le disciple cherche d'abord),
/// son introduction, ses horaires et la mise en garde éventuelle.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (answer != null) ...[
                      ContentText(
                        answer.textFor(isArabic),
                        style: _titleStyle(isArabic, size: 32, color: AppColors.emerald),
                      ),
                      const SizedBox(height: 10),
                      Container(width: 36, height: 2, color: AppColors.gold),
                      const SizedBox(height: 12),
                    ],
                    if (intro != null)
                      ContentText(intro.textFor(isArabic), style: _contentStyle(isArabic, size: 14.5, color: AppColors.bronze)),
                    if (timings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CollapsibleSchedule(label: l10n.wirdRepairSchedule, notes: timings),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (warning != null) ...[const SizedBox(height: 12), _WarningBand(text: warning.textFor(isArabic))],
      ],
    );
  }
}

/// Horaires repliés par défaut dans la vue par situation. Dépliés, ceux du
/// Lazim occupaient plus d'un écran et repoussaient les cas — ce que le
/// disciple vient chercher — loin en dessous (constaté sur émulateur le
/// 2026-10-17). La réponse rapide et la mise en garde restent visibles ; la
/// lecture complète, elle, montre toujours les horaires.
class _CollapsibleSchedule extends StatefulWidget {
  const _CollapsibleSchedule({required this.label, required this.notes});

  final String label;
  final List<WirdRepairNote> notes;

  @override
  State<_CollapsibleSchedule> createState() => _CollapsibleScheduleState();
}

class _CollapsibleScheduleState extends State<_CollapsibleSchedule> {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.emerald),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: AppColors.emerald),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: AlignmentDirectional.topStart,
          child: _open ? _TimingTable(notes: widget.notes) : const SizedBox(width: double.infinity),
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
                  width: 76,
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

class _KindChips extends StatelessWidget {
  const _KindChips({required this.selected, required this.onSelected});

  final RepairKind? selected;
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
        for (final (kind, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: kind == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(kind),
            selectedColor: AppColors.emeraldSoft,
            backgroundColor: AppColors.offWhite,
            side: BorderSide(color: kind == selected ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.3)),
            labelStyle: TextStyle(
              color: kind == selected ? AppColors.emerald : AppColors.ink,
              fontWeight: kind == selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

/// Les cas, dans une seule surface séparée par des filets plutôt qu'une pile
/// de cartes : ils se lisent comme une liste continue de questions-réponses.
class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases, required this.markCommon});

  final List<WirdRepairCase> cases;

  /// Signaler les règles communes à tous les wirds (vue par situation).
  final bool markCommon;

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
            _CaseTile(repairCase: cases[i], markCommon: markCommon),
          ],
        ],
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.repairCase, required this.markCommon});

  final WirdRepairCase repairCase;
  final bool markCommon;

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
          if (markCommon && repairCase.wird == RepairWird.all) ...[
            Text(
              l10n.wirdRepairCommonRule,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.emerald),
            ),
            const SizedBox(height: 4),
          ],
          ContentText(repairCase.situationFor(isArabic), style: _contentStyle(isArabic, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          ContentText(repairCase.actionFor(isArabic), style: _contentStyle(isArabic, size: 14.5)),
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 8),
            ContentText(
              l10n.wirdRepairSource(source),
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.bronze, height: 1.4),
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
            Icon(Icons.edit_note, color: AppColors.bronze, size: 20),
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
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
