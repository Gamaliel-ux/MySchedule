import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Alarm sound resolver
// Maps logical alarm sound names to platform-specific resource names.
//   Android : res/raw/<name>.wav  (referenced WITHOUT extension)
//   iOS     : ios/Runner/<name>.wav (referenced WITH extension)
// ─────────────────────────────────────────────────────────────────────────────
String _androidSoundResource(String soundName) {
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

String _iosSoundFile(String soundName) {
  switch (soundName) {
    case 'soft_chime':
      return 'soft_chime.wav';
    case 'urgent_buzz':
      return 'urgent_buzz.wav';
    case 'default_alarm':
    default:
      return 'alarm_default.wav';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alarm channel IDs
// We use separate channels per sound so Android can cache different audio URIs.
// ─────────────────────────────────────────────────────────────────────────────
String _channelId(String soundName) {
  switch (soundName) {
    case 'soft_chime':
      return 'myschedule_alarm_chime';
    case 'urgent_buzz':
      return 'myschedule_alarm_buzz';
    default:
      return 'myschedule_alarm_default';
  }
}

String _channelName(String soundName) {
  switch (soundName) {
    case 'soft_chime':
      return 'MySchedule - Soft Chime';
    case 'urgent_buzz':
      return 'MySchedule - Urgent Alarm';
    default:
      return 'MySchedule - Alarm';
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
    tz.initializeTimeZones();
    await _configureTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

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

    // Create one alarm channel per sound variant.
    // IMPORTANT: Once a channel is created with a sound, Android caches it.
    // Delete the app + reinstall if you change the sound of an existing channel ID.
    await _createAlarmChannels();
  }

  Future<void> _createAlarmChannels() async {
    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    final sounds = ['default_alarm', 'soft_chime', 'urgent_buzz'];

    for (final sound in sounds) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId(sound),
          _channelName(sound),
          description: 'Alarm reminder untuk jadwal dan tugas MySchedule',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 300, 200, 300, 200, 300]),
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: RawResourceAndroidNotificationSound(
            _androidSoundResource(sound),
          ),
        ),
      );
    }
  }

  Future<void> _configureTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final identifier = timezoneInfo.identifier;

      if (tz.timeZoneDatabase.locations.containsKey(identifier)) {
        tz.setLocalLocation(tz.getLocation(identifier));
        return;
      }

      // Fallback by UTC offset
      final deviceOffset = DateTime.now().timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == deviceOffset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (_) {}

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
  // SCHEDULE NOTIFICATION (ALARM)
  // ==========================================================

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String alarmSound = 'default_alarm',
  }) async {
    // Check master toggle
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!isEnabled) return;

    DateTime targetDate = scheduledDate;
    final now = DateTime.now();

    if (targetDate.isBefore(now)) {
      if (now.difference(targetDate).inMinutes < 60) {
        // Fire almost immediately so user still gets notified
        targetDate = now.add(const Duration(seconds: 3));
      } else {
        return; // Too old — skip silently
      }
    }

    final notificationDate = tz.TZDateTime.from(targetDate, tz.local);
    final channelId = _channelId(alarmSound);

    // ── Android ─────────────────────────────────────────────
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(alarmSound),
      channelDescription: 'Alarm reminder untuk jadwal dan tugas MySchedule',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        _androidSoundResource(alarmSound),
      ),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300, 200, 300]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ticker: 'MySchedule Alarm',
      // Keep the notification visible even on lock screen
      visibility: NotificationVisibility.public,
    );

    // ── iOS ─────────────────────────────────────────────────
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: _iosSoundFile(alarmSound),
      interruptionLevel: InterruptionLevel.timeSensitive,
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
      // Fallback: inexact alarm (Android 12+ without SCHEDULE_EXACT_ALARM)
      try {
        await notifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: notificationDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'schedule_planner',
        );
      } catch (_) {}
    }
  }

  // ==========================================================
  // TEST NOTIFICATION (5 DETIK)
  // ==========================================================

  Future<void> showTestNotification({
    int delaySeconds = 5,
    String sound = 'default_alarm',
  }) async {
    const testId = 999999;
    final testTime = DateTime.now().add(Duration(seconds: delaySeconds));

    await scheduleNotification(
      id: testId,
      title: 'Alarm MySchedule',
      body: 'Alarm dan notifikasi berfungsi dengan baik!',
      scheduledDate: testTime,
      alarmSound: sound,
    );
  }

  // ==========================================================
  // CANCEL
  // ==========================================================

  Future<void> cancelNotification(int id) async {
    await notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await notifications.cancelAll();
  }
}
