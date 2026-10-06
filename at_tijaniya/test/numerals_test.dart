import 'package:at_tijaniya/core/text/numerals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLocalizedInt', () {
    test('accepte les chiffres occidentaux', () {
      expect(parseLocalizedInt(' 1445 '), 1445);
    });

    test('accepte les chiffres arabo-indiens et persans', () {
      expect(parseLocalizedInt('١٤٤٥'), 1445);
      expect(parseLocalizedInt('۱۳۴۰'), 1340);
    });

    test('refuse une saisie non entière', () {
      expect(parseLocalizedInt('abc'), isNull);
      expect(parseLocalizedInt(''), isNull);
      expect(parseLocalizedInt('12.5'), isNull);
    });
  });

  group('parseLocalizedDouble', () {
    test('accepte la virgule et les chiffres arabes', () {
      expect(parseLocalizedDouble('14,69'), 14.69);
      expect(parseLocalizedDouble('١٤٫٦٩'), 14.69);
    });

    test('refuse un texte non numérique', () {
      expect(parseLocalizedDouble('nord'), isNull);
    });
  });
}
