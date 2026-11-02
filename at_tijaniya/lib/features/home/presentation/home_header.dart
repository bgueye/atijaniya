// En-tête de l'accueil et carte « Prochaine étape » (refonte du 2026-11-01,
// proposition B retenue par le porteur de projet). Remplace l'ancien en-tête
// (`home_hero.dart`) et les cartes « Aujourd'hui », « Prochain moment » et
// « Accès rapide » (`home_wird_cards.dart`), qui répétaient trois fois la
// même information sur les wirds du jour.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/presentation/free_wird_screen.dart';
import '../../wird/presentation/tasbih_screen.dart';
import '../../wird/presentation/wird_detail_screen.dart';
import '../../wird/presentation/wird_display_name.dart';
import '../../wird/presentation/wird_icon.dart';
import '../domain/home_dashboard.dart';

/// Hauteur de la bande zaytoune que la carte d'action chevauche.
const double _overlap = 34;

/// Texte du statut du jour, pour l'anneau (lecteur d'écran).
String homeStatusText(HomeTodayStatus status, AppLocalizations l10n) => switch (status.kind) {
      HomeStatusKind.allDone => l10n.homeStatusAllDone,
      HomeStatusKind.noneDone => l10n.homeStatusNoneDone,
      HomeStatusKind.partial => l10n.homeStatusPartial(status.doneCount, status.totalCount),
    };

/// En-tête zaytoune : jour, salutation, date hégirienne et anneau du jour.
/// Le zaytoune y reste par exception (`CLAUDE.md`, décision du 2026-10-26) :
/// c'est la porte d'entrée de la pratique.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.dayLine,
    required this.greeting,
    required this.hijriLine,
    required this.statuses,
    required this.todayStatus,
  });

  final String dayLine;
  final String greeting;
  final String hijriLine;

  /// Wirds applicables aujourd'hui, `null` tant que le tableau de bord n'est
  /// pas chargé (l'anneau n'est alors pas dessiné).
  final List<HomeWirdStatus>? statuses;
  final HomeTodayStatus? todayStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Halo émeraude en haut, côté fin de ligne : la profondeur vient de la
        // palette existante, sans nouvelle couleur.
        gradient: RadialGradient(
          center: AlignmentDirectional.topEnd.resolve(Directionality.of(context)),
          radius: 1.3,
          colors: [Color.lerp(AppColors.zaytoune, AppColors.emerald, 0.45)!, AppColors.zaytoune],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Motif signature, une seule occurrence par écran
          // (design_tokens.yaml § iconography).
          const PositionedDirectional(
            top: -28,
            end: -28,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.goldOnDark, strokeWidth: 1.6)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLine.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          color: AppColors.goldOnDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ContentText(
                        greeting,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Titre arabe en Amiri (design_tokens.yaml § sacred_and_arabic_titles).
                        style: Localizations.localeOf(context).languageCode == 'ar'
                            ? AppTheme.sacredText(fontSize: 24, color: AppColors.offWhite).copyWith(height: 1.4)
                            : AppTheme.titleText(fontSize: 28, height: 1.08, color: AppColors.offWhite),
                      ),
                      const SizedBox(height: 4),
                      // La date hégirienne est calculée et peut différer d'un
                      // jour de l'observation de la lune : la ligne le dit
                      // (décision du 2026-10-26, audit de l'accueil P2-4).
                      Text(hijriLine, style: TextStyle(fontSize: 11.5, color: AppColors.secondaryOnDark)),
                    ],
                  ),
                ),
                if (statuses != null && statuses!.isNotEmpty && todayStatus != null) ...[
                  const SizedBox(width: 12),
                  HomeDayRing(statuses: statuses!, label: homeStatusText(todayStatus!, l10n)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anneau segmenté : un segment par wird applicable aujourd'hui, doré quand
/// il est fait. Annoncé au lecteur d'écran par le statut du jour en clair.
class HomeDayRing extends StatelessWidget {
  const HomeDayRing({super.key, required this.statuses, required this.label});

  final List<HomeWirdStatus> statuses;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final done = statuses.where((s) => s.doneToday).length;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        height: 72,
        child: CustomPaint(
          painter: _RingPainter([for (final s in statuses) s.doneToday]),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$done/${statuses.length}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.offWhite, height: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.homeRingCaption,
                      style: TextStyle(fontSize: 9, letterSpacing: 0.8, color: AppColors.secondaryOnDark, height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.segments);

  final List<bool> segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    const stroke = 5.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final n = segments.length;
    final gap = n == 1 ? 0.0 : 0.32;
    final sweep = 2 * math.pi / n - gap;
    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = n == 1 ? StrokeCap.butt : StrokeCap.round
        ..color = segments[i] ? AppColors.goldOnDark : AppColors.offWhite.withValues(alpha: 0.18);
      canvas.drawArc(rect, -math.pi / 2 + i * 2 * math.pi / n + gap / 2, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.segments.length != segments.length ||
      [for (var i = 0; i < segments.length; i++) oldDelegate.segments[i] != segments[i]].any((d) => d);
}

/// Bande zaytoune chevauchée par la carte d'action : prolonge l'en-tête sous
/// le haut de la carte, qui semble ainsi posée dessus.
class HomeOverlapping extends StatelessWidget {
  const HomeOverlapping({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(top: 0, left: 0, right: 0, height: _overlap, child: ColoredBox(color: AppColors.zaytoune)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: child),
      ],
    );
  }
}

/// Carte « Prochaine étape » : la seule action principale de l'accueil. Dit
/// quel wird faire maintenant (ou reprendre), avec son rappel ; quand tout
/// est fait, « Journée accomplie » et le tasbih libre. En bas, une pastille
/// par wird du jour, qui ouvre son guide.
class HomeActionCard extends StatelessWidget {
  const HomeActionCard({super.key, required this.statuses, required this.nextStep});

  /// Wirds applicables aujourd'hui.
  final List<HomeWirdStatus> statuses;
  final HomeNextStep? nextStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final step = nextStep;

    void openWird(Wird wird) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)));
    void openFreeTasbih() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FreeWirdScreen()));

    final String eyebrow;
    final Widget title;
    final String meta;
    final String cta;
    final VoidCallback onCta;
    final IconData icon;
    final bool primary;

    if (step == null) {
      final streak = dailyStreakOfTheDay(statuses);
      eyebrow = l10n.homeDayDoneEyebrow;
      title = Text(l10n.homeDayDoneTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500));
      meta = streak > 0
          ? (streak == 1 ? l10n.homeStreakDailySingular(streak) : l10n.homeStreakDaily(streak))
          : l10n.homeStatusAllDone;
      cta = l10n.homeQuickTasbihLabel;
      onCta = openFreeTasbih;
      icon = Icons.check_circle_outline;
      primary = false;
    } else {
      final wird = step.status.wird;
      final resumable = step.resumable;
      final name = wirdDisplayName(context, wird);
      title = ContentText(
        name,
        style: isArabic
            ? AppTheme.sacredText(fontSize: 20, color: AppColors.ink).copyWith(height: 1.4)
            : const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      );
      icon = iconForWird(wird.id);
      primary = true;
      if (resumable != null) {
        // Index borné : une session enregistrée par une ancienne version peut
        // pointer au-delà du nombre de piliers actuel.
        final pillars = wird.pillars;
        final pillarIndex = resumable.session.pillarIndex.clamp(0, pillars.length - 1);
        final pillarLabel = l10n.wirdTasbihPillarProgress(pillarIndex + 1, pillars.length);
        eyebrow = l10n.homeResumeEyebrow;
        meta = l10n.homeResumeTasbihSubtitle(
            pillarLabel, resumable.session.currentCount, pillars[pillarIndex].repetitions);
        cta = l10n.homeNextStepResume;
        onCta = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TasbihScreen(wird: wird)));
      } else {
        eyebrow = l10n.homeNextStepEyebrow;
        final reminder = step.reminder;
        if (reminder != null) {
          String two(int n) => n.toString().padLeft(2, '0');
          meta = l10n.homeNextStepReminder('${two(reminder.setting.hour)}:${two(reminder.setting.minute)}');
        } else {
          meta = wird.frequency == WirdFrequency.daily
              ? l10n.homeWirdSubtitlePendingDaily
              : l10n.homeWirdSubtitlePendingFridayToday;
        }
        cta = l10n.homeNextStepStart;
        onCta = () => openWird(wird);
      }
    }

    // À forte taille de texte, le bouton passe sous le texte plutôt que de
    // le réduire à une colonne étroite (même règle que l'audit P2-6).
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final button = primary
        ? FilledButton(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.offWhite,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Text(cta),
          )
        : FilledButton.tonal(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emeraldSoft,
              foregroundColor: AppColors.emerald,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Text(cta),
          );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(style: const TextStyle(color: AppColors.ink), child: title),
        const SizedBox(height: 2),
        ContentText(meta, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
      ],
    );

    final chip = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppColors.emerald, size: 22),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.zaytoune.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large) ...[
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [chip, const SizedBox(width: 12), Expanded(child: text)]),
              const SizedBox(height: 10),
              Align(alignment: AlignmentDirectional.centerEnd, child: button),
            ] else
              Row(children: [chip, const SizedBox(width: 12), Expanded(child: text), const SizedBox(width: 8), button]),
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
            Wrap(
              spacing: 6,
              children: [
                for (final status in statuses)
                  _WirdPill(
                    label: wirdDisplayName(context, status.wird),
                    arabic: isArabic,
                    done: status.doneToday,
                    onTap: () => openWird(status.wird),
                  ),
                if (step != null)
                  _WirdPill(
                      label: l10n.homeQuickTasbihLabel,
                      arabic: false,
                      done: false,
                      dashed: true,
                      onTap: openFreeTasbih),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille d'un wird du jour : 48 dp de zone tactile pour un dessin de 32.
class _WirdPill extends StatelessWidget {
  const _WirdPill(
      {required this.label, required this.arabic, required this.done, required this.onTap, this.dashed = false});

  final String label;

  /// Nom arabe d'un wird : Amiri (texte religieux), jamais pour un libellé
  /// d'interface comme « Tasbih libre ».
  final bool arabic;
  final bool done;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.emerald : AppColors.secondaryInk;
    return Semantics(
      button: true,
      selected: done,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: done ? AppColors.emeraldSoft : null,
                borderRadius: BorderRadius.circular(999),
                border: done ? null : Border.all(color: AppColors.bronze.withValues(alpha: dashed ? 0.45 : 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) ...[Icon(Icons.check, size: 13, color: color), const SizedBox(width: 4)],
                  // Flexible : à 200 %, un libellé long passe à la ligne au
                  // lieu de déborder de la carte.
                  Flexible(
                    child: ContentText(
                      label,
                      style: arabic
                          ? AppTheme.sacredText(fontSize: 13, color: color).copyWith(height: 1.3)
                          : TextStyle(fontSize: 12, color: color, fontWeight: done ? FontWeight.w500 : FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
