// Rappels d'un wird : un échec de programmation ne doit pas laisser un
// réglage « activé » sans alarme (audit du 2026-10-25, P2-4). Le service de
// notifications est remplacé par une doublure qui réussit ou échoue à la
// demande.

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wird_notification_service.dart';
import 'package:at_tijaniya/features/wird/data/wird_reminder_store.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_messages.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_reminder_controller.dart';

class _FakeNotifications implements WirdNotificationService {
  bool failScheduling = false;
  bool granted = true;
  final scheduled = <String>[];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> scheduleReminder({
    required WirdReminderSlot slot,
    required WirdReminderSetting setting,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (failScheduling) throw Exception('zonedSchedule a échoué');
    if (setting.enabled) scheduled.add(slot.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final wazifa = validatedWirds.firstWhere((w) => w.id == 'wazifa');
  late _FakeNotifications notifications;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifications = _FakeNotifications();
  });

  WirdReminderController controller() =>
      WirdReminderController(wird: wazifa, locale: const Locale('fr'), notifications: notifications);

  test('programmation en échec : interrupteur rétabli, rien d’enregistré, message affiché', () async {
    final reminders = controller();
    await _settle();
    final slotId = reminders.slots.first.id;
    expect(reminders.state.settings[slotId]!.enabled, isFalse);

    notifications.failScheduling = true;
    await reminders.setEnabled(slotId, true);

    expect(reminders.state.settings[slotId]!.enabled, isFalse);
    expect(reminders.state.errorMessage, wirdMsgReminderScheduleFailed);
    expect(await const WirdReminderStore().load(wazifa.id), isEmpty);
  });

  test('programmation réussie : réglage activé et enregistré', () async {
    final reminders = controller();
    await _settle();
    final slotId = reminders.slots.first.id;

    await reminders.setEnabled(slotId, true);

    expect(reminders.state.settings[slotId]!.enabled, isTrue);
    expect(reminders.state.errorMessage, isNull);
    expect(notifications.scheduled, [slotId]);
    final saved = await const WirdReminderStore().load(wazifa.id);
    expect(saved.singleWhere((s) => s.slotId == slotId).enabled, isTrue);
  });

  test('permission refusée : réglage inchangé, message de permission', () async {
    final reminders = controller();
    await _settle();
    final slotId = reminders.slots.first.id;

    notifications.granted = false;
    await reminders.setEnabled(slotId, true);

    expect(reminders.state.settings[slotId]!.enabled, isFalse);
    expect(reminders.state.errorMessage, wirdMsgReminderPermissionDenied);
  });
}
