import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';
import 'tasbih_screen.dart';
import 'wird_audio_controller.dart';
import 'wird_history_screen.dart';
import 'wird_pillar_audio_controller.dart';
import 'wird_reminders_screen.dart';

/// Guide d'un Wird — arabe, translittération, traduction, lecture séquencée,
/// lecteur audio synchronisé au texte. Priorité P0
/// (docs/03-architecture-ecrans.md).
///
/// Le contenu texte affiché ici provient exclusivement de
/// `lib/features/wird/data/wirds_content.dart` (corpus validé) — voir la
/// règle impérative en tête de ce fichier. Les récitations audio, elles,
/// viennent de Supabase (`wird_recitations`, résolu par
/// `WirdPillarAudioController` — docs/decision-gestion-audio-wirds.md) :
/// tant qu'aucune n'est validée pour un pilier, le lecteur affiche un état
/// "bientôt disponible" plutôt que de rester muet sans explication.
class WirdDetailScreen extends ConsumerStatefulWidget {
  const WirdDetailScreen({super.key, required this.wird});

  final Wird wird;

  @override
  ConsumerState<WirdDetailScreen> createState() => _WirdDetailScreenState();
}

class _WirdDetailScreenState extends ConsumerState<WirdDetailScreen> {
  final Map<int, GlobalKey> _pillarKeys = {};

  GlobalKey _keyFor(int index) => _pillarKeys.putIfAbsent(index, () => GlobalKey());

  void _scrollToPillar(int index) {
    final key = _pillarKeys[index];
    final pillarContext = key?.currentContext;
    if (pillarContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        pillarContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final wird = widget.wird;

    ref.listen(wirdAudioControllerProvider(wird), (previous, next) {
      if (next.activePillarIndex != null && next.activePillarIndex != previous?.activePillarIndex) {
        _scrollToPillar(next.activePillarIndex!);
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    final audioState = ref.watch(wirdAudioControllerProvider(wird));
    final audioController = ref.read(wirdAudioControllerProvider(wird).notifier);
    final pillarAudio = ref.watch(wirdPillarAudioProvider(wird));
    final hasAnyAudio = pillarAudio.values.any((s) => s.recitation != null);

    // Le titre d'AppBar (et tout autre widget qui lit Theme.of(context))
    // doit passer par le thème immersif : sans ce wrapper, le titre hérite
    // de AppBarTheme.titleTextStyle du thème clair ambiant (couleur `ink`
    // explicite, donc prioritaire sur `foregroundColor`) et s'affiche en
    // texte quasi noir sur le fond vert zaytoune — illisible.
    return Theme(
      data: AppTheme.immersive,
      child: Scaffold(
        backgroundColor: AppColors.zaytoune,
        appBar: AppBar(
        backgroundColor: AppColors.zaytoune,
        foregroundColor: AppColors.parchment,
        title: Text(wird.nameFrench),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Historique',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WirdHistoryScreen(wird: wird)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Rappels',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WirdRemindersScreen(wird: wird)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.touch_app),
        label: const Text('Tasbih'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TasbihScreen(wird: wird)),
        ),
      ),
      bottomNavigationBar: _AudioPlayerBar(
        wird: wird,
        state: audioState,
        controller: audioController,
        hasAnyAudio: hasAnyAudio,
        activePillarAvailability: audioState.activePillarIndex != null
            ? pillarAudio[audioState.activePillarIndex]?.availability
            : null,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              wird.nameArabic,
              textAlign: TextAlign.center,
              style: AppTheme.sacredText(fontSize: 32, color: AppColors.gold),
            ),
            if (wird.conditionsNote != null) ...[
              const SizedBox(height: 16),
              _InfoBanner(text: wird.conditionsNote!),
            ],
            if (wird.repetitionsNote != null) ...[
              const SizedBox(height: 8),
              _InfoBanner(text: wird.repetitionsNote!, icon: Icons.repeat),
            ],
            const SizedBox(height: 24),
            const Text(
              'Piliers obligatoires',
              style: TextStyle(
                color: AppColors.parchment,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < wird.pillars.length; i++) ...[
              _PillarCard(
                key: _keyFor(i),
                pillar: wird.pillars[i],
                availability: pillarAudio[i]?.availability ?? PillarAudioAvailability.noRecitation,
                isActive: audioState.activePillarIndex == i,
                isPlaying: audioState.activePillarIndex == i && audioState.isPlaying,
                isBuffering: audioState.activePillarIndex == i &&
                    (audioState.isBuffering || pillarAudio[i]?.availability == PillarAudioAvailability.downloading),
                onTogglePlay: () => audioController.playPillar(i),
              ),
              const SizedBox(height: 12),
            ],
            // Espace pour ne pas laisser la barre de lecture masquer le
            // dernier élément.
            const SizedBox(height: 96),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.parchment, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    super.key,
    required this.pillar,
    required this.availability,
    required this.isActive,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTogglePlay,
  });

  final WirdPillar pillar;
  final PillarAudioAvailability availability;
  final bool isActive;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AudioPillarButton(
                availability: availability,
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                onPressed: onTogglePlay,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pillar.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.sacredText(fontSize: 22, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              _RepetitionBadge(count: pillar.repetitions),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pillar.transliteration,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.bronze,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pillar.translation,
            style: const TextStyle(color: AppColors.ink, fontSize: 16),
          ),
          if (pillar.note != null) ...[
            const SizedBox(height: 10),
            Text(
              pillar.note!,
              style: const TextStyle(fontSize: 12, color: AppColors.bronze),
            ),
          ],
          if (pillar.conditions != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conditions strictes',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  for (final c in pillar.conditions!)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('• $c', style: const TextStyle(fontSize: 12, color: AppColors.ink)),
                    ),
                ],
              ),
            ),
          ],
          if (pillar.fullText != null) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Texte intégral',
                  style: TextStyle(fontSize: 13, color: AppColors.emerald, fontWeight: FontWeight.w500),
                ),
                children: [
                  for (final p in pillar.fullText!) _ParagraphBlock(paragraph: p),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton de lecture individuel affiché sur chaque pilier — grisé et
/// désactivé tant qu'aucune récitation validée n'existe pour ce pilier ;
/// une icône de téléchargement quand elle existe mais n'est pas encore sur
/// l'appareil (docs/decision-gestion-audio-wirds.md §4).
class _AudioPillarButton extends StatelessWidget {
  const _AudioPillarButton({
    required this.availability,
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  final PillarAudioAvailability availability;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (availability == PillarAudioAvailability.noRecitation) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.music_off, color: AppColors.bronze, size: 22),
      );
    }
    if (availability == PillarAudioAvailability.error) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.error_outline, color: AppColors.bronze, size: 22),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: isBuffering
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
              )
            : availability == PillarAudioAvailability.notDownloaded
                ? const Icon(Icons.download_for_offline_outlined, color: AppColors.emerald, size: 26)
                : Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: AppColors.emerald,
                    size: 26,
                  ),
      ),
    );
  }
}

/// Barre de lecture persistante — lecture séquentielle du wird "synchronisée
/// au texte" (docs/03-architecture-ecrans.md) : surligne le pilier en cours
/// dans la liste et avance automatiquement au suivant.
class _AudioPlayerBar extends StatelessWidget {
  const _AudioPlayerBar({
    required this.wird,
    required this.state,
    required this.controller,
    required this.hasAnyAudio,
    required this.activePillarAvailability,
  });

  final Wird wird;
  final WirdAudioState state;
  final WirdAudioController controller;
  final bool hasAnyAudio;

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
        ? (isDownloading ? 'Téléchargement en cours…' : wird.pillars[activeIndex].transliteration)
        : hasAnyAudio
            ? 'Lecture audio du Wird'
            : 'Récitation audio bientôt disponible';
    final position = state.position;
    final duration = state.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: const BoxDecoration(
          color: AppColors.zaytoune,
          border: Border(top: BorderSide(color: AppColors.bronze, width: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: AppColors.parchment),
                  onPressed: hasAnyAudio && controller.hasPrevious ? controller.playPrevious : null,
                ),
                IconButton(
                  iconSize: 34,
                  icon: Icon(
                    state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: hasAnyAudio ? AppColors.gold : AppColors.bronze,
                  ),
                  onPressed: controller.togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: AppColors.parchment),
                  onPressed: hasAnyAudio && controller.hasNext ? controller.playNext : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasAnyAudio ? AppColors.parchment : AppColors.bronze,
                      fontStyle: hasAnyAudio ? FontStyle.normal : FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (activeIndex != null)
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(color: AppColors.bronze, fontSize: 11),
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
                  activeColor: AppColors.gold,
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({required this.paragraph});

  final WirdParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            paragraph.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            paragraph.transliteration,
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.bronze),
          ),
          const SizedBox(height: 4),
          Text(paragraph.translation, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _RepetitionBadge extends StatelessWidget {
  const _RepetitionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '×$count',
        style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
