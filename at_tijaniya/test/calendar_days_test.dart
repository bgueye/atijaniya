import 'package:at_tijaniya/core/date/calendar_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('addDays', () {
    test("traverse le passage à l'heure d'hiver sans quitter minuit", () {
      // Nuit du 24 au 25 octobre 2026 : journée de 25 h en Europe.
      expect(addDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 10, 26), -7), DateTime(2026, 10, 19));
    });

    test("traverse le passage à l'heure d'été sans sauter de jour", () {
      // Nuit du 28 au 29 mars 2026 : journée de 23 h en Europe.
      expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
      expect(addDays(DateTime(2026, 3, 30), -1), DateTime(2026, 3, 29));
    });

    test("conserve l'heure et la minute locales", () {
      expect(addDays(DateTime(2026, 10, 23, 14, 30), 7), DateTime(2026, 10, 30, 14, 30));
    });

    test("gère les changements de mois et d'année", () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });
}
