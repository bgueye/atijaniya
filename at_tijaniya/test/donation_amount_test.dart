import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/donation/domain/donation_amount.dart';

void main() {
  group('parseDonationAmount', () {
    test('accepte un montant entier dans les bornes', () {
      expect(parseDonationAmount('5000'), 5000);
      expect(parseDonationAmount('100'), 100);
      expect(parseDonationAmount('5000000'), 5000000);
    });

    test('ignore les espaces autour et à l’intérieur du nombre', () {
      expect(parseDonationAmount('  2000  '), 2000);
      expect(parseDonationAmount('10 000'), 10000);
    });

    test('accepte les chiffres arabes', () {
      expect(parseDonationAmount('٥٠٠٠'), 5000);
    });

    test('rejette un montant décimal : le franc CFA n’a pas de centimes', () {
      expect(parseDonationAmount('12,5'), isNull);
      expect(parseDonationAmount('12.5'), isNull);
    });

    test('rejette un montant hors bornes, nul ou négatif', () {
      expect(parseDonationAmount('0'), isNull);
      expect(parseDonationAmount('99'), isNull);
      expect(parseDonationAmount('5000001'), isNull);
      expect(parseDonationAmount('-10'), isNull);
    });

    test('rejette un texte vide ou non numérique', () {
      expect(parseDonationAmount(''), isNull);
      expect(parseDonationAmount('abc'), isNull);
    });
  });

  test('donationPresetAmounts correspond à la maquette (2000/5000/10000)', () {
    expect(donationPresetAmounts, [2000, 5000, 10000]);
  });
}
