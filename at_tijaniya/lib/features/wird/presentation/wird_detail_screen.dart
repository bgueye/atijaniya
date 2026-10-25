import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';
import 'tasbih_screen.dart';
import 'wird_audio_controller.dart';
import 'wird_audio_player_bar.dart';
import 'wird_display_name.dart';
import 'wird_history_screen.dart';
import 'wird_messages.dart';
import 'wird_pillar_card.dart';
import 'wird_pillar_audio_controller.dart';
import 'wird_reminders_screen.dart';
import '../../../core/widgets/content_text.dart';

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
          ..showSnackBar(SnackBar(content: Text(wirdMessage(AppLocalizations.of(context)!, next.errorMessage!))));
        // Message consommé : la même erreur pourra s'afficher de nouveau.
        // Différé, pour ne pas modifier l'état pendant sa notification.
        final controller = ref.read(wirdAudioControllerProvider(wird).notifier);
        Future.microtask(controller.clearError);
      }
    });

    final audioState = ref.watch(wirdAudioControllerProvider(wird));
    final audioController = ref.read(wirdAudioControllerProvider(wird).notifier);
    final pillarAudio = ref.watch(wirdPillarAudioProvider(wird));
    final hasAnyAudio = pillarAudio.values.any((s) => s.recitation != null);
    final audioLoadFailed = pillarAudio.values.any((s) => s.availability == PillarAudioAvailability.loadFailed);

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
        title: ContentText(wirdDisplayName(context, wird)),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: AppLocalizations.of(context)!.wirdDetailHistoryTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WirdHistoryScreen(wird: wird)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: AppLocalizations.of(context)!.wirdDetailRemindersTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WirdRemindersScreen(wird: wird)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'wird_detail_tasbih',
        backgroundColor: AppColors.goldOnDark,
        foregroundColor: AppColors.ink,
        icon: const Icon(Icons.touch_app),
        label: Text(AppLocalizations.of(context)!.wirdDetailTasbihButton),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TasbihScreen(wird: wird)),
        ),
      ),
      bottomNavigationBar: WirdAudioPlayerBar(
        wird: wird,
        state: audioState,
        controller: audioController,
        hasAnyAudio: hasAnyAudio,
        audioLoadFailed: audioLoadFailed,
        activePillarAvailability: audioState.activePillarIndex != null
            ? pillarAudio[audioState.activePillarIndex]?.availability
            : null,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Bottom généreux : le FAB "Tasbih" flotte en permanence au-dessus
          // de ce ListView (Scaffold ne réserve de la place que pour la
          // bottomNavigationBar, pas pour un FAB) et masquait la fin du
          // dernier pilier sans cette marge — constaté sur les 3 wirds lors
          // de l'audit design pré-publication Play Store.
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            ContentText(
              wird.nameArabic,
              textAlign: TextAlign.center,
              style: AppTheme.sacredText(fontSize: 32, color: AppColors.goldOnDark),
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
            Text(
              AppLocalizations.of(context)!.wirdDetailPillarsTitle,
              style: const TextStyle(
                color: AppColors.parchment,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < wird.pillars.length; i++) ...[
              WirdPillarCard(
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
        border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldOnDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ContentText(text, style: const TextStyle(color: AppColors.parchment, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
