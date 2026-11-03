// Guide d'un wird — refait le 2026-11-02. Pas de maquette propre
// (`docs/maquettes/README.md`) : il reprend le bandeau, l'historique, le
// rappel, les piliers et leurs nombres de `ecran-wird.html`, et l'affichage
// des piliers et des clôtures de `ecran-pratique.html`. Décisions validées le
// 2026-11-02 :
// - pas de « Commencer » pour la Hadratou-l-Jouma hors vendredi (même règle
//   que l'écran Wird) ; le guide reste lisible toute la semaine ;
// - « Aa » ne règle que la taille de l'arabe (partagée avec le tasbih) :
//   translittération et traduction restent toujours affichées, le guide étant
//   le texte de référence ;
// - piliers sur le fond sombre de l'écran de pratique, sans cartes blanches.
//
// Contenu religieux : les textes viennent exclusivement du corpus validé
// (`lib/features/wird/data/wirds_content.dart`). Les récitations audio
// viennent de Supabase (`wird_recitations`, `WirdPillarAudioController`) ;
// la lecture audio est inchangée.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/current_day.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/section_title.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_overview.dart';
import '../domain/wird_progress_stats.dart';
import '../domain/wird_recitation.dart';
import 'tasbih_reading_prefs_provider.dart';
import 'tasbih_reading_sheet.dart';
import 'tasbih_screen.dart';
import 'wird_audio_controller.dart';
import 'wird_audio_player_bar.dart';
import 'wird_band.dart';
import 'wird_display_name.dart';
import 'wird_history_screen.dart';
import 'wird_messages.dart';
import 'wird_overview_provider.dart';
import 'wird_overview_widgets.dart';
import 'wird_pillar_audio_controller.dart';
import 'wird_pillar_card.dart';
import 'wird_reminders_screen.dart';

class WirdDetailScreen extends ConsumerStatefulWidget {
  const WirdDetailScreen({super.key, required this.wird});

  final Wird wird;

  @override
  ConsumerState<WirdDetailScreen> createState() => _WirdDetailScreenState();
}

class _WirdDetailScreenState extends ConsumerState<WirdDetailScreen> {
  final Map<int, GlobalKey> _pillarKeys = {};

  GlobalKey _keyFor(int index) => _pillarKeys.putIfAbsent(index, () => GlobalKey());

  /// Fait défiler jusqu'au pilier en cours de lecture audio.
  void _scrollToPillar(int index) {
    final pillarContext = _pillarKeys[index]?.currentContext;
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

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final wird = widget.wird;
    final l10n = AppLocalizations.of(context)!;

    ref.listen(wirdAudioControllerProvider(wird), (previous, next) {
      if (next.activePillarIndex != null && next.activePillarIndex != previous?.activePillarIndex) {
        _scrollToPillar(next.activePillarIndex!);
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(wirdMessage(l10n, next.errorMessage!))));
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
    final arabicSize = ref.watch(tasbihReadingPrefsProvider).arabicSize - 4;

    // État du jour (complétions, session en pause, rappels) : tant qu'il
    // n'est pas lu, le guide s'affiche sans série ni état plutôt que vide.
    final now = ref.watch(clockProvider)();
    final entry = ref.watch(wirdOverviewProvider).valueOrNull?.where((e) => e.wird.id == wird.id).firstOrNull ??
        WirdOverviewEntry(
          wird: wird,
          stats: computeWirdProgressStats(frequency: wird.frequency, completionDates: const [], now: now),
          known: false,
        );

    // Thème immersif : sans lui, le titre et les boutons héritent des couleurs
    // du thème clair ambiant, illisibles sur le zaytoune.
    return Theme(
      data: AppTheme.immersive,
      child: Scaffold(
        backgroundColor: AppColors.zaytoune,
        appBar: AppBar(
          backgroundColor: AppColors.zaytoune,
          foregroundColor: AppColors.parchment,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: ContentText(wirdDisplayName(context, wird)),
          actions: [
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
                onPressed: () => showTasbihReadingSheet(context, sizeOnly: true),
                child: const Text('Aa', textDirection: TextDirection.ltr),
              ),
            ),
          ],
        ),
        bottomNavigationBar: WirdAudioPlayerBar(
          wird: wird,
          state: audioState,
          controller: audioController,
          hasAnyAudio: hasAnyAudio,
          audioLoadFailed: audioLoadFailed,
          activePillarAvailability:
              audioState.activePillarIndex != null ? pillarAudio[audioState.activePillarIndex]?.availability : null,
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // Identité du wird et son état du jour, comme sur sa carte.
              // Filet or : le bandeau du Lazim est zaytoune, comme le fond de
              // l'écran, et s'y confondait (vu sur capture).
              Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.35)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: WirdBand(wird: wird, state: wirdStatePill(context, entry, now)),
                ),
              ),
              const SizedBox(height: 8),
              _GuideActions(entry: entry, now: now, onPush: _push),
              const SizedBox(height: 4),
              WirdStreakLine(entry: entry, onDark: true),
              if (wird.conditionsNote != null) ...[
                const SizedBox(height: 16),
                _DarkNotice(text: wird.conditionsNote!),
              ],
              if (wird.repetitionsNote != null) ...[
                const SizedBox(height: 8),
                _DarkNotice(text: wird.repetitionsNote!, icon: Icons.repeat),
              ],
              SectionTitle(
                l10n.wirdDetailPillarsTitle,
                onDark: true,
                padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8),
              ),
              _PillarSummary(entry: entry),
              const SizedBox(height: 14),
              for (var i = 0; i < wird.pillars.length; i++) ...[
                WirdPillarCard(
                  key: _keyFor(i),
                  pillar: wird.pillars[i],
                  number: i + 1,
                  arabicSize: arabicSize,
                  availability: pillarAudio[i]?.availability ?? PillarAudioAvailability.noRecitation,
                  isActive: audioState.activePillarIndex == i,
                  isPlaying: audioState.activePillarIndex == i && audioState.isPlaying,
                  isBuffering: audioState.activePillarIndex == i &&
                      (audioState.isBuffering || pillarAudio[i]?.availability == PillarAudioAvailability.downloading),
                  onTogglePlay: () => audioController.playPillar(i),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// « Commencer » (ou « Reprendre ») ouvre le tasbih ; Historique et Rappel
/// (avec son heure) à un toucher. Pas de « Commencer » pour la Hadra hors
/// vendredi. À forte taille de texte, la rangée passe à la ligne.
class _GuideActions extends StatelessWidget {
  const _GuideActions({required this.entry, required this.now, required this.onPush});

  final WirdOverviewEntry entry;
  final DateTime now;
  final void Function(Widget screen) onPush;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wird = entry.wird;
    final time = reminderTimeLabel(entry.reminders, now);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (entry.canStart)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.goldOnDark,
              foregroundColor: AppColors.zaytoune,
              side: BorderSide.none,
            ),
            onPressed: () => onPush(TasbihScreen(wird: wird)),
            icon: const Icon(Icons.touch_app_outlined, size: 18),
            label: Text(entry.paused ? l10n.homeNextStepResume : l10n.homeNextStepStart),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DarkIconAction(
              icon: Icons.bar_chart_outlined,
              label: l10n.wirdDetailHistoryTooltip,
              onTap: () => onPush(WirdHistoryScreen(wird: wird)),
            ),
            _DarkIconAction(
              icon: time == null ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
              label: time ?? l10n.wirdReminderButton,
              semanticsLabel: time == null ? l10n.wirdReminderButton : l10n.wirdReminderButtonAt(time),
              onTap: () => onPush(WirdRemindersScreen(wird: wird)),
            ),
          ],
        ),
      ],
    );
  }
}

class _DarkIconAction extends StatelessWidget {
  const _DarkIconAction({required this.icon, required this.label, required this.onTap, this.semanticsLabel});

  final IconData icon;
  final String label;
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: AppColors.parchment),
                const SizedBox(height: 2),
                Text(
                  label,
                  textDirection: label.contains(':') ? TextDirection.ltr : null,
                  style: TextStyle(fontSize: 11.5, color: AppColors.secondaryOnDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les piliers qui se répètent, en puces avec leur nombre : le wird en un
/// coup d'œil avant le détail (intention et Fatiha n'en ont pas, comme sur
/// la carte de l'écran Wird).
class _PillarSummary extends StatelessWidget {
  const _PillarSummary({required this.entry});

  final WirdOverviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final pillar in entry.chipPillars)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.parchment.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ContentText(
                    pillar.labelFor(arabic: arabic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arabic
                        ? AppTheme.sacredText(fontSize: 14, color: AppColors.parchment).copyWith(height: 1.4)
                        : const TextStyle(fontSize: 12.5, color: AppColors.parchment),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '×${pillar.repetitions}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.goldOnDark),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Note du corpus sur fond sombre (équivalent de `Notice.info` pour un écran
/// de pratique) : texte en entier, jamais coupé.
class _DarkNotice extends StatelessWidget {
  const _DarkNotice({required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldOnDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ContentText(text, style: const TextStyle(color: AppColors.parchment, fontSize: 13.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
