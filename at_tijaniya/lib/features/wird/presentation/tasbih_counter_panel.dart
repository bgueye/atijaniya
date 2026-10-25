import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/tasbih_session.dart' show TasbihMode;
import 'tasbih_beads_ring.dart';
import 'voice_error_message.dart';
import '../../../core/widgets/content_text.dart';

/// Mise en page commune du Tasbih d'un wird et du Wird libre : une zone de
/// lecture en haut, qui défile seule si le texte est long, et le compteur en
/// bas, toujours au même endroit et à la même hauteur.
///
/// En paysage, la hauteur manque : empilé, le compteur prenait presque tout
/// l'écran et ses commandes étaient rognées (retour du porteur de projet du
/// 2026-10-08). La lecture et le compteur y sont donc placés côte à côte.
///
/// Avant, texte, sélecteur de mode, compteur et boutons défilaient d'un seul
/// bloc : sur un pilier au texte long, le cercle de comptage sortait de
/// l'écran et changeait de place d'un pilier à l'autre.
class TasbihCounterLayout extends StatelessWidget {
  const TasbihCounterLayout({super.key, required this.reading, required this.panel});

  final Widget reading;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Un peu plus de la moitié de l'écran pour le compteur, bornée : assez
        // pour un cercle confortable sur un grand téléphone, sans priver la
        // lecture de toute place sur un petit.
        final landscape = constraints.maxWidth > constraints.maxHeight;
        // Léger voile et filet doré : la zone de comptage se lit comme un
        // socle distinct de la lecture, sans carte ni ombre. Le filet est du
        // côté qui touche la lecture.
        final gold = BorderSide(color: AppColors.goldOnDark.withValues(alpha: 0.45));
        Widget base(Widget child) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.parchment.withValues(alpha: 0.045),
                border: landscape ? BorderDirectional(start: gold) : Border(top: gold),
              ),
              child: child,
            );

        if (landscape) {
          final panelWidth = (constraints.maxWidth * 0.45).clamp(280.0, 420.0);
          return Row(
            children: [
              Expanded(child: reading),
              SizedBox(width: panelWidth, child: base(panel)),
            ],
          );
        }
        final panelHeight = (constraints.maxHeight * 0.52).clamp(280.0, 410.0);
        return Column(
          children: [
            Expanded(child: reading),
            SizedBox(height: panelHeight, child: base(panel)),
          ],
        );
      },
    );
  }
}

/// Partie basse, fixe, d'un écran de comptage : chapelet de perles, décompte,
/// puis une rangée "corriger / mode / recommencer".
///
/// En mode manuel, toute la zone au-dessus de la rangée de boutons compte une
/// répétition — pas seulement le cercle : un wird se récite souvent sans
/// regarder l'écran, le téléphone dans une main. En mode voix, seul le bouton
/// "Démarrer l'écoute / Mettre en pause" agit : un toucher ailleurs coupait
/// l'écoute par mégarde (retour du porteur de projet du 2026-10-08).
///
/// Purement visuel : le comptage, la voix et la persistance restent dans
/// `TasbihController` et `FreeWirdController`, que ce widget ne connaît pas.
class TasbihCounterPanel extends StatelessWidget {
  const TasbihCounterPanel({
    super.key,
    required this.count,
    required this.target,
    required this.complete,
    required this.mode,
    required this.onModeChanged,
    required this.onCount,
    required this.onUndo,
    required this.onReset,
    required this.isListening,
    required this.voiceSupported,
    required this.voiceError,
    required this.onStartListening,
    required this.onStopListening,
    required this.completeAction,
    this.completeHint,
    this.extraAction,
  });

  final int count;
  final int target;
  final bool complete;
  final TasbihMode mode;
  final ValueChanged<TasbihMode> onModeChanged;

  /// Une répétition comptée au toucher (mode manuel).
  final VoidCallback onCount;
  final VoidCallback onUndo;
  final VoidCallback onReset;

  final bool isListening;
  final bool voiceSupported;

  /// Code d'erreur vocale posé par le contrôleur — voir `voice_error_message.dart`.
  final String? voiceError;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;

  /// Bouton affiché à la place de la rangée de commandes une fois le compte
  /// atteint ("Pilier suivant", "Terminer le wird", "Terminer").
  final Widget completeAction;

  /// Phrase au-dessus de [completeAction] (ex. enchaînement automatique).
  final String? completeHint;

  /// Commande supplémentaire en bout de rangée (Wird libre : abandonner le
  /// compteur en cours).
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => _build(context, constraints.maxHeight));
  }

  Widget _build(BuildContext context, double height) {
    final l10n = AppLocalizations.of(context)!;
    final voice = mode == TasbihMode.voice;
    // Socle bas (téléphone en paysage) : on resserre le statut et les
    // commandes pour laisser sa place au cercle, plutôt que de les rogner.
    final compact = height < 320;
    final double statusHeight = voice ? (compact ? 72 : 88) : (compact ? 30 : 76);
    final double controlsHeight = compact ? 56 : 68;
    final canListen = voice && voiceSupported && !complete;

    // La zone ne réagit qu'en mode manuel.
    final VoidCallback? onZoneTap = complete || voice ? null : onCount;

    return Column(
        children: [
          Expanded(
            child: Semantics(
              button: onZoneTap != null,
              label: voice ? null : l10n.wirdFreeTapToCount,
              value: '$count / $target',
              // En mode voix, le disciple ne touche pas l'écran : sans région
              // annoncée, un lecteur d'écran ne lui disait jamais où il en
              // était (audit du 2026-10-25, P3-5). Pas en mode manuel, où
              // chaque toucher serait doublé d'une annonce.
              liveRegion: voice,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onZoneTap,
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = math.max(
                            80.0,
                            math.min(240.0, math.min(constraints.maxHeight - 12, constraints.maxWidth - 48)),
                          );
                          return Center(
                            child: _Ring(count: count, target: target, complete: complete, size: size),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: complete ? 0 : statusHeight,
                      child: complete ? null : _status(l10n, voice: voice, canListen: canListen, compact: compact),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            // À la fin du compte, le bouton d'action occupe la place du statut
            // et des commandes : la hauteur totale du socle ne change pas.
            // Jamais moins de 104 : la phrase d'enchaînement et le bouton ne
            // tenaient plus dans le socle resserré d'un petit écran.
            height: complete ? math.max(104.0, statusHeight + controlsHeight) : controlsHeight,
            child: complete ? _completion() : _controls(l10n),
          ),
        ],
    );
  }

  Widget _status(AppLocalizations l10n, {required bool voice, required bool canListen, required bool compact}) {
    if (!voice) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: compact ? 2 : 6),
          child: Text(l10n.wirdFreeTapToCount, style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 14)),
        ),
      );
    }

    final failed = !voiceSupported || voiceError != null;
    final message = failed
        ? (voiceErrorMessage(l10n, voiceError) ?? l10n.wirdFreeVoiceUnavailable)
        : (isListening ? l10n.wirdFreeListeningActive : l10n.wirdFreeListeningPaused);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ContentText(
            message,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: failed ? AppColors.goldOnDark : AppColors.secondaryOnDark, fontSize: 13, height: 1.25),
          ),
          if (canListen) ...[
            SizedBox(height: compact ? 2 : 6),
            // Seul ce bouton démarre ou met en pause l'écoute. La marge
            // transparente autour de la pastille porte sa hauteur tactile à
            // 44 px sans grossir son dessin.
            // `FittedBox` : le libellé se réduit plutôt que de déborder quand
            // le socle est étroit (paysage, grande taille de police).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isListening ? onStopListening : onStartListening,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isListening ? Colors.transparent : AppColors.goldOnDark,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.goldOnDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.pause : Icons.mic,
                    size: 16,
                    color: isListening ? AppColors.goldOnDark : AppColors.ink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isListening ? l10n.wirdFreeStopListening : l10n.wirdFreeStartListening,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isListening ? AppColors.goldOnDark : AppColors.ink,
                    ),
                  ),
                ],
              ),
                  ),
                ),
              ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _completion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (completeHint != null) ...[
            ContentText(
              completeHint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          completeAction,
        ],
      ),
    );
  }

  Widget _controls(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _PanelAction(
              icon: Icons.undo,
              label: l10n.wirdFreeUndo,
              onPressed: count == 0 ? null : onUndo,
            ),
          ),
          _ModeToggle(mode: mode, onChanged: onModeChanged, l10n: l10n),
          Expanded(
            child: _PanelAction(
              icon: Icons.replay,
              label: l10n.wirdFreeReset,
              onPressed: count == 0 ? null : onReset,
            ),
          ),
          if (extraAction != null) extraAction!,
        ],
      ),
    );
  }
}

/// Chapelet et décompte. La taille des chiffres suit celle du cercle, lui-même
/// réduit sur les petits écrans.
class _Ring extends StatelessWidget {
  const _Ring({required this.count, required this.target, required this.complete, required this.size});

  final int count;
  final int target;
  final bool complete;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TasbihBeadsRing(
      count: count,
      target: target,
      size: size,
      complete: complete,
      child: Container(
        width: size - 50,
        height: size - 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.emerald.withValues(alpha: complete ? 0.4 : 0.22),
        ),
        alignment: Alignment.center,
        // Déjà annoncé par la zone de comptage (libellé + "37 / 100").
        child: ExcludeSemantics(
          // `FittedBox` : sur les plus petits écrans le cercle se réduit, et
          // le décompte suivi de la coche de fin n'y tenait plus en hauteur.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ContentText(
                '$count',
                style: TextStyle(
                  color: AppColors.parchment,
                  fontSize: size * 0.25,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              // Toujours de gauche à droite : en arabe, « / 100 » s'affichait
              // « 100 / » sous le décompte.
              Text(
                '/ $target',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: AppColors.secondaryOnDark, fontSize: math.max(14, size * 0.075)),
              ),
              if (complete) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle, color: AppColors.goldOnDark, size: size * 0.11),
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

/// Commande secondaire du socle : icône et libellé court dessous, pour tenir
/// à trois sur un écran étroit là où deux boutons texte débordaient.
class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.parchment.withValues(alpha: 0.35) : AppColors.parchment;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              ContentText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix du mode de comptage, réduit à deux icônes : on le règle une fois,
/// il n'a pas à occuper une rangée entière entre le texte et le compteur.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged, required this.l10n});

  final TasbihMode mode;
  final ValueChanged<TasbihMode> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget segment(TasbihMode value, IconData icon, String label) {
      final selected = mode == value;
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: selected ? null : () => onChanged(value),
            child: Container(
              width: 52,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.goldOnDark : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 22, color: selected ? AppColors.ink : AppColors.parchment),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.parchment.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(TasbihMode.manual, Icons.touch_app, l10n.wirdFreeManualMode),
          segment(TasbihMode.voice, Icons.mic, l10n.wirdFreeVoiceMode),
        ],
      ),
    );
  }
}

/// Message affiché après « Réinitialiser », avec « Annuler » pour rétablir le
/// compte (Tasbih d'un wird et Wird libre). Plutôt qu'une confirmation avant
/// chaque remise à zéro : le geste voulu reste immédiat, seul le geste
/// accidentel se rattrape (audit du 2026-10-25).
///
/// Couleurs explicites : sur le thème immersif, le `SnackBar` prend un fond
/// parchemin et une action en or, illisible sur ce fond (2,15:1) ; l'émeraude
/// y atteint 5,57:1.
void showCounterResetSnackBar(BuildContext context, {required VoidCallback onUndo}) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: AppColors.parchment,
      duration: const Duration(seconds: 6),
      content: Text(l10n.wirdCounterResetDone, style: const TextStyle(color: AppColors.ink)),
      action: SnackBarAction(
        label: l10n.wirdCounterResetUndo,
        textColor: AppColors.emerald,
        onPressed: onUndo,
      ),
    ));
}
