import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';
import 'firestore_activity_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await _ensureTimeZones();

    // Must be a drawable resource name. We provide a drawable wrapper in Android.
    const androidInit = AndroidInitializationSettings('ic_launcher');
    // Ask permissions explicitly (on user action) instead of prompting on init.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<void> _ensureTimeZones() async {
    if (_tzInitialized) return;

    tz.initializeTimeZones();

    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      if (tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
      }
    } catch (_) {
      // If we can't read device tz, keep default (UTC).
    }

    _tzInitialized = true;
  }

  Future<void> ensurePermissions() async {
    try {
      await _ensureInitialized();
    } catch (_) {
      // Best effort only: if initialization fails (e.g. missing icon), don't crash the app.
      return;
    }

    // iOS/macOS: request local notification permission.
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Ignore any platform exceptions.
    }

    try {
      final mac = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      await mac?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Ignore any platform exceptions.
    }

    // Android 13+: request notification permission.
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      // Android 14+: best-effort request exact alarms permission (API varies by plugin version).
      try {
        await (android as dynamic)?.requestExactAlarmsPermission();
      } catch (_) {
        // Ignore if not supported or not required.
      }
    } catch (_) {
      // Ignore any platform exceptions.
    }
  }

  int _stableId(String input) {
    // 32-bit FNV-1a hash for stable IDs across app runs.
    const int fnvOffsetBasis = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffsetBasis;
    final units = input.codeUnits;
    for (final b in units) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    return hash & 0x7FFFFFFF;
  }

  int _notificationId({required String weekId, required String dayId, required String activityId}) {
    return _stableId('$weekId|$dayId|$activityId');
  }

  DateTime? _remindAtFromReminder(Map<String, dynamic> reminder) {
    final v = reminder['remindAt'];
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _enabled(Map<String, dynamic> reminder) => reminder['enabled'] == true;

  Future<void> scheduleForActivityIfEnabled({
    required String weekId,
    required String dayId,
    required String activityId,
    required String title,
    required Map<String, dynamic> reminder,
  }) async {
    if (!_enabled(reminder)) return;

    final remindAt = _remindAtFromReminder(reminder);
    if (remindAt == null) return;

    // Don't schedule notifications in the past.
    if (!remindAt.isAfter(DateTime.now())) return;

    await _ensureInitialized();

    final id = _notificationId(weekId: weekId, dayId: dayId, activityId: activityId);

    const androidDetails = AndroidNotificationDetails(
      'liflow_reminders',
      'Lembretes',
      channelDescription: 'Lembretes de atividades do Liflow',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final scheduled = tz.TZDateTime.from(remindAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      null,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'activity:$activityId',
    );

    if (kDebugMode) {
      debugPrint('Scheduled notification $id at $scheduled');
    }
  }

  Future<void> cancelForActivity({
    required String weekId,
    required String dayId,
    required String activityId,
  }) async {
    await _ensureInitialized();
    final id = _notificationId(weekId: weekId, dayId: dayId, activityId: activityId);
    await _plugin.cancel(id);
  }

  /// Helper used on create: writes the activity with a stable notificationId
  /// and schedules it (if enabled).
  ///
  /// This keeps the reminder map aligned with the scheduled local notification.
  Future<void> scheduleAndPersistForActivity({
    required FirestoreActivityService service,
    required String weekId,
    required String dayId,
    required String activityId,
    required String title,
    required String? description,
    required ActivityStatus status,
    required int order,
    required String? scheduledTime,
    required Map<String, dynamic> reminder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final id = _notificationId(weekId: weekId, dayId: dayId, activityId: activityId);

    final reminderWithId = Map<String, dynamic>.from(reminder);
    if (reminderWithId['enabled'] == true) {
      reminderWithId['notificationId'] = id;
    } else {
      reminderWithId.remove('notificationId');
    }

    await service.upsertActivity(
      weekId: weekId,
      dayId: dayId,
      activity: Activity(
        id: activityId,
        title: title,
        description: description,
        status: status,
        order: order,
        scheduledTime: scheduledTime,
        reminder: reminderWithId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    await scheduleForActivityIfEnabled(
      weekId: weekId,
      dayId: dayId,
      activityId: activityId,
      title: title,
      reminder: reminderWithId,
    );
  }
}
