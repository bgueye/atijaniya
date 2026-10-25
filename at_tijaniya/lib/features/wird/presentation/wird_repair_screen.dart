import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_repair_models.dart';
import 'wird_repair_cases.dart';
import 'wird_repair_providers.dart';
import 'wird_repair_styles.dart';
import 'wird_repair_summary.dart';

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
                Text(l10n.wirdRepairIntro, style: repairUiBody(size: 14)),
                const SizedBox(height: 20),
                if (_readAll) ..._buildReadAll(context, content) else ..._buildBySituation(context, content),
                const SizedBox(height: 28),
                RepairAskMoqaddamPanel(notes: content.notesFor(RepairWird.all, RepairNoteType.askMoqaddam)),
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
      RepairWirdTabs(selected: _wird, onSelected: (wird) => setState(() => _wird = wird)),
      const SizedBox(height: 16),
      // Le fondu ne joue qu'au changement de wird : il montre au disciple
      // que la réponse affichée a changé avec son choix.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: RepairWirdSummary(key: ValueKey(_wird), wird: _wird, content: content),
      ),
      const SizedBox(height: 28),
      _Label(l10n.wirdRepairWhatHappened),
      const SizedBox(height: 10),
      RepairKindChips(
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
          child: Text(l10n.wirdRepairEmpty, textAlign: TextAlign.center, style: repairUiBody(size: 14.5)),
        )
      else ...[
        if (own.isNotEmpty) RepairCaseList(cases: own),
        if (common.isNotEmpty) ...[
          if (own.isNotEmpty) const SizedBox(height: 24),
          // Un seul intertitre pour toutes les règles communes, plutôt que la
          // mention « Vaut pour tous les wirds » répétée sur chaque cas.
          _GroupHeading(icon: Icons.all_inclusive, text: l10n.wirdRepairCommonGroup),
          const SizedBox(height: 10),
          RepairCaseList(cases: common),
        ],
      ],
    ];
  }

  List<Widget> _buildReadAll(BuildContext context, WirdRepairContent content) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    final widgets = <Widget>[];
    for (final wird in RepairWird.values) {
      final cases = content.casesOnlyFor(wird);
      final intro = content.noteFor(wird, RepairNoteType.intro);
      if (cases.isEmpty && intro == null) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 32));
      widgets.add(_SectionTitle(wird == RepairWird.all ? l10n.wirdRepairCommonSection : repairWirdName(context, wird)));
      // La réponse rapide sous le nom du wird : sans elle, la lecture
      // complète ne disait plus d'emblée si le wird se rattrape.
      final answer = content.noteFor(wird, RepairNoteType.quickAnswer);
      if (answer != null) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(RepairQuickAnswer(note: answer, size: 20));
      }
      if (intro != null) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(ContentText(intro.textFor(isArabic), style: repairContentStyle(isArabic, size: 14.5)));
      }
      final timings = content.notesFor(wird, RepairNoteType.timing);
      if (timings.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
        widgets.add(RepairTimingTable(notes: timings));
      }
      final warning = content.noteFor(wird, RepairNoteType.warning);
      if (warning != null) {
        widgets.add(const SizedBox(height: 14));
        widgets.add(RepairWarningBand(text: warning.textFor(isArabic)));
      }
      if (cases.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(RepairCaseList(cases: cases));
      }
    }
    return widgets;
  }
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
  Widget build(BuildContext context) => ContentText(text, style: repairTitleStyle(repairIsArabic(context)));
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
              child: Text(text, style: repairUiBody(size: 15.5, weight: FontWeight.w600, color: AppColors.emerald)),
            ),
          ],
        ),
      ],
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
            Text(text, textAlign: TextAlign.center, style: repairUiBody(size: 14.5)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
