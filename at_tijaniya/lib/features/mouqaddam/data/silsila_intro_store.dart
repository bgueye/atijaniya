/// Persistance locale (SharedPreferences) de l'état de lecture de
/// l'animation de révélation de la silsila d'ijaza
/// (`docs/08-spec-animation-silsila.md` §2).
///
/// La spec déclenche l'auto-lecture via une notification push "Votre
/// parrainage a été accepté" — infrastructure absente de l'app (seuls des
/// rappels locaux existent, pour le Wird). Approximation retenue : on
/// mémorise la LONGUEUR de la chaîne au dernier auto-play ; si elle a
/// augmenté depuis (nouvelle acceptation de parrainage, ou nouveau maillon
/// manuel saisi), l'animation se rejoue automatiquement à la prochaine
/// ouverture de l'écran — sinon état final statique + bouton "Revivre
/// l'ascension". Ne détecte pas un changement de contenu à longueur égale
/// (cas marginal, non couvert par la spec non plus).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';

class SilsilaIntroStore {
  const SilsilaIntroStore();

  static const _baseKey = 'silsila_intro_played_chain_length';

  /// Clé propre au compte connecté — voir `user_scoped_prefs.dart`.
  String _key(SharedPreferences prefs) => userScopedKey(prefs, _baseKey);

  Future<int> lastPlayedChainLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(prefs)) ?? 0;
  }

  Future<void> markPlayed(int chainLength) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(prefs), chainLength);
  }
}
