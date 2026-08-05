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
