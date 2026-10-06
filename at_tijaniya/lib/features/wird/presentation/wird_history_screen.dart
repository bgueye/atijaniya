import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_progress_stats.dart';
import 'wird_history_controller.dart';

/// Historique & progression du Wird — P1 (docs/03-architecture-ecrans.md :
/// "Régularité, jours consécutifs, taux de complétion").
///
/// Un wird est compté comme "terminé" le jour où le disciple a parcouru tous
/// ses piliers via le Tasbih digital jusqu'au bout — voir
/// `TasbihController.nextPillar()`. Aucune notion de partiel ici, cohérent
/// avec le caractère "Lazim" (obligatoire, sans exception) du corpus validé.
///
/// Présentation revue le 2026-10-06 : le calendrier est le cœur de l'écran
/// (la question du disciple est "ai-je été régulier ?"), la série en cours
/// est le seul grand chiffre, et le reste tient en deux lignes sobres. Les
/// trois tuiles à icône d'origine (flamme, anneau, coche) donnaient le même
/// poids à tout et un ton de jeu déplacé pour une pratique obligatoire.
class WirdHistoryScreen extends ConsumerWidget {
  const WirdHistoryScreen({super.key, required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wirdHistoryControllerProvider(wird));

    return Scaffold(
      backgroundColor: AppColors.parchment,
      // Titre court : "Historique — Hadratou-l-Jouma" ne tenait pas sur une
      // ligne, le nom du wird est repris en tête du contenu.
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.wirdHistoryHeading)),
      body: state.loading || state.stats == null
          ? Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : _HistoryBody(wird: wird, stats: state.stats!),
    );
  }
}

/// Chiffres alignés entre eux (largeur fixe), pour que "26 sur 30" et le
/// total ne dansent pas d'une valeur à l'autre.
const _tabularFigures = [FontFeature.tabularFigures()];

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.wird, required this.stats});

  final Wird wird;
  final WirdProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekly = wird.frequency == WirdFrequency.weekly;
    final hasHistory = stats.totalCompletions > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        _WirdName(wird: wird),
        const SizedBox(height: 16),
        // Filet doré : "accents, filets" est l'usage prévu de l'or dans la
        // charte (design_tokens.yaml).
        Container(height: 1, color: AppColors.gold.withValues(alpha: 0.7)),
        const SizedBox(height: 20),
        hasHistory
            ? _StreakHero(
                streak: stats.currentStreak,
                // Singulier jusqu'à 1 : "0 jour", "1 jour", "2 jours".
                label: stats.currentStreak <= 1
                    ? (weekly ? l10n.wirdHistoryStreakFridaySingular : l10n.wirdHistoryStreakDaySingular)
                    : (weekly ? l10n.wirdHistoryStreakFridays : l10n.wirdHistoryStreakDays),
              )
            : _EmptyHero(title: l10n.wirdHistoryEmptyTitle, hint: l10n.wirdHistoryEmptyHint),
        const SizedBox(height: 24),
        weekly ? _FridayStrip(periods: stats.recentPeriods, today: stats.today) : _MonthGrid(stats: stats),
        const SizedBox(height: 14),
        const _Legend(),
        if (hasHistory) ...[
          const SizedBox(height: 20),
          const _Hairline(),
          const SizedBox(height: 16),
          // Pas de pourcentage : "26 sur 30" dit la même chose sans donner
          // une note à la pratique (décision du 2026-10-06).
          _StatLine(
            label: weekly ? l10n.wirdHistoryFridaysPractised : l10n.wirdHistoryDaysPractised,
            value: l10n.wirdHistoryRatio(stats.completedInRateWindow, stats.ratePeriods),
          ),
          const SizedBox(height: 10),
          _Meter(fraction: stats.completionRate),
          const SizedBox(height: 16),
          const _Hairline(),
          const SizedBox(height: 16),
          _StatLine(
            label: weekly ? l10n.wirdHistoryTotalWeekly : l10n.wirdHistoryTotalDaily,
            value: '${stats.totalCompletions}',
          ),
          const SizedBox(height: 4),
          Text(
            l10n.wirdHistorySince(MaterialLocalizations.of(context).formatShortDate(stats.firstCompletion!)),
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
        ],
      ],
    );
  }
}

/// Nom du wird en tête d'écran : toujours le nom arabe du corpus validé, en
/// Amiri ; le nom français en dessous quand l'interface n'est pas en arabe.
class _WirdName extends StatelessWidget {
  const _WirdName({required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context) {
    final arabicUi = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        Text(
          wird.nameArabic,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: AppTheme.sacredText(fontSize: 26, color: AppColors.ink).copyWith(height: 1.5),
        ),
        if (!arabicUi)
          Text(
            wird.nameFrench,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.ink),
          ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.bronze.withValues(alpha: 0.3));
  }
}

/// Série en cours : le seul grand chiffre de l'écran. La rosace — une seule
/// occurrence par écran, en filigrane (design_tokens.yaml § iconography) —
/// l'accompagne du côté opposé au texte.
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak, required this.label});

  final int streak;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _HeroFrame(
      // Lu d'un seul tenant par un lecteur d'écran : "12 jours d'affilée".
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 60,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                fontFeatures: _tabularFigures,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 17, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Premier passage, aucune récitation enregistrée : on dit comment une
/// journée se marque plutôt que d'afficher une rangée de zéros. Aucun texte
/// religieux ici, seulement le mode d'emploi de l'écran.
class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return _HeroFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({required this.child});

  final Widget child;

  static const double _rosaceSize = 104;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rosaceSize),
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 12),
          // Décor pur : ignoré par les lecteurs d'écran.
          ExcludeSemantics(
            child: SizedBox(
              width: _rosaceSize,
              height: _rosaceSize,
              child: CustomPaint(
                painter: RosacePainter(color: AppColors.gold.withValues(alpha: 0.55), strokeWidth: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille des cinq dernières semaines d'un wird quotidien : une colonne par
/// jour de la semaine, dans l'ordre de la langue de l'interface, la semaine
/// en cours en dernière ligne. L'ancienne frise de 14 pastilles glissait d'un
/// jour chaque jour et ne couvrait pas la même durée que le taux affiché.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.stats});

  final WirdProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    // `firstDayOfWeekIndex` compte à partir du dimanche (0) ; `DateTime.weekday`
    // de 1 (lundi) à 7 (dimanche).
    final firstWeekday = material.firstDayOfWeekIndex == 0 ? DateTime.sunday : material.firstDayOfWeekIndex;
    final days = buildWirdCalendar(stats: stats, firstWeekday: firstWeekday);

    return Column(
      children: [
        // Initiales des jours, écrites une seule fois. Purement visuelles :
        // chaque case annonce déjà sa date complète.
        ExcludeSemantics(
          child: Row(
            children: [
              for (final day in days.take(7))
                Expanded(
                  child: Text(
                    material.narrowWeekdays[day.date.weekday % 7],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < days.length ~/ 7; week++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                for (final day in days.skip(week * 7).take(7)) Expanded(child: Center(child: _DayCell(status: day, today: stats.today))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Les huit derniers vendredis de Hadratou-l-Jouma, sur toute la largeur. Le
/// mois n'est écrit que sous le premier vendredi et à chaque changement de
/// mois ; il est fourni par `intl` dans la langue de l'interface (l'ancien
/// "jour/mois" était écrit en dur).
class _FridayStrip extends StatelessWidget {
  const _FridayStrip({required this.periods, required this.today});

  final List<WirdPeriodStatus> periods;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat.MMM(Localizations.localeOf(context).toLanguageTag());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < periods.length; i++)
          Expanded(
            child: Column(
              children: [
                _DayCell(status: periods[i], today: today),
                const SizedBox(height: 4),
                SizedBox(
                  height: 16,
                  child: i == 0 || periods[i].date.month != periods[i - 1].date.month
                      ? ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              month.format(periods[i].date),
                              style: const TextStyle(fontSize: 12, color: AppColors.ink),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Une case de calendrier : le quantième dans un disque. L'état ne repose
/// jamais sur la seule couleur — disque plein (fait), cercle vide (manqué),
/// anneau doré (aujourd'hui), chiffre nu et estompé (à venir, ou antérieur au
/// début de la pratique).
class _DayCell extends StatelessWidget {
  const _DayCell({required this.status, required this.today});

  final WirdPeriodStatus status;

  /// Jour de référence des statistiques, pour l'anneau "aujourd'hui".
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = status.state;
    final isToday = status.date == today;
    final inactive = state == WirdPeriodState.upcoming || state == WirdPeriodState.beforeStart;

    final cell = Container(
      width: 40,
      height: 40,
      // L'anneau doré d'aujourd'hui entoure la case quel que soit son état :
      // on voit à la fois "c'est aujourd'hui" et "c'est fait / pas encore".
      decoration: isToday
          ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2))
          : null,
      alignment: Alignment.center,
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state == WirdPeriodState.done ? AppColors.emerald : null,
          border: state == WirdPeriodState.missed ? Border.all(color: AppColors.bronze, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${status.date.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: state == WirdPeriodState.done || isToday ? FontWeight.w600 : FontWeight.w400,
            color: state == WirdPeriodState.done
                ? AppColors.offWhite
                : inactive
                    ? AppColors.bronze.withValues(alpha: 0.6)
                    : AppColors.ink,
            fontFeatures: _tabularFigures,
          ),
        ),
      ),
    );

    // Un jour à venir ou antérieur au début n'a rien à annoncer.
    if (inactive) return ExcludeSemantics(child: cell);

    final stateLabel = switch (state) {
      WirdPeriodState.done => l10n.wirdHistoryDone,
      WirdPeriodState.missed => l10n.wirdHistoryMissed,
      _ => l10n.wirdHistoryPending,
    };
    return Semantics(
      // `container` : chaque jour reste une annonce distincte, au lieu d'être
      // fondu avec ses voisins de ligne en un seul long libellé.
      container: true,
      label: '${MaterialLocalizations.of(context).formatFullDate(status.date)}, $stateLabel',
      child: ExcludeSemantics(child: cell),
    );
  }
}

/// Légende des trois dessins de case, sous le calendrier.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget item(BoxDecoration swatch, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: swatch),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
        ],
      );
    }

    // Redondante avec l'annonce de chaque case pour un lecteur d'écran.
    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 6,
        children: [
          item(BoxDecoration(shape: BoxShape.circle, color: AppColors.emerald), l10n.wirdHistoryDone),
          item(
            BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.bronze, width: 1.5)),
            l10n.wirdHistoryMissed,
          ),
          item(
            BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2)),
            l10n.wirdHistoryToday,
          ),
        ],
      ),
    );
  }
}

/// Une ligne "libellé … valeur" : le libellé en phrase, la valeur en gras du
/// côté opposé. Lue d'un seul tenant par un lecteur d'écran.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.ink))),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              fontFeatures: _tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Jauge fine de la part des jours pratiqués. Simple renfort visuel de la
/// ligne "26 sur 30" au-dessus : ignorée par les lecteurs d'écran.
class _Meter extends StatelessWidget {
  const _Meter({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: AppColors.bronze.withValues(alpha: 0.22),
          // Aligné sur le début de ligne : la jauge se remplit de droite à
          // gauche en arabe.
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: AppColors.emerald),
          ),
        ),
      ),
    );
  }
}
