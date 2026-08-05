/// Enrobe `flutter_local_notifications` pour les rappels du Wird (P0 —
/// docs/03-architecture-ecrans.md). Notifications locales uniquement (pas de
/// push serveur) : programmées en heure de l'appareil via `timezone`.
///
/// Programmation en mode "inexact" (`AndroidScheduleMode.inexactAllowWhileIdle`)
/// : peut déclencher avec quelques minutes de retard sur Android en Doze,
/// mais évite de demander la permission `SCHEDULE_EXACT_ALARM`, disproportionnée
/// pour un simple rappel de pratique. Les alarmes programmées via AlarmManager
/// ne survivent pas à un redémarrage de l'appareil, et cette version de
/// `flutter_local_notifications` ne déclare pas de récepteur de boot pour
/// les reprogrammer automatiquement ; `WirdReminderController` reprogramme
/// donc les rappels actifs du wird concerné à chaque fois que son écran de
/// rappels ou son guide est ouvert (voir `WirdReminderController._load()`)
/// en mitigation partielle.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/wird_reminder.dart';

class WirdNotificationService {
  WirdNotificationService._();

  static final WirdNotificationService instance = WirdNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      // Fuseau horaire introuvable (appareil mal configuré) : reste sur le
      // fuseau par défaut du package `timezone` plutôt que de planter.
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  /// Dérive un identifiant de notification stable et déterministe à partir
  /// de l'identifiant du créneau — évite de maintenir une table séparée.
  int _notificationId(String slotId) => slotId.hashCode & 0x7fffffff;

  Future<void> scheduleReminder({
    required WirdReminderSlot slot,
    required WirdReminderSetting setting,
    required String title,
    required String body,
  }) async {
    await cancel(slot.id);
    if (!setting.enabled) return;

    final scheduled = _nextInstance(setting.hour, setting.minute, slot.frequency);
    await _plugin.zonedSchedule(
      _notificationId(slot.id),
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wird_reminders',
          'Rappels des Wirds',
          channelDescription: 'Rappels programmés pour la pratique des wirds.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          slot.frequency == ReminderFrequency.daily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancel(String slotId) => _plugin.cancel(_notificationId(slotId));

  tz.TZDateTime _nextInstance(int hour, int minute, ReminderFrequency frequency) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (frequency == ReminderFrequency.weeklyFriday) {
      while (scheduled.weekday != DateTime.friday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    } else if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
