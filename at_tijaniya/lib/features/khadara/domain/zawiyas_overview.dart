/// Logique de l'écran Zawiyas refait d'après sa maquette
/// (`docs/maquettes/ecran-zawiyas.html`, décisions validées du 2026-11-01 et
/// du 2026-11-03) : groupes de lieux par pays, points de la carte
/// schématique, classement « Près de moi », frise de l'Agenda par mois et
/// compte à rebours. Logique pure, sans Flutter ni Supabase, testée dans
/// `test/zawiyas_overview_test.dart` — même esprit que `wird_overview.dart`.
library;

import 'khadara_models.dart';
import 'zawiya_countries.dart';

/// Lieux d'un même pays. [countryCode] `null` : pays non renseigné (lieu
/// créé avant la colonne, ou par une ancienne version du formulaire).
class CountryGroup {
  const CountryGroup(this.countryCode, this.places);

  final String? countryCode;
  final List<Zawiya> places;
}

/// Groupes de l'annuaire : du pays le plus fourni au moins fourni (le Sénégal
/// d'abord, comme dans la maquette), à égalité dans l'ordre du nom du pays
/// dans la langue de l'interface ; « pays non renseigné » toujours en
/// dernier. Les lieux gardent l'ordre reçu (alphabétique, celui de la
/// requête).
List<CountryGroup> groupPlacesByCountry(List<Zawiya> places, String languageCode) {
  final byCode = <String?, List<Zawiya>>{};
  for (final place in places) {
    byCode.putIfAbsent(place.country, () => []).add(place);
  }
  final groups = [for (final entry in byCode.entries) CountryGroup(entry.key, entry.value)];
  groups.sort((a, b) {
    if (a.countryCode == null) return 1;
    if (b.countryCode == null) return -1;
    final bySize = b.places.length.compareTo(a.places.length);
    if (bySize != 0) return bySize;
    return zawiyaCountryName(a.countryCode!, languageCode).compareTo(zawiyaCountryName(b.countryCode!, languageCode));
  });
  return groups;
}

/// Un point de la carte : un pays et son nombre de lieux.
class CountryPoint {
  const CountryPoint(this.country, this.count);

  final ZawiyaCountry country;
  final int count;
}

/// Points de la carte : tous les lieux comptent, y compris ceux sans
/// coordonnées (le point est placé à la position fixe du pays, voir
/// `zawiya_countries.dart`). Un code absent de la liste des pays n'a pas de
/// position et n'est pas dessiné ; ses lieux restent dans la liste.
/// [outside] : pays hors du cadre de la carte (New York), cités à part.
({List<CountryPoint> inside, List<CountryPoint> outside}) countryPoints(List<Zawiya> places) {
  final counts = <String, int>{};
  for (final place in places) {
    final code = place.country;
    if (code != null) counts[code] = (counts[code] ?? 0) + 1;
  }
  final inside = <CountryPoint>[];
  final outside = <CountryPoint>[];
  for (final entry in counts.entries) {
    final country = zawiyaCountryByCode(entry.key);
    if (country == null) continue;
    (SchematicMapFrame.contains(country) ? inside : outside).add(CountryPoint(country, entry.value));
  }
  // Les plus gros points d'abord : dessinés en premier, ils passent sous les
  // petits, qui restent touchables quand deux pays sont proches.
  inside.sort((a, b) => b.count.compareTo(a.count));
  outside.sort((a, b) => b.count.compareTo(a.count));
  return (inside: inside, outside: outside);
}

/// Nombre de pays distincts renseignés (légende « La Tariqa · 12 pays »).
int countryCount(List<Zawiya> places) => {for (final place in places) place.country}.whereType<String>().length;

/// Un lieu et sa distance à la position du disciple.
class PlaceDistance {
  const PlaceDistance(this.place, this.distanceKm);

  final Zawiya place;
  final double distanceKm;
}

/// « Près de moi » : les lieux qui ont des coordonnées, du plus proche au
/// plus lointain. Les autres ne peuvent pas être classés ; l'écran dit
/// combien ils sont ([unlocatedCount]), plutôt que de les faire disparaître
/// sans explication.
({List<PlaceDistance> sorted, int unlocatedCount}) sortPlacesByDistance(
  List<Zawiya> places, {
  required double latitude,
  required double longitude,
}) {
  final sorted = <PlaceDistance>[];
  var unlocated = 0;
  for (final place in places) {
    if (!place.hasLocation) {
      unlocated++;
      continue;
    }
    sorted.add(PlaceDistance(
      place,
      distanceInKm(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: place.latitude!,
        toLongitude: place.longitude!,
      ),
    ));
  }
  sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return (sorted: sorted, unlocatedCount: unlocated);
}

/// Date affichée d'un rendez-vous : la prochaine occurrence pour un
/// évènement récurrent (hebdomadaire), sa date sinon — la même règle que la
/// fiche d'un évènement.
DateTime displayDateOf(KhadaraEvent event, DateTime now) =>
    event.isRecurring ? (nextOccurrence(event, from: now) ?? event.startsAt) : event.startsAt;

/// Jours de calendrier entre aujourd'hui et [date] (0 = aujourd'hui), comptés
/// en UTC : en heure locale, un passage à l'heure d'été retirait une heure
/// et `inDays` perdait un jour (même calcul que la fiche d'un évènement).
int calendarDaysUntil(DateTime date, DateTime now) =>
    DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

/// Un mois de la frise de l'Agenda.
class AgendaMonth {
  const AgendaMonth(this.year, this.month, this.events);

  final int year;
  final int month;
  final List<KhadaraEvent> events;
}

/// Rendez-vous groupés par mois, dans l'ordre reçu (déjà trié par prochaine
/// occurrence, `sortByNextOccurrence`). Un mois n'apparaît que s'il a au
/// moins un rendez-vous.
List<AgendaMonth> groupEventsByMonth(List<KhadaraEvent> events, DateTime now) {
  final months = <AgendaMonth>[];
  for (final event in events) {
    final date = displayDateOf(event, now);
    if (months.isEmpty || months.last.year != date.year || months.last.month != date.month) {
      months.add(AgendaMonth(date.year, date.month, []));
    }
    months.last.events.add(event);
  }
  return months;
}

/// Ce qu'une carte de lieu dit de lui-même : rendez-vous à venir, longueur de
/// sa succession et nombre de figures liées. Les deux derniers ne comptent
/// que ce que la RLS laisse lire (figures publiées, sauf pour l'admin), comme
/// la fiche du lieu.
class PlaceFacts {
  const PlaceFacts({this.upcoming = 0, this.succession = 0, this.figures = 0});

  final int upcoming;
  final int succession;
  final int figures;

  bool get isEmpty => upcoming == 0 && succession == 0 && figures == 0;
}

/// Successions et figures liées, comptées par lieu (`fetchZawiyaLinkCounts`).
class ZawiyaLinkCounts {
  const ZawiyaLinkCounts({this.succession = const {}, this.figures = const {}});

  final Map<String, int> succession;
  final Map<String, int> figures;
}

/// Faits d'un lieu à partir des rendez-vous chargés et des comptes de liens.
PlaceFacts placeFacts(String placeId, List<KhadaraEvent> events, ZawiyaLinkCounts counts) {
  return PlaceFacts(
    upcoming: events.where((e) => e.zawiyaId == placeId).length,
    succession: counts.succession[placeId] ?? 0,
    figures: counts.figures[placeId] ?? 0,
  );
}

/// Nombre de lieux de chaque type, pour les puces de filtre (« Zawiyas ·
/// 27 »).
Map<ZawiyaKind, int> countByKind(List<Zawiya> places) {
  final counts = {for (final kind in ZawiyaKind.values) kind: 0};
  for (final place in places) {
    counts[place.kind] = counts[place.kind]! + 1;
  }
  return counts;
}
