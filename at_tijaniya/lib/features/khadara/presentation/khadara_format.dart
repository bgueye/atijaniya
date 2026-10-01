import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';

/// Formatage numérique volontairement neutre (pas de nom de mois/jour
/// localisé) pour éviter d'initialiser les données `intl` par locale
/// (`ar` notamment) — cohérent avec le reste de l'app, qui évite `intl`
/// DateFormat (voir les compteurs "×100" du module Wirds, non traduits).
String formatKhadaraDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} — ${two(dt.hour)}:${two(dt.minute)}';
}

/// Même formatage, sans l'heure — pour une date pure comme
/// `KhadaraEvent.recurrenceUntil` (colonne Postgres `date`, pas de notion
/// d'heure).
String formatKhadaraDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// Nom de jour localisé sans passer par `intl` (voir la note sur
/// `formatKhadaraDateTime` ci-dessus) — convention Dart `DateTime.weekday`
/// (1=lundi ... 7=dimanche), même que `KhadaraEvent.recurrenceDayOfWeek`.
String khadaraWeekdayLabel(int dayOfWeek, AppLocalizations l10n) {
  switch (dayOfWeek) {
    case DateTime.monday:
      return l10n.khadaraWeekdayMonday;
    case DateTime.tuesday:
      return l10n.khadaraWeekdayTuesday;
    case DateTime.wednesday:
      return l10n.khadaraWeekdayWednesday;
    case DateTime.thursday:
      return l10n.khadaraWeekdayThursday;
    case DateTime.friday:
      return l10n.khadaraWeekdayFriday;
    case DateTime.saturday:
      return l10n.khadaraWeekdaySaturday;
    default:
      return l10n.khadaraWeekdaySunday;
  }
}

/// Libellé horaire d'un évènement — date/heure fixe pour un évènement
/// classique, ou motif récurrent ("Tous les vendredis à 14:00") pour un
/// évènement récurrent. Centralisé ici pour que l'accueil, la liste et la
/// fiche détail affichent la même chose.
String formatKhadaraEventSchedule(KhadaraEvent event, AppLocalizations l10n) {
  if (!event.isRecurring) return formatKhadaraDateTime(event.startsAt);
  String two(int n) => n.toString().padLeft(2, '0');
  final weekday = khadaraWeekdayLabel(event.recurrenceDayOfWeek!, l10n);
  final time = '${two(event.recurrenceHour!)}:${two(event.recurrenceMinute!)}';
  return l10n.khadaraRecurrenceLabel(weekday, time);
}

/// `null` si l'évènement n'est pas récurrent, ou si sa récurrence est
/// terminée (voir `nextOccurrence`) — l'appelant décide alors de ne pas
/// afficher la ligne "Prochaine occurrence".
String? formatKhadaraNextOccurrence(KhadaraEvent event, AppLocalizations l10n, {DateTime? from}) {
  final next = nextOccurrence(event, from: from);
  if (next == null) return null;
  return l10n.khadaraNextOccurrenceLabel(formatKhadaraDateTime(next));
}

/// "850 m" en dessous d'un kilomètre, "3,2 km" au-delà — utilisé par
/// `NearbyRecurringEventsScreen`. Virgule plutôt que point : cohérent avec
/// l'usage courant en français, l'arabe utilisé dans l'app affichant
/// aussi les chiffres latins ailleurs (voir `formatKhadaraDateTime`).
String formatKhadaraDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

IconData khadaraEventTypeIcon(KhadaraEventType type) {
  switch (type) {
    case KhadaraEventType.ziyara:
      return Icons.location_on_outlined;
    case KhadaraEventType.hadra:
      return Icons.groups_outlined;
    case KhadaraEventType.other:
      return Icons.event_outlined;
  }
}

String khadaraEventTypeLabel(KhadaraEventType type, AppLocalizations l10n) {
  switch (type) {
    case KhadaraEventType.ziyara:
      return l10n.khadaraEventTypeZiyara;
    case KhadaraEventType.hadra:
      return l10n.khadaraEventTypeHadra;
    case KhadaraEventType.other:
      return l10n.khadaraEventTypeOther;
  }
}

IconData liveStreamSourceIcon(LiveStreamSourceType type) {
  switch (type) {
    case LiveStreamSourceType.youtube:
      return Icons.smart_display_outlined;
    case LiveStreamSourceType.facebook:
      return Icons.facebook_outlined;
    case LiveStreamSourceType.native:
      return Icons.videocam_outlined;
    case LiveStreamSourceType.other:
      return Icons.link;
  }
}

String liveStreamSourceLabel(LiveStreamSourceType type, AppLocalizations l10n) {
  switch (type) {
    case LiveStreamSourceType.youtube:
      return l10n.khadaraSourceYoutube;
    case LiveStreamSourceType.facebook:
      return l10n.khadaraSourceFacebook;
    case LiveStreamSourceType.native:
      return l10n.khadaraSourceNative;
    case LiveStreamSourceType.other:
      return l10n.khadaraSourceOther;
  }
}

/// Icône d'un lieu de l'annuaire selon son type — la zawiya garde l'icône
/// historique de l'annuaire.
IconData zawiyaKindIcon(ZawiyaKind kind) {
  return switch (kind) {
    ZawiyaKind.zawiya => Icons.mosque_outlined,
    ZawiyaKind.holyPlace => Icons.landscape_outlined,
    ZawiyaKind.mosque => Icons.mosque,
  };
}

/// Libellé singulier d'un type de lieu ("Zawiya", "Lieu saint", "Mosquée").
String zawiyaKindLabel(ZawiyaKind kind, AppLocalizations l10n) {
  return switch (kind) {
    ZawiyaKind.zawiya => l10n.zawiyaKindZawiya,
    ZawiyaKind.holyPlace => l10n.zawiyaKindHolyPlace,
    ZawiyaKind.mosque => l10n.zawiyaKindMosque,
  };
}
