/// Contrôleur des rappels du Wird (P0 — docs/03-architecture-ecrans.md :
/// "Paramètres de rappels").
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_notification_service.dart';
import '../data/wird_reminder_slots.dart';
import '../data/wird_reminder_store.dart';
import '../domain/wird_models.dart';
import '../domain/wird_reminder.dart';

class WirdReminderState {
  const WirdReminderState({this.loading = true, this.settings = const {}, this.errorMessage});

  final bool loading;

  /// Réglage courant par identifiant de créneau (`WirdReminderSlot.id`).
  final Map<String, WirdReminderSetting> settings;

  final String? errorMessage;

  WirdReminderState copyWith({
    bool? loading,
    Map<String, WirdReminderSetting>? settings,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WirdReminderState(
      loading: loading ?? this.loading,
      settings: settings ?? this.settings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final wirdReminderControllerProvider =
    StateNotifierProvider.family<WirdReminderController, WirdReminderState, Wird>(
  (ref, wird) => WirdReminderController(wird: wird),
);

class WirdReminderController extends StateNotifier<WirdReminderState> {
  WirdReminderController({required this.wird}) : super(const WirdReminderState()) {
    _load();
  }

  final Wird wird;
  final WirdReminderStore _store = const WirdReminderStore();

  List<WirdReminderSlot> get slots => wirdReminderSlots[wird.id] ?? const [];

  Future<void> _load() async {
    final saved = await _store.load(wird.id);
    final savedById = {for (final s in saved) s.slotId: s};
    final settings = {
      for (final slot in slots) slot.id: savedById[slot.id] ?? WirdReminderSetting.defaultFor(slot),
    };
    state = state.copyWith(loading: false, settings: settings);
    // Reprogramme les rappels actifs à chaque ouverture de l'écran : couvre
    // le cas d'un redémarrage de l'appareil ayant purgé les alarmes système
    // (voir commentaire de `WirdNotificationService`).
    for (final slot in slots) {
      final setting = settings[slot.id];
      if (setting != null && setting.enabled) {
        await _scheduleSlot(slot, setting);
      }
    }
  }

  Future<void> setEnabled(String slotId, bool enabled) async {
    if (enabled) {
      final granted = await WirdNotificationService.instance.requestPermission();
      if (!granted) {
        state = state.copyWith(
          errorMessage: "Autorisez les notifications dans les réglages du téléphone pour activer ce rappel.",
        );
        return;
      }
    }
    final slot = slots.firstWhere((s) => s.id == slotId);
    final current = state.settings[slotId] ?? WirdReminderSetting.defaultFor(slot);
    await _applyAndPersist(slot, current.copyWith(enabled: enabled));
  }

  Future<void> setTime(String slotId, int hour, int minute) async {
    final slot = slots.firstWhere((s) => s.id == slotId);
    final current = state.settings[slotId] ?? WirdReminderSetting.defaultFor(slot);
    await _applyAndPersist(slot, current.copyWith(hour: hour, minute: minute));
  }

  Future<void> _applyAndPersist(WirdReminderSlot slot, WirdReminderSetting setting) async {
    final updated = {...state.settings, slot.id: setting};
    state = state.copyWith(settings: updated, clearError: true);
    await _store.save(wird.id, updated.values.toList());
    await _scheduleSlot(slot, setting);
  }

  Future<void> _scheduleSlot(WirdReminderSlot slot, WirdReminderSetting setting) {
    return WirdNotificationService.instance.scheduleReminder(
      slot: slot,
      setting: setting,
      title: wird.nameFrench,
      body: 'Rappel — prenez un moment pour réciter votre wird.',
    );
  }
}
