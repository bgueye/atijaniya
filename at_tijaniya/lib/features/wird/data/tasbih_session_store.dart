/// Persistance locale (SharedPreferences) des sessions de Tasbih en cours,
/// pour la "reprise de session" (docs/03-architecture-ecrans.md, P0).
///
/// Une seule session en cours par wird est conservée. Elle est supprimée dès
/// que le wird est entièrement terminé (voir `TasbihController.completeWird`)
/// ou explicitement réinitialisée par le disciple.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tasbih_session.dart';

class TasbihSessionStore {
  const TasbihSessionStore();

  String _key(String wirdId) => 'tasbih_session_$wirdId';

  Future<TasbihSession?> load(String wirdId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(wirdId));
    if (raw == null) return null;
    return TasbihSession.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(TasbihSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(session.wirdId), jsonEncode(session.toJson()));
  }

  Future<void> clear(String wirdId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(wirdId));
  }
}
