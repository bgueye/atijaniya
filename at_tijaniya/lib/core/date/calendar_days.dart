/// Arithmétique en jours CIVILS (audit du 2026-10-04).
///
/// `date.add(Duration(days: n))` ajoute n × 24 heures réelles. Sur un appareil
/// dont le fuseau change d'heure (toute la diaspora en Europe), une journée
/// dure 23 h ou 25 h deux fois par an : minuit + 24 h tombe alors à 23:00 la
/// veille ou à 01:00, et ne correspond plus à la date attendue. Conséquences
/// constatées : séries de wirds remises à zéro, semaine de la « Figure de la
/// semaine » décalée d'un jour, prochaine occurrence d'un évènement récurrent
/// décalée d'une heure. Sans effet au Sénégal, qui ne change pas d'heure.
///
/// [addDays] reconstruit la date à partir de ses composantes : l'heure
/// affichée (heure et minute locales) est conservée quel que soit le fuseau.
library;

DateTime addDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days, date.hour, date.minute, date.second);
}
