/// Clés SharedPreferences propres à chaque compte (audit du 2026-10-04, S42).
///
/// L'historique des wirds, la session de tasbih, le wird libre et le drapeau
/// d'intro de la silsila étaient enregistrés sous une clé unique par
/// appareil : un second compte connecté sur le même téléphone héritait des
/// données du premier, et elles survivaient à la suppression du compte.
/// Chaque clé est désormais suffixée par l'identifiant du compte (ou
/// `guest` hors connexion).
///
/// Reprise de l'existant : la première lecture d'une clé suffixée adopte la
/// valeur de l'ancienne clé non suffixée, puis supprime cette dernière —
/// l'utilisateur en place garde son historique, le compte suivant n'en
/// hérite pas.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _separator = '::';

/// `null` hors connexion, et aussi quand Supabase n'est pas initialisé
/// (tests unitaires des stores).
String? _currentUserIdOrNull() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// Clé de [base] pour le compte courant, après reprise éventuelle de
/// l'ancienne valeur non suffixée.
String userScopedKey(SharedPreferences prefs, String base) {
  final scoped = '$base$_separator${_currentUserIdOrNull() ?? 'guest'}';
  if (!prefs.containsKey(scoped) && prefs.containsKey(base)) {
    final legacy = prefs.get(base);
    if (legacy is String) {
      prefs.setString(scoped, legacy);
    } else if (legacy is int) {
      prefs.setInt(scoped, legacy);
    } else if (legacy is List) {
      prefs.setStringList(scoped, legacy.cast<String>());
    }
    prefs.remove(base);
  }
  return scoped;
}

/// Efface toutes les données locales du compte [userId] — appelé à la
/// suppression du compte, pour que rien de personnel ne reste sur l'appareil.
Future<void> clearUserScopedPrefs(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final suffix = '$_separator$userId';
  for (final key in prefs.getKeys().where((k) => k.endsWith(suffix)).toList()) {
    await prefs.remove(key);
  }
}
