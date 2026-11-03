// Corrections de l'audit des écrans refaits du 2026-11-03, étape 3
// (`docs/audits/2026-11-03-ecrans-refaits.md`) : sessions de tasbih en pause
// (accueil, onglet Wird, tasbih) et état inconnu des cartes du Wird avant la
// lecture des données locales. Logique pure ; wirds factices.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/home/domain/home_dashboard.dart';
import 'package:at_tijaniya/features/wird/domain/tasbih_session.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_overview.dart';
import 'package:at_tijaniya/features/wird/domain/wird_progress_stats.dart';

Wird _wird(String id, WirdFrequency frequency) =>
    Wird(id: id, nameArabic: id, nameFrench: id, frequency: frequency, pillars: const []);

final _lazim = _wird('lazim', WirdFrequency.daily);
final _hadra = _wird('hadratou_jouma', WirdFrequency.weekly);

TasbihSession _session(String wirdId, DateTime at) =>
    TasbihSession(wirdId: wirdId, pillarIndex: 1, currentCount: 3, mode: TasbihMode.manual, updatedAt: at);

// Vendredi 6 et vendredi 13 novembre 2026, samedi 7.
final _friday = DateTime(2026, 11, 6, 17);
final _nextFriday = DateTime(2026, 11, 13, 17, 30);
final _saturday = DateTime(2026, 11, 7, 9);

WirdOverviewEntry _entry(Wird wird, DateTime now, {TasbihSession? session, List<DateTime> done = const []}) =>
    WirdOverviewEntry(
      wird: wird,
      stats: computeWirdProgressStats(frequency: wird.frequency, completionDates: done, now: now),
      session: session,
    );

void main() {
  group('isTasbihSessionResumable', () {
    test('Hadra : le jour même seulement', () {
      expect(isTasbihSessionResumable(_session('h', _friday), weekly: true, now: _friday), isTrue);
      expect(isTasbihSessionResumable(_session('h', _friday), weekly: true, now: _nextFriday), isFalse);
    });

    test('wird quotidien : d\'un jour à l\'autre, comme avant', () {
      expect(isTasbihSessionResumable(_session('l', _friday), weekly: false, now: _saturday), isTrue);
    });
  });

  group('onglet Wird', () {
    test('une Hadra laissée en pause ne revient pas le vendredi suivant', () {
      expect(_entry(_hadra, _friday, session: _session('hadratou_jouma', _friday)).paused, isTrue);
      expect(_entry(_hadra, _nextFriday, session: _session('hadratou_jouma', _friday)).paused, isFalse);
    });

    test('une pause d\'hier ne masque pas « Fait aujourd\'hui »', () {
      final entry = _entry(_lazim, _saturday, session: _session('lazim', _friday), done: [_saturday]);
      expect(entry.doneToday, isTrue);
      expect(entry.paused, isFalse);
      expect(entry.collapsed, isTrue);
    });

    test('une pause d\'aujourd\'hui reste proposée, même le wird déjà fait', () {
      // Lazim fait le matin, celui du soir commencé puis mis en pause.
      final entry = _entry(_lazim, _saturday, session: _session('lazim', DateTime(2026, 11, 7, 19)), done: [_saturday]);
      expect(entry.paused, isTrue);
    });

    test('une pause d\'hier d\'un wird pas encore fait reste proposée', () {
      expect(_entry(_lazim, _saturday, session: _session('lazim', _friday)).paused, isTrue);
    });

    test('entrée connue par défaut', () {
      expect(_entry(_lazim, _saturday).known, isTrue);
    });
  });

  group('accueil : pickResumableSession', () {
    test('la Hadra d\'hier, plus récente, n\'empêche plus de proposer le Lazim', () {
      // Lazim mis en pause vendredi matin, Hadra vendredi soir ; samedi.
      final result = pickResumableSession([
        (wird: _lazim, session: _session('lazim', DateTime(2026, 11, 6, 8))),
        (wird: _hadra, session: _session('hadratou_jouma', _friday)),
      ], now: _saturday);
      expect(result?.wird.id, 'lazim');
    });

    test('la session d\'un wird déjà fait aujourd\'hui est écartée avant le choix', () {
      final result = pickResumableSession(
          [
            (wird: _lazim, session: _session('lazim', DateTime(2026, 11, 7, 8))),
            (wird: _wird('wazifa', WirdFrequency.daily), session: _session('wazifa', DateTime(2026, 11, 6, 18))),
          ],
          now: _saturday,
          doneWirdIds: {'lazim'});
      expect(result?.wird.id, 'wazifa');
    });

    test('rien à reprendre : null', () {
      expect(
        pickResumableSession([(wird: _hadra, session: _session('hadratou_jouma', _friday))], now: _nextFriday),
        isNull,
      );
    });
  });
}
