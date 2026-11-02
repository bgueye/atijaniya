/// « Ma pratique » sur le Profil (refonte du 2026-11-02, maquette
/// `docs/maquettes/ecran-profil.html`) : trois chiffres tirés des données de
/// pratique déjà enregistrées sur le téléphone (`wirdOverviewProvider`), et le
/// réglage qui permet de les masquer (décision validée : les afficher, avec un
/// réglage pour ne pas « compter » sa pratique).
///
/// Ces chiffres ne quittent pas l'appareil et ne sont visibles que du
/// disciple ; ils repartent de zéro après une réinstallation (l'écran le dit).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/user_scoped_prefs.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_overview.dart';

/// Les trois chiffres de « Ma pratique ».
typedef PracticeStats = ({int dailyStreak, int monthCount, int fridayStreak});

/// - [PracticeStats.dailyStreak] : la plus courte des séries des wirds
///   quotidiens (Lazim et Wazifa) — la journée entière n'est tenue que depuis
///   ce nombre de jours, même calcul que l'accueil ;
/// - [PracticeStats.monthCount] : récitations complètes enregistrées ce mois-ci,
///   tous wirds confondus (une par wird et par jour, comme l'historique) ;
/// - [PracticeStats.fridayStreak] : la série de la Hadratou-l-Jouma.
PracticeStats computePracticeStats(List<WirdOverviewEntry> entries, DateTime now) {
  final daily = [
    for (final e in entries)
      if (e.wird.frequency == WirdFrequency.daily) e.stats.currentStreak
  ];
  final weekly = [
    for (final e in entries)
      if (e.wird.frequency == WirdFrequency.weekly) e.stats.currentStreak
  ];
  var month = 0;
  for (final e in entries) {
    month += e.stats.completedDays.where((d) => d.year == now.year && d.month == now.month).length;
  }
  return (
    dailyStreak: daily.isEmpty ? 0 : daily.reduce((a, b) => a < b ? a : b),
    monthCount: month,
    fridayStreak: weekly.isEmpty ? 0 : weekly.first,
  );
}

/// Afficher ou masquer « Ma pratique ». Affichée par défaut ; gardé sur
/// l'appareil, propre au compte connecté.
final showPracticeStatsProvider = NotifierProvider<ShowPracticeStatsController, bool>(ShowPracticeStatsController.new);

class ShowPracticeStatsController extends Notifier<bool> {
  static const _base = 'profile_show_practice_stats';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(userScopedKey(prefs, _base));
    if (stored != null && stored != state) state = stored;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(userScopedKey(prefs, _base), value);
  }
}
