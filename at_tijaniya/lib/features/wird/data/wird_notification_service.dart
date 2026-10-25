/// Enrobe `flutter_local_notifications` pour les rappels du Wird (P0 —
/// docs/03-architecture-ecrans.md). Notifications locales uniquement (pas de
/// push serveur) : programmées en heure de l'appareil via `timezone`.
///
/// Programmation en mode "inexact" (`AndroidScheduleMode.inexactAllowWhileIdle`)
/// : peut déclencher avec quelques minutes de retard sur Android en Doze,
/// mais évite de demander la permission `SCHEDULE_EXACT_ALARM`, disproportionnée
/// pour un simple rappel de pratique. Les alarmes programmées via AlarmManager
/// ne survivent pas à un redémarrage de l'appareil : le récepteur de
/// redémarrage du plugin (`ScheduledNotificationBootReceiver`), déclaré dans
/// `AndroidManifest.xml` depuis le 2026-10-05, les reprogramme. En plus,
/// `WirdReminderController` reprogramme les rappels actifs d'un wird à chaque
/// ouverture de son écran de rappels (voir `WirdReminderController._load()`).
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

  /// Identifiant de notification de chaque créneau, fixé une fois pour
  /// toutes. Il était dérivé de `String.hashCode`, dont la valeur n'est pas
  /// garantie d'une version de Dart à l'autre : après une mise à jour, un
  /// rappel posé par l'ancienne version aurait pu ne plus être annulé, et
  /// arriver en double (audit du 2026-10-25, P3-3). Ne jamais renuméroter un
  /// créneau existant.
  static const _notificationIds = {
    'lazim_morning': 1101,
    'lazim_evening': 1102,
    'wazifa_daily': 1201,
    'hadratou_jouma_weekly': 1301,
  };

  int _notificationId(String slotId) => _notificationIds[slotId] ?? _legacyNotificationId(slotId);

  /// Ancien identifiant, encore annulé à chaque programmation : les rappels
  /// posés avant le passage aux identifiants fixes ne doivent pas rester en
  /// plus des nouveaux.
  int _legacyNotificationId(String slotId) => slotId.hashCode & 0x7fffffff;

  /// [channelName] et [channelDescription] : nom et description du canal,
  /// affichés dans les réglages de notification d'Android, dans la langue de
  /// l'app (ils étaient en français en dur).
  Future<void> scheduleReminder({
    required WirdReminderSlot slot,
    required WirdReminderSetting setting,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await cancel(slot.id);
    if (!setting.enabled) return;

    final scheduled = _nextInstance(setting.hour, setting.minute, slot.frequency);
    await _plugin.zonedSchedule(
      _notificationId(slot.id),
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wird_reminders',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          slot.frequency == ReminderFrequency.daily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancel(String slotId) async {
    await _plugin.cancel(_notificationId(slotId));
    final legacy = _legacyNotificationId(slotId);
    if (legacy != _notificationId(slotId)) await _plugin.cancel(legacy);
  }

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
