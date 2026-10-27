import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/nav_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../communaute/presentation/communaute_screen.dart';
import '../../communaute/presentation/community_providers.dart';
import '../../communaute/presentation/groups_providers.dart';
import '../../figures/presentation/figures_screen.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../khadara/presentation/khadara_screen.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profil/presentation/profil_screen.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../wird/data/wird_notification_service.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/presentation/wird_detail_screen.dart';
import '../../wird/presentation/wird_list_screen.dart';
import 'home_dashboard_provider.dart';
import 'home_screen.dart';
import '../../../core/widgets/content_text.dart';

/// Barre d'onglets inférieure, 5 destinations : Accueil · Wird · Zawiyas ·
/// Figures · Communauté. Profil accessible via une icône avatar en en-tête.
/// (docs/03-architecture-ecrans.md — Navigation principale)
///
/// L'onglet "Zawiyas" pointe toujours vers `KhadaraScreen`/le module
/// `features/khadara` : seul le libellé affiché change (2026-09-27,
/// demande du porteur de projet) — pas le code, les tables (`events`,
/// `zawiyas`) ni les routes, pour limiter le risque sur un module déjà en
/// fin de développement.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  /// Onglets déjà ouverts (audit de l'accueil du 2026-10-26, P2-7) : un
  /// onglet n'est construit qu'à sa première visite, puis gardé (et son état
  /// avec) par l'`IndexedStack`. Les cinq étaient construits dès l'arrivée sur
  /// l'accueil, et leurs requêtes (fil, groupes, conversations, lieux, directs,
  /// figures) passaient avant celles de l'accueil sur une connexion lente.
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    // Rappel du wird touché (P2-5) : ouvert dès l'arrivée sur les onglets
    // s'il a lancé l'app, ou aussitôt s'il est touché pendant l'utilisation.
    WirdNotificationService.instance.pendingWirdId.addListener(_openPendingWird);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingWird());
  }

  @override
  void dispose() {
    WirdNotificationService.instance.pendingWirdId.removeListener(_openPendingWird);
    super.dispose();
  }

  /// Ouvre le guide du wird dont le rappel a été touché, par-dessus l'écran
  /// courant : le retour arrière ramène là où était le disciple.
  void _openPendingWird() {
    if (!mounted || WirdNotificationService.instance.pendingWirdId.value == null) return;
    final wirdId = WirdNotificationService.instance.takePendingWirdId();
    final wird = validatedWirds.where((w) => w.id == wirdId).firstOrNull;
    if (wird == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WirdDetailScreen(wird: wird)));
  }

  static const _screens = [
    HomeScreen(),
    WirdListScreen(),
    KhadaraScreen(),
    FiguresScreen(),
    CommunauteScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final isSignedIn = ref.watch(currentUserIdProvider) != null;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    // Bouton retour d'Android (audit de l'accueil du 2026-10-26, P3-1) :
    // depuis un autre onglet, il quittait l'app ; il revient d'abord à
    // l'accueil, et ne quitte l'app que depuis l'accueil.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectTab(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleFor(_index, l10n)),
          actions: [
            if (isSignedIn)
              IconButton(
                icon: Badge(
                  label: ContentText('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  // Émeraude : le chiffre blanc cassé sur or faisait 2,40:1
                  // (audit de l'accueil du 2026-10-26, P1) ; 6,11:1 ici, comme
                  // les pastilles de non-lus de la Communauté.
                  backgroundColor: AppColors.emerald,
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: l10n.notificationsTooltip,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: l10n.profileTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilScreen()),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _screens.length; i++) _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _selectTab,
          items: [
            BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.home), label: l10n.navHome),
            BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.wird), label: l10n.navWird),
            BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.khadara), label: l10n.navKhadara),
            BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.figures), label: l10n.navFigures),
            BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.communaute), label: l10n.navCommunity),
          ],
        ),
      ),
    );
  }

  /// Passe à l'onglet [i] — touché dans la barre, ou l'accueil par le bouton
  /// retour (voir `PopScope` dans [build]).
  void _selectTab(int i) {
    // `IndexedStack` garde les 5 onglets montés en permanence : sans
    // cette invalidation explicite, `homeDashboardProvider` (pourtant
    // `autoDispose`) ne serait jamais rechargé au retour sur l'accueil,
    // puisqu'il resterait "observé" en continu par un widget jamais
    // démonté. Un wird terminé ou une session de tasbih avancée dans
    // un autre onglet doit se refléter dès le retour sur "Accueil".
    if (i == 0 && _index != 0) ref.invalidate(homeDashboardProvider);
    // Même raison pour les listes venues du réseau : ces providers ne
    // sont jamais libérés (onglets toujours montés), donc un direct
    // démarré ou terminé par quelqu'un d'autre, un évènement passé ou
    // une nouvelle publication n'apparaissaient qu'au redémarrage de
    // l'app. On recharge à l'arrivée sur l'onglet ; l'ancien contenu
    // reste affiché pendant le rechargement.
    if (i != _index) {
      if (i == 0 || i == 2) ref.invalidate(upcomingEventsProvider);
      // Les lieux aussi, depuis l'audit Zawiyas du 2026-10-25 (P3-2) :
      // un lieu ajouté ou modifié par l'admin n'apparaissait qu'au
      // redémarrage.
      if (i == 2) ref.invalidate(zawiyasProvider);
      if (i == 2) {
        // Statut mouqaddam et zawiya attribuée : décidés par d'autres
        // (parrain, admin) pendant que l'app est ouverte, ils n'étaient
        // jamais relus avant un redémarrage.
        ref.invalidate(myMouqaddamStatusProvider);
        ref.invalidate(allLiveStreamsProvider);
        ref.invalidate(streamReplaysProvider);
      }
      if (i == 4) {
        ref.invalidate(communityFeedProvider);
        ref.invalidate(groupsProvider);
      }
    }
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  String _titleFor(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.appName;
      case 1:
        return l10n.navWird;
      case 2:
        return l10n.navKhadara;
      case 3:
        return l10n.navFigures;
      case 4:
        return l10n.navCommunity;
      default:
        return l10n.appName;
    }
  }
}
