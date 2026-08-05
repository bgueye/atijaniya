/// Persistance locale (SharedPreferences) des jours où un wird a été
/// entièrement terminé — P1 "Historique & progression"
/// (docs/03-architecture-ecrans.md). Même approche que
/// `tasbih_session_store.dart` : pas de dépendance à l'authentification
/// Supabase, qui n'est pas encore branchée côté app.
///
/// Une date est ajoutée par `TasbihController` quand le disciple termine le
/// dernier pilier d'un wird (voir `TasbihController.nextPillar()`). Stockée
/// en `yyyy-MM-dd`, sans heure : un wird n'est compté qu'une fois par jour,
/// même s'il est re-parcouru plusieurs fois.
library;

import 'package:shared_preferences/shared_preferences.dart';

class WirdCompletionStore {
  const WirdCompletionStore();

  String _key(String wirdId) => 'wird_completions_$wirdId';

  String _format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<List<DateTime>> load(String wirdId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(wirdId)) ?? const [];
    return raw.map(DateTime.parse).toList()..sort();
  }

  /// Enregistre la date du jour comme complétée pour ce wird — idempotent :
  /// ne crée pas de doublon si le wird est terminé plusieurs fois le même
  /// jour.
  Future<void> recordCompletionToday(String wirdId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(wirdId);
    final existing = (prefs.getStringList(key) ?? const []).toSet();
    existing.add(_format(DateTime.now()));
    await prefs.setStringList(key, existing.toList()..sort());
  }
}
