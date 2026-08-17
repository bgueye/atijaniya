/// Conversion grégorien → hégirien approximative (calendrier tabulaire dit
/// "koweïtien", algorithme arithmétique standard sans observation lunaire
/// réelle) — utilisée uniquement pour l'indication de date affichée en
/// en-tête de l'accueil (`home_screen.dart`), jamais pour déterminer un
/// horaire de pratique ou une date d'évènement religieux (Ramadan, Eid...),
/// qui restent définis par une source humaine (calendrier Khadara en base,
/// annonce officielle) et non par un calcul.
///
/// Résultat volontairement approximatif (± 1 jour possible selon la
/// convention tabulaire utilisée) — cohérent avec les autres calendriers
/// arithmétiques grand public, mais pas une source religieuse faisant foi.
library;

/// Date hégirienne (calendrier tabulaire), avec [month] 1-12 (1 = Mouharram).
class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day});

  final int year;
  final int month;
  final int day;

  /// Conversion depuis une date grégorienne, via le nombre de jour julien
  /// (JDN) — passage intermédiaire standard entre calendriers.
  factory HijriDate.fromGregorian(DateTime date) {
    // +1 : décalage constant d'époque entre le JDN "civil" calculé ci-dessous
    // et la convention utilisée par `_fromJulianDayNumber` — sans ce
    // réglage, chaque date sort systématiquement un jour hégirien trop tôt
    // (vérifié par recoupement avec `System.Globalization.HijriCalendar` sur
    // 7 dates de référence dans `test/hijri_date_test.dart`).
    return _fromJulianDayNumber(_julianDayNumberFrom(date) + 1);
  }
}

int _julianDayNumberFrom(DateTime date) {
  final y = date.year;
  final m = date.month;
  final d = date.day;
  final a = (14 - m) ~/ 12;
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return d + ((153 * m2 + 2) ~/ 5) + 365 * y2 + (y2 ~/ 4) - (y2 ~/ 100) + (y2 ~/ 400) - 32045;
}

/// Algorithme tabulaire (koweïtien) standard — voir par ex. l'implémentation
/// de référence de `System.Globalization.HijriCalendar` (.NET), contre
/// laquelle ce calcul est vérifié dans `test/hijri_date_test.dart`.
HijriDate _fromJulianDayNumber(int jd) {
  final l1 = jd - 1948440 + 10632;
  final n = (l1 - 1) ~/ 10631;
  var l2 = l1 - 10631 * n + 354;
  final j = ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) + (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
  l2 = l2 - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final month = (24 * l2) ~/ 709;
  final day = l2 - (709 * month) ~/ 24;
  final year = 30 * n + j - 30;
  return HijriDate(year: year, month: month, day: day);
}
