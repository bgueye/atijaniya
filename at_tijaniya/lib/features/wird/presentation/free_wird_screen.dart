import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/numerals.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/keep_screen_on.dart';
import '../../../l10n/app_localizations.dart';
import 'free_wird_controller.dart';
import 'tasbih_counter_panel.dart';
import '../../../core/widgets/content_text.dart';

/// Wird libre — compteur paramétré par le disciple (nom + cible), en plus
/// des trois wirds au contenu fixe et validé. Priorité demandée par le
/// porteur de projet, en complément du module Wirds P0/P1.
///
/// Contrôleur volontairement autonome vis-à-vis de `tasbih_controller.dart`
/// (piloté par `Wird.pillars`). Depuis le 2026-10-06, la présentation du
/// compteur, elle, est commune aux deux écrans (`tasbih_counter_panel.dart`) :
/// compteur fixe en bas, zone de comptage élargie. Aucun texte religieux n'est
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
          title: Text(
            state.session != null && state.session!.label.isNotEmpty
                ? state.session!.label
                : l10n.wirdFreeTitle,
          ),
        ),
        body: SafeArea(
          child: state.loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.goldOnDark))
              : state.completed
                  ? _CompletedView(l10n: l10n, controller: controller)
                  : state.session == null
                      ? _SetupForm(l10n: l10n, controller: controller)
                      : _CounterBody(l10n: l10n, state: state, controller: controller),
        ),
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
    final target = parseLocalizedInt(_targetController.text.trim());
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
              labelStyle: TextStyle(color: AppColors.secondaryOnDark),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondaryOnDark)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldOnDark)),
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
          // Le libellé visible (« Nombre de répétitions ») est au-dessus des
          // pastilles : sans ce `Semantics`, TalkBack n'annonçait du champ que
          // son indication, « 100 » (audit du 2026-10-25, P2-8).
          MergeSemantics(
            child: Semantics(
              label: l10n.wirdFreeTargetFieldLabel,
              child: TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'))],
                style: const TextStyle(color: AppColors.parchment),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: '100',
                  hintStyle: TextStyle(color: AppColors.secondaryOnDark),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondaryOnDark)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldOnDark)),
                  errorText: _error,
                ),
              ),
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
    // Annoncée comme un bouton, avec son état ; hauteur portée à 48 dp, la
    // zone tactile minimale d'Android (la pastille en faisait environ 40,
    // audit du 2026-10-25, P2-8).
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: _pill(),
      ),
    );
  }

  Widget _pill() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldOnDark : AppColors.parchment.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        ),
        // `widthFactor: 1` : centre le nombre dans les 48 dp de haut sans
        // étirer la pastille. Un `alignment` sur le `Container` lui faisait
        // prendre toute la largeur du `Wrap` (vu sur émulateur le 2026-10-25).
        child: Center(
          widthFactor: 1,
          child: ContentText(
            '$value',
            style: TextStyle(
              color: selected ? AppColors.ink : AppColors.parchment,
              fontWeight: FontWeight.w500,
            ),
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

  /// Abandonner le compteur en cours pour en paramétrer un autre : sans ce
  /// bouton, une cible saisie par erreur obligeait à compter jusqu'au bout
  /// (le compteur est restauré à chaque retour sur l'écran).
  Future<void> _abandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.wirdFreeAbandonConfirmTitle),
        content: Text(l10n.wirdFreeAbandonConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.wirdFreeNewCounterButton),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.newCounter();
  }

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    final complete = controller.isTargetReached;

    // Même mise en page que le Tasbih d'un wird (`TasbihCounterLayout`) : ce
    // que le disciple récite en haut, le compteur fixe en bas, écran maintenu
    // allumé. Seule la présentation est partagée — les deux contrôleurs
    // restent indépendants.
    return KeepScreenOn(
      child: TasbihCounterLayout(
        reading: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            // Texte saisi par le disciple, jamais fourni par l'app. Déjà
            // présent dans le titre : repris ici en grand, à l'endroit où les
            // wirds validés affichent leur formule.
            child: session.label.isEmpty
                ? const SizedBox.shrink()
                : ExcludeSemantics(
                    child: ContentText(
                      session.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.parchment, fontSize: 24, height: 1.5),
                    ),
                  ),
          ),
        ),
        panel: TasbihCounterPanel(
          count: session.currentCount,
          target: session.target,
          complete: complete,
          mode: session.mode,
          onModeChanged: controller.setMode,
          onCount: () {
            HapticFeedback.lightImpact();
            controller.increment();
          },
          onUndo: controller.undo,
          onReset: () {
            controller.resetCount();
            showCounterResetSnackBar(
              context,
              onUndo: () => controller.restoreCount(
                label: session.label,
                target: session.target,
                previousCount: session.currentCount,
              ),
            );
          },
          isListening: state.isListening,
          voiceSupported: state.voiceSupported,
          voiceError: state.voiceError,
          onStartListening: controller.startListening,
          onStopListening: controller.stopListening,
          extraAction: IconButton(
            tooltip: l10n.wirdFreeNewCounterButton,
            icon: const Icon(Icons.close, color: AppColors.parchment),
            onPressed: () => _abandon(context),
          ),
          completeAction: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                controller.finish();
              },
              icon: const Icon(Icons.check_circle),
              label: Text(l10n.wirdFreeFinishButton),
            ),
          ),
        ),
      ),
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
            const Icon(Icons.check_circle, color: AppColors.goldOnDark, size: 72),
            const SizedBox(height: 16),
            Text(
              l10n.wirdFreeCompletedTitle,
              style: const TextStyle(color: AppColors.parchment, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.wirdFreeCompletedBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryOnDark),
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
