/// Persistance locale (SharedPreferences) des réglages de rappels par wird —
/// même approche que `tasbih_session_store.dart` : pas de dépendance à
/// l'authentification Supabase, qui n'est pas encore branchée côté app.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/wird_reminder.dart';

class WirdReminderStore {
  const WirdReminderStore();

  String _key(String wirdId) => 'wird_reminders_$wirdId';

  Future<List<WirdReminderSetting>> load(String wirdId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(wirdId));
    if (raw == null) return const [];
    // Valeur illisible (ancienne version, écriture interrompue) : on repart
    // de zéro plutôt que de laisser l'écran bloqué sur son chargement.
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => WirdReminderSetting.tryFromJson(e as Map<String, dynamic>))
          .whereType<WirdReminderSetting>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String wirdId, List<WirdReminderSetting> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(wirdId), jsonEncode(settings.map((s) => s.toJson()).toList()));
  }
}
