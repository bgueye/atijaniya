/// Contrôleur des rappels du Wird (P0 — docs/03-architecture-ecrans.md :
/// "Paramètres de rappels").
library;

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wird_notification_service.dart';
import '../data/wird_reminder_slots.dart';
import '../data/wird_reminder_store.dart';
import '../domain/wird_models.dart';
import '../domain/wird_reminder.dart';
import '../../../core/theme/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import 'wird_messages.dart';

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
  (ref, wird) {
    // Dépend de la langue choisie : à un changement de langue, le contrôleur
    // est recréé et `_load()` reprogramme les rappels actifs avec le texte
    // de la nouvelle langue (ils restaient en français, audit 2026-10-04).
    final locale = ref.watch(localeControllerProvider) ?? const Locale('fr');
    return WirdReminderController(wird: wird, locale: locale);
  },
);

class WirdReminderController extends StateNotifier<WirdReminderState> {
  /// [notifications] n'est passé que par les tests, avec un faux service ;
  /// l'app utilise toujours `WirdNotificationService.instance`.
  WirdReminderController({required this.wird, required this.locale, WirdNotificationService? notifications})
      : _notifications = notifications ?? WirdNotificationService.instance,
        super(const WirdReminderState()) {
    _load();
  }

  final Wird wird;

  /// Langue du texte des notifications programmées par ce contrôleur.
  final Locale locale;
  final WirdReminderStore _store = const WirdReminderStore();
  final WirdNotificationService _notifications;

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
        try {
          await _scheduleSlot(slot, setting);
        } catch (_) {
          // Le réglage reste affiché activé (il l'est, et sera reprogrammé à
          // la prochaine ouverture) ; le disciple est prévenu que l'alarme
          // n'a pas pu être posée cette fois.
          if (mounted) state = state.copyWith(errorMessage: wirdMsgReminderScheduleFailed);
        }
      }
    }
  }

  Future<void> setEnabled(String slotId, bool enabled) async {
    if (enabled) {
      final bool granted;
      try {
        granted = await _notifications.requestPermission();
      } catch (_) {
        state = state.copyWith(errorMessage: wirdMsgReminderScheduleFailed);
        return;
      }
      if (!granted) {
        state = state.copyWith(
          errorMessage: wirdMsgReminderPermissionDenied,
        );
        return;
      }
    }
    final slot = slots.firstWhere((s) => s.id == slotId);
    final current = state.settings[slotId] ?? WirdReminderSetting.defaultFor(slot);
    await _applyAndPersist(slot, current.copyWith(enabled: enabled));
  }

  /// Efface le message d'erreur une fois affiché — voir
  /// `WirdAudioController.clearError` : un second refus de la permission
  /// n'était plus signalé.
  void clearError() {
    if (mounted && state.errorMessage != null) state = state.copyWith(clearError: true);
  }

  Future<void> setTime(String slotId, int hour, int minute) async {
    final slot = slots.firstWhere((s) => s.id == slotId);
    final current = state.settings[slotId] ?? WirdReminderSetting.defaultFor(slot);
    await _applyAndPersist(slot, current.copyWith(hour: hour, minute: minute));
  }

  /// Programme (ou annule) le rappel, puis enregistre le réglage. Si la
  /// programmation échoue, l'interrupteur et l'heure reviennent à leur valeur
  /// précédente et un message le dit : avant, le réglage était enregistré
  /// « activé » sans aucune alarme posée, ni message (audits du 2026-10-04 et
  /// du 2026-10-25, P2-4).
  Future<void> _applyAndPersist(WirdReminderSlot slot, WirdReminderSetting setting) async {
    final previous = state.settings;
    final updated = {...previous, slot.id: setting};
    // Affiché tout de suite : l'interrupteur suit le doigt pendant la
    // programmation.
    state = state.copyWith(settings: updated, clearError: true);
    try {
      await _scheduleSlot(slot, setting);
    } catch (_) {
      if (mounted) state = state.copyWith(settings: previous, errorMessage: wirdMsgReminderScheduleFailed);
      return;
    }
    await _store.save(wird.id, updated.values.toList());
  }

  Future<void> _scheduleSlot(WirdReminderSlot slot, WirdReminderSetting setting) {
    final l10n = lookupAppLocalizations(locale);
    return _notifications.scheduleReminder(
      slot: slot,
      setting: setting,
      title: locale.languageCode == 'ar' ? wird.nameArabic : wird.nameFrench,
      body: l10n.wirdReminderNotificationBody,
      channelName: l10n.wirdReminderChannelName,
      channelDescription: l10n.wirdReminderChannelDescription,
    );
  }
}
