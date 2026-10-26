/// Jour courant de l'app (audit de l'accueil du 2026-10-26, P1).
///
/// L'accueil lisait `DateTime.now()` au moment de se construire, et son
/// tableau de bord n'était rechargé qu'au retour d'un écran ou au changement
/// d'onglet. Laissée en arrière-plan la nuit — Android garde le processus —,
/// l'app affichait le lendemain matin la date de la veille et les wirds de la
/// veille comme accomplis : un disciple pouvait omettre son Lazim en s'y fiant.
///
/// [currentDayProvider] vaut la date du jour (minuit local) et change :
/// - au passage de minuit, l'app restant au premier plan (minuteur) ;
/// - au retour au premier plan, si la date a changé entre-temps (un minuteur
///   ne se déclenche pas quand l'app est en arrière-plan).
/// Tout ce qui dépend du jour le regarde (`ref.watch`) : tableau de bord,
/// en-tête, sections réservées au vendredi, figure de la semaine.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_days.dart';

/// Horloge de l'app — remplacée dans les tests pour simuler le passage d'un
/// jour sans attendre minuit.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final currentDayProvider = NotifierProvider<CurrentDayNotifier, DateTime>(CurrentDayNotifier.new);

class CurrentDayNotifier extends Notifier<DateTime> {
  Timer? _midnightTimer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    _lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _midnightTimer?.cancel();
      _lifecycle?.dispose();
    });
    final today = _today();
    _scheduleMidnight(today);
    return today;
  }

  DateTime _today() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// Relit l'horloge : ne publie un nouvel état que si la date a changé, pour
  /// ne pas reconstruire l'accueil à chaque retour au premier plan.
  void refresh() {
    final today = _today();
    if (today != state) state = today;
    _scheduleMidnight(today);
  }

  /// Minuteur jusqu'au minuit suivant (en jours civils, voir [addDays]), plus
  /// une seconde de marge.
  void _scheduleMidnight(DateTime today) {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider)();
    final delay = addDays(today, 1).difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay.isNegative ? Duration.zero : delay, refresh);
  }
}
