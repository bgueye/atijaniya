/// Persistance locale (SharedPreferences) du Wird libre en cours, pour la
/// reprise de session — même principe que `tasbih_session_store.dart`, mais
/// une seule clé fixe : un seul compteur libre en cours à la fois (pas
/// d'id, contrairement aux wirds du corpus validé).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../domain/free_wird_session.dart';

class FreeWirdStore {
  const FreeWirdStore();

  static const _baseKey = 'free_wird_session';

  /// Clé propre au compte connecté — voir `user_scoped_prefs.dart`.
  String _key(SharedPreferences prefs) => userScopedKey(prefs, _baseKey);

  Future<FreeWirdSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(prefs));
    if (raw == null) return null;
    // Valeur illisible (ancienne version, écriture interrompue) : on repart
    // de zéro plutôt que de laisser l'écran bloqué sur son chargement.
    try {
      return FreeWirdSession.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(FreeWirdSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(prefs), jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(prefs));
  }
}
