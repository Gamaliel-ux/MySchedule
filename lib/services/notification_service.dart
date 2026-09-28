import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

String _resolveAlarmSound(String soundName) {
  switch (soundName) {
    case 'soft_chime':
      return 'soft_chime';
    case 'urgent_buzz':
      return 'urgent_buzz';
    case 'default_alarm':
    default:
      return 'alarm_default';
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  // ID Namespace Helpers to avoid notification ID collisions
  static int scheduleIdToNotificationId(int dbId) => 100000 + dbId;
  static int taskIdToNotificationId(int dbId) => 200000 + dbId;

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    await _configureTimezone();

    // Android Settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS Settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notifications.initialize(settings: settings);

    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'schedule_planner_alarm_v3',
        'MySchedule Alarm',
        description: 'Alarm reminder untuk jadwal dan tugas',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  Future<void> _configureTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final identifier = timezoneInfo.identifier;

      if (tz.timeZoneDatabase.locations.containsKey(identifier)) {
        tz.setLocalLocation(tz.getLocation(identifier));
        return;
      }

      // Windows/Device name mapping fallback by UTC offset
      final now = DateTime.now();
      final deviceOffset = now.timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == deviceOffset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (_) {}

    // Fallback to UTC if timezone cannot be matched
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}
  }

  // ==========================================================
  // REQUEST PERMISSION
  // ==========================================================

  Future<void> requestPermission() async {
    // Android
    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    // iOS
    final ios = notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ==========================================================
  // SCHEDULE NOTIFICATION
  // ==========================================================

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String alarmSound = 'default_alarm',
  }) async {
    // Check if master notifications toggle is enabled
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!isEnabled) {
      return;
    }

    DateTime targetDate = scheduledDate;
    final now = DateTime.now();

    // If scheduled reminder time is in the past, schedule 3 seconds from now
    // so the user still gets notified rather than dropping it silently!
    if (targetDate.isBefore(now)) {
      if (now.difference(targetDate).inMinutes < 60) {
        targetDate = now.add(const Duration(seconds: 3));
      } else {
        return; // Don't schedule old reminders from days ago
      }
    }

    final notificationDate = tz.TZDateTime.from(targetDate, tz.local);
    final soundResource = _resolveAlarmSound(alarmSound);

    final androidDetails = AndroidNotificationDetails(
      'schedule_planner_alarm_v3',
      'MySchedule Alarm',
      channelDescription: 'Alarm reminder untuk jadwal dan tugas',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ticker: 'MySchedule alarm',
      sound: RawResourceAndroidNotificationSound(soundResource),
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: '$soundResource.wav',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: notificationDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'schedule_planner',
      );
    } catch (_) {
      // Fallback if exact alarm permission is missing on Android 12+
      await notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: notificationDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'schedule_planner',
      );
    }
  }

  // ==========================================================
  // TEST NOTIFICATION INSTANT (5 DETIK)
  // ==========================================================

  Future<void> showTestNotification({
    int delaySeconds = 5,
    String sound = 'default_alarm',
  }) async {
    final testId = 999999;
    final testTime = DateTime.now().add(Duration(seconds: delaySeconds));

    await scheduleNotification(
      id: testId,
      title: '🔔 Tes Alarm MySchedule',
      body: 'Alarm & Notifikasi aplikasi Anda berfungsi dengan baik!',
      scheduledDate: testTime,
      alarmSound: sound,
    );
  }

  // ==========================================================
  // CANCEL NOTIFICATION
  // ==========================================================

  Future<void> cancelNotification(int id) async {
    await notifications.cancel(id: id);
  }

  // ==========================================================
  // CANCEL ALL
  // ==========================================================

  Future<void> cancelAll() async {
    await notifications.cancelAll();
  }
}
