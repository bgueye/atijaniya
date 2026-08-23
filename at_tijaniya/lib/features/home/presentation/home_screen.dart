import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/date/hijri_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/presentation/donation_screen.dart';
import '../../figures/domain/featured_figure.dart';
import '../../figures/presentation/figure_detail_screen.dart';
import '../../figures/presentation/figures_providers.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/event_detail_screen.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/presentation/free_wird_screen.dart';
import '../../wird/presentation/tasbih_screen.dart';
import '../../wird/presentation/wird_detail_screen.dart';
import '../domain/home_dashboard.dart';
import 'home_dashboard_provider.dart';

/// Accueil / Tableau de bord — "Statut du jour, accès rapide, prochain
/// horaire" (P0, docs/03-architecture-ecrans.md). Construit entièrement à
/// partir de données déjà persistées ailleurs dans l'app (complétion des
/// wirds, session de tasbih en pause, rappels programmés, prochain
/// évènement Khadara) — voir `home_dashboard_provider.dart`. Aucun
/// Scaffold/AppBar ici : héberge dans `HomeShell`, qui fournit déjà l'un et
/// l'autre pour les 5 onglets.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // `disciple` générique en mode invité (pas de session) ou tant que le
    // profil n'a pas encore été chargé — jamais d'appel à myProfileProvider
    // sans session réelle, qui échouerait (`currentUser!.id` dans
    // `ProfileRepository.fetchMyProfile`).
    final userId = ref.watch(currentUserIdProvider);
    final displayName = userId == null
        ? null
        : ref.watch(myProfileProvider).maybeWhen(data: (profile) => profile.displayName, orElse: () => null);
    final greeting = displayName != null ? '${l10n.homeGreetingPrefix} $displayName' : l10n.homeGreeting;

    final dashboardAsync = ref.watch(homeDashboardProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final featuredFigureAsync = ref.watch(featuredFigureProvider);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          greeting: greeting,
          dateLine: _formatTodayDate(l10n, DateTime.now()),
          statusPill: dashboardAsync.maybeWhen(
            data: (data) => _StatusPill(status: data.todayStatus, l10n: l10n),
            orElse: () => null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: dashboardAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            ),
            error: (error, stackTrace) => _DashboardErrorState(
              l10n: l10n,
              onRetry: () => ref.invalidate(homeDashboardProvider),
            ),
            data: (data) => _DashboardBody(
              data: data,
              l10n: l10n,
              eventsAsync: eventsAsync,
              featuredFigureAsync: featuredFigureAsync,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Vendredi 21 août 2026 · 7 Rabi al-Awwal 1448" — date grégorienne
/// (spellée, pas le format numérique de `formatKhadaraDateTime`, propre à
/// l'en-tête de l'accueil) accompagnée de son équivalent hégirien
/// approximatif (`HijriDate`, calendrier tabulaire — voir sa documentation
/// pour la réserve sur sa précision, jamais une source pour une date
/// religieuse officielle).
String _formatTodayDate(AppLocalizations l10n, DateTime now) {
  String weekdayLabel(int weekday) => switch (weekday) {
        DateTime.monday => l10n.homeDateWeekdayMonday,
        DateTime.tuesday => l10n.homeDateWeekdayTuesday,
        DateTime.wednesday => l10n.homeDateWeekdayWednesday,
        DateTime.thursday => l10n.homeDateWeekdayThursday,
        DateTime.friday => l10n.homeDateWeekdayFriday,
        DateTime.saturday => l10n.homeDateWeekdaySaturday,
        _ => l10n.homeDateWeekdaySunday,
      };
  String monthLabel(int month) => switch (month) {
        1 => l10n.homeDateMonthJanuary,
        2 => l10n.homeDateMonthFebruary,
        3 => l10n.homeDateMonthMarch,
        4 => l10n.homeDateMonthApril,
        5 => l10n.homeDateMonthMay,
        6 => l10n.homeDateMonthJune,
        7 => l10n.homeDateMonthJuly,
        8 => l10n.homeDateMonthAugust,
        9 => l10n.homeDateMonthSeptember,
        10 => l10n.homeDateMonthOctober,
        11 => l10n.homeDateMonthNovember,
        _ => l10n.homeDateMonthDecember,
      };
  String hijriMonthLabel(int month) => switch (month) {
        1 => l10n.homeDateHijriMonth1,
        2 => l10n.homeDateHijriMonth2,
        3 => l10n.homeDateHijriMonth3,
        4 => l10n.homeDateHijriMonth4,
        5 => l10n.homeDateHijriMonth5,
        6 => l10n.homeDateHijriMonth6,
        7 => l10n.homeDateHijriMonth7,
        8 => l10n.homeDateHijriMonth8,
        9 => l10n.homeDateHijriMonth9,
        10 => l10n.homeDateHijriMonth10,
        11 => l10n.homeDateHijriMonth11,
        _ => l10n.homeDateHijriMonth12,
      };

  final hijri = HijriDate.fromGregorian(now);
  return l10n.homeDateLine(
    weekdayLabel(now.weekday),
    now.day,
    monthLabel(now.month),
    now.year,
    hijri.day,
    hijriMonthLabel(hijri.month),
    hijri.year,
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.greeting, required this.dateLine, required this.statusPill});

  final String greeting;
  final String dateLine;
  final Widget? statusPill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.zaytoune,
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Motif signature du design system, une seule occurrence par
            // écran (design_tokens.yaml § iconography) — jamais utilisé sur
            // l'accueil jusqu'ici.
            Positioned(
              top: -28,
              right: -28,
              child: Opacity(
                opacity: 0.14,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.gold, strokeWidth: 1.6)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: AppColors.offWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.offWhite.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: 16),
                  if (statusPill != null) statusPill!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.l10n});

  final HomeTodayStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = switch (status.kind) {
      HomeStatusKind.allDone => l10n.homeStatusAllDone,
      HomeStatusKind.noneDone => l10n.homeStatusNoneDone,
      HomeStatusKind.partial => l10n.homeStatusPartial(status.doneCount, status.totalCount),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.offWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.offWhite, fontSize: 13.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(l10n.homeLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.homeRetry)),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.l10n,
    required this.eventsAsync,
    required this.featuredFigureAsync,
  });

  final HomeDashboardData data;
  final AppLocalizations l10n;
  final AsyncValue<List<KhadaraEvent>> eventsAsync;
  final AsyncValue<FeaturedFigure?> featuredFigureAsync;

  @override
  Widget build(BuildContext context) {
    final hasNextMoment = data.resumableSession != null || data.nextReminder != null;
    final nextEvent = eventsAsync.maybeWhen(data: (list) => list.isNotEmpty ? list.first : null, orElse: () => null);
    final featuredFigure = featuredFigureAsync.maybeWhen(data: (value) => value, orElse: () => null);
    // Hadratou-l-Jouma (hebdomadaire) n'a de sens que le vendredi — hors de
    // ce jour, la ligne "non fait aujourd'hui" serait trompeuse puisqu'il
    // n'y a rien à faire.
    final isFriday = DateTime.now().weekday == DateTime.friday;
    final todayStatuses = data.statuses.where((s) => s.wird.frequency == WirdFrequency.daily || isFriday).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.homeSectionToday),
        _WirdChecklistCard(statuses: todayStatuses, l10n: l10n),
        if (hasNextMoment) ...[
          const SizedBox(height: 20),
          _SectionLabel(l10n.homeSectionNextMoment),
          if (data.resumableSession != null) _ResumeTasbihCard(resumable: data.resumableSession!, l10n: l10n),
          if (data.resumableSession != null && data.nextReminder != null) const SizedBox(height: 10),
          if (data.nextReminder != null) _NextReminderCard(next: data.nextReminder!, l10n: l10n),
        ],
        const SizedBox(height: 20),
        _SectionLabel(l10n.homeSectionQuickAccess),
        _QuickAccessRow(l10n: l10n),
        if (nextEvent != null) ...[
          const SizedBox(height: 20),
          _SectionLabel(l10n.homeSectionKhadara),
          _KhadaraTeaserCard(event: nextEvent),
        ],
        if (featuredFigure != null) ...[
          const SizedBox(height: 20),
          _SectionLabel(l10n.homeSectionFeaturedFigure),
          _FeaturedFigureCard(featured: featuredFigure),
        ],
        const SizedBox(height: 20),
        _SectionLabel(l10n.homeSectionDonation),
        _DonationCard(l10n: l10n),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.bronze,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _WirdChecklistCard extends StatelessWidget {
  const _WirdChecklistCard({required this.statuses, required this.l10n});

  final List<HomeWirdStatus> statuses;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            _WirdRow(status: statuses[i], l10n: l10n),
            if (i < statuses.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _WirdRow extends StatelessWidget {
  const _WirdRow({required this.status, required this.l10n});

  final HomeWirdStatus status;
  final AppLocalizations l10n;

  String? _subtitle(DateTime now) {
    if (status.doneToday) return null;
    if (status.wird.frequency == WirdFrequency.daily) return l10n.homeWirdSubtitlePendingDaily;
    return now.weekday == DateTime.friday ? l10n.homeWirdSubtitlePendingFridayToday : l10n.homeWirdSubtitleWeeklyInfo;
  }

  String? _streakLabel() {
    if (status.streak <= 0) return null;
    return status.wird.frequency == WirdFrequency.daily
        ? l10n.homeStreakDaily(status.streak)
        : l10n.homeStreakWeekly(status.streak);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle(DateTime.now());
    final streakLabel = status.doneToday ? _streakLabel() : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: status.wird)),
      ),
      leading: Icon(
        status.doneToday ? Icons.check_circle : Icons.radio_button_unchecked,
        color: status.doneToday ? AppColors.emerald : AppColors.bronze,
      ),
      title: Text(status.wird.nameFrench, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: AppColors.bronze, fontSize: 12)) : null,
      trailing: streakLabel != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(streakLabel, style: TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w500)),
            )
          : Icon(Icons.chevron_right, color: AppColors.bronze),
    );
  }
}

class _ResumeTasbihCard extends StatelessWidget {
  const _ResumeTasbihCard({required this.resumable, required this.l10n});

  final HomeResumableSession resumable;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pillar = resumable.wird.pillars[resumable.session.pillarIndex];
    final subtitle =
        '${resumable.wird.nameFrench} · ${l10n.homeResumeTasbihSubtitle(pillar.transliteration, resumable.session.currentCount, pillar.repetitions)}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.replay_circle_filled_outlined, color: AppColors.gold, size: 20),
        ),
        title: Text(l10n.homeResumeTasbihTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.bronze, fontSize: 12)),
        trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: AppColors.emerald),
            foregroundColor: AppColors.emerald,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TasbihScreen(wird: resumable.wird)),
          ),
          child: Text(l10n.homeResumeTasbihCta, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _NextReminderCard extends StatelessWidget {
  const _NextReminderCard({required this.next, required this.l10n});

  final HomeNextReminder next;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final time = '${next.setting.hour.toString().padLeft(2, '0')}:${next.setting.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.notifications_active_outlined, color: AppColors.emerald, size: 19),
        ),
        title: Text(next.slot.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          l10n.homeNextReminderSubtitle(next.wird.nameFrench, time),
          style: TextStyle(color: AppColors.bronze, fontSize: 12),
        ),
      ),
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isFriday = DateTime.now().weekday == DateTime.friday;
    final quickAccessWirds = validatedWirds.where((wird) => wird.frequency == WirdFrequency.daily || isFriday);

    return Row(
      children: [
        for (final wird in quickAccessWirds) ...[
          Expanded(
            child: _QuickAccessItem(
              icon: Icons.nights_stay_outlined,
              label: wird.nameFrench,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _QuickAccessItem(
            icon: Icons.tune,
            label: l10n.homeQuickTasbihLabel,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FreeWirdScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.emeraldSoft, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.emerald, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accès à `DonationScreen` — volontairement toujours affiché sur l'accueil,
/// invité compris (aucune session requise, voir `donation_repository.dart` :
/// `user_id` reste `null` pour un don anonyme, même RLS que pour un don
/// identifié). Avant cette carte, le seul chemin passait par Profil →
/// Paramètres, injoignable pour un disciple non connecté puisque Profil
/// affiche un mur "connectez-vous" avant même Paramètres.
class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DonationScreen()),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.favorite_outline, color: AppColors.gold, size: 19),
        ),
        title: Text(l10n.donationTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.settingsDonationTileSubtitle, style: TextStyle(color: AppColors.bronze, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
      ),
    );
  }
}

class _KhadaraTeaserCard extends StatelessWidget {
  const _KhadaraTeaserCard({required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: event.imageUrl != null
              ? Image.network(
                  event.imageUrl!,
                  width: 44,
                  height: 44,
                  // Voir la même note dans khadara_screen.dart.
                  cacheWidth: (44 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (44 * MediaQuery.of(context).devicePixelRatio).round(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const _KhadaraThumbFallback(),
                )
              : const _KhadaraThumbFallback(),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatKhadaraDateTime(event.startsAt), style: TextStyle(color: AppColors.bronze, fontSize: 11.5)),
        trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
      ),
    );
  }
}

/// Carte "Figure de la semaine" — portrait plein cadre, nom + citation/date
/// de ziara superposés en bas sur un dégradé émeraude translucide (jamais
/// zaytoune ici : réservé aux écrans de pratique, voir `CLAUDE.md`), pour
/// que la photo reste lisible sous le texte plutôt que d'être masquée par
/// un bandeau opaque. `featuredFigureProvider` ne renvoie jamais de figure
/// sans portrait (voir `eligibleForRotation`), donc l'image est toujours
/// présente ici.
class _FeaturedFigureCard extends StatelessWidget {
  const _FeaturedFigureCard({required this.featured});

  final FeaturedFigure featured;

  @override
  Widget build(BuildContext context) {
    final figure = featured.figure;
    final citation = featured.citation;
    final nextZiyara = featured.nextZiyara;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
        ),
        // 3:4 (portrait) plutôt que 4:3 : carte plus grande, format proche
        // des portraits en base (sujet proche du haut de la photo, comme
        // `figure_detail_screen.dart`) et assez de hauteur pour que le
        // dégradé + le texte n'empiètent que sur le tiers bas de l'image.
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                figure.portraitUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // Voir la même note dans event_detail_screen.dart.
                cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      AppColors.emerald.withValues(alpha: 0.25),
                      AppColors.emerald.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        figure.nameFrench,
                        style: const TextStyle(
                          fontFamily: AppFonts.titlesFr,
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                          height: 1.05,
                          color: AppColors.offWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        figure.nameArabic,
                        textDirection: TextDirection.rtl,
                        style: AppTheme.sacredText(fontSize: 19, color: AppColors.goldSoft),
                      ),
                      if (citation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '« ${citation.translation} »',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.offWhite.withValues(alpha: 0.9),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (nextZiyara != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 14, color: AppColors.goldSoft),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${nextZiyara.title} · ${formatKhadaraDateTime(nextZiyara.startsAt)}',
                                style: const TextStyle(color: AppColors.goldSoft, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KhadaraThumbFallback extends StatelessWidget {
  const _KhadaraThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.zaytoune, AppColors.emerald],
        ),
      ),
    );
  }
}
