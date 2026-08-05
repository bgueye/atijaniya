import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../communaute/presentation/communaute_screen.dart';
import '../../figures/presentation/figures_screen.dart';
import '../../khadara/presentation/khadara_screen.dart';
import '../../profil/presentation/profil_screen.dart';
import '../../wird/presentation/wird_list_screen.dart';
import 'home_screen.dart';

/// Barre d'onglets inférieure, 5 destinations : Accueil · Wird · Khadara ·
/// Figures · Communauté. Profil accessible via une icône avatar en en-tête.
/// (docs/03-architecture-ecrans.md — Navigation principale)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: l10n.navHome),
          BottomNavigationBarItem(icon: const Icon(Icons.menu_book_outlined), label: l10n.navWird),
          BottomNavigationBarItem(icon: const Icon(Icons.groups_outlined), label: l10n.navKhadara),
          BottomNavigationBarItem(icon: const Icon(Icons.auto_stories_outlined), label: l10n.navFigures),
          BottomNavigationBarItem(icon: const Icon(Icons.people_alt_outlined), label: l10n.navCommunity),
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
