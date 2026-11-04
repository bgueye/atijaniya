// Écran de pratique d'un wird (tasbih) — refonte du 2026-11-02 d'après la
// maquette de référence `docs/maquettes/ecran-pratique.html`, décisions
// validées dans `docs/maquettes/README.md`.
//
// Le disciple est suivi pilier par pilier, jusqu'à la dernière formule :
// - repères nommés (pilier en cours, nombre, ce qui vient ensuite) ;
// - lecture qui prend la place qu'il lui faut, réglable par « Aa » (taille de
//   l'arabe, translittération, traduction ; gardé sur l'appareil) ;
// - compteur à l'échelle du nombre (`tasbih_counter_dial.dart`) ;
// - mode concentré, jamais automatique (proposé une fois par une bulle,
//   puis au geste ou par le bouton « Concentré ») ;
// - piliers récités une fois (intention, Fatiha) en entier, avec un seul
//   bouton ;
// - clôture en plein écran, formules à cocher (facultatif) ;
// - écran de fin : sceau, piliers, série, prochain rappel.
//
// Contenu religieux (CLAUDE.md) : tous les textes affichés viennent du
// corpus validé (`wirds_content.dart`) ; seul le comptage est saisi ici.
// Comptage, voix, avance automatique et reprise de session restent dans
// `TasbihController`, inchangés.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/current_day.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/keep_screen_on.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/data/donation_feature_flag.dart';
import '../../donation/data/donation_nudge_store.dart';
import '../../donation/presentation/donation_screen.dart';
import '../data/tasbih_reading_prefs_store.dart';
import '../domain/tasbih_session.dart';
import '../domain/wird_models.dart';
import '../domain/wird_overview.dart';
import 'tasbih_controller.dart';
import 'tasbih_counter_panel.dart';
import 'tasbih_reading_prefs_provider.dart';
import 'tasbih_reading_sheet.dart';
import 'wird_counter_feedback.dart';
import 'wird_display_name.dart';
import 'wird_history_screen.dart';
import 'wird_overview_provider.dart';

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key, required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tasbihControllerProvider(wird));

    // Thème immersif : sans lui, les textes et boutons héritent des couleurs
    // du thème clair ambiant, illisibles sur le zaytoune.
    return Theme(
      data: AppTheme.immersive,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.zaytoune,
          body: SafeArea(
            child: state.loadingSession
                ? const Center(child: CircularProgressIndicator(color: AppColors.goldOnDark))
                : state.wirdCompleted
                    ? _WirdCompletedView(wird: wird)
                    : KeepScreenOn(child: _TasbihBody(wird: wird)),
          ),
        ),
      ),
    );
  }
}

/// Corps de l'écran pendant la récitation. Garde l'état propre à l'affichage
/// (mode concentré, bulle) ; tout le reste vient du contrôleur.
class _TasbihBody extends ConsumerStatefulWidget {
  const _TasbihBody({required this.wird});

  final Wird wird;

  @override
  ConsumerState<_TasbihBody> createState() => _TasbihBodyState();
}

class _TasbihBodyState extends ConsumerState<_TasbihBody> {
  bool _focus = false;

  /// Bulle du mode concentré, montrée une seule fois (décision validée).
  bool _hintVisible = false;

  Wird get wird => widget.wird;

  /// Durée pendant laquelle les touchers sont ignorés après un changement de
  /// scène (pilier suivant, fin d'un pilier, clôture). Audit du 2026-11-03 :
  /// l'intention et la Fatiha ont le même bouton au même endroit, et un
  /// double toucher marquait la Fatiha récitée sans retour possible ; en mode
  /// concentré, un toucher de trop après le dernier compte tombait sur
  /// « Terminer » et enregistrait le wird. Assez court pour ne pas gêner un
  /// geste voulu.
  static const sceneGuard = Duration(milliseconds: 600);

  /// Scène affichée au dernier rendu (pilier, pilier terminé, clôture), pour
  /// repérer un changement.
  String? _sceneKey;
  bool _guarding = false;
  Timer? _guardTimer;

  @override
  void dispose() {
    _guardTimer?.cancel();
    super.dispose();
  }

  /// Appelé à chaque rendu : à un changement de scène, ignore les touchers
  /// pendant [sceneGuard]. Le premier affichage n'est pas neutralisé.
  void _watchScene(String key) {
    final previous = _sceneKey;
    _sceneKey = key;
    if (previous == null || previous == key) return;
    _guarding = true;
    _guardTimer?.cancel();
    _guardTimer = Timer(sceneGuard, () {
      if (mounted) setState(() => _guarding = false);
    });
  }

  void _enterFocus() => setState(() {
        _focus = true;
        _hintVisible = false;
      });

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasbihControllerProvider(wird));
    final controller = ref.read(tasbihControllerProvider(wird).notifier);
    final prefs = ref.watch(tasbihReadingPrefsProvider);
    final session = state.session;
    final complete = controller.isPillarComplete;
    final closingNow = complete && controller.hasClosingToRecite;
    final once = controller.isOncePillar;
    // Le mode concentré ne sert qu'à compter : il cède la place à la clôture
    // ou au bouton de fin de pilier.
    final focus = _focus && !complete && !once;

    // Bulle proposée une fois, sur une longue série comptée au toucher.
    if (prefs.loaded &&
        !prefs.focusHintShown &&
        !_hintVisible &&
        !focus &&
        !once &&
        !complete &&
        controller.targetCount >= 100 &&
        session.mode == TasbihMode.manual) {
      _hintVisible = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => ref.read(tasbihReadingPrefsProvider.notifier).markFocusHintShown());
    }

    void count() {
      tasbihTapHaptic(session.currentCount + 1, controller.targetCount);
      controller.increment();
    }

    _watchScene('${session.pillarIndex}|$complete|$closingNow|$once');

    final Widget scene;
    if (closingNow) {
      scene = _ClosingView(
        key: ValueKey('closing-${session.pillarIndex}'),
        controller: controller,
        prefs: prefs,
      );
    } else if (once) {
      scene = _OncePillarView(key: ValueKey('once-${session.pillarIndex}'), controller: controller, prefs: prefs);
    } else if (focus) {
      scene = _FocusView(
        controller: controller,
        state: state,
        onCount: count,
        onExit: () => setState(() => _focus = false),
      );
    } else {
      scene = _CountView(
        controller: controller,
        state: state,
        prefs: prefs,
        onCount: count,
        onFocus: _enterFocus,
        hintVisible: _hintVisible,
        onCloseHint: () => setState(() => _hintVisible = false),
      );
    }

    return Column(
      children: [
        _Header(
          wird: wird,
          subtitle: focus ? _pillarChipLabel(context, controller) : null,
          canReset: !once && !closingNow && session.currentCount > 0,
          onReset: () => _reset(context, controller, state),
          showReading: !focus,
        ),
        if (!focus) _Landmarks(controller: controller, count: session.currentCount),
        Expanded(child: IgnorePointer(ignoring: _guarding, child: scene)),
      ],
    );
  }

  void _reset(BuildContext context, TasbihController controller, TasbihState state) {
    // Relevé avant la remise à zéro, pour que « Annuler » rétablisse le compte
    // de ce pilier-là (voir `TasbihController.restoreCount`).
    final pillarIndex = state.session.pillarIndex;
    final useAlternative = state.session.useAlternative;
    final previous = state.session.currentCount;
    controller.resetPillar();
    showCounterResetSnackBar(
      context,
      onUndo: () => controller.restoreCount(
        pillarIndex: pillarIndex,
        useAlternative: useAlternative,
        previousCount: previous,
      ),
    );
  }
}

/// Nom court et nombre du pilier en cours : « Hailala ×100 ».
String _pillarName(BuildContext context, TasbihController controller) {
  final alternative = controller.currentPillar.alternative;
  final name = controller.usingAlternative && alternative != null
      ? alternative.name
      : controller.currentPillar.labelFor(arabic: _isArabic(context));
  return '$name ×${controller.targetCount}';
}

/// « Pilier 5 / 5 · Hailala ×100 ».
String _pillarChipLabel(BuildContext context, TasbihController controller) {
  final l10n = AppLocalizations.of(context)!;
  final progress = l10n.wirdTasbihPillarProgress(controller.pillarIndex + 1, controller.wird.pillars.length);
  return '$progress · ${_pillarName(context, controller)}';
}

// ---------------------------------------------------------------------------
// En-tête et repères
// ---------------------------------------------------------------------------

/// ✕ (quitter, la session reste gardée), nom du wird et son nom arabe,
/// « Aa » (réglages de lecture) et « ⋯ » (réinitialiser le pilier).
class _Header extends ConsumerWidget {
  const _Header({
    required this.wird,
    required this.canReset,
    required this.onReset,
    required this.showReading,
    this.subtitle,
  });

  final Wird wird;
  final String? subtitle;
  final bool canReset;
  final VoidCallback onReset;
  final bool showReading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.wirdTasbihQuit,
            icon: const Icon(Icons.close, color: AppColors.parchment),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContentText(
                  wird.nameFrench,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleText(fontSize: 20, color: AppColors.offWhite, height: 1.15),
                ),
                if (subtitle != null)
                  ContentText(subtitle, style: TextStyle(fontSize: 12, color: AppColors.secondaryOnDark))
                else
                  Text(
                    wird.nameArabic,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.sacredText(fontSize: 14, color: AppColors.goldOnDark).copyWith(height: 1.3),
                  ),
              ],
            ),
          ),
          if (showReading)
            Semantics(
              button: true,
              label: l10n.wirdTasbihReadingSettings,
              excludeSemantics: true,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.parchment,
                  minimumSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
                onPressed: () => showTasbihReadingSheet(context),
                child: const Text('Aa', textDirection: TextDirection.ltr),
              ),
            ),
          PopupMenuButton<void>(
            tooltip: l10n.wirdTasbihMoreActions,
            icon: const Icon(Icons.more_horiz, color: AppColors.parchment),
            itemBuilder: (_) => [
              PopupMenuItem(enabled: canReset, onTap: onReset, child: Text(l10n.wirdTasbihResetPillar)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un segment par pilier — celui en cours se remplit au fil du comptage —,
/// puis le pilier en cours nommé et ce qui vient ensuite.
class _Landmarks extends StatelessWidget {
  const _Landmarks({required this.controller, required this.count});

  final TasbihController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillars = controller.wird.pillars;
    final current = controller.pillarIndex;
    final target = controller.targetCount;
    final String next;
    // Une fois le compte atteint, la clôture est en cours : on annonce ce qui
    // vient après elle.
    if (controller.hasClosingToRecite && !controller.isPillarComplete) {
      next = l10n.wirdTasbihNextClosing;
    } else if (controller.isLastPillar) {
      next = l10n.wirdTasbihNextEnd;
    } else {
      final pillar = pillars[current + 1];
      next = l10n.wirdTasbihNext('${pillar.labelFor(arabic: _isArabic(context))} ×${pillar.repetitions}');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          // Décor : l'information est portée par le texte juste en dessous.
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < pillars.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: i < current ? AppColors.goldOnDark : AppColors.parchment.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: i == current
                          ? FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: target == 0 ? 0 : (count / target).clamp(0.0, 1.0),
                              child: const ColoredBox(color: AppColors.goldOnDark),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ContentText(
                  _pillarChipLabel(context, controller),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.parchment, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ContentText(
                  next,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comptage
// ---------------------------------------------------------------------------

/// Lecture en haut, à sa hauteur (dans une limite), compteur en dessous ;
/// côte à côte en paysage.
class _CountView extends StatelessWidget {
  const _CountView({
    required this.controller,
    required this.state,
    required this.prefs,
    required this.onCount,
    required this.onFocus,
    required this.hintVisible,
    required this.onCloseHint,
  });

  final TasbihController controller;
  final TasbihState state;
  final TasbihReadingPrefs prefs;
  final VoidCallback onCount;
  final VoidCallback onFocus;
  final bool hintVisible;
  final VoidCallback onCloseHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = state.session;
    final complete = controller.isPillarComplete;

    final panel = Stack(
      children: [
        TasbihCounterPanel(
          count: session.currentCount,
          target: controller.targetCount,
          complete: complete,
          mode: session.mode,
          onModeChanged: controller.setMode,
          onCount: onCount,
          onUndo: controller.undo,
          onFocus: onFocus,
          onSwipeDown: onFocus,
          isListening: state.isListening,
          voiceSupported: state.voiceSupported,
          voiceError: state.voiceError,
          onStartListening: controller.startListening,
          onStopListening: controller.stopListening,
          // Piliers intermédiaires sans clôture : le contrôleur enchaîne tout
          // seul après un court délai, le bouton reste là pour qui veut
          // avancer sans attendre.
          completeHint: controller.autoAdvancesAfterCompletion ? l10n.wirdTasbihNextPillarSoon : null,
          completeAction: PracticeButton(
            icon: controller.isLastPillar ? Icons.check : Icons.arrow_forward,
            label: controller.isLastPillar
                ? l10n.wirdTasbihFinishNamed(wirdDisplayName(context, controller.wird))
                : l10n.wirdTasbihNextPillar,
            onPressed: () {
              HapticFeedback.mediumImpact();
              controller.nextPillar();
            },
          ),
        ),
        if (hintVisible) Positioned(top: 8, left: 16, right: 16, child: _FocusHint(onClose: onCloseHint)),
      ],
    );

    final reading = _Reading(controller: controller, prefs: prefs, count: session.currentCount);

    return LayoutBuilder(builder: (context, constraints) {
      final gold = BorderSide(color: AppColors.goldOnDark.withValues(alpha: 0.45));
      Widget base(Widget child, {required bool landscape}) => DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.parchment.withValues(alpha: 0.045),
              border: landscape ? BorderDirectional(start: gold) : Border(top: gold),
            ),
            child: child,
          );
      if (constraints.maxWidth > constraints.maxHeight) {
        final width = (constraints.maxWidth * 0.45).clamp(280.0, 420.0);
        return Row(
          children: [
            Expanded(child: SingleChildScrollView(child: reading)),
            SizedBox(width: width, child: base(panel, landscape: true)),
          ],
        );
      }
      // La lecture prend la hauteur de son texte, jusqu'à laisser au moins
      // 300 px (ou 45 % de l'écran) au compteur ; au-delà, elle défile.
      final panelMin = (constraints.maxHeight * 0.45).clamp(280.0, 360.0);
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: (constraints.maxHeight - panelMin).clamp(80.0, double.infinity)),
            child: _FadedScroll(
              key: ValueKey('${controller.wird.id}-${session.pillarIndex}-${controller.usingAlternative}'),
              child: reading,
            ),
          ),
          Expanded(child: base(panel, landscape: false)),
        ],
      );
    });
  }
}

/// Zone de lecture qui défile, avec un fondu en bas quand le texte dépasse.
class _FadedScroll extends StatelessWidget {
  const _FadedScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, (rect.height - 20).clamp(0, rect.height) / rect.height, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Texte du pilier en cours : l'arabe d'abord (c'est lui qui est récité),
/// puis, selon les réglages, la translittération et la traduction ; la note
/// du corpus, le choix de l'alternative, et l'annonce de la clôture.
class _Reading extends StatelessWidget {
  const _Reading({required this.controller, required this.prefs, required this.count});

  final TasbihController controller;
  final TasbihReadingPrefs prefs;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillar = controller.currentPillar;
    final usingAlternative = controller.usingAlternative;
    final alternative = pillar.alternative;
    final showTransliteration = prefs.transliterationVisible(arabicInterface: _isArabic(context));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            usingAlternative ? alternative!.arabic : pillar.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTheme.sacredText(fontSize: prefs.arabicSize, color: AppColors.goldOnDark).copyWith(height: 1.7),
          ),
          // Translittération, traduction et notes sont en caractères latins :
          // toujours de gauche à droite, sinon l'interface en arabe rejette
          // leur ponctuation finale en début de ligne.
          if (showTransliteration) ...[
            const SizedBox(height: 6),
            Text(
              usingAlternative ? alternative!.transliteration : pillar.transliteration,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style:
                  const TextStyle(color: AppColors.parchment, fontSize: 15, height: 1.45, fontStyle: FontStyle.italic),
            ),
          ],
          if (prefs.showTranslation) ...[
            const SizedBox(height: 6),
            Text(
              usingAlternative ? alternative!.translation : pillar.translation,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 14, height: 1.45),
            ),
          ],
          // La note du pilier normal explique quand recourir à l'alternative :
          // elle n'a plus lieu d'être une fois l'alternative choisie.
          if (!usingAlternative && pillar.note != null) ...[
            const SizedBox(height: 10),
            Text(
              pillar.note!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryOnDark),
            ),
          ],
          if (alternative != null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: AppColors.goldOnDark,
              title: Text(
                l10n.wirdTasbihUseAlternative(alternative.repetitions, alternative.name),
                style: const TextStyle(color: AppColors.parchment, fontSize: 14),
              ),
              value: usingAlternative,
              // Sans effet une fois le comptage commencé (voir
              // `TasbihController.setUseAlternative`).
              onChanged: count == 0 ? controller.setUseAlternative : null,
            ),
          ],
          if (controller.hasClosingToRecite) ...[
            const SizedBox(height: 10),
            Text(
              l10n.wirdTasbihClosingAhead(controller.targetCount),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryOnDark),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bulle qui propose le mode concentré, une seule fois.
class _FocusHint extends StatelessWidget {
  const _FocusHint({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.goldSoft,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 4),
        child: Row(
          children: [
            const Icon(Icons.swipe_down_outlined, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(
                child: Text(l10n.wirdTasbihFocusHint, style: const TextStyle(fontSize: 12.5, color: AppColors.ink))),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode concentré
// ---------------------------------------------------------------------------

/// Une ligne de texte, un grand chiffre, tout l'écran compte (au toucher).
/// En mode voix, l'écoute reste visible et se commande ici.
class _FocusView extends StatelessWidget {
  const _FocusView({required this.controller, required this.state, required this.onCount, required this.onExit});

  final TasbihController controller;
  final TasbihState state;
  final VoidCallback onCount;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = state.session.currentCount;
    final target = controller.targetCount;
    final voice = state.session.mode == TasbihMode.voice;
    final pillar = controller.currentPillar;
    final arabic = controller.usingAlternative ? pillar.alternative!.arabic : pillar.arabic;

    return Semantics(
      button: !voice,
      label: voice ? null : l10n.wirdFreeTapToCount,
      value: '$count / $target',
      liveRegion: voice,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: voice ? null : onCount,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Text(
                  arabic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.sacredText(fontSize: 22, color: AppColors.goldOnDark).copyWith(height: 1.5),
                ),
              ),
              const Spacer(),
              ExcludeSemantics(
                child: Text(
                  '$count',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.parchment,
                    fontSize: 110,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(l10n.wirdTasbihFocusOf(target),
                    style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 15)),
              ),
              const SizedBox(height: 18),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: target == 0 ? 0 : count / target,
                    minHeight: 5,
                    color: AppColors.goldOnDark,
                    backgroundColor: AppColors.parchment.withValues(alpha: 0.15),
                  ),
                ),
              ),
              if (voice) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldOnDark,
                    side: const BorderSide(color: AppColors.goldOnDark),
                  ),
                  onPressed: state.isListening ? controller.stopListening : controller.startListening,
                  icon: Icon(state.isListening ? Icons.pause : Icons.mic),
                  label: Text(state.isListening ? l10n.wirdFreeListeningActive : l10n.wirdFreeStartListening),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.parchment),
                onPressed: onExit,
                icon: const Icon(Icons.close_fullscreen, size: 18),
                label: Text(l10n.wirdTasbihFocusExit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clôture
// ---------------------------------------------------------------------------

/// Le pilier a atteint son nombre : les formules de clôture prennent tout
/// l'écran, l'une après l'autre. Les cocher est facultatif (décision validée) ;
/// la suivante s'éclaire, et l'on peut terminer à tout moment.
class _ClosingView extends StatefulWidget {
  const _ClosingView({super.key, required this.controller, required this.prefs});

  final TasbihController controller;
  final TasbihReadingPrefs prefs;

  @override
  State<_ClosingView> createState() => _ClosingViewState();
}

class _ClosingViewState extends State<_ClosingView> {
  late final List<bool> _ticks = List.filled(widget.controller.currentPillar.closingFormulas!.length, false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final formulas = controller.currentPillar.closingFormulas!;
    final current = _ticks.indexWhere((t) => !t);
    final showTransliteration = widget.prefs.transliterationVisible(arabicInterface: _isArabic(context));
    final target = controller.targetCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.goldOnDark.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 16, color: AppColors.goldOnDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.wirdTasbihClosingNow(target, target),
                    style: const TextStyle(color: AppColors.parchment, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: formulas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _FormulaCard(
              formula: formulas[i],
              ticked: _ticks[i],
              current: i == current,
              arabicSize: widget.prefs.arabicSize - 4,
              showTransliteration: showTransliteration,
              onTap: () => setState(() => _ticks[i] = !_ticks[i]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: PracticeButton(
            icon: controller.isLastPillar ? Icons.check : Icons.arrow_forward,
            label: controller.isLastPillar
                ? l10n.wirdTasbihFinishNamed(wirdDisplayName(context, controller.wird))
                : l10n.wirdTasbihNextPillar,
            onPressed: () {
              HapticFeedback.mediumImpact();
              controller.nextPillar();
            },
          ),
        ),
      ],
    );
  }
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({
    required this.formula,
    required this.ticked,
    required this.current,
    required this.arabicSize,
    required this.showTransliteration,
    required this.onTap,
  });

  final WirdClosingFormula formula;
  final bool ticked;
  final bool current;
  final double arabicSize;
  final bool showTransliteration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // La formule en cours s'éclaire ; une formule cochée s'efface un peu.
    final border = current ? AppColors.goldOnDark : AppColors.parchment.withValues(alpha: 0.14);
    return Semantics(
      button: true,
      checked: ticked,
      child: Material(
        color: AppColors.parchment.withValues(alpha: current ? 0.08 : 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: current ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: ticked ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          formula.intro,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.secondaryOnDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Case à cocher : un simple repère, facultatif.
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ticked ? AppColors.goldOnDark : null,
                          border: Border.all(color: AppColors.goldOnDark),
                        ),
                        child: ticked
                            ? Semantics(
                                label: l10n.wirdTasbihFormulaDone,
                                child: const Icon(Icons.check, size: 15, color: AppColors.zaytoune),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formula.arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.sacredText(fontSize: arabicSize, color: AppColors.goldOnDark).copyWith(height: 1.7),
                  ),
                  if (showTransliteration && formula.transliteration != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formula.transliteration!,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 14, height: 1.45, fontStyle: FontStyle.italic, color: AppColors.parchment),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pilier récité une fois
// ---------------------------------------------------------------------------

/// Intention et Fatiha : le texte complet (verset par verset pour la
/// Fatiha), et un seul bouton. Pas d'anneau pour un seul toucher.
class _OncePillarView extends StatelessWidget {
  const _OncePillarView({super.key, required this.controller, required this.prefs});

  final TasbihController controller;
  final TasbihReadingPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillar = controller.currentPillar;
    final showTransliteration = prefs.transliterationVisible(arabicInterface: _isArabic(context));
    final paragraphs = pillar.fullText ??
        [
          WirdParagraph(arabic: pillar.arabic, transliteration: pillar.transliteration, translation: pillar.translation)
        ];
    final numbered = paragraphs.length > 1;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            children: [
              if (pillar.note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    pillar.note!,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.secondaryOnDark),
                  ),
                ),
              for (var i = 0; i < paragraphs.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: AppColors.parchment.withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (numbered)
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsetsDirectional.only(end: 10, top: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.6)),
                          ),
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppColors.goldOnDark)),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              paragraphs[i].arabic,
                              textAlign: numbered ? TextAlign.right : TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: AppTheme.sacredText(
                                fontSize: prefs.arabicSize - (numbered ? 6 : 4),
                                color: AppColors.goldOnDark,
                              ).copyWith(height: 1.7),
                            ),
                            if (showTransliteration)
                              Text(
                                paragraphs[i].transliteration,
                                textAlign: numbered ? TextAlign.left : TextAlign.center,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.parchment),
                              ),
                            if (prefs.showTranslation)
                              Text(
                                paragraphs[i].translation,
                                textAlign: numbered ? TextAlign.left : TextAlign.center,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryOnDark),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: PracticeButton(
            icon: Icons.check,
            label: l10n.wirdTasbihOnceDone,
            onPressed: () {
              HapticFeedback.mediumImpact();
              controller.completeOncePillar();
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fin du wird
// ---------------------------------------------------------------------------

/// Un écran calme : sceau doré sur la rosace, nom du wird, piliers récités,
/// série en cours, prochain rappel. Le rappel de don reste, discret.
class _WirdCompletedView extends ConsumerStatefulWidget {
  const _WirdCompletedView({required this.wird});

  final Wird wird;

  @override
  ConsumerState<_WirdCompletedView> createState() => _WirdCompletedViewState();
}

class _WirdCompletedViewState extends ConsumerState<_WirdCompletedView> {
  @override
  void initState() {
    super.initState();
    // La complétion vient d'être enregistrée : série et rappels relus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(wirdOverviewProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wird = widget.wird;
    final now = ref.watch(clockProvider)();
    final entry = ref.watch(wirdOverviewProvider).valueOrNull?.where((e) => e.wird.id == wird.id).firstOrNull;
    final streak = entry?.stats.currentStreak;
    final reminder = entry == null ? null : reminderTimeLabel(entry.reminders, now);
    final weekly = wird.frequency == WirdFrequency.weekly;
    final arabic = _isArabic(context);

    return Stack(
      children: [
        // Rosace en filigrane, une seule fois sur l'écran.
        const Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment(0, -0.55),
              child: Opacity(
                opacity: 0.14,
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.goldOnDark, strokeWidth: 1.4)),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldOnDark),
                  child: const Icon(Icons.check, size: 40, color: AppColors.zaytoune),
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: ContentText(
                    l10n.wirdTasbihEndTitle(wirdDisplayName(context, wird)),
                    textAlign: TextAlign.center,
                    style: arabic
                        ? AppTheme.sacredText(fontSize: 26, color: AppColors.offWhite).copyWith(height: 1.4)
                        : AppTheme.titleText(fontSize: 28, color: AppColors.offWhite, height: 1.15),
                  ),
                ),
                if (!arabic)
                  Text(
                    wird.nameArabic,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.sacredText(fontSize: 24, color: AppColors.goldOnDark).copyWith(height: 1.5),
                  ),
                const SizedBox(height: 18),
                // `Wrap` : à forte taille de texte ou sur un petit écran, la
                // seconde tuile passe dessous au lieu de déborder.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _EndStat(value: '${wird.pillars.length}/${wird.pillars.length}', label: l10n.wirdTasbihEndPillars),
                    if (streak != null && streak > 0) ...[
                      _EndStat(
                        value: '$streak',
                        label: weekly
                            ? (streak == 1 ? l10n.wirdHistoryStreakFridaySingular : l10n.wirdHistoryStreakFridays)
                            : (streak == 1 ? l10n.wirdHistoryStreakDaySingular : l10n.wirdHistoryStreakDays),
                      ),
                    ],
                  ],
                ),
                if (reminder != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    l10n.wirdTasbihEndNextReminder(reminder),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 13.5),
                  ),
                ],
                const SizedBox(height: 24),
                PracticeButton(label: l10n.wirdTasbihBack, onPressed: () => Navigator.of(context).pop()),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.parchment),
                  onPressed: () => Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => WirdHistoryScreen(wird: wird))),
                  child: Text(l10n.wirdTasbihSeeHistory),
                ),
                if (kDonationsEnabled) const _DonationNudge(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chiffre de l'écran de fin, sur fond sombre (nombre en `gold_on_dark`).
class _EndStat extends StatelessWidget {
  const _EndStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // Opaque : la rosace en filigrane ne doit pas traverser les chiffres.
          color: Color.alphaBlend(AppColors.parchment.withValues(alpha: 0.06), AppColors.zaytoune),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                textDirection: TextDirection.ltr,
                style: AppTheme.titleText(fontSize: 28, color: AppColors.goldOnDark, height: 1)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.secondaryOnDark)),
          ],
        ),
      ),
    );
  }
}

/// Rappel discret vers `DonationScreen`, uniquement sur l'écran de fin — le
/// moment de gratitude le plus naturel de l'app — et au maximum une fois par
/// semaine (`DonationNudgeStore`). Toujours sous les boutons : un ajout
/// secondaire, jamais la priorité visuelle de cet écran.
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
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationScreen())),
        // Zone tactile de 48 dp de haut (audit du 2026-10-25, P2-8).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_outline, size: 14, color: AppColors.goldOnDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.wirdTasbihDonationNudge,
                    style: TextStyle(
                        color: AppColors.secondaryOnDark,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.secondaryOnDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
