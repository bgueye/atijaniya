import '../../../l10n/app_localizations.dart';

/// Formatage numérique volontairement neutre — même choix que
/// `khadara_format.dart` (pas d'initialisation `intl` par locale).
String formatCommunityDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} — ${two(dt.hour)}:${two(dt.minute)}';
}

/// Date relative d'une publication (« il y a 2 h », « hier », refonte du
/// 2026-11-02) ; au-delà d'une semaine, la date seule. Moins de 24 h : en
/// heures, même la veille (« il y a 2 h » plutôt que « hier » à 0 h 30). Puis
/// des jours de calendrier comptés en UTC, pour ne pas perdre un jour au
/// changement d'heure.
String formatCommunityRelative(DateTime dt, AppLocalizations l10n, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = dt.toLocal();
  final elapsed = current.difference(local);
  if (elapsed.inMinutes < 1) return l10n.communityTimeNow;
  if (elapsed.inMinutes < 60) return l10n.communityTimeMinutes(elapsed.inMinutes);
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  if (elapsed.inHours < 24) return l10n.communityTimeHours(elapsed.inHours);
  if (days == 1) return l10n.communityTimeYesterday;
  if (days < 7) return l10n.communityTimeDays(days);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
