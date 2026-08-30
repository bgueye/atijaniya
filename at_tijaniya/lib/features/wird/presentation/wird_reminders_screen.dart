import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wird_reminder_slots.dart';
import '../domain/wird_models.dart';
import '../domain/wird_reminder.dart';
import 'wird_reminder_controller.dart';

/// Traduit le libellé d'un créneau par son `id` plutôt que d'afficher
/// `slot.label` (toujours en français, `wird_reminder_slots.dart`) — même
/// fonction que `_NextReminderCard._slotLabel` dans `home_screen.dart`,
/// dupliquée ici faute d'un point commun partagé entre les deux écrans pour
/// l'instant.
String _slotLabel(AppLocalizations l10n, WirdReminderSlot slot) {
  return switch (slot.id) {
    'lazim_morning' => l10n.reminderSlotMorning,
    'lazim_evening' => l10n.reminderSlotEvening,
    'wazifa_daily' => l10n.reminderSlotDaily,
    'hadratou_jouma_weekly' => l10n.reminderSlotFriday,
    _ => slot.label,
  };
}

/// Paramètres de rappels du Wird — P0 (docs/03-architecture-ecrans.md :
/// "Notifications calées sur horaires de prière").
///
/// L'heure de chaque rappel est choisie librement par le disciple — voir la
/// justification dans `wird_reminder_slots.dart` (pas de calcul automatique
/// d'horaire de prière en V1, pour ne rien inventer côté contenu religieux).
class WirdRemindersScreen extends ConsumerWidget {
  const WirdRemindersScreen({super.key, required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(wirdReminderControllerProvider(wird));
    final controller = ref.read(wirdReminderControllerProvider(wird).notifier);
    final slots = wirdReminderSlots[wird.id] ?? const [];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final wirdName = isArabic ? wird.nameArabic : wird.nameFrench;

    ref.listen(wirdReminderControllerProvider(wird), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(l10n.wirdRemindersTitle(wirdName)),
      ),
      body: state.loading
          ? Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ScopeNote(l10n: l10n),
                const SizedBox(height: 20),
                for (final slot in slots) ...[
                  _ReminderTile(
                    slot: slot,
                    l10n: l10n,
                    setting: state.settings[slot.id] ?? WirdReminderSetting.defaultFor(slot),
                    onToggle: (value) => controller.setEnabled(slot.id, value),
                    onPickTime: (time) => controller.setTime(slot.id, time.hour, time.minute),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.emerald, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.wirdRemindersScopeNote,
              style: const TextStyle(color: AppColors.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.slot,
    required this.l10n,
    required this.setting,
    required this.onToggle,
    required this.onPickTime,
  });

  final WirdReminderSlot slot;
  final AppLocalizations l10n;
  final WirdReminderSetting setting;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onPickTime;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: setting.hour, minute: setting.minute);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.emerald,
            title: Text(_slotLabel(l10n, slot), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
            subtitle: Text(
              slot.frequency == ReminderFrequency.weeklyFriday ? l10n.reminderFrequencyWeekly : l10n.reminderFrequencyDaily,
              style: TextStyle(color: AppColors.bronze, fontSize: 12),
            ),
            value: setting.enabled,
            onChanged: onToggle,
          ),
          if (setting.enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: time);
                    if (picked != null) onPickTime(picked);
                  },
                  icon: Icon(Icons.schedule, color: AppColors.emerald, size: 18),
                  label: Text(
                    time.format(context),
                    style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
