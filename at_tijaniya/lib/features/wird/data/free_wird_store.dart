/// Persistance locale (SharedPreferences) du Wird libre en cours, pour la
/// reprise de session — même principe que `tasbih_session_store.dart`, mais
/// une seule clé fixe : un seul compteur libre en cours à la fois (pas
/// d'id, contrairement aux wirds du corpus validé).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/free_wird_session.dart';

class FreeWirdStore {
  const FreeWirdStore();

  static const _key = 'free_wird_session';

  Future<FreeWirdSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return FreeWirdSession.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(FreeWirdSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
