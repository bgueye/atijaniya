// Les trois états de la maquette de l'écran Wird (`docs/maquettes/ecran-wird.html`),
// reconstitués avec les vraies règles de calcul : dimanche matin, dimanche
// soir avec la Wazifa en pause, vendredi. Partagés par les tests de l'écran
// et par ses captures. Dates : semaine du lundi 26 octobre au dimanche
// 1er novembre 2026, puis vendredi 6 novembre.

import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/tasbih_session.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_overview.dart';
import 'package:at_tijaniya/features/wird/domain/wird_progress_stats.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';

/// Un état de la maquette : l'heure de référence et ce que l'écran a chargé.
typedef WirdMockupState = ({String name, DateTime now, List<WirdOverviewEntry> entries});

List<DateTime> _days(List<int> octoberOrNovember, {int month = 10}) =>
    [for (final d in octoberOrNovember) DateTime(2026, month, d, 7, 30)];

const _reminders = {
  'lazim': [
    WirdReminderSetting(slotId: 'lazim_morning', enabled: true, hour: 6, minute: 30),
    WirdReminderSetting(slotId: 'lazim_evening', enabled: false, hour: 19, minute: 0),
  ],
  'wazifa': [WirdReminderSetting(slotId: 'wazifa_daily', enabled: true, hour: 18, minute: 0)],
  'hadratou_jouma': [WirdReminderSetting(slotId: 'hadratou_jouma_weekly', enabled: true, hour: 15, minute: 30)],
};

WirdOverviewEntry _entry(Wird wird, List<DateTime> dates, DateTime now, {TasbihSession? session}) {
  return WirdOverviewEntry(
    wird: wird,
    stats: computeWirdProgressStats(frequency: wird.frequency, completionDates: dates, now: now),
    session: session,
    reminders: _reminders[wird.id]!,
  );
}

/// Dimanche matin : rien de fait aujourd'hui ; Lazim tenu 6 jours, Wazifa non
/// marquée mercredi, Hadra faite vendredi dernier.
WirdMockupState sundayMorning() {
  final now = DateTime(2026, 11, 1, 8, 0);
  return (
    name: 'matin',
    now: now,
    entries: [
      _entry(lazim, _days([26, 27, 28, 29, 30, 31]), now),
      _entry(wazifa, _days([26, 27, 29, 30, 31]), now),
      _entry(hadratouJouma, _days([30]), now),
    ],
  );
}

/// Dimanche soir : Lazim fait ce jour, Wazifa en pause au 4ᵉ pilier
/// (Salatoul Fatihi, 18 sur 50).
WirdMockupState sundayEvening() {
  final now = DateTime(2026, 11, 1, 20, 0);
  return (
    name: 'soir',
    now: now,
    entries: [
      _entry(
          lazim,
          [
            ..._days([26, 27, 28, 29, 30, 31]),
            DateTime(2026, 11, 1, 7, 0)
          ],
          now),
      _entry(
        wazifa,
        _days([26, 27, 29, 30, 31]),
        now,
        session: TasbihSession(
          wirdId: 'wazifa',
          pillarIndex: 3,
          currentCount: 18,
          mode: TasbihMode.manual,
          updatedAt: DateTime(2026, 11, 1, 19, 40),
        ),
      ),
      _entry(hadratouJouma, _days([30]), now),
    ],
  );
}

/// Vendredi : Lazim fait ce matin, Wazifa pas encore, Hadra à faire (deux
/// vendredis tenus).
WirdMockupState friday() {
  final now = DateTime(2026, 11, 6, 10, 0);
  return (
    name: 'vendredi',
    now: now,
    entries: [
      _entry(lazim, _days([2, 3, 4, 5, 6], month: 11), now),
      _entry(wazifa, _days([2, 3, 4, 5], month: 11), now),
      _entry(hadratouJouma, _days([23, 30]), now),
    ],
  );
}

List<WirdMockupState> allMockupStates() => [sundayMorning(), sundayEvening(), friday()];
