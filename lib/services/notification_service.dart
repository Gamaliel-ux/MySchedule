import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'myschedule_system_alarm_channel_v2';
  static const String channelName = 'MySchedule - Alarm Reminder';

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
    await _createAlarmChannel();
  }

  Future<void> _createAlarmChannel() async {
    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    // Create system alarm channel using device system sound (sound: null)
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Notifikasi dan alarm pengingat jadwal serta tugas',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
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
        // Fire almost immediately so user still gets notified if recently passed
        targetDate = now.add(const Duration(seconds: 3));
      } else {
        return; // Skip expired notifications
      }
    }

    final notificationDate = tz.TZDateTime.from(targetDate, tz.local);

    // ── Android ─────────────────────────────────────────────
    // sound: null causes Android to play the device system default sound
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifikasi dan alarm pengingat jadwal serta tugas',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ticker: 'MySchedule Alarm',
      visibility: NotificationVisibility.public,
    );

    // ── iOS ─────────────────────────────────────────────────
    // sound: null uses iOS system default sound
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
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
      // Fallback: inexact alarm if Android 12+ exact alarm permission is missing
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
      body: 'Alarm dan notifikasi HP berhasil berbunyi!',
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
