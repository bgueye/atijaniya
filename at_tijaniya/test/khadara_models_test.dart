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

    test('parse address_text quand présent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3b',
        'title': 'Hadra',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'address_text': 'Quartier Médina, Dakar',
      });
      expect(event.addressText, 'Quartier Médina, Dakar');
    });

    test('hasMapsTarget est vrai avec des coordonnées mais sans adresse', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3c',
        'title': 'Ziyara',
        'event_type': 'ziyara',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'latitude': 14.7,
        'longitude': -17.5,
      });
      expect(event.hasMapsTarget, isTrue);
    });

    test('hasMapsTarget est vrai avec une adresse mais sans coordonnées', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3d',
        'title': 'Gamou',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'address_text': 'Quartier Médina, Dakar',
      });
      expect(event.hasMapsTarget, isTrue);
    });

    test('hasMapsTarget est faux sans adresse ni coordonnées', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3e',
        'title': 'Évènement',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(event.hasMapsTarget, isFalse);
    });

    test('hasMapsTarget est faux si address_text est une chaîne vide', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e3f',
        'title': 'Évènement',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'address_text': '   ',
      });
      expect(event.hasMapsTarget, isFalse);
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

  group('KhadaraEvent.fromRow — récurrence', () {
    test('parse les champs de récurrence quand présents', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e8',
        'title': 'Hadratou-l-Jouma',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 30,
        'recurrence_until': '2027-01-01',
      });
      expect(event.isRecurring, isTrue);
      expect(event.recurrenceDayOfWeek, 5);
      expect(event.recurrenceHour, 14);
      expect(event.recurrenceMinute, 30);
      expect(event.recurrenceUntil, DateTime(2027, 1, 1));
    });

    test('isRecurring retombe sur false quand absent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e9',
        'title': 'Gamou',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(event.isRecurring, isFalse);
      expect(event.recurrenceDayOfWeek, isNull);
    });
  });

  group('computeNextWeeklyOccurrence', () {
    test('avance jusqu\'au prochain jour de semaine demandé', () {
      // Lundi 2026-08-03 -> prochain vendredi = 2026-08-07.
      final from = DateTime(2026, 8, 3, 9);
      final next = computeNextWeeklyOccurrence(dayOfWeek: DateTime.friday, hour: 14, minute: 0, from: from);
      expect(next, DateTime(2026, 8, 7, 14, 0));
    });

    test('reste le jour même si l\'heure est encore à venir', () {
      // Vendredi 2026-08-07 à 9h -> occurrence du jour même à 14h.
      final from = DateTime(2026, 8, 7, 9);
      final next = computeNextWeeklyOccurrence(dayOfWeek: DateTime.friday, hour: 14, minute: 0, from: from);
      expect(next, DateTime(2026, 8, 7, 14, 0));
    });

    test('passe à la semaine suivante si l\'heure du jour même est dépassée', () {
      // Vendredi 2026-08-07 à 15h -> occurrence reportée au 2026-08-14.
      final from = DateTime(2026, 8, 7, 15);
      final next = computeNextWeeklyOccurrence(dayOfWeek: DateTime.friday, hour: 14, minute: 0, from: from);
      expect(next, DateTime(2026, 8, 14, 14, 0));
    });

    test('renvoie null si la récurrence est terminée', () {
      final from = DateTime(2026, 8, 3, 9);
      final next = computeNextWeeklyOccurrence(
        dayOfWeek: DateTime.friday,
        hour: 14,
        minute: 0,
        from: from,
        until: DateTime(2026, 8, 1),
      );
      expect(next, isNull);
    });

    test('accepte encore le dernier jour de récurrence (until inclusif)', () {
      final from = DateTime(2026, 8, 3, 9);
      final next = computeNextWeeklyOccurrence(
        dayOfWeek: DateTime.friday,
        hour: 14,
        minute: 0,
        from: from,
        until: DateTime(2026, 8, 7),
      );
      expect(next, DateTime(2026, 8, 7, 14, 0));
    });
  });

  group('nextOccurrence', () {
    test('null pour un évènement non récurrent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e10',
        'title': 'Ziyara',
        'event_type': 'ziyara',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      expect(nextOccurrence(event, from: DateTime(2026, 8, 3)), isNull);
    });

    test('calcule la prochaine occurrence pour un évènement récurrent', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e11',
        'title': 'Hadratou-l-Jouma',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 0,
      });
      expect(nextOccurrence(event, from: DateTime(2026, 8, 3, 9)), DateTime(2026, 8, 7, 14, 0));
    });
  });

  group('sortByNextOccurrence', () {
    test('trie un évènement récurrent proche avant un évènement classique lointain', () {
      final from = DateTime(2026, 8, 3, 9);
      final classique = KhadaraEvent.fromRow({
        'id': 'e12',
        'title': 'Gamou annuel',
        'event_type': 'other',
        'starts_at': '2026-09-01T10:00:00.000Z',
      });
      final recurrent = KhadaraEvent.fromRow({
        'id': 'e13',
        'title': 'Hadratou-l-Jouma',
        'event_type': 'hadra',
        // starts_at (première occurrence de référence) très ancien —
        // ne doit pas faire remonter l'évènement en tête du tri.
        'starts_at': '2020-01-03T14:00:00.000Z',
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 0,
      });

      final sorted = sortByNextOccurrence([classique, recurrent], from: from);
      expect(sorted.map((e) => e.id).toList(), ['e13', 'e12']);
    });

    test('repousse en fin de liste un évènement récurrent dont la récurrence est terminée', () {
      final from = DateTime(2026, 8, 3, 9);
      final classique = KhadaraEvent.fromRow({
        'id': 'e14',
        'title': 'Gamou',
        'event_type': 'other',
        'starts_at': '2026-09-01T10:00:00.000Z',
      });
      final recurrentTermine = KhadaraEvent.fromRow({
        'id': 'e15',
        'title': 'Ancienne Hadra',
        'event_type': 'hadra',
        'starts_at': '2020-01-03T14:00:00.000Z',
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 0,
        'recurrence_until': '2020-02-01',
      });

      final sorted = sortByNextOccurrence([recurrentTermine, classique], from: from);
      expect(sorted.map((e) => e.id).toList(), ['e14', 'e15']);
    });
  });

  group('distanceInKm', () {
    test('distance nulle entre deux points identiques', () {
      expect(distanceInKm(fromLatitude: 14.6, fromLongitude: -17.4, toLatitude: 14.6, toLongitude: -17.4), 0);
    });

    test('distance approximative Dakar–Thiès (~65 km à vol d\'oiseau)', () {
      final km = distanceInKm(fromLatitude: 14.7167, fromLongitude: -17.4677, toLatitude: 14.7910, toLongitude: -16.9359);
      expect(km, greaterThan(50));
      expect(km, lessThan(80));
    });
  });

  group('findNearbyRecurringEvents', () {
    const userLat = 14.7167;
    const userLon = -17.4677;

    final zawiyaProche = Zawiya.fromRow({
      'id': 'z1',
      'name': 'Zawiya proche',
      'latitude': 14.72,
      'longitude': -17.47,
    });
    final zawiyaLointaine = Zawiya.fromRow({
      'id': 'z2',
      'name': 'Zawiya lointaine',
      'latitude': 14.79,
      'longitude': -16.94,
    });
    final zawiyaSansCoordonnees = Zawiya.fromRow({'id': 'z3', 'name': 'Zawiya sans coordonnées'});

    KhadaraEvent recurringEvent(String id, String zawiyaId) => KhadaraEvent.fromRow({
          'id': id,
          'zawiya_id': zawiyaId,
          'title': 'Hadratou-l-Jouma',
          'event_type': 'hadra',
          'starts_at': '2026-08-07T14:00:00.000Z',
          'is_recurring': true,
          'recurrence_day_of_week': 5,
          'recurrence_hour': 14,
          'recurrence_minute': 0,
        });

    test('trie les évènements récurrents par distance croissante', () {
      final results = findNearbyRecurringEvents(
        events: [recurringEvent('e1', 'z2'), recurringEvent('e2', 'z1')],
        zawiyas: [zawiyaProche, zawiyaLointaine],
        userLatitude: userLat,
        userLongitude: userLon,
      );
      expect(results.map((r) => r.event.id).toList(), ['e2', 'e1']);
      expect(results.first.distanceKm, lessThan(results.last.distanceKm));
    });

    test('exclut un évènement non récurrent', () {
      final classique = KhadaraEvent.fromRow({
        'id': 'e3',
        'zawiya_id': 'z1',
        'title': 'Gamou',
        'event_type': 'other',
        'starts_at': '2026-08-07T14:00:00.000Z',
      });
      final results = findNearbyRecurringEvents(
        events: [classique],
        zawiyas: [zawiyaProche],
        userLatitude: userLat,
        userLongitude: userLon,
      );
      expect(results, isEmpty);
    });

    test('exclut un évènement récurrent sans zawiya liée', () {
      final event = KhadaraEvent.fromRow({
        'id': 'e4',
        'title': 'Hadratou-l-Jouma',
        'event_type': 'hadra',
        'starts_at': '2026-08-07T14:00:00.000Z',
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 0,
      });
      final results = findNearbyRecurringEvents(
        events: [event],
        zawiyas: [zawiyaProche],
        userLatitude: userLat,
        userLongitude: userLon,
      );
      expect(results, isEmpty);
    });

    test('exclut un évènement récurrent dont la zawiya n\'a pas de coordonnées', () {
      final results = findNearbyRecurringEvents(
        events: [recurringEvent('e5', 'z3')],
        zawiyas: [zawiyaSansCoordonnees],
        userLatitude: userLat,
        userLongitude: userLon,
      );
      expect(results, isEmpty);
    });
  });

  group('canManageEvent', () {
    final event = KhadaraEvent.fromRow({
      'id': 'e6',
      'title': 'Hadra',
      'event_type': 'hadra',
      'starts_at': '2026-08-07T14:00:00.000Z',
      'created_by': 'u1',
      'zawiya_id': 'z1',
    });

    test('un admin peut toujours gérer', () {
      expect(canManageEvent(event, userId: 'other', isAdmin: true, managedZawiyaId: null), isTrue);
    });

    test("l'auteur peut gérer son évènement tant qu'il gère cette zawiya", () {
      expect(canManageEvent(event, userId: 'u1', isAdmin: false, managedZawiyaId: 'z1'), isTrue);
    });

    test("l'auteur sans zawiya attribuée (révoqué, ou jamais attribuée) ne peut plus gérer", () {
      expect(canManageEvent(event, userId: 'u1', isAdmin: false, managedZawiyaId: null), isFalse);
    });

    test("l'auteur ne peut plus gérer un évènement d'une zawiya qui n'est plus la sienne", () {
      expect(canManageEvent(event, userId: 'u1', isAdmin: false, managedZawiyaId: 'z2'), isFalse);
    });

    test('un non-auteur non-admin ne peut pas gérer', () {
      expect(canManageEvent(event, userId: 'other', isAdmin: false, managedZawiyaId: 'z1'), isFalse);
    });

    test('un invité (userId null) ne peut pas gérer', () {
      expect(canManageEvent(event, userId: null, isAdmin: false, managedZawiyaId: null), isFalse);
    });
  });

  // Type de lieu (`zawiyas.kind`, migration `add_kind_to_zawiyas`, 2026-10-01).
  group('ZawiyaKind', () {
    test('aller-retour base <-> enum sur les trois types', () {
      for (final kind in ZawiyaKind.values) {
        expect(zawiyaKindFromDb(zawiyaKindToDb(kind)), kind);
      }
      expect(zawiyaKindToDb(ZawiyaKind.holyPlace), 'lieu_saint');
      expect(zawiyaKindToDb(ZawiyaKind.mosque), 'mosquee');
    });

    test('valeur inconnue ou absente -> zawiya', () {
      expect(zawiyaKindFromDb('autre'), ZawiyaKind.zawiya);
      expect(zawiyaKindFromDb(null), ZawiyaKind.zawiya);
    });

    test('Zawiya.fromRow lit la colonne kind, zawiya par défaut si absente', () {
      expect(Zawiya.fromRow({'id': 'z1', 'name': 'Lieu', 'kind': 'lieu_saint'}).kind, ZawiyaKind.holyPlace);
      expect(Zawiya.fromRow({'id': 'z2', 'name': 'Sans type'}).kind, ZawiyaKind.zawiya);
    });

    test('attachableZawiyas ne garde que les zawiyas, dans l\'ordre d\'origine', () {
      const places = [
        Zawiya(id: 'a', name: 'Zawiya A'),
        Zawiya(id: 'b', name: 'Village natal', kind: ZawiyaKind.holyPlace),
        Zawiya(id: 'c', name: 'Mosquée', kind: ZawiyaKind.mosque),
        Zawiya(id: 'd', name: 'Zawiya D'),
      ];
      expect(attachableZawiyas(places).map((z) => z.id), ['a', 'd']);
    });
  });

  // Date approximative (`events.is_date_approximate`/`date_note`, migration
  // `add_approximate_date_to_events`, 2026-10-01).
  group('KhadaraEvent — date approximative', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 'e1',
          'title': 'Évènement de test',
          'event_type': 'ziyara',
          'starts_at': '2027-03-06T10:00:00Z',
          ...extra,
        };

    test('colonnes absentes -> date exacte, pas de précision', () {
      final event = KhadaraEvent.fromRow(row({}));
      expect(event.isDateApproximate, isFalse);
      expect(event.showsApproximateDate, isFalse);
      expect(event.dateNote, isNull);
    });

    test('lit le drapeau et la précision', () {
      final event = KhadaraEvent.fromRow(row({'is_date_approximate': true, 'date_note': 'Selon la lune'}));
      expect(event.showsApproximateDate, isTrue);
      expect(event.dateNote, 'Selon la lune');
    });

    test('drapeau ignoré pour un évènement récurrent', () {
      final event = KhadaraEvent.fromRow(row({
        'is_date_approximate': true,
        'is_recurring': true,
        'recurrence_day_of_week': 5,
        'recurrence_hour': 14,
        'recurrence_minute': 0,
      }));
      expect(event.isDateApproximate, isTrue);
      expect(event.showsApproximateDate, isFalse);
    });
  });
}
