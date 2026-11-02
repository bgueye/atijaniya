// Éléments partagés par la carte d'un wird (écran Wird) et le guide d'un wird
// (refontes du 2026-11-02) : la pastille d'état du jour posée sur le bandeau
// (`WirdBand`), et la ligne de série. Sortis de `wird_list_screen.dart` pour
// que les deux écrans disent la même chose de la même façon.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_overview.dart';

/// État du jour sur le bandeau d'un wird : En pause, Fait aujourd'hui, À faire
/// aujourd'hui, ou la date du prochain vendredi pour la Hadra. Le bandeau de
/// la Hadra est clair (`gold_soft`) : ses pastilles sont celles des fonds
/// clairs.
Widget wirdStatePill(BuildContext context, WirdOverviewEntry entry, DateTime now) {
  final l10n = AppLocalizations.of(context)!;
  final lightBand = entry.wird.frequency == WirdFrequency.weekly;
  if (entry.paused) {
    return StatePill(l10n.wirdStatePaused, variant: lightBand ? StatePillVariant.todo : StatePillVariant.gold);
  }
  if (entry.doneToday) return StatePill(l10n.wirdStateDoneToday, variant: StatePillVariant.done);
  if (!entry.applicableToday) {
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat.MMMMEEEEd(locale).format(nextFriday(now));
    return StatePill(date[0].toUpperCase() + date.substring(1), variant: StatePillVariant.neutral);
  }
  if (lightBand) return StatePill(l10n.homeWirdSubtitlePendingFridayToday, variant: StatePillVariant.neutral);
  return StatePill(l10n.wirdStateTodoToday, variant: StatePillVariant.onDark);
}

/// Série : frise des 7 derniers jours et nombre de jours d'affilée pour un
/// wird quotidien ; nombre de vendredis d'affilée pour la Hadra (rien avant
/// le premier vendredi marqué). [onDark] : sur zaytoune (guide).
class WirdStreakLine extends StatelessWidget {
  const WirdStreakLine({super.key, required this.entry, this.onDark = false});

  final WirdOverviewEntry entry;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final streak = entry.stats.currentStreak;
    final weekly = entry.wird.frequency == WirdFrequency.weekly;
    final unit = weekly
        ? (streak == 1 ? l10n.wirdHistoryStreakFridaySingular : l10n.wirdHistoryStreakFridays)
        : (streak == 1 ? l10n.wirdHistoryStreakDaySingular : l10n.wirdHistoryStreakDays);
    final strong = onDark ? AppColors.offWhite : AppColors.ink;
    final soft = onDark ? AppColors.secondaryOnDark : AppColors.secondaryInk;
    final on = onDark ? AppColors.goldOnDark : AppColors.emerald;
    final off = onDark ? AppColors.parchment.withValues(alpha: 0.18) : AppColors.bronze.withValues(alpha: 0.22);
    final streakText =
        Text('$streak $unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: strong));
    if (weekly) {
      return streak > 0
          ? Align(alignment: AlignmentDirectional.centerStart, child: streakText)
          : const SizedBox.shrink();
    }
    return Row(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final done in entry.last7Days)
                Container(
                  width: 14,
                  height: 5,
                  margin: const EdgeInsetsDirectional.only(end: 3),
                  decoration: BoxDecoration(color: done ? on : off, borderRadius: BorderRadius.circular(3)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(l10n.wirdLast7Days, style: TextStyle(fontSize: 12, color: soft))),
        streakText,
      ],
    );
  }
}
