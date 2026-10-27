// Cartes du wird de l'accueil : liste du jour, reprise du tasbih, prochain rappel.
// Extrait de `home_screen.dart` (audit de l'accueil du 2026-10-26, P3-5).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/presentation/tasbih_screen.dart';
import '../../wird/presentation/wird_detail_screen.dart';
import '../domain/home_dashboard.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/content_text.dart';

class HomeWirdChecklistCard extends StatelessWidget {
  const HomeWirdChecklistCard({super.key, required this.statuses, required this.isFriday, required this.l10n});

  final List<HomeWirdStatus> statuses;
  final bool isFriday;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            _WirdRow(status: statuses[i], isFriday: isFriday, l10n: l10n),
            if (i < statuses.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _WirdRow extends StatelessWidget {
  const _WirdRow({required this.status, required this.isFriday, required this.l10n});

  final HomeWirdStatus status;
  final bool isFriday;
  final AppLocalizations l10n;

  String? _subtitle() {
    if (status.doneToday) return null;
    if (status.wird.frequency == WirdFrequency.daily) return l10n.homeWirdSubtitlePendingDaily;
    return isFriday ? l10n.homeWirdSubtitlePendingFridayToday : l10n.homeWirdSubtitleWeeklyInfo;
  }

  String? _streakLabel() {
    if (status.streak <= 0) return null;
    return status.wird.frequency == WirdFrequency.daily
        // Singulier jusqu'à 1 : "1 jour de suite", "2 jours de suite".
        ? (status.streak <= 1 ? l10n.homeStreakDailySingular(status.streak) : l10n.homeStreakDaily(status.streak))
        : (status.streak <= 1 ? l10n.homeStreakWeeklySingular(status.streak) : l10n.homeStreakWeekly(status.streak));
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle();
    final streakLabel = status.doneToday ? _streakLabel() : null;
    // Même règle que la liste des wirds (`wird_list_screen.dart`) : le nom
    // arabe validé sert de titre en locale `ar`, plutôt que la
    // translittération `nameFrench` — trouvé non traduit ici à l'audit
    // design pré-publication Play Store alors que le reste de cette carte
    // "Aujourd'hui" l'était déjà.
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: status.wird)),
      ),
      leading: Icon(
        status.doneToday ? Icons.check_circle : Icons.radio_button_unchecked,
        color: status.doneToday ? AppColors.emerald : AppColors.bronze,
      ),
      title: ContentText(
        isArabic ? status.wird.nameArabic : status.wird.nameFrench,
        style: isArabic
            ? AppTheme.sacredText(fontSize: 18, color: AppColors.ink)
            : const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? ContentText(subtitle, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12))
          : null,
      trailing: streakLabel != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(999)),
              // Émeraude sur or pâle (5,00:1) : l'or sur or pâle faisait
              // 1,93:1, illisible (audit de l'accueil du 2026-10-26, P1).
              child: ContentText(streakLabel,
                  style: TextStyle(color: AppColors.emerald, fontSize: 10.5, fontWeight: FontWeight.w500)),
            )
          : DirectionalChevron(color: AppColors.bronze),
    );
  }
}

class HomeResumeTasbihCard extends StatelessWidget {
  const HomeResumeTasbihCard({super.key, required this.resumable, required this.l10n});

  final HomeResumableSession resumable;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Index borné : une session enregistrée par une ancienne version peut
    // pointer au-delà du nombre de piliers actuel.
    final pillars = resumable.wird.pillars;
    final pillarIndex = resumable.session.pillarIndex.clamp(0, pillars.length - 1);
    final pillar = pillars[pillarIndex];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final wirdName = isArabic ? resumable.wird.nameArabic : resumable.wird.nameFrench;
    // Position du pilier plutôt que sa translittération (audit de l'accueil
    // du 2026-10-26, P3-4) : elle restait en latin dans l'interface arabe, et
    // pour l'intention ou Salatoul Fatihi elle contient le texte entier. Même
    // libellé que l'écran du Tasbih.
    final pillarLabel = l10n.wirdTasbihPillarProgress(pillarIndex + 1, pillars.length);
    final subtitle =
        '$wirdName · ${l10n.homeResumeTasbihSubtitle(pillarLabel, resumable.session.currentCount, pillar.repetitions)}';

    void resume() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TasbihScreen(wird: resumable.wird)),
        );

    // Audit de l'accueil du 2026-10-26 (P2-6) : la carte entière reprend le
    // tasbih, et le bouton passe sous le texte, à 48 dp. Il faisait 25 dp, et
    // placé à droite il réduisait le texte à une colonne étroite à 200 %
    // (« Repren / dre le Tasbih »).
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resume,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.replay_circle_filled_outlined, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.homeResumeTasbihTitle, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                    const SizedBox(height: 4),
                    ContentText(subtitle, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.emerald),
                          foregroundColor: AppColors.emerald,
                        ),
                        onPressed: resume,
                        child: Text(l10n.homeResumeTasbihCta),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeNextReminderCard extends StatelessWidget {
  const HomeNextReminderCard({super.key, required this.next, required this.l10n});

  final HomeNextReminder next;
  final AppLocalizations l10n;

  /// Traduit le libellé du créneau par son `id` plutôt que d'afficher
  /// `slot.label` (toujours en français, `wird_reminder_slots.dart`) —
  /// même gap trouvé sur l'écran Wird > Rappels (`wird_reminders_screen.dart`),
  /// non corrigé ici : hors du périmètre "page d'accueil" demandé.
  String _slotLabel(AppLocalizations l10n) {
    return switch (next.slot.id) {
      'lazim_morning' => l10n.reminderSlotMorning,
      'lazim_evening' => l10n.reminderSlotEvening,
      'wazifa_daily' => l10n.reminderSlotDaily,
      'hadratou_jouma_weekly' => l10n.reminderSlotFriday,
      _ => next.slot.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final time = '${next.setting.hour.toString().padLeft(2, '0')}:${next.setting.minute.toString().padLeft(2, '0')}';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final wirdName = isArabic ? next.wird.nameArabic : next.wird.nameFrench;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.notifications_active_outlined, color: AppColors.emerald, size: 19),
        ),
        title: Text(_slotLabel(l10n), style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          l10n.homeNextReminderSubtitle(wirdName, time),
          style: TextStyle(color: AppColors.secondaryInk, fontSize: 12),
        ),
      ),
    );
  }
}
