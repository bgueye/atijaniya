import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/donation/domain/donation_amount.dart';

void main() {
  group('parseDonationAmount', () {
    test('accepte un montant entier positif', () {
      expect(parseDonationAmount('5000'), 5000.0);
    });

    test('accepte une virgule décimale', () {
      expect(parseDonationAmount('12,5'), 12.5);
    });

    test('ignore les espaces autour du texte', () {
      expect(parseDonationAmount('  2000  '), 2000.0);
    });

    test('rejette un texte vide', () {
      expect(parseDonationAmount(''), isNull);
    });

    test('rejette un montant nul ou négatif', () {
      expect(parseDonationAmount('0'), isNull);
      expect(parseDonationAmount('-10'), isNull);
    });

    test('rejette un texte non numérique', () {
      expect(parseDonationAmount('abc'), isNull);
    });
  });

  test('donationPresetAmounts correspond à la maquette (2000/5000/10000)', () {
    expect(donationPresetAmounts, [2000, 5000, 10000]);
  });
}
