// Contrôleur du mode contraste renforcé (design/design_tokens.yaml §
// accessibility.high_contrast_mode) — bascule persistée, contrairement à
// LocaleController (locale_controller.dart) qui diffère volontairement sa
// persistance à plus tard : un réglage d'accessibilité pour utilisateurs
// âgés n'a de valeur que s'il tient d'un lancement à l'autre.
//
// `AppColors.setHighContrast` (app_colors.dart) est le seul point qui doit
// être synchronisé avec cet état — voir `app.dart`, où il est appelé au
// tout début du build de `AtTijaniyaApp`, avant que le reste de l'arbre ne
// soit (re)construit.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'high_contrast_enabled';

class ContrastController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}

final contrastControllerProvider = NotifierProvider<ContrastController, bool>(
  ContrastController.new,
);
