/// Pays des lieux de l'annuaire (`zawiyas.country`, code ISO 3166-1 alpha-2,
/// migration `2026-11-03_zawiyas_country.sql`, validée par le porteur de
/// projet le 2026-11-03).
///
/// La base ne stocke que le code : le nom affiché vient d'ici, en français et
/// en arabe, pour que l'annuaire se lise dans la langue de l'interface (un nom
/// en texte libre ne se traduisait pas et variait d'une saisie à l'autre).
///
/// Ce sont des données géographiques, pas du contenu religieux. La liste
/// couvre les 12 pays présents en base au 2026-11-03 et quelques voisins ou
/// pays de la diaspora, proposés dans le formulaire d'un lieu ; un code
/// inconnu (saisi en SQL) reste affiché tel quel plutôt que de disparaître.
///
/// [mapLatitude]/[mapLongitude] : position du point du pays sur la carte
/// schématique de l'écran Zawiyas. Une position fixe par pays, et non la
/// moyenne des lieux : 6 lieux sur 34 n'ont pas de coordonnées (le Niger et le
/// Burkina Faso n'en ont aucune), et leur pays doit quand même apparaître.
/// Positions reprises de la maquette `docs/maquettes/ecran-zawiyas.html` pour
/// les pays qu'elle montre, centre approximatif du pays ou de sa capitale
/// pour les autres.
library;

class ZawiyaCountry {
  const ZawiyaCountry(this.code, this.nameFr, this.nameAr, this.mapLatitude, this.mapLongitude);

  final String code;
  final String nameFr;
  final String nameAr;
  final double mapLatitude;
  final double mapLongitude;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameFr;
}

/// Ordre du formulaire : l'Afrique de l'Ouest d'abord (la plupart des lieux),
/// puis le Maghreb et l'Égypte, puis le reste du monde.
const zawiyaCountries = <ZawiyaCountry>[
  ZawiyaCountry('SN', 'Sénégal', 'السنغال', 14.8, -16.0),
  ZawiyaCountry('ML', 'Mali', 'مالي', 14.3, -8.0),
  ZawiyaCountry('MR', 'Mauritanie', 'موريتانيا', 19.5, -11.0),
  ZawiyaCountry('GM', 'Gambie', 'غامبيا', 13.45, -15.4),
  ZawiyaCountry('GN', 'Guinée', 'غينيا', 11.3, -10.7),
  ZawiyaCountry('GW', 'Guinée-Bissau', 'غينيا بيساو', 12.0, -15.0),
  ZawiyaCountry('SL', 'Sierra Leone', 'سيراليون', 8.5, -11.8),
  ZawiyaCountry('LR', 'Liberia', 'ليبيريا', 6.4, -9.4),
  ZawiyaCountry('CI', "Côte d'Ivoire", 'ساحل العاج', 7.5, -5.5),
  ZawiyaCountry('BF', 'Burkina Faso', 'بوركينا فاسو', 13.8, -1.6),
  ZawiyaCountry('GH', 'Ghana', 'غانا', 8.0, -0.9),
  ZawiyaCountry('TG', 'Togo', 'توغو', 8.6, 1.1),
  ZawiyaCountry('BJ', 'Bénin', 'بنين', 9.6, 2.3),
  ZawiyaCountry('NE', 'Niger', 'النيجر', 13.4, 2.9),
  ZawiyaCountry('NG', 'Nigeria', 'نيجيريا', 12.0, 8.5),
  ZawiyaCountry('TD', 'Tchad', 'تشاد', 13.0, 18.7),
  ZawiyaCountry('CM', 'Cameroun', 'الكاميرون', 6.0, 12.4),
  ZawiyaCountry('SD', 'Soudan', 'السودان', 15.6, 30.0),
  ZawiyaCountry('MA', 'Maroc', 'المغرب', 34.0, -5.9),
  ZawiyaCountry('DZ', 'Algérie', 'الجزائر', 33.2, 2.7),
  ZawiyaCountry('TN', 'Tunisie', 'تونس', 36.8, 10.2),
  ZawiyaCountry('LY', 'Libye', 'ليبيا', 30.0, 15.0),
  ZawiyaCountry('EG', 'Égypte', 'مصر', 30.0, 31.3),
  ZawiyaCountry('SA', 'Arabie saoudite', 'السعودية', 23.9, 45.1),
  ZawiyaCountry('FR', 'France', 'فرنسا', 46.6, 2.4),
  ZawiyaCountry('ES', 'Espagne', 'إسبانيا', 40.4, -3.7),
  ZawiyaCountry('IT', 'Italie', 'إيطاليا', 42.5, 12.5),
  ZawiyaCountry('GB', 'Royaume-Uni', 'المملكة المتحدة', 52.5, -1.5),
  ZawiyaCountry('US', 'États-Unis', 'الولايات المتحدة', 40.8, -73.9),
  ZawiyaCountry('CA', 'Canada', 'كندا', 45.5, -73.6),
];

final _byCode = {for (final country in zawiyaCountries) country.code: country};

ZawiyaCountry? zawiyaCountryByCode(String? code) => code == null ? null : _byCode[code];

/// Nom du pays dans la langue de l'interface ; le code brut pour un pays
/// absent de la liste (jamais une chaîne vide).
String zawiyaCountryName(String code, String languageCode) => _byCode[code]?.name(languageCode) ?? code;

/// Cadre de la carte schématique (Afrique de l'Ouest, Maghreb, Égypte), le
/// même que la maquette. Un pays hors de ce cadre (États-Unis, France...) est
/// cité à part sous la carte, plutôt que d'élargir le dessin au point que le
/// Sénégal et ses voisins se confondent.
class SchematicMapFrame {
  static const minLongitude = -20.0;
  static const maxLongitude = 34.0;
  static const minLatitude = 4.0;
  static const maxLatitude = 40.0;

  static bool contains(ZawiyaCountry country) =>
      country.mapLongitude >= minLongitude &&
      country.mapLongitude <= maxLongitude &&
      country.mapLatitude >= minLatitude &&
      country.mapLatitude <= maxLatitude;
}
