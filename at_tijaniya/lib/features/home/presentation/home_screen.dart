import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/current_day.dart';
import '../../../core/date/hijri_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/network_section.dart';
import '../../../core/widgets/section_title.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/data/donation_feature_flag.dart';
import '../../donation/presentation/donation_screen.dart';
import '../../figures/domain/featured_figure.dart';
import '../../figures/presentation/figures_providers.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/presentation/wird_repair_providers.dart';
import 'home_dashboard_provider.dart';
import 'home_discover_section.dart';
import 'home_featured_figure_card.dart';
import 'home_header.dart';
import 'home_upcoming_section.dart';

/// Accueil — refonte du 2026-11-01 (proposition B retenue par le porteur de
/// projet, maquettes : `docs/09-journal-implementation-frontend.md`).
///
/// De haut en bas :
/// 1. en-tête zaytoune : jour, salutation, date hégirienne, anneau du jour ;
/// 2. carte « Prochaine étape », la seule action principale de l'écran ;
/// 3. carrousel « Comprendre et rattraper » (contenu validé des trois pages
///    de l'onglet Wird) ;
/// 4. figure de la semaine ;
/// 5. « À venir » (direct en cours, prochains évènements) ;
/// 6. don.
///
/// Les wirds du jour n'apparaissent qu'une fois (anneau + carte d'action),
/// au lieu de trois (pastille, « Aujourd'hui », « Accès rapide »). Aucun
/// Scaffold/AppBar ici : `HomeShell` les fournit pour les 5 onglets.
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

    // Jour courant, et non `DateTime.now()` lu à la construction : l'en-tête
    // et les wirds du vendredi suivent le changement de jour (P1).
    final today = ref.watch(currentDayProvider);
    final now = ref.watch(clockProvider)();
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final featuredFigureAsync = ref.watch(featuredFigureProvider);

    // Tirer pour actualiser : tableau de bord local, carrousel, évènements,
    // directs et figure de la semaine. Un échec n'interrompt pas le geste :
    // la section concernée le dit.
    Future<void> refresh() async {
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(figuresProvider);
      ref.invalidate(allLiveStreamsProvider);
      ref.invalidate(wirdRepairContentProvider);
      ref.invalidate(tariqaConditionsProvider);
      ref.invalidate(tariqaBenefitsRowsProvider);
      await Future.wait([
        ref.refresh(upcomingEventsProvider.future).then<void>((_) {}, onError: (_) {}),
        ref.refresh(featuredFigureProvider.future).then<void>((_) {}, onError: (_) {}),
      ]);
    }

    final isFriday = today.weekday == DateTime.friday;
    final data = dashboardAsync.valueOrNull;
    // Hadratou-l-Jouma (hebdomadaire) n'a de sens que le vendredi.
    final todayStatuses = data?.statuses.where((s) => s.wird.frequency == WirdFrequency.daily || isFriday).toList();
    final hadraPending =
        isFriday && (data?.statuses.any((s) => s.wird.frequency == WirdFrequency.weekly && !s.doneToday) ?? false);

    final (dayLine, hijriLine) = _formatTodayDate(l10n, today);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          HomeHeader(
            dayLine: dayLine,
            greeting: greeting,
            hijriLine: hijriLine,
            statuses: todayStatuses,
            todayStatus: data?.todayStatus,
          ),
          HomeOverlapping(
            child: dashboardAsync.when(
              // Les données sont locales : le chargement est bref, la carte
              // garde sa place pour que la page ne saute pas.
              loading: () => const _ActionPlaceholder(),
              error: (error, stackTrace) => _DashboardErrorState(
                l10n: l10n,
                onRetry: () => ref.invalidate(homeDashboardProvider),
              ),
              data: (data) => HomeActionCard(statuses: todayStatuses!, nextStep: data.nextStep),
            ),
          ),
          HomeDiscoverSection(
            now: now,
            unmarkedYesterday: data?.unmarkedYesterday ?? const [],
            hadraPendingToday: hadraPending,
          ),
          // La figure de la semaine peut ne pas exister (aucune éligible) : la
          // section n'apparaît alors pas, sauf erreur ou chargement.
          if (featuredFigureAsync.valueOrNull != null || !featuredFigureAsync.hasValue) ...[
            SectionTitle(l10n.homeSectionFeaturedFigure),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NetworkSection<FeaturedFigure?>(
                value: featuredFigureAsync,
                placeholderHeight: 200,
                errorMessage: l10n.homeFigureLoadError,
                onRetry: () {
                  ref.invalidate(figuresProvider);
                  ref.invalidate(featuredFigureProvider);
                },
                builder: (featured) =>
                    featured == null ? const SizedBox.shrink() : HomeFeaturedFigureCard(featured: featured),
              ),
            ),
          ],
          SectionTitle(l10n.homeSectionUpcoming),
          HomeUpcomingSection(
            eventsAsync: eventsAsync,
            now: now,
            onRetry: () => ref.invalidate(upcomingEventsProvider),
          ),
          if (kDonationsEnabled) _DonationLine(l10n: l10n),
        ],
      ),
    );
  }
}

/// Jour (« Dimanche 1 novembre ») et date hégirienne (« 21 Joumada al-Oula
/// 1448 · calculée, à un jour près »). La date hégirienne vient du
/// calendrier tabulaire (`HijriDate`) : jamais une source pour une date
/// religieuse officielle, d'où la mention.
(String, String) _formatTodayDate(AppLocalizations l10n, DateTime now) {
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
  return (
    l10n.homeDayLine(weekdayLabel(now.weekday), now.day, monthLabel(now.month)),
    l10n.homeHijriShortLine(hijri.day, hijriMonthLabel(hijri.month), hijri.year),
  );
}

class _ActionPlaceholder extends StatelessWidget {
  const _ActionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.sectionLoading,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(18)),
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
    return Container(
      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.bronze, size: 28),
          const SizedBox(height: 8),
          Text(l10n.homeLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

/// Accès à `DonationScreen` — toujours affiché sur l'accueil, invité
/// compris (aucune session requise, voir `donation_repository.dart`). Une
/// ligne discrète en bas de page plutôt qu'une carte : le don n'est pas
/// l'action principale de l'accueil.
class _DonationLine extends StatelessWidget {
  const _DonationLine({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
      child: Column(
        children: [
          Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
          Row(
            children: [
              Icon(Icons.favorite_outline, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l10n.homeDonationLine, style: TextStyle(fontSize: 13, color: AppColors.secondaryInk))),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationScreen())),
                style: TextButton.styleFrom(foregroundColor: AppColors.emerald),
                child: Text(l10n.donationTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
