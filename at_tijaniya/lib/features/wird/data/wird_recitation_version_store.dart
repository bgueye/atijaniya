/// Mémorise, pour chaque pilier, quel `audio_path` est la version
/// actuellement "active" sur l'appareil (docs/decision-gestion-audio-wirds.md
/// §4, rétention) — distinct du statut "téléchargé" de
/// `WirdRecitationDownloadStore` : deux fichiers peuvent être téléchargés en
/// même temps (ancienne + nouvelle version) le temps d'une mise à jour, ce
/// store dit lequel est celui que le disciple utilise réellement.
///
/// La position d'un pilier dans `Wird.pillars` est une identité stable
/// (corpus local fixe à l'exécution) : pas besoin de `wird_step_id` pour
/// cette clé.
library;

import 'package:shared_preferences/shared_preferences.dart';

class WirdRecitationVersionStore {
  const WirdRecitationVersionStore();

  String _key(String wirdId, int pillarIndex) => 'wird_recitation_active_path_${wirdId}_$pillarIndex';

  Future<String?> activeAudioPath(String wirdId, int pillarIndex) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(wirdId, pillarIndex));
  }

  Future<void> setActiveAudioPath(String wirdId, int pillarIndex, String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(wirdId, pillarIndex), audioPath);
  }
}
