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

    test('parse created_by quand présent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e4',
        'title': 'Gamou',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'created_by': 'u1',
      });
      expect(event.createdBy, 'u1');
    });

    test('createdBy est null quand absent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e5',
        'title': 'Évènement',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(event.createdBy, isNull);
    });

    test('parse image_url quand présent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e6',
        'title': 'Évènement illustré',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'image_url': 'https://example.com/event-images/e6/cover.jpg',
      });
      expect(event.imageUrl, 'https://example.com/event-images/e6/cover.jpg');
    });

    test('imageUrl est null quand absent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e7',
        'title': 'Évènement sans image',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(event.imageUrl, isNull);
    });
  });

  group('canManageEvent', () {
    final event = KhadaraEvent.fromRow({
      'id': 'e6',
      'title': 'Hadra',
      'event_type': 'hadra',
      'starts_at': '2026-08-07T14:00:00.000Z',
      'created_by': 'u1',
    });

    test('un admin peut toujours gérer', () {
      expect(canManageEvent(event, userId: 'other', isAdmin: true), isTrue);
    });

    test("l'auteur peut gérer son propre évènement", () {
      expect(canManageEvent(event, userId: 'u1', isAdmin: false), isTrue);
    });

    test('un non-auteur non-admin ne peut pas gérer', () {
      expect(canManageEvent(event, userId: 'other', isAdmin: false), isFalse);
    });

    test('un invité (userId null) ne peut pas gérer', () {
      expect(canManageEvent(event, userId: null, isAdmin: false), isFalse);
    });
  });
}
