// Contrôleur de langue — bascule FR/AR (et donc RTL/LTR automatique via
// Flutter, qui déduit la directionnalité de la Locale). Pas de persistance
// pour l'instant (à ajouter en Phase 2 avec shared_preferences, une fois la
// dépendance choisie) : le choix initial se refait à chaque lancement tant
// qu'aucun compte n'est connecté.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null; // null => écran de choix de langue affiché au démarrage

  void setLocale(Locale locale) => state = locale;
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
