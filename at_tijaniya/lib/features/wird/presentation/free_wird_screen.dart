import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/free_wird_session.dart';
import '../domain/tasbih_session.dart' show TasbihMode;
import 'free_wird_controller.dart';

/// Wird libre — compteur paramétré par le disciple (nom + cible), en plus
/// des trois wirds au contenu fixe et validé. Priorité demandée par le
/// porteur de projet, en complément du module Wirds P0/P1.
///
/// Volontairement autonome vis-à-vis de `tasbih_screen.dart`/
/// `tasbih_controller.dart` (écran P0 déjà validé en conditions réelles,
/// piloté par `Wird.pillars`) : pas de refactor partagé, pour ne prendre
/// aucun risque de régression sur ce dernier. Aucun texte religieux n'est
/// fourni par l'app ici — [FreeWirdSession.label] est entièrement saisi et
/// privé au disciple (voir la règle "contenu religieux" de CLAUDE.md, qui
/// ne s'applique qu'au contenu publié par l'app elle-même).
class FreeWirdScreen extends ConsumerWidget {
  const FreeWirdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(freeWirdControllerProvider);
    final controller = ref.read(freeWirdControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.zaytoune,
      appBar: AppBar(
        backgroundColor: AppColors.zaytoune,
        foregroundColor: AppColors.parchment,
        title: Text(
          state.session != null && state.session!.label.isNotEmpty
              ? state.session!.label
              : l10n.wirdFreeTitle,
        ),
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : state.completed
                ? _CompletedView(l10n: l10n, controller: controller)
                : state.session == null
                    ? _SetupForm(l10n: l10n, controller: controller)
                    : _CounterBody(l10n: l10n, state: state, controller: controller),
      ),
    );
  }
}

class _SetupForm extends StatefulWidget {
  const _SetupForm({required this.l10n, required this.controller});

  final AppLocalizations l10n;
  final FreeWirdController controller;

  @override
  State<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<_SetupForm> {
  static const _quickTargets = [33, 99, 100, 1000];

  final _labelController = TextEditingController();
  final _targetController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _pickQuickTarget(int value) {
    setState(() {
      _targetController.text = '$value';
      _error = null;
    });
  }

  void _submit() {
    final target = int.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      setState(() => _error = widget.l10n.wirdFreeTargetRequired);
      return;
    }
    widget.controller.configure(label: _labelController.text, target: target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            style: const TextStyle(color: AppColors.parchment),
            decoration: InputDecoration(
              labelText: l10n.wirdFreeLabelFieldLabel,
              labelStyle: const TextStyle(color: AppColors.bronze),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.bronze)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.wirdFreeTargetFieldLabel, style: const TextStyle(color: AppColors.parchment)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _quickTargets)
                _QuickTargetPill(
                  value: value,
                  selected: _targetController.text == '$value',
                  onTap: () => _pickQuickTarget(value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.parchment),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: '100',
              hintStyle: const TextStyle(color: AppColors.bronze),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.bronze)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _submit, child: Text(l10n.wirdFreeStartButton)),
        ],
      ),
    );
  }
}

/// Puce de cible rapide (33/99/100/1000) — `Container` explicite plutôt
/// qu'un `ChoiceChip` : le thème M3 par défaut de l'app (aucun `chipTheme`
/// personnalisé, voir `app_theme.dart`) écrase les couleurs passées
/// directement au widget sur le thème immersif sombre, rendant le texte
/// illisible. Même approche que `_RepetitionBadge`
/// (`wird_detail_screen.dart`), déjà utilisée ailleurs dans le module Wird.
class _QuickTargetPill extends StatelessWidget {
  const _QuickTargetPill({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.parchment.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            color: selected ? AppColors.ink : AppColors.parchment,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CounterBody extends StatelessWidget {
  const _CounterBody({required this.l10n, required this.state, required this.controller});

  final AppLocalizations l10n;
  final FreeWirdState state;
  final FreeWirdController controller;

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    final complete = controller.isTargetReached;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SegmentedButton<TasbihMode>(
            segments: [
              ButtonSegment(value: TasbihMode.manual, label: Text(l10n.wirdFreeManualMode), icon: const Icon(Icons.touch_app)),
              ButtonSegment(value: TasbihMode.voice, label: Text(l10n.wirdFreeVoiceMode), icon: const Icon(Icons.mic)),
            ],
            selected: {session.mode},
            onSelectionChanged: (selection) => controller.setMode(selection.first),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: session.mode == TasbihMode.manual
                  ? _ManualCounter(
                      l10n: l10n,
                      count: session.currentCount,
                      target: session.target,
                      complete: complete,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.increment();
                      },
                    )
                  : _VoiceCounter(l10n: l10n, state: state, session: session, complete: complete, controller: controller),
            ),
          ),
          if (!complete)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: session.currentCount == 0 ? null : controller.undo,
                  icon: const Icon(Icons.undo, color: AppColors.parchment),
                  label: Text(l10n.wirdFreeUndo, style: const TextStyle(color: AppColors.parchment)),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: session.currentCount == 0 ? null : controller.resetCount,
                  icon: const Icon(Icons.replay, color: AppColors.parchment),
                  label: Text(l10n.wirdFreeReset, style: const TextStyle(color: AppColors.parchment)),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  controller.finish();
                },
                icon: const Icon(Icons.check_circle),
                label: Text(l10n.wirdFreeFinishButton),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualCounter extends StatelessWidget {
  const _ManualCounter({
    required this.l10n,
    required this.count,
    required this.target,
    required this.complete,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final int count;
  final int target;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: complete ? null : onTap,
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: AppColors.parchment.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(complete ? AppColors.gold : AppColors.emerald),
            ),
            Container(
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
                    Text(l10n.wirdFreeTapToCount, style: const TextStyle(color: AppColors.bronze, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCounter extends StatelessWidget {
  const _VoiceCounter({
    required this.l10n,
    required this.state,
    required this.session,
    required this.complete,
    required this.controller,
  });

  final AppLocalizations l10n;
  final FreeWirdState state;
  final FreeWirdSession session;
  final bool complete;
  final FreeWirdController controller;

  @override
  Widget build(BuildContext context) {
    final count = session.currentCount;
    final target = session.target;
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: AppColors.parchment.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(complete ? AppColors.gold : AppColors.emerald),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(color: AppColors.parchment, fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  Text('/ $target', style: const TextStyle(color: AppColors.bronze, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!state.voiceSupported || state.voiceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              state.voiceError ?? l10n.wirdFreeVoiceUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold, fontSize: 13),
            ),
          )
        else
          Text(
            state.isListening ? l10n.wirdFreeListeningActive : l10n.wirdFreeListeningPaused,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.bronze, fontSize: 13),
          ),
        const SizedBox(height: 12),
        if (state.voiceSupported && !complete)
          ElevatedButton.icon(
            onPressed: state.isListening ? controller.stopListening : controller.startListening,
            icon: Icon(state.isListening ? Icons.mic_off : Icons.mic),
            label: Text(state.isListening ? l10n.wirdFreeStopListening : l10n.wirdFreeStartListening),
          ),
      ],
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.l10n, required this.controller});

  final AppLocalizations l10n;
  final FreeWirdController controller;

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
              l10n.wirdFreeCompletedTitle,
              style: const TextStyle(color: AppColors.parchment, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.wirdFreeCompletedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.bronze),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: controller.newCounter,
              child: Text(l10n.wirdFreeNewCounterButton),
            ),
          ],
        ),
      ),
    );
  }
}
