// Logique de l'écran Zawiyas refait (2026-11-03) : pays, groupes, points de la
// carte schématique, « Près de moi », frise de l'Agenda et faits d'un lieu.
// Logique pure (`zawiyas_overview.dart`, `zawiya_countries.dart`).

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/domain/zawiya_countries.dart';
import 'package:at_tijaniya/features/khadara/domain/zawiyas_overview.dart';

Zawiya _place(String id, {String? country, double? lat, double? lon, ZawiyaKind kind = ZawiyaKind.zawiya}) =>
    Zawiya(id: id, name: 'Lieu $id', country: country, latitude: lat, longitude: lon, kind: kind);

KhadaraEvent _event(String id, DateTime date, {String? zawiyaId}) => KhadaraEvent(
      id: id,
      zawiyaId: zawiyaId,
      title: 'Rendez-vous $id',
      type: KhadaraEventType.ziyara,
      startsAt: date,
    );

void main() {
  // Ligne de la base : la colonne `country` (migration du 2026-11-03) est
  // lue, et son absence (réponse d'avant la migration) laisse le pays non
  // renseigné.
  test('Zawiya.fromRow lit le pays', () {
    expect(Zawiya.fromRow({'id': 'a', 'name': 'A', 'country': 'SN'}).country, 'SN');
    expect(Zawiya.fromRow({'id': 'a', 'name': 'A'}).country, isNull);
  });

  group('pays', () {
    test('les 12 pays présents en base ont un nom français et arabe, et un code ISO valide', () {
      for (final code in ['SN', 'ML', 'DZ', 'MA', 'GN', 'NE', 'NG', 'GH', 'BF', 'TN', 'EG', 'US']) {
        final country = zawiyaCountryByCode(code);
        expect(country, isNotNull, reason: code);
        expect(country!.nameFr, isNotEmpty);
        expect(country.nameAr, isNotEmpty);
      }
      // Même contrainte que la base (`zawiyas_country_iso_check`).
      for (final country in zawiyaCountries) {
        expect(RegExp(r'^[A-Z]{2}$').hasMatch(country.code), isTrue, reason: country.code);
      }
      expect({for (final c in zawiyaCountries) c.code}.length, zawiyaCountries.length);
    });

    test('nom traduit, ou le code brut pour un pays absent de la liste', () {
      expect(zawiyaCountryName('SN', 'fr'), 'Sénégal');
      expect(zawiyaCountryName('SN', 'ar'), 'السنغال');
      expect(zawiyaCountryName('XK', 'fr'), 'XK');
    });

    test('cadre de la carte : l\'Afrique de l\'Ouest et le Maghreb dedans, New York dehors', () {
      expect(SchematicMapFrame.contains(zawiyaCountryByCode('SN')!), isTrue);
      expect(SchematicMapFrame.contains(zawiyaCountryByCode('EG')!), isTrue);
      expect(SchematicMapFrame.contains(zawiyaCountryByCode('US')!), isFalse);
    });
  });

  group('groupes par pays', () {
    test('du plus fourni au moins fourni, à égalité par nom, « non renseigné » en dernier', () {
      final groups = groupPlacesByCountry([
        _place('1'),
        _place('2', country: 'ML'),
        _place('3', country: 'SN'),
        _place('4', country: 'SN'),
        _place('5', country: 'DZ'),
      ], 'fr');
      expect(groups.map((g) => g.countryCode), ['SN', 'DZ', 'ML', null]);
      expect(groups.first.places.map((p) => p.id), ['3', '4']);
    });

    test('l\'égalité se départage dans la langue de l\'interface', () {
      // Algérie avant Mali en français ; en arabe, « الجزائر » avant « مالي ».
      final places = [_place('1', country: 'ML'), _place('2', country: 'DZ')];
      expect(groupPlacesByCountry(places, 'fr').map((g) => g.countryCode), ['DZ', 'ML']);
      expect(groupPlacesByCountry(places, 'ar').map((g) => g.countryCode), ['DZ', 'ML']);
    });
  });

  group('points de la carte', () {
    test('un point par pays avec tous ses lieux, y compris sans coordonnées ; hors cadre à part', () {
      final points = countryPoints([
        _place('1', country: 'SN', lat: 14.9, lon: -16.8),
        _place('2', country: 'SN'),
        _place('3', country: 'NE'),
        _place('4', country: 'US', lat: 40.8, lon: -73.9),
        _place('5'),
        _place('6', country: 'XK'),
      ]);
      expect(points.inside.map((p) => (p.country.code, p.count)), [('SN', 2), ('NE', 1)]);
      expect(points.outside.map((p) => p.country.code), ['US']);
    });

    test('nombre de pays renseignés', () {
      expect(countryCount([_place('1', country: 'SN'), _place('2', country: 'SN'), _place('3')]), 1);
    });
  });

  group('Près de moi', () {
    test('lieux localisés du plus proche au plus lointain, les autres comptés', () {
      final result = sortPlacesByDistance([
        _place('segou', lat: 13.43, lon: -6.22),
        _place('sans'),
        _place('kaolack', lat: 14.15, lon: -16.07),
      ], latitude: 14.69, longitude: -17.44);
      expect(result.sorted.map((p) => p.place.id), ['kaolack', 'segou']);
      expect(result.sorted.first.distanceKm, inInclusiveRange(150, 170));
      expect(result.unlocatedCount, 1);
    });
  });

  group('Agenda', () {
    test('compte à rebours en jours de calendrier', () {
      final now = DateTime(2026, 11, 3, 23, 30);
      expect(calendarDaysUntil(DateTime(2026, 11, 3, 8), now), 0);
      expect(calendarDaysUntil(DateTime(2026, 11, 4, 0, 5), now), 1);
      expect(calendarDaysUntil(DateTime(2026, 12, 25), now), 52);
    });

    test('rendez-vous groupés par mois, dans l\'ordre reçu', () {
      final now = DateTime(2026, 11, 3);
      final months = groupEventsByMonth([
        _event('a', DateTime(2026, 12, 25)),
        _event('b', DateTime(2027, 1, 8)),
        _event('c', DateTime(2027, 1, 22)),
      ], now);
      expect(months.map((m) => (m.year, m.month, m.events.length)), [(2026, 12, 1), (2027, 1, 2)]);
    });

    test('un évènement récurrent est rangé au mois de sa prochaine occurrence', () {
      final now = DateTime(2026, 11, 3, 10); // un mardi
      final weekly = KhadaraEvent(
        id: 'jouma',
        title: 'Hadratou-l-Jouma',
        type: KhadaraEventType.hadra,
        startsAt: DateTime(2025, 1, 3, 17),
        isRecurring: true,
        recurrenceDayOfWeek: DateTime.friday,
        recurrenceHour: 17,
        recurrenceMinute: 0,
      );
      expect(displayDateOf(weekly, now), DateTime(2026, 11, 6, 17));
      expect(groupEventsByMonth([weekly], now).single.month, 11);
    });
  });

  group('faits d\'un lieu', () {
    test('rendez-vous, succession et figures du lieu', () {
      final events = [
        _event('a', DateTime(2026, 12, 1), zawiyaId: 'tiv'),
        _event('b', DateTime(2027, 4, 4), zawiyaId: 'tiv'),
        _event('c', DateTime(2027, 4, 4), zawiyaId: 'autre'),
      ];
      const counts = ZawiyaLinkCounts(succession: {'tiv': 7}, figures: {'tiv': 8});
      final facts = placeFacts('tiv', events, counts);
      expect((facts.upcoming, facts.succession, facts.figures), (2, 7, 8));
      expect(placeFacts('vide', events, counts).isEmpty, isTrue);
    });

    test('nombre de lieux par type', () {
      final counts = countByKind([
        _place('1'),
        _place('2', kind: ZawiyaKind.holyPlace),
        _place('3'),
      ]);
      expect(counts, {ZawiyaKind.zawiya: 2, ZawiyaKind.holyPlace: 1, ZawiyaKind.mosque: 0});
    });
  });
}
