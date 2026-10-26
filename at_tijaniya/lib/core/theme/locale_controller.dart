// Contrôleur de langue — bascule FR/AR (et donc RTL/LTR automatique via
// Flutter, qui déduit la directionnalité de la Locale).
//
// Langue enregistrée sur l'appareil depuis l'audit de l'accueil du
// 2026-10-26 (P2-1) : elle n'était jamais conservée, et l'écran de choix de
// langue revenait à chaque lancement, y compris pour un disciple connecté ;
// un changement fait dans Paramètres était perdu au redémarrage. La langue
// enregistrée est lue dans `main()` avant le premier affichage
// ([initialLocaleProvider]) : l'étape de langue est alors sautée.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue enregistrée au lancement précédent, lue par `main()` ; `null` au
/// premier lancement (écran de choix de langue).
final initialLocaleProvider = Provider<Locale?>((ref) => null);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.read(initialLocaleProvider); // null => écran de choix de langue affiché au démarrage

  /// Change la langue et l'enregistre pour les lancements suivants (au
  /// mieux : un échec d'écriture n'empêche pas le changement immédiat).
  void setLocale(Locale locale) {
    state = locale;
    unawaited(LocaleStore.save(locale).catchError((_) {}));
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// Enregistrement de la langue choisie (`shared_preferences`, comme le
/// contraste renforcé). Commun à tous les comptes de l'appareil : c'est la
/// langue de l'app, pas une donnée personnelle.
abstract final class LocaleStore {
  static const _key = 'app_locale';
  static const _supported = {'fr', 'ar'};

  static Future<Locale?> load() async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    return _supported.contains(code) ? Locale(code!) : null;
  }

  static Future<void> save(Locale locale) async {
    await (await SharedPreferences.getInstance()).setString(_key, locale.languageCode);
  }
}
