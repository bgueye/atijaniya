import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/nav_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../communaute/presentation/communaute_screen.dart';
import '../../figures/presentation/figures_screen.dart';
import '../../khadara/presentation/khadara_screen.dart';
import '../../profil/presentation/profil_screen.dart';
import '../../wird/presentation/wird_list_screen.dart';
import 'home_dashboard_provider.dart';
import 'home_screen.dart';

/// Barre d'onglets inférieure, 5 destinations : Accueil · Wird · Khadara ·
/// Figures · Communauté. Profil accessible via une icône avatar en en-tête.
/// (docs/03-architecture-ecrans.md — Navigation principale)
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(_index, l10n)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          // `IndexedStack` garde les 5 onglets montés en permanence : sans
          // cette invalidation explicite, `homeDashboardProvider` (pourtant
          // `autoDispose`) ne serait jamais rechargé au retour sur l'accueil,
          // puisqu'il resterait "observé" en continu par un widget jamais
          // démonté. Un wird terminé ou une session de tasbih avancée dans
          // un autre onglet doit se refléter dès le retour sur "Accueil".
          if (i == 0 && _index != 0) ref.invalidate(homeDashboardProvider);
          setState(() => _index = i);
        },
        items: [
          BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.home), label: l10n.navHome),
          BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.wird), label: l10n.navWird),
          BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.khadara), label: l10n.navKhadara),
          BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.figures), label: l10n.navFigures),
          BottomNavigationBarItem(icon: const AppNavIcon(AppNavIconType.communaute), label: l10n.navCommunity),
        ],
      ),
    );
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
