// Téléphone et e-mail repérés dans le contact libre d'un lieu (audit Zawiyas
// du 2026-10-25, P3-1).

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/contact_links.dart';

void main() {
  test('repère courriel et téléphone dans le contact réel, dans l\'ordre', () {
    final links = extractContactLinks("hiccnyc@gmail.com · +1 332-223-0579 (d'après un annuaire en ligne, à vérifier)");
    expect(links.map((l) => l.kind), [ContactLinkKind.email, ContactLinkKind.phone]);
    expect(links[0].uri.toString(), 'mailto:hiccnyc@gmail.com');
    expect(links[1].uri.toString(), 'tel:+13322230579');
    expect(links[1].label, '+1 332-223-0579');
  });

  test('numéro sénégalais sans indicatif', () {
    final links = extractContactLinks('Appeler le 77 123 45 67');
    expect(links.single.uri.toString(), 'tel:771234567');
  });

  test('ni année, ni numéro de rue, ni texte sans contact', () {
    expect(extractContactLinks('Fondée en 1902, 108 East 128th Street'), isEmpty);
    expect(extractContactLinks('Se renseigner sur place'), isEmpty);
  });
}
