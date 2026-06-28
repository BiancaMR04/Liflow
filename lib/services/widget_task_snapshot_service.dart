import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';

import '../models/activity.dart';
import 'date_ids.dart';
import 'widget_keys.dart';
import 'firestore_activity_service.dart';

/// Generates and persists the widget snapshot for the current day.
///
/// Widget rules (Android):
/// - Show only NOT completed tasks
/// - Filter by time cutoff (e.g. up to 12:00)
/// - Primary sort: scheduledTime
/// - Secondary sort: order
/// - Completed tasks must disappear from the widget
class WidgetTaskSnapshotService {
  final FirestoreActivityService _firestore;

  /// Android widget receiver name.
  ///
  /// We use the qualified name to avoid surprises.
  static const String _androidQualifiedReceiver =
      'com.example.liflow.TaskWidgetProvider';

  // iOS WidgetKit widget name (must match the widget target name/kind).
  static const String _iosWidgetName = 'LiflowWidget';

  WidgetTaskSnapshotService(this._firestore);

  /// Updates the widget for today.
  ///
  /// [cutoffTime] must be in "HH:mm" format (e.g. "12:00").
  Future<void> updateToday({required String cutoffTime}) async {
    final now = DateTime.now();
    final weekId = DateIds.routineWeekId;
    final dayId = DateIds.routineDayId(now);
    await updateForDay(
      weekId: weekId,
      dayId: dayId,
      date: now,
      cutoffTime: cutoffTime,
    );
  }

  /// Updates the widget for a specific day.
  ///
  /// This is used both by the app and by the widget interactivity callback.
  Future<void> updateForDay({
    required String weekId,
    required String dayId,
    required DateTime date,
    required String cutoffTime,
  }) async {
    List<Activity> activities;
    try {
      activities = await _fetchDayActivities(weekId: weekId, dayId: dayId);
    } on FirebaseException {
      // If Firestore is not accessible (e.g. permission-denied), do not crash.
      return;
    }

    final tasks = _buildTasksJson(
      weekId: weekId,
      dayId: dayId,
      date: date,
      activities: activities,
      cutoffTime: cutoffTime,
    );

    final dayTasks = _buildDayTasksJson(
      weekId: weekId,
      dayId: dayId,
      date: date,
      activities: activities,
    );

    // We keep the API signature compatible, but the widget now shows the day split
    // (Manhã/Tarde/Noite) so we don't apply a cutoff filter anymore.
    final title = 'Tarefas de hoje';
    final subtitle = 'Hoje • ${DateIds.dayId(date)}';

    await HomeWidget.saveWidgetData<String>(WidgetKeys.title, title);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.subtitle, subtitle);
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.tasksJson,
      jsonEncode(tasks),
    );

    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.dayTasksJson,
      jsonEncode(dayTasks),
    );

    await HomeWidget.updateWidget(
      qualifiedAndroidName: _androidQualifiedReceiver,
      iOSName: _iosWidgetName,
    );
  }

  Future<List<Activity>> _fetchDayActivities({
    required String weekId,
    required String dayId,
  }) async {
    return _firestore.getDayActivities(weekId: weekId, dayId: dayId);
  }

  List<Map<String, dynamic>> _buildTasksJson({
    required String weekId,
    required String dayId,
    required DateTime date,
    required List<Activity> activities,
    required String cutoffTime,
  }) {
    final pending = activities.where((a) => !_isDoneForDate(a, date)).toList();

    // They should already be sorted by Firestore query (scheduledTime, order),
    // but we keep a stable local sort as a safety net.
    pending.sort((a, b) {
      final at = a.scheduledTime ?? '99:99';
      final bt = b.scheduledTime ?? '99:99';
      final c1 = at.compareTo(bt);
      if (c1 != 0) return c1;
      return a.order.compareTo(b.order);
    });

    bool isMorning(Activity a) {
      final minutes = _parseMinutes(a.scheduledTime ?? '');
      if (minutes == null) return false;
      return minutes >= 5 * 60 && minutes < 12 * 60;
    }

    bool isAfternoon(Activity a) {
      final minutes = _parseMinutes(a.scheduledTime ?? '');
      if (minutes == null) return false;
      return minutes >= 12 * 60 && minutes < 18 * 60;
    }

    bool isNight(Activity a) {
      final minutes = _parseMinutes(a.scheduledTime ?? '');
      if (minutes == null) return true;
      return minutes < 5 * 60 || minutes >= 18 * 60;
    }

    final morning = pending.where(isMorning).toList();
    final afternoon = pending.where(isAfternoon).toList();
    final night = pending.where(isNight).toList();

    final entries = <Map<String, dynamic>>[];

    void addHeader(String text) {
      entries.add(<String, dynamic>{'type': 'header', 'text': text});
    }

    void addTask(Activity a) {
      final id = a.id;
      entries.add(<String, dynamic>{
        'type': 'task',
        'activityId': id ?? '',
        'weekId': weekId,
        'dayId': dayId,
        'text': '${a.scheduledTime ?? ''}  •  ${a.title}',
      });
    }

    void addGroup(String header, List<Activity> list) {
      if (list.isEmpty) return;
      addHeader(header);
      for (final a in list) {
        if (entries.length >= 8) return;
        addTask(a);
        if (entries.length >= 8) return;
      }
    }

    addGroup('MANHÃ', morning);
    addGroup('TARDE', afternoon);
    addGroup('NOITE', night);

    return entries.take(8).toList();
  }

  /// iOS widget payload: pending tasks with time + title.
  ///
  /// The widget will pick the current one based on "now" and the next scheduled time.
  List<Map<String, dynamic>> _buildDayTasksJson({
    required String weekId,
    required String dayId,
    required DateTime date,
    required List<Activity> activities,
  }) {
    final pending = activities
        .where((a) => !_isDoneForDate(a, date))
        .where((a) => (a.scheduledTime ?? '').isNotEmpty)
        .toList();

    pending.sort((a, b) {
      final at = a.scheduledTime ?? '99:99';
      final bt = b.scheduledTime ?? '99:99';
      final c1 = at.compareTo(bt);
      if (c1 != 0) return c1;
      return a.order.compareTo(b.order);
    });

    return pending.map((a) {
      return <String, dynamic>{
        'activityId': a.id ?? '',
        'weekId': weekId,
        'dayId': dayId,
        'time': a.scheduledTime ?? '',
        'title': a.title,
      };
    }).toList();
  }

  int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23) return null;
    if (m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  bool _isDoneForDate(Activity activity, DateTime date) {
    if (activity.status != ActivityStatus.done) return false;
    final completedAt = activity.completedAt;
    if (completedAt == null) return false;

    return completedAt.year == date.year &&
        completedAt.month == date.month &&
        completedAt.day == date.day;
  }
}
