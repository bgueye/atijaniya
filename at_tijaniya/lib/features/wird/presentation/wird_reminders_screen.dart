import 'package:flutter/material.dart';
import '../data/wird_notification_service.dart';
import '../../../core/widgets/notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/wird_reminder_slots.dart';
import '../domain/wird_models.dart';
import '../domain/wird_reminder.dart';
import 'wird_reminder_controller.dart';
import 'wird_messages.dart';
import '../../../core/widgets/content_text.dart';

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
/// Notifications de l'app autorisées dans les réglages du téléphone ;
/// remplaçable dans les tests. Relu à chaque ouverture de l'écran des
/// rappels (`autoDispose`), au retour des réglages du téléphone.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => WirdNotificationService.instance.notificationsEnabled(),
);

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
          ..showSnackBar(SnackBar(content: Text(wirdMessage(AppLocalizations.of(context)!, next.errorMessage!))));
        // Message consommé, voir `wird_detail_screen.dart`.
        Future.microtask(controller.clearError);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(l10n.wirdRemindersTitle(wirdName)),
      ),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: state.loading
            ? Center(child: CircularProgressIndicator(color: AppColors.emerald))
            : ListView(
                // Gouttière `space-16` du kit, sur tous les écrans.
                padding: const EdgeInsets.all(16),
                children: [
                  // Note du kit (`Notice.info`) plutôt qu'un encadré recopié à
                  // la main (mise au thème du kit, 2026-11-04).
                  Notice.info(l10n.wirdRemindersScopeNote),
                  // Rappels activés mais notifications coupées : ils ne
                  // sonneront pas, et l'écran le dit (audit du 2026-11-03).
                  if (ref.watch(notificationsEnabledProvider).valueOrNull == false &&
                      state.settings.values.any((s) => s.enabled)) ...[
                    const SizedBox(height: 12),
                    Notice.error(l10n.wirdRemindersNotificationsOff),
                  ],
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
    // `Card` du kit (blanc cassé, filet bronze à 20 %, rayon 16) : la
    // `Material` nue d'avant n'avait pas de filet (mise au thème du kit,
    // 2026-11-04). Une `Material` reste nécessaire sous `SwitchListTile`
    // pour l'effet du toucher (audit du 2026-11-03), et `Card` en est une.
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.emerald,
              title: Text(_slotLabel(l10n, slot),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              subtitle: Text(
                slot.frequency == ReminderFrequency.weeklyFriday
                    ? l10n.reminderFrequencyWeekly
                    : l10n.reminderFrequencyDaily,
                // Encre secondaire : le bronze en texte est sous le seuil AA
                // (4,09:1 sur blanc cassé, kit § Couleurs).
                style: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5),
              ),
              value: setting.enabled,
              onChanged: onToggle,
            ),
            if (setting.enabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: time);
                      if (picked != null) onPickTime(picked);
                    },
                    icon: Icon(Icons.schedule, color: AppColors.emerald, size: 18),
                    label: ContentText(
                      time.format(context),
                      style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
