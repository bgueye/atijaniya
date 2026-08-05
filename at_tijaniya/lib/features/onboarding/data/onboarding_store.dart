/// Persistance locale (SharedPreferences) du fait que le disciple a déjà vu
/// l'onboarding — présentation des modules (P1, docs/03-architecture-ecrans.md :
/// "Onboarding — présentation | 3-4 écrans d'introduction"). Affiché une
/// seule fois : le réafficher à chaque lancement casserait l'expérience
/// (contrairement au choix de langue, qui reste volontairement non persisté
/// pour l'instant — voir `locale_controller.dart`).
library;

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  const OnboardingStore();

  static const _key = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
