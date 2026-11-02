/// Réglages de lecture de l'écran de pratique (bouton « Aa », refonte du
/// 2026-11-02, maquette `docs/maquettes/ecran-pratique.html`) : taille de
/// l'arabe, translittération et traduction affichées ou non, et la bulle du
/// mode concentré déjà montrée. Gardés sur l'appareil, propres au compte
/// connecté comme les autres données de pratique (`user_scoped_prefs.dart`).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';

class TasbihReadingPrefs {
  const TasbihReadingPrefs({
    this.arabicSize = defaultArabicSize,
    this.showTransliteration,
    this.showTranslation = false,
    this.focusHintShown = false,
    this.loaded = false,
  });

  static const defaultArabicSize = 30.0;
  static const minArabicSize = 22.0;
  static const maxArabicSize = 40.0;

  /// Taille du texte arabe récité (Amiri), de 22 à 40.
  final double arabicSize;

  /// `null` tant que le disciple n'a rien choisi : affichée par défaut en
  /// français, masquée en arabe (maquette, « Limites ») — voir
  /// [transliterationVisible].
  final bool? showTransliteration;

  /// Masquée par défaut (décision validée du 2026-11-02).
  final bool showTranslation;

  /// La bulle qui propose le mode concentré n'est montrée qu'une fois
  /// (décision validée : jamais automatique, proposé une fois, puis au geste).
  final bool focusHintShown;

  /// Valeurs lues sur l'appareil. Tant qu'elles ne le sont pas, la bulle du
  /// mode concentré n'est pas proposée : elle réapparaissait à chaque
  /// ouverture, décidée avant la fin de la lecture (vu sur capture).
  final bool loaded;

  bool transliterationVisible({required bool arabicInterface}) => showTransliteration ?? !arabicInterface;

  TasbihReadingPrefs copyWith({
    double? arabicSize,
    bool? showTransliteration,
    bool? showTranslation,
    bool? focusHintShown,
  }) {
    return TasbihReadingPrefs(
      arabicSize: (arabicSize ?? this.arabicSize).clamp(minArabicSize, maxArabicSize),
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showTranslation: showTranslation ?? this.showTranslation,
      focusHintShown: focusHintShown ?? this.focusHintShown,
      loaded: loaded,
    );
  }
}

class TasbihReadingPrefsStore {
  const TasbihReadingPrefsStore();

  String _key(SharedPreferences prefs, String name) => userScopedKey(prefs, 'tasbih_reading_$name');

  Future<TasbihReadingPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TasbihReadingPrefs(
      arabicSize: (prefs.getDouble(_key(prefs, 'arabic_size')) ?? TasbihReadingPrefs.defaultArabicSize)
          .clamp(TasbihReadingPrefs.minArabicSize, TasbihReadingPrefs.maxArabicSize),
      showTransliteration: prefs.getBool(_key(prefs, 'transliteration')),
      showTranslation: prefs.getBool(_key(prefs, 'translation')) ?? false,
      focusHintShown: prefs.getBool(_key(prefs, 'focus_hint_shown')) ?? false,
      loaded: true,
    );
  }

  Future<void> save(TasbihReadingPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key(prefs, 'arabic_size'), value.arabicSize);
    final transliteration = value.showTransliteration;
    if (transliteration != null) await prefs.setBool(_key(prefs, 'transliteration'), transliteration);
    await prefs.setBool(_key(prefs, 'translation'), value.showTranslation);
    await prefs.setBool(_key(prefs, 'focus_hint_shown'), value.focusHintShown);
  }
}
