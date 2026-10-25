/// Barre de lecture du guide d'un wird et format du minutage. Sortie de
/// `wird_detail_screen.dart` (audit du 2026-10-25, P3-8), sans changement de
/// comportement.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';
import 'wird_audio_controller.dart';

/// Barre de lecture persistante — lecture séquentielle du wird "synchronisée
/// au texte" (docs/03-architecture-ecrans.md) : surligne le pilier en cours
/// dans la liste et avance automatiquement au suivant.
class WirdAudioPlayerBar extends StatelessWidget {
  const WirdAudioPlayerBar({super.key, 
    required this.wird,
    required this.state,
    required this.controller,
    required this.hasAnyAudio,
    required this.audioLoadFailed,
    required this.activePillarAvailability,
  });

  final Wird wird;
  final WirdAudioState state;
  final WirdAudioController controller;
  final bool hasAnyAudio;

  /// Liste des récitations non chargée (hors ligne) : la barre le dit, au
  /// lieu de « bientôt disponible ». Le bouton de lecture la redemande.
  final bool audioLoadFailed;

  /// Disponibilité du pilier en cours (`state.activePillarIndex`), `null`
  /// si aucun pilier actif. Sert uniquement à afficher "Téléchargement en
  /// cours…" pendant que `WirdPillarAudioController.ensureDownloaded`
  /// travaille (docs/decision-gestion-audio-wirds.md §4).
  final PillarAudioAvailability? activePillarAvailability;

  @override
  Widget build(BuildContext context) {
    final activeIndex = state.activePillarIndex;
    final isDownloading = activePillarAvailability == PillarAudioAvailability.downloading;
    final label = activeIndex != null
        ? (isDownloading ? AppLocalizations.of(context)!.wirdAudioDownloading : wird.pillars[activeIndex].transliteration)
        : hasAnyAudio
            ? AppLocalizations.of(context)!.wirdAudioPlayLabel
            : audioLoadFailed
                ? AppLocalizations.of(context)!.wirdAudioLoadFailed
                : AppLocalizations.of(context)!.wirdAudioSoonLabel;
    final position = state.position;
    final duration = state.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.zaytoune,
          border: Border(top: BorderSide(color: AppColors.bronze, width: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(tooltip: AppLocalizations.of(context)!.a11yPrevious, 
                  icon: const Icon(Icons.skip_previous, color: AppColors.parchment),
                  onPressed: hasAnyAudio && controller.hasPrevious ? controller.playPrevious : null,
                ),
                IconButton(tooltip: AppLocalizations.of(context)!.a11yPlayPause, 
                  iconSize: 34,
                  icon: Icon(
                    state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: hasAnyAudio ? AppColors.goldOnDark : AppColors.secondaryOnDark,
                  ),
                  onPressed: controller.togglePlayPause,
                ),
                IconButton(tooltip: AppLocalizations.of(context)!.a11yNext, 
                  icon: const Icon(Icons.skip_next, color: AppColors.parchment),
                  onPressed: hasAnyAudio && controller.hasNext ? controller.playNext : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ContentText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasAnyAudio ? AppColors.parchment : AppColors.secondaryOnDark,
                      fontStyle: hasAnyAudio ? FontStyle.normal : FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (activeIndex != null)
                  // Toujours de gauche à droite : fait de chiffres et de
                  // signes, ce texte prenait le sens de l'interface, et
                  // s'affichait « durée / position » en arabe (passe sur
                  // émulateur du 2026-10-25). Même règle que « ×100 ».
                  Text(
                    '${formatPlaybackDuration(position)} / ${formatPlaybackDuration(duration)}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: AppColors.secondaryOnDark, fontSize: 11),
                  ),
              ],
            ),
            if (activeIndex != null)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: progress,
                  activeColor: AppColors.goldOnDark,
                  inactiveColor: AppColors.parchment.withValues(alpha: 0.2),
                  onChanged: duration == Duration.zero
                      ? null
                      : (value) => controller.seek(duration * value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Position ou durée d'une récitation : « mm:ss », puis « h:mm:ss » à partir
/// d'une heure. Les heures étaient ignorées : 1 h 05 s'affichait « 05:00 »
/// (audit du 2026-10-25, P3-7).
String formatPlaybackDuration(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$minutes:$seconds';
  }
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
