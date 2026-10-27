import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/date/current_day.dart';
import '../../../core/date/hijri_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/data/donation_feature_flag.dart';
import '../../donation/presentation/donation_screen.dart';
import '../../figures/domain/featured_figure.dart';
import '../../figures/presentation/figures_providers.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/presentation/free_wird_screen.dart';
import '../../wird/presentation/wird_detail_screen.dart';
import 'home_dashboard_provider.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/content_text.dart';
import 'home_hero.dart';
import 'home_wird_cards.dart';
import 'home_sections.dart';
import 'home_khadara_teaser_card.dart';
import 'home_featured_figure_card.dart';

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

    // Jour courant, et non `DateTime.now()` lu à la construction : l'en-tête
    // et les sections du vendredi suivent le changement de jour (P1).
    final today = ref.watch(currentDayProvider);
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final featuredFigureAsync = ref.watch(featuredFigureProvider);

    // Tirer pour actualiser (audit de l'accueil du 2026-10-26, P2-2) : le
    // tableau de bord local, le prochain évènement et la figure de la semaine.
    // Un échec n'interrompt pas le geste : la section concernée le dit.
    Future<void> refresh() async {
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(figuresProvider);
      await Future.wait([
        ref.refresh(upcomingEventsProvider.future).then<void>((_) {}, onError: (_) {}),
        ref.refresh(featuredFigureProvider.future).then<void>((_) {}, onError: (_) {}),
      ]);
    }

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          HomeHero(
            greeting: greeting,
            dateLine: _formatTodayDate(l10n, today),
            statusPill: dashboardAsync.maybeWhen(
              data: (data) => HomeStatusPill(status: data.todayStatus, l10n: l10n),
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
                today: today,
                l10n: l10n,
                eventsAsync: eventsAsync,
                featuredFigureAsync: featuredFigureAsync,
                onRetryEvents: () => ref.invalidate(upcomingEventsProvider),
                onRetryFigure: () {
                  ref.invalidate(figuresProvider);
                  ref.invalidate(featuredFigureProvider);
                },
              ),
            ),
          ),
        ],
      ),
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
            Text(l10n.homeLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
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
    required this.today,
    required this.l10n,
    required this.eventsAsync,
    required this.featuredFigureAsync,
    required this.onRetryEvents,
    required this.onRetryFigure,
  });

  final HomeDashboardData data;
  final VoidCallback onRetryEvents;
  final VoidCallback onRetryFigure;

  /// Jour courant (`currentDayProvider`).
  final DateTime today;
  final AppLocalizations l10n;
  final AsyncValue<List<KhadaraEvent>> eventsAsync;
  final AsyncValue<FeaturedFigure?> featuredFigureAsync;

  @override
  Widget build(BuildContext context) {
    final hasNextMoment = data.resumableSession != null || data.nextReminder != null;
    // Hadratou-l-Jouma (hebdomadaire) n'a de sens que le vendredi — hors de
    // ce jour, la ligne "non fait aujourd'hui" serait trompeuse puisqu'il
    // n'y a rien à faire.
    final isFriday = today.weekday == DateTime.friday;
    final todayStatuses = data.statuses.where((s) => s.wird.frequency == WirdFrequency.daily || isFriday).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionLabel(l10n.homeSectionToday),
        HomeWirdChecklistCard(statuses: todayStatuses, isFriday: isFriday, l10n: l10n),
        if (hasNextMoment) ...[
          const SizedBox(height: 20),
          HomeSectionLabel(l10n.homeSectionNextMoment),
          if (data.resumableSession != null) HomeResumeTasbihCard(resumable: data.resumableSession!, l10n: l10n),
          if (data.resumableSession != null && data.nextReminder != null) const SizedBox(height: 10),
          if (data.nextReminder != null) HomeNextReminderCard(next: data.nextReminder!, l10n: l10n),
        ],
        const SizedBox(height: 20),
        HomeSectionLabel(l10n.homeSectionQuickAccess),
        _QuickAccessRow(isFriday: isFriday, l10n: l10n),
        // Sections venues du réseau (P2-2) : elles disparaissaient en silence
        // en cas d'erreur, apparaissaient en décalant la page, et rien ne
        // disait qu'on était hors ligne. Voir `HomeNetworkSection`.
        const SizedBox(height: 20),
        HomeSectionLabel(l10n.homeSectionKhadara),
        HomeNetworkSection<List<KhadaraEvent>>(
          value: eventsAsync,
          placeholderHeight: 72,
          errorMessage: l10n.homeEventsLoadError,
          onRetry: onRetryEvents,
          builder: (events) =>
              events.isEmpty ? HomeSectionNotice(l10n.homeEventsEmpty) : HomeKhadaraTeaserCard(event: events.first),
        ),
        // La figure de la semaine peut ne pas exister (aucune éligible) : la
        // section n'apparaît alors pas, sauf erreur ou chargement.
        if (featuredFigureAsync.valueOrNull != null || !featuredFigureAsync.hasValue) ...[
          const SizedBox(height: 20),
          HomeSectionLabel(l10n.homeSectionFeaturedFigure),
          HomeNetworkSection<FeaturedFigure?>(
            value: featuredFigureAsync,
            placeholderHeight: 280,
            errorMessage: l10n.homeFigureLoadError,
            onRetry: onRetryFigure,
            builder: (featured) =>
                featured == null ? const SizedBox.shrink() : HomeFeaturedFigureCard(featured: featured),
          ),
        ],
        if (kDonationsEnabled) ...[
          const SizedBox(height: 20),
          HomeSectionLabel(l10n.homeSectionDonation),
          _DonationCard(l10n: l10n),
        ],
      ],
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow({required this.isFriday, required this.l10n});

  final bool isFriday;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final quickAccessWirds = validatedWirds.where((wird) => wird.frequency == WirdFrequency.daily || isFriday);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Row(
      children: [
        for (final wird in quickAccessWirds) ...[
          Expanded(
            child: _QuickAccessItem(
              icon: Icons.nights_stay_outlined,
              label: isArabic ? wird.nameArabic : wird.nameFrench,
              arabic: isArabic,
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
  const _QuickAccessItem({required this.icon, required this.label, required this.onTap, this.arabic = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// `true` quand [label] est un nom de wird en arabe (`nameArabic`) plutôt
  /// que le libellé générique "Tasbih libre" — bascule sur Amiri, jamais
  /// pour un libellé d'interface générique (règle design, `CLAUDE.md`).
  final bool arabic;

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
            ContentText(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: arabic
                  ? GoogleFonts.amiri(fontSize: 12, color: AppColors.ink)
                  : const TextStyle(fontSize: 10.5, color: AppColors.ink),
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
        subtitle:
            Text(l10n.settingsDonationTileSubtitle, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12)),
        trailing: DirectionalChevron(color: AppColors.bronze),
      ),
    );
  }
}
