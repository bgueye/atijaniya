import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/keep_screen_on.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/data/donation_feature_flag.dart';
import '../../donation/data/donation_nudge_store.dart';
import '../../donation/presentation/donation_screen.dart';
import '../domain/wird_models.dart';
import 'tasbih_controller.dart';
import 'tasbih_counter_panel.dart';
import 'wird_display_name.dart';

/// Tasbih digital — comptage au toucher, reconnaissance vocale, reprise de
/// session. Priorité P0 (docs/03-architecture-ecrans.md).
///
/// Fait dérouler les piliers obligatoires du wird (`Wird.pillars`) dans
/// l'ordre impératif du corpus validé — voir la règle "contenu religieux"
/// dans CLAUDE.md : aucun texte n'est saisi ici, seul le comptage l'est.
///
/// Présentation revue le 2026-10-06 : le texte du pilier défile seul en
/// haut, le compteur reste fixe en bas (`TasbihCounterLayout`), et l'écran ne
/// se met plus en veille pendant la récitation.
class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key, required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tasbihControllerProvider(wird));
    final controller = ref.read(tasbihControllerProvider(wird).notifier);

    // Cf. wird_detail_screen.dart : sans le thème immersif, le titre d'AppBar
    // hérite de la couleur `ink` (quasi noire) du thème clair ambiant et
    // devient illisible sur le fond vert zaytoune.
    return Theme(
      data: AppTheme.immersive,
      child: Scaffold(
        backgroundColor: AppColors.zaytoune,
        appBar: AppBar(
          backgroundColor: AppColors.zaytoune,
          foregroundColor: AppColors.parchment,
          // Le nom du wird seul : "Tasbih —" n'apprenait rien à qui vient
          // d'appuyer sur "Tasbih".
          title: Text(wirdDisplayName(context, wird), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          child: state.loadingSession
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : state.wirdCompleted
                  ? _WirdCompletedView(wird: wird)
                  : KeepScreenOn(child: _TasbihBody(wird: wird, state: state, controller: controller)),
        ),
      ),
    );
  }
}

class _TasbihBody extends StatelessWidget {
  const _TasbihBody({required this.wird, required this.state, required this.controller});

  final Wird wird;
  final TasbihState state;
  final TasbihController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = state.session.currentCount;
    final complete = controller.isPillarComplete;

    return Column(
      children: [
        _PillarProgress(
          current: state.session.pillarIndex,
          total: wird.pillars.length,
          label: l10n.wirdTasbihPillarProgress(state.session.pillarIndex + 1, wird.pillars.length),
        ),
        Expanded(
          child: TasbihCounterLayout(
            reading: _Reading(
              controller: controller,
              pillarIndex: state.session.pillarIndex,
              count: count,
              complete: complete,
            ),
            panel: TasbihCounterPanel(
              count: count,
              target: controller.targetCount,
              complete: complete,
              mode: state.session.mode,
              onModeChanged: controller.setMode,
              onCount: () {
                HapticFeedback.lightImpact();
                controller.increment();
              },
              onUndo: controller.undo,
              onReset: controller.resetPillar,
              isListening: state.isListening,
              voiceSupported: state.voiceSupported,
              voiceError: state.voiceError,
              onStartListening: controller.startListening,
              onStopListening: controller.stopListening,
              // Piliers intermédiaires sans clôture : le contrôleur enchaîne
              // tout seul après un court délai, le bouton reste là pour qui
              // veut avancer sans attendre. Avec une clôture à réciter, ou
              // sur le dernier pilier, avancer reste un geste volontaire.
              completeHint: controller.autoAdvancesAfterCompletion ? l10n.wirdTasbihNextPillarSoon : null,
              completeAction: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    controller.nextPillar();
                  },
                  icon: Icon(controller.isLastPillar ? Icons.check_circle : Icons.arrow_forward),
                  label: Text(controller.isLastPillar ? l10n.wirdTasbihFinishWird : l10n.wirdTasbihNextPillar),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avancement dans le wird : un segment par pilier (les piliers forment bien
/// une suite ordonnée), doré jusqu'au pilier en cours, et le rappel chiffré.
class _PillarProgress extends StatelessWidget {
  const _PillarProgress({required this.current, required this.total, required this.label});

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        children: [
          // Décor : l'information est portée par le texte juste en dessous.
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: i <= current ? AppColors.gold : AppColors.parchment.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: tasbihSecondaryText(), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Zone de lecture du pilier : le texte arabe d'abord (c'est lui qui est
/// récité), sa translittération ensuite, puis la note et la clôture. Défile
/// seule, avec un fondu en bas quand le texte dépasse.
///
/// Une fois le compte atteint, si le pilier a une formule de clôture, elle
/// prend toute la zone en grand : c'est à ce moment qu'elle se récite.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.controller,
    required this.pillarIndex,
    required this.count,
    required this.complete,
  });

  final TasbihController controller;
  final int pillarIndex;
  final int count;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillar = controller.currentPillar;
    final usingAlternative = controller.usingAlternative;
    final alternative = pillar.alternative;
    // Les formules de clôture sont propres au pilier normal, pas à
    // l'alternative.
    final closing = usingAlternative ? null : pillar.closingFormulas;
    final closingNow = complete && closing != null;

    return ShaderMask(
      // Fondu des 28 derniers pixels : signale qu'il reste du texte à faire
      // défiler sans qu'une ligne soit coupée net contre le socle.
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, (rect.height - 28).clamp(0, rect.height) / rect.height, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        // Nouvelle clé à chaque changement de contenu : la lecture repart du
        // haut au pilier suivant et à l'apparition de la clôture.
        key: ValueKey('${controller.wird.id}-$pillarIndex-$usingAlternative-$closingNow'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              if (closingNow)
                for (final formula in closing) ..._closing(formula, large: true)
              else ...[
                Text(
                  usingAlternative ? alternative!.arabic : pillar.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.sacredText(fontSize: 28, color: AppColors.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  usingAlternative ? alternative!.transliteration : pillar.transliteration,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.parchment,
                    fontSize: 16,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                // Le pilier normal explique dans sa note quand recourir à
                // l'alternative (ex. conditions de Jawharatoul Kamal non
                // réunies) — cette explication n'a plus lieu d'être une fois
                // l'alternative choisie.
                if (!usingAlternative && pillar.note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    pillar.note!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: tasbihSecondaryText()),
                  ),
                ],
                if (alternative != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: AppColors.gold,
                    title: Text(
                      l10n.wirdTasbihUseAlternative(alternative.repetitions, alternative.name),
                      style: const TextStyle(color: AppColors.parchment, fontSize: 14),
                    ),
                    value: usingAlternative,
                    // Ignoré une fois le comptage commencé (voir
                    // `TasbihController.setUseAlternative`) : le bouton reste
                    // visible mais n'a plus d'effet, pour ne pas faire
                    // disparaître l'option sous les yeux du disciple en pleine
                    // récitation.
                    onChanged: count == 0 ? (value) => controller.setUseAlternative(value) : null,
                  ),
                ],
                if (closing != null)
                  for (final formula in closing) ..._closing(formula, large: false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bloc d'une formule de clôture : introduction française, arabe en Amiri,
  /// translittération quand le document source en fournit une.
  List<Widget> _closing(WirdClosingFormula formula, {required bool large}) {
    return [
      SizedBox(height: large ? 4 : 18),
      Text(
        formula.intro,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: large ? 15 : 14, height: 1.4, color: tasbihSecondaryText()),
      ),
      const SizedBox(height: 6),
      Text(
        formula.arabic,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: AppTheme.sacredText(fontSize: large ? 26 : 20, color: AppColors.gold),
      ),
      if (formula.transliteration != null) ...[
        const SizedBox(height: 4),
        Text(
          formula.transliteration!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: large ? 16 : 14,
            height: 1.45,
            color: large ? AppColors.parchment : tasbihSecondaryText(),
          ),
        ),
      ],
      if (large) const SizedBox(height: 12),
    ];
  }
}

class _WirdCompletedView extends StatelessWidget {
  const _WirdCompletedView({required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.gold, size: 72),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.wirdTasbihCompletedTitle(wirdDisplayName(context, wird)),
              style: const TextStyle(color: AppColors.parchment, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.wirdTasbihCompletedBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.bronze),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.wirdTasbihBackToGuide),
            ),
            if (kDonationsEnabled) const _DonationNudge(),
          ],
        ),
      ),
    );
  }
}

/// Rappel discret vers `DonationScreen`, uniquement sur l'écran "Wird terminé"
/// — le moment de gratitude le plus naturel de l'app — et au maximum une fois
/// par semaine (`DonationNudgeStore`). Toujours en dessous du bouton "Retour
/// au guide" : un ajout secondaire, jamais la priorité visuelle de cet écran.
class _DonationNudge extends StatefulWidget {
  const _DonationNudge();

  @override
  State<_DonationNudge> createState() => _DonationNudgeState();
}

class _DonationNudgeState extends State<_DonationNudge> {
  static const _store = DonationNudgeStore();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    if (await _store.shouldShow()) {
      await _store.markShown();
      if (mounted) setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationScreen())),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 14, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.wirdTasbihDonationNudge,
              style: TextStyle(color: AppColors.bronze, fontSize: 12, decoration: TextDecoration.underline, decorationColor: AppColors.bronze),
            ),
          ],
        ),
      ),
    );
  }
}
