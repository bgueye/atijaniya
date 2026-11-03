/// Activation de plusieurs rappels d'un coup, pour l'étape « Rappels » du
/// parcours d'entrée (refonte du 2026-11-03, maquette `parcours-entree.html`).
///
/// Pourquoi pas `WirdReminderController` : il y en a un par wird, et chacun
/// charge ses réglages de façon asynchrone à sa création. Activer un créneau
/// juste après l'avoir créé pouvait voir ce chargement repasser derrière et
/// réafficher le créneau désactivé. Cette fonction écrit directement dans le
/// même stockage ([WirdReminderStore]) et programme les mêmes notifications
/// ([WirdNotificationService.scheduleReminder]) que le contrôleur : le guide
/// d'un wird relit ensuite ces réglages comme s'ils avaient été faits chez lui.
library;

import 'dart:ui' show Locale;

import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_reminder.dart';
import 'wird_notification_service.dart';
import 'wird_reminder_slots.dart';
import 'wird_reminder_store.dart';

/// Issue d'une activation groupée.
enum BulkReminderOutcome {
  /// Tous les créneaux demandés sont programmés et enregistrés.
  done,

  /// Notifications refusées : rien n'a été activé.
  permissionDenied,

  /// Au moins un créneau n'a pas pu être programmé ; ceux-là restent
  /// désactivés, les autres sont enregistrés.
  partialFailure,
}

/// Active les créneaux [slotIds] des [wirds], à leur heure enregistrée ou à
/// l'heure par défaut du créneau ([WirdReminderSetting.defaultHourFor]).
///
/// Demande l'autorisation des notifications **une seule fois**, avant tout :
/// sur Android 13 et plus, un refus ne peut plus être redemandé par l'app, il
/// ne faut donc pas la demander créneau par créneau. Les créneaux non cités
/// ne sont pas touchés (un rappel déjà réglé dans un guide reste tel quel).
Future<BulkReminderOutcome> enableWirdReminders({
  required List<Wird> wirds,
  required Set<String> slotIds,
  required Locale locale,
  WirdNotificationService? notifications,
  WirdReminderStore store = const WirdReminderStore(),
}) async {
  final service = notifications ?? WirdNotificationService.instance;
  if (slotIds.isEmpty) return BulkReminderOutcome.done;

  final bool granted;
  try {
    granted = await service.requestPermission();
  } catch (_) {
    return BulkReminderOutcome.partialFailure;
  }
  if (!granted) return BulkReminderOutcome.permissionDenied;

  final l10n = lookupAppLocalizations(locale);
  var failed = false;
  for (final wird in wirds) {
    final slots = (wirdReminderSlots[wird.id] ?? const <WirdReminderSlot>[]).where((s) => slotIds.contains(s.id));
    if (slots.isEmpty) continue;
    final saved = {for (final s in await store.load(wird.id)) s.slotId: s};
    for (final slot in slots) {
      final setting = (saved[slot.id] ?? WirdReminderSetting.defaultFor(slot)).copyWith(enabled: true);
      try {
        // Même titre et même texte que le contrôleur du guide
        // (`WirdReminderController._scheduleSlot`).
        await service.scheduleReminder(
          slot: slot,
          setting: setting,
          title: locale.languageCode == 'ar' ? wird.nameArabic : wird.nameFrench,
          body: l10n.wirdReminderNotificationBody,
          channelName: l10n.wirdReminderChannelName,
          channelDescription: l10n.wirdReminderChannelDescription,
        );
        saved[slot.id] = setting;
      } catch (_) {
        // Pas d'alarme posée : le créneau n'est pas enregistré « activé »
        // (même règle que le contrôleur, audit du 2026-10-25, P2-4).
        failed = true;
      }
    }
    await store.save(wird.id, saved.values.toList());
  }
  return failed ? BulkReminderOutcome.partialFailure : BulkReminderOutcome.done;
}
