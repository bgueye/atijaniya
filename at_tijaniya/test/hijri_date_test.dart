import 'package:at_tijaniya/core/date/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HijriDate.fromGregorian', () {
    // Références croisées via System.Globalization.HijriCalendar (.NET,
    // HijriAdjustment=0) — même algorithme tabulaire standard, calculé
    // indépendamment de l'implémentation ici pour servir de vérification.
    const cases = [
      ('2026-08-17', HijriDate(year: 1448, month: 3, day: 4)),
      ('2026-08-21', HijriDate(year: 1448, month: 3, day: 8)),
      ('2000-01-01', HijriDate(year: 1420, month: 9, day: 25)),
      ('2024-03-21', HijriDate(year: 1445, month: 9, day: 12)),
      ('1990-01-01', HijriDate(year: 1410, month: 6, day: 4)),
      ('2050-12-31', HijriDate(year: 1473, month: 4, day: 17)),
      ('1970-01-01', HijriDate(year: 1389, month: 10, day: 23)),
    ];

    for (final (gregorian, expected) in cases) {
      test('$gregorian -> ${expected.day}/${expected.month}/${expected.year}', () {
        final result = HijriDate.fromGregorian(DateTime.parse(gregorian));
        expect(result.year, expected.year);
        expect(result.month, expected.month);
        expect(result.day, expected.day);
      });
    }

    test('deux jours grégoriens consécutifs restent consécutifs en hégirien', () {
      final d1 = HijriDate.fromGregorian(DateTime(2026, 8, 17));
      final d2 = HijriDate.fromGregorian(DateTime(2026, 8, 18));
      expect(d2.day, d1.day + 1);
      expect(d2.month, d1.month);
      expect(d2.year, d1.year);
    });
  });
}
