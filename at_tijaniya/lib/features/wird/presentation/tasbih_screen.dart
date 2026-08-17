import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/tasbih_session.dart';
import '../domain/wird_models.dart';
import 'tasbih_beads_ring.dart';
import 'tasbih_controller.dart';

/// Tasbih digital — tape manuel, reconnaissance vocale, reprise de session.
/// Priorité P0 (docs/03-architecture-ecrans.md).
///
/// Fait dérouler les piliers obligatoires du wird (`Wird.pillars`) dans
/// l'ordre impératif du corpus validé — voir la règle "contenu religieux"
/// dans CLAUDE.md : aucun texte n'est saisi ici, seul le comptage l'est.
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
          title: Text('Tasbih — ${wird.nameFrench}'),
        ),
        body: SafeArea(
          child: state.loadingSession
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : state.wirdCompleted
                  ? _WirdCompletedView(wird: wird)
                  : _TasbihBody(wird: wird, state: state, controller: controller),
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
    final pillar = controller.currentPillar;
    final target = controller.targetCount;
    final count = state.session.currentCount;
    final complete = controller.isPillarComplete;

    // SingleChildScrollView plutôt qu'un Column simple : le pilier
    // "Intention" (piliers[0], ajouté le 2026-08-12) est un paragraphe
    // complet — bien plus haut que les formules courtes des autres piliers
    // — qui dépasse la hauteur d'écran sur la plupart des appareils. Le
    // cercle de comptage (TasbihBeadsRing) a une taille fixe (voir
    // _ManualCounter/_VoiceCounter) : sans scroll, il se retrouvait écrasé
    // dans l'espace résiduel laissé par un Expanded plutôt que de
    // s'afficher à sa taille prévue.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Pilier ${state.session.pillarIndex + 1} / ${wird.pillars.length}',
            style: const TextStyle(color: AppColors.bronze, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            pillar.transliteration,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.parchment, fontSize: 16, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Text(
            pillar.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTheme.sacredText(fontSize: 26, color: AppColors.gold),
          ),
          if (pillar.note != null) ...[
            const SizedBox(height: 8),
            Text(
              pillar.note!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.bronze),
            ),
          ],
          if (pillar.closingFormulas != null)
            for (final formula in pillar.closingFormulas!) ...[
              const SizedBox(height: 10),
              Text(
                formula.intro,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.bronze),
              ),
              const SizedBox(height: 4),
              Text(
                formula.arabic,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: AppTheme.sacredText(fontSize: 18, color: AppColors.gold),
              ),
              if (formula.transliteration != null) ...[
                const SizedBox(height: 2),
                Text(
                  formula.transliteration!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.bronze),
                ),
              ],
            ],
          const SizedBox(height: 20),
          SegmentedButton<TasbihMode>(
            segments: const [
              ButtonSegment(value: TasbihMode.manual, label: Text('Tape manuel'), icon: Icon(Icons.touch_app)),
              ButtonSegment(value: TasbihMode.voice, label: Text('Voix'), icon: Icon(Icons.mic)),
            ],
            selected: {state.session.mode},
            onSelectionChanged: (selection) => controller.setMode(selection.first),
          ),
          const SizedBox(height: 24),
          state.session.mode == TasbihMode.manual
              ? _ManualCounter(
                  count: count,
                  target: target,
                  complete: complete,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.increment();
                  },
                )
              : _VoiceCounter(state: state, count: count, target: target, complete: complete, controller: controller),
          const SizedBox(height: 24),
          if (!complete)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: count == 0 ? null : controller.undo,
                  icon: const Icon(Icons.undo, color: AppColors.parchment),
                  label: const Text('Corriger -1', style: TextStyle(color: AppColors.parchment)),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: count == 0 ? null : controller.resetPillar,
                  icon: const Icon(Icons.replay, color: AppColors.parchment),
                  label: const Text('Réinitialiser', style: TextStyle(color: AppColors.parchment)),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  controller.nextPillar();
                },
                icon: Icon(controller.isLastPillar ? Icons.check_circle : Icons.arrow_forward),
                label: Text(controller.isLastPillar ? 'Terminer le wird' : 'Pilier suivant'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualCounter extends StatelessWidget {
  const _ManualCounter({
    required this.count,
    required this.target,
    required this.complete,
    required this.onTap,
  });

  final int count;
  final int target;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: complete ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: TasbihBeadsRing(
        count: count,
        target: target,
        size: 240,
        complete: complete,
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emerald.withValues(alpha: complete ? 0.35 : 0.18),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(color: AppColors.parchment, fontSize: 56, fontWeight: FontWeight.bold),
              ),
              Text('/ $target', style: const TextStyle(color: AppColors.bronze, fontSize: 18)),
              const SizedBox(height: 8),
              if (complete)
                const Icon(Icons.check_circle, color: AppColors.gold, size: 26)
              else
                const Text(
                  'Toucher pour compter',
                  style: TextStyle(color: AppColors.bronze, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceCounter extends StatelessWidget {
  const _VoiceCounter({
    required this.state,
    required this.count,
    required this.target,
    required this.complete,
    required this.controller,
  });

  final TasbihState state;
  final int count;
  final int target;
  final bool complete;
  final TasbihController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TasbihBeadsRing(
          count: count,
          target: target,
          size: 220,
          complete: complete,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(color: AppColors.parchment, fontSize: 48, fontWeight: FontWeight.bold),
              ),
              Text('/ $target', style: const TextStyle(color: AppColors.bronze, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!state.voiceSupported || state.voiceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              state.voiceError ?? 'Reconnaissance vocale indisponible sur cet appareil.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold, fontSize: 13),
            ),
          )
        else
          Text(
            state.isListening ? "À l'écoute — récitez, une pause de silence = +1" : 'Micro en pause',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.bronze, fontSize: 13),
          ),
        const SizedBox(height: 12),
        if (state.voiceSupported && !complete)
          ElevatedButton.icon(
            onPressed: state.isListening ? controller.stopListening : controller.startListening,
            icon: Icon(state.isListening ? Icons.mic_off : Icons.mic),
            label: Text(state.isListening ? 'Mettre en pause' : "Démarrer l'écoute"),
          ),
      ],
    );
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
            const Icon(Icons.check_circle, color: AppColors.gold, size: 72),
            const SizedBox(height: 16),
            Text(
              '${wird.nameFrench} terminé',
              style: const TextStyle(color: AppColors.parchment, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tous les piliers ont été récités.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.bronze),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour au guide'),
            ),
          ],
        ),
      ),
    );
  }
}
