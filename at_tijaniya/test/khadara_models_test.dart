import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';

void main() {
  group('Zawiya.fromRow', () {
    test('parse une ligne complète', () {
      final zawiya = Zawiya.fromRow({
        'id': 'z1',
        'name': 'Zawiya Test',
        'description': 'Description',
        'latitude': 14.6,
        'longitude': -17.4,
        'address_text': 'Adresse test',
        'contact_info': '+221 00 000 00 00',
      });
      expect(zawiya.id, 'z1');
      expect(zawiya.name, 'Zawiya Test');
      expect(zawiya.latitude, 14.6);
      expect(zawiya.hasLocation, isTrue);
    });

    test('gère les champs optionnels absents', () {
      final zawiya = Zawiya.fromRow({'id': 'z2', 'name': 'Zawiya Minimale'});
      expect(zawiya.description, isNull);
      expect(zawiya.hasLocation, isFalse);
    });
  });

  group('KhadaraEvent.fromRow', () {
    test('résout le nom de la zawiya via la relation embarquée', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e1',
        'zawiya_id': 'z1',
        'title': 'Hadra du vendredi',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'zawiyas': {'name': 'Zawiya Test'},
      });
      expect(event.zawiyaName, 'Zawiya Test');
      expect(event.type, KhadaraEventType.hadra);
    });

    test('event_type inconnu retombe sur "other"', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e2',
        'title': 'Évènement',
        'event_type': 'quelque-chose-d-inattendu',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(event.type, KhadaraEventType.other);
      expect(event.zawiyaName, isNull);
    });

    test('hasLocation reflète la présence des coordonnées', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3',
        'title': 'Ziyara',
        'event_type': 'ziyara',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'latitude': 14.7,
        'longitude': -17.5,
      });
      expect(event.hasLocation, isTrue);
    });
  });
}
