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
    _ready = _load();
  }

  final TasbihReadingPrefsStore _store;

  /// Fin de la lecture des réglages enregistrés.
  late final Future<void> _ready;

  Future<void> _load() async {
    final loaded = await _store.load();
    if (mounted) state = loaded;
  }

  /// Applique [change] aux réglages lus. Un changement fait avant la fin du
  /// chargement attend celle-ci : avant l'audit du 2026-11-03, il partait des
  /// valeurs par défaut et enregistrait celles-ci pour les autres réglages,
  /// en gardant `loaded: false`.
  Future<void> _update(TasbihReadingPrefs Function(TasbihReadingPrefs current) change) async {
    await _ready;
    if (!mounted) return;
    final next = change(state);
    state = next;
    await _store.save(next);
  }

  /// A− / A+ : de 2 en 2, entre 22 et 40.
  void stepArabicSize(int direction) => _update((s) => s.copyWith(arabicSize: s.arabicSize + 2 * direction));

  void setTransliteration(bool value) => _update((s) => s.copyWith(showTransliteration: value));

  void setTranslation(bool value) => _update((s) => s.copyWith(showTranslation: value));

  void markFocusHintShown() {
    if (!state.focusHintShown) _update((s) => s.copyWith(focusHintShown: true));
  }
}
