/// État des réglages de lecture de l'écran de pratique (« Aa ») : chargés une
/// fois, enregistrés à chaque changement. Voir `tasbih_reading_prefs_store.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasbih_reading_prefs_store.dart';

final tasbihReadingPrefsProvider =
    StateNotifierProvider<TasbihReadingPrefsController, TasbihReadingPrefs>((ref) => TasbihReadingPrefsController());

class TasbihReadingPrefsController extends StateNotifier<TasbihReadingPrefs> {
  /// [store] n'est passé que par les tests.
  TasbihReadingPrefsController({TasbihReadingPrefsStore store = const TasbihReadingPrefsStore()})
      : _store = store,
        super(const TasbihReadingPrefs()) {
    _load();
  }

  final TasbihReadingPrefsStore _store;

  /// Un changement fait avant la fin du chargement ne doit pas être écrasé
  /// par les valeurs lues ensuite.
  bool _changed = false;

  Future<void> _load() async {
    final loaded = await _store.load();
    if (mounted && !_changed) state = loaded;
  }

  void _update(TasbihReadingPrefs next) {
    _changed = true;
    state = next;
    _store.save(next);
  }

  /// A− / A+ : de 2 en 2, entre 22 et 40.
  void stepArabicSize(int direction) => _update(state.copyWith(arabicSize: state.arabicSize + 2 * direction));

  void setTransliteration(bool value) => _update(state.copyWith(showTransliteration: value));

  void setTranslation(bool value) => _update(state.copyWith(showTranslation: value));

  void markFocusHintShown() {
    if (!state.focusHintShown) _update(state.copyWith(focusHintShown: true));
  }
}
