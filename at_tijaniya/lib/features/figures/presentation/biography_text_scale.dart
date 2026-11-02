/// Taille du texte d'une biographie (« Aa » de la fiche d'une figure, refonte
/// du 2026-11-02) : trois paliers, en boucle, gardés sur l'appareil.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const biographyTextScales = [1.0, 1.15, 1.3];

final biographyTextScaleProvider =
    NotifierProvider<BiographyTextScaleController, double>(BiographyTextScaleController.new);

class BiographyTextScaleController extends Notifier<double> {
  static const _key = 'figure_biography_text_scale';

  @override
  double build() {
    _load();
    return biographyTextScales.first;
  }

  /// Stockage illisible : la taille par défaut reste, sans erreur.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_key);
      if (stored != null && biographyTextScales.contains(stored) && stored != state) state = stored;
    } catch (_) {}
  }

  /// Palier suivant, puis retour au premier.
  Future<void> next() async {
    final index = biographyTextScales.indexOf(state);
    state = biographyTextScales[(index + 1) % biographyTextScales.length];
    // Échec d'écriture : la taille vaut pour la session seulement.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, state);
    } catch (_) {}
  }
}
