/// Fréquence d'affichage du rappel de don après un wird terminé — voir
/// `_DonationNudge` (`tasbih_screen.dart`). Basé sur la date de dernier
/// affichage plutôt qu'un compteur de wirds terminés : reste correct quel
/// que soit le rythme de pratique du disciple (un seul rappel par semaine,
/// qu'il termine un wird par jour ou un par mois), et évite qu'un geste de
/// soutien pensé comme discret devienne un réflexe agaçant sur un écran de
/// pratique.
library;

import 'package:shared_preferences/shared_preferences.dart';

class DonationNudgeStore {
  const DonationNudgeStore();

  static const _key = 'donation_nudge_last_shown';
  static const cooldown = Duration(days: 7);

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return true;
    final lastShown = DateTime.tryParse(raw);
    if (lastShown == null) return true;
    return DateTime.now().difference(lastShown) >= cooldown;
  }

  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }
}
