import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity.dart';
import '../models/subtask.dart';

/// Basic Firestore read/write service for days, activities and subtasks.
///
/// This is intentionally simple and focused:
/// - It does not depend on any UI/state management
/// - It keeps path building centralized
/// - It returns models (Activity/Subtask) and exposes Streams
///
/// Firestore structure (typical):
/// profiles/{profileId}/weeks/{weekId}/days/{dayId}/activities/{activityId}/subtasks/{subtaskId}
class FirestoreActivityService {
  final FirebaseFirestore _db;

  /// Optional explicit profile id override.
  ///
  /// When not provided, we derive it from the current authenticated user's uid.
  final String? _profileIdOverride;

  /// The root profile document id.
  ///
  /// Defaults to the current authenticated user's uid (including anonymous auth).
  /// Falls back to 'default' when there is no user (Firestore calls may be denied by rules).
  String get profileId =>
      _profileIdOverride ?? FirebaseAuth.instance.currentUser?.uid ?? 'default';

  FirestoreActivityService({FirebaseFirestore? firestore, String? profileId})
    : _db = firestore ?? FirebaseFirestore.instance,
      _profileIdOverride = profileId;

  DocumentReference<Map<String, dynamic>> _profileRef() {
    return _db.collection('profiles').doc(profileId);
  }

  CollectionReference<Map<String, dynamic>> _weeksCol() {
    return _profileRef().collection('weeks');
  }

  DocumentReference<Map<String, dynamic>> _weekRef(String weekId) {
    return _weeksCol().doc(weekId);
  }

  CollectionReference<Map<String, dynamic>> _daysCol(String weekId) {
    return _weekRef(weekId).collection('days');
  }

  DocumentReference<Map<String, dynamic>> _dayRef(String weekId, String dayId) {
    return _daysCol(weekId).doc(dayId);
  }

  /// Watches the stored mood for a day (ritual do dia).
  ///
  /// Stored on the day document to keep it lightweight:
  /// - ritualMood: 'low' | 'ok' | 'high'
  /// - ritualUpdatedAt: Timestamp
  Stream<String?> watchDayRitualMood({
    required String weekId,
    required String dayId,
  }) {
    return _dayRef(weekId, dayId).snapshots().map((doc) {
      final data = doc.data();
      final mood = data?['ritualMood'];
      return mood is String ? mood : null;
    });
  }

  /// Sets the mood for a day (ritual do dia).
  Future<void> setDayRitualMood({
    required String weekId,
    required String dayId,
    required DateTime date,
    required String mood,
  }) async {
    await ensureDayExists(weekId: weekId, dayId: dayId, date: date);

    await _dayRef(weekId, dayId).set(<String, dynamic>{
      'ritualMood': mood,
      'ritualUpdatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _activitiesCol(
    String weekId,
    String dayId,
  ) {
    return _dayRef(weekId, dayId).collection('activities');
  }

  DocumentReference<Map<String, dynamic>> _activityRef(
    String weekId,
    String dayId,
    String activityId,
  ) {
    return _activitiesCol(weekId, dayId).doc(activityId);
  }

  CollectionReference<Map<String, dynamic>> _subtasksCol(
    String weekId,
    String dayId,
    String activityId,
  ) {
    return _activityRef(weekId, dayId, activityId).collection('subtasks');
  }

  DateTime _atTimeOfDay({
    required DateTime day,
    required int hour,
    required int minute,
  }) {
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  void _sortActivitiesInPlace(List<Activity> items) {
    items.sort((a, b) {
      final at = (a.scheduledTime == null || a.scheduledTime!.isEmpty)
          ? '99:99'
          : a.scheduledTime!;
      final bt = (b.scheduledTime == null || b.scheduledTime!.isEmpty)
          ? '99:99'
          : b.scheduledTime!;
      final c1 = at.compareTo(bt);
      if (c1 != 0) return c1;
      return a.order.compareTo(b.order);
    });
  }

  /// Parses a "HH:mm" string.
  ///
  /// Returns null if invalid.
  ({int hour, int minute})? _parseHHmm(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    return (hour: hour, minute: minute);
  }

  Map<String, dynamic> _reminderForCopiedDay({
    required Map<String, dynamic> original,
    required DateTime targetDay,
    String? scheduledTime,
  }) {
    // Business rules:
    // - Copy reminders
    // - Re-schedule remindAt to the new date
    // - Do NOT carry over local notification identifiers
    final reminder = Map<String, dynamic>.from(original);

    final enabled = reminder['enabled'] == true;
    if (!enabled) {
      reminder.remove('notificationId');
      return reminder;
    }

    // Prefer scheduledTime; fallback to existing remindAt time-of-day.
    final parsed = _parseHHmm(scheduledTime);
    int? hour = parsed?.hour;
    int? minute = parsed?.minute;

    if (hour == null || minute == null) {
      final remindAt = reminder['remindAt'];
      if (remindAt is Timestamp) {
        final dt = remindAt.toDate();
        hour = dt.hour;
        minute = dt.minute;
      }
    }

    if (hour != null && minute != null) {
      reminder['remindAt'] = Timestamp.fromDate(
        _atTimeOfDay(day: targetDay, hour: hour, minute: minute),
      );
    }

    reminder.remove('notificationId');
    return reminder;
  }

  /// Ensures the day document exists.
  ///
  /// We use merge=true to make it idempotent.
  Future<void> ensureDayExists({
    required String weekId,
    required String dayId,
    required DateTime date,
  }) async {
    await _dayRef(weekId, dayId).set(<String, dynamic>{
      'date': Timestamp.fromDate(date),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Watches all activities of a day.
  ///
  /// Ordering rule:
  /// - primary: scheduledTime
  /// - secondary: order
  ///
  /// Note: Firestore sorts strings lexicographically; with "HH:mm" this matches time order.
  Stream<List<Activity>> watchDayActivities({
    required String weekId,
    required String dayId,
  }) {
    return _activitiesCol(
      weekId,
      dayId,
    ).orderBy('scheduledTime').snapshots().map((snapshot) {
      final items = snapshot.docs.map(Activity.fromDoc).toList();
      // Keep the desired secondary ordering without needing a composite index.
      _sortActivitiesInPlace(items);
      return items;
    });
  }

  /// Fetches all activities of a day (one-shot read).
  ///
  /// Ordering rule matches the widget and the main screen:
  /// - primary: scheduledTime
  /// - secondary: order
  Future<List<Activity>> getDayActivities({
    required String weekId,
    required String dayId,
  }) async {
    final snapshot = await _activitiesCol(
      weekId,
      dayId,
    ).orderBy('scheduledTime').get();

    final items = snapshot.docs.map(Activity.fromDoc).toList();
    _sortActivitiesInPlace(items);
    return items;
  }

  /// Watches only NOT completed activities.
  ///
  /// We filter client-side to keep query simple and avoid Firestore inequality quirks.
  Stream<List<Activity>> watchDayPendingActivities({
    required String weekId,
    required String dayId,
  }) {
    return watchDayActivities(weekId: weekId, dayId: dayId).map(
      (items) => items.where((a) => a.status != ActivityStatus.done).toList(),
    );
  }

  /// Adds a new activity and returns its generated id.
  Future<String> createActivity({
    required String weekId,
    required String dayId,
    required Activity activity,
  }) async {
    final now = Timestamp.now();

    final payload = activity.copyWith(
      // Creation defaults.
      createdAt: activity.createdAt ?? now.toDate(),
      updatedAt: now.toDate(),
    );

    final docRef = await _activitiesCol(
      weekId,
      dayId,
    ).add(payload.toFirestore());
    return docRef.id;
  }

  /// Creates or updates an activity with a known id.
  Future<void> upsertActivity({
    required String weekId,
    required String dayId,
    required Activity activity,
  }) async {
    final id = activity.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Activity.id is required for upsertActivity');
    }

    await _activityRef(
      weekId,
      dayId,
      id,
    ).set(activity.toFirestore(), SetOptions(merge: true));
  }

  /// Marks an activity as done/undone.
  ///
  /// Business rule:
  /// - When done=true -> sets status=done and completedAt=now
  /// - When done=false -> resets to pending and clears completedAt
  Future<void> setActivityDone({
    required String weekId,
    required String dayId,
    required String activityId,
    required bool done,
  }) async {
    await _activityRef(weekId, dayId, activityId).update(<String, dynamic>{
      'status': done ? ActivityStatus.done.value : ActivityStatus.pending.value,
      'completedAt': done ? Timestamp.now() : null,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Deletes an activity and all its subtasks.
  ///
  /// Firestore does not cascade deletes automatically.
  Future<void> deleteActivity({
    required String weekId,
    required String dayId,
    required String activityId,
  }) async {
    final batch = _db.batch();

    final subtasks = await _subtasksCol(weekId, dayId, activityId).get();
    for (final subtaskDoc in subtasks.docs) {
      batch.delete(subtaskDoc.reference);
    }

    batch.delete(_activityRef(weekId, dayId, activityId));
    await batch.commit();
  }

  /// Deletes ALL activities for a day (and their subtasks).
  ///
  /// Useful for your "SUBSTITUIR" duplication rule.
  Future<void> deleteAllActivitiesForDay({
    required String weekId,
    required String dayId,
  }) async {
    final activities = await _activitiesCol(weekId, dayId).get();

    final batch = _db.batch();

    for (final activityDoc in activities.docs) {
      final subtasks = await activityDoc.reference.collection('subtasks').get();
      for (final subtaskDoc in subtasks.docs) {
        batch.delete(subtaskDoc.reference);
      }
      batch.delete(activityDoc.reference);
    }

    await batch.commit();
  }

  /// Duplicates ALL activities from a source day into a target day using the
  /// "SUBSTITUIR" policy.
  ///
  /// Rules applied:
  /// - Target day is cleaned before copy (no merge)
  /// - Activities are copied with schedule preserved (scheduledTime)
  /// - Reminders are copied and re-scheduled to the target date
  /// - Completion state is reset (status/pending, completedAt null)
  /// - Subtasks are copied with done=false and completedAt null
  /// - Writes are performed in a batch for consistency
  ///
  /// Note: This operation is idempotent *per user command* (the caller should
  /// not auto-retry silently). If the user runs it twice, it will overwrite
  /// the target day twice, producing the same result (clean + copy).
  Future<void> duplicateDayReplace({
    required String sourceWeekId,
    required String sourceDayId,
    required String targetWeekId,
    required String targetDayId,
    required DateTime targetDate,
  }) async {
    // Basic validation.
    if (sourceWeekId == targetWeekId && sourceDayId == targetDayId) {
      throw ArgumentError('Source and target day must be different');
    }

    // Ensure target day doc exists.
    await ensureDayExists(
      weekId: targetWeekId,
      dayId: targetDayId,
      date: targetDate,
    );

    // Read source activities.
    final sourceActivitiesSnap = await _activitiesCol(
      sourceWeekId,
      sourceDayId,
    ).orderBy('scheduledTime').get();

    // Clean target day first.
    await deleteAllActivitiesForDay(weekId: targetWeekId, dayId: targetDayId);

    // Copy.
    final now = DateTime.now();
    final batch = _db.batch();

    for (final sourceActivityDoc in sourceActivitiesSnap.docs) {
      final sourceActivity = Activity.fromDoc(sourceActivityDoc);

      final newActivityRef = _activitiesCol(targetWeekId, targetDayId).doc();

      final copiedReminder = _reminderForCopiedDay(
        original: sourceActivity.reminder,
        targetDay: targetDate,
        scheduledTime: sourceActivity.scheduledTime,
      );

      final activityPayload = sourceActivity
          .copyWith(reminder: copiedReminder)
          .toFirestoreForCopy(now: now);

      batch.set(newActivityRef, activityPayload);

      // Copy subtasks.
      final sourceSubtasksSnap = await sourceActivityDoc.reference
          .collection('subtasks')
          .orderBy('order')
          .get();
      for (final sourceSubtaskDoc in sourceSubtasksSnap.docs) {
        final subtask = Subtask.fromDoc(sourceSubtaskDoc);
        final newSubtaskRef = newActivityRef.collection('subtasks').doc();
        batch.set(newSubtaskRef, subtask.toFirestoreResetCompletion(now: now));
      }
    }

    // Mark metadata on target day.
    batch.set(_dayRef(targetWeekId, targetDayId), <String, dynamic>{
      'updatedAt': Timestamp.now(),
      'copiedFromDayRef': _dayRef(sourceWeekId, sourceDayId),
      'copyMetadata': <String, dynamic>{
        'copiedAt': Timestamp.now(),
        'mode': 'replace',
      },
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Watches subtasks for a given activity.
  Stream<List<Subtask>> watchSubtasks({
    required String weekId,
    required String dayId,
    required String activityId,
  }) {
    return _subtasksCol(weekId, dayId, activityId)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Subtask.fromDoc).toList());
  }

  Future<String> createSubtask({
    required String weekId,
    required String dayId,
    required String activityId,
    required Subtask subtask,
  }) async {
    final now = Timestamp.now();

    final payload = subtask.copyWith(
      createdAt: subtask.createdAt ?? now.toDate(),
      updatedAt: now.toDate(),
    );

    final docRef = await _subtasksCol(
      weekId,
      dayId,
      activityId,
    ).add(payload.toFirestore());

    return docRef.id;
  }

  Future<void> upsertSubtask({
    required String weekId,
    required String dayId,
    required String activityId,
    required Subtask subtask,
  }) async {
    final id = subtask.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Subtask.id is required for upsertSubtask');
    }

    await _subtasksCol(
      weekId,
      dayId,
      activityId,
    ).doc(id).set(subtask.toFirestore(), SetOptions(merge: true));
  }

  /// Marks a subtask as done/undone.
  Future<void> setSubtaskDone({
    required String weekId,
    required String dayId,
    required String activityId,
    required String subtaskId,
    required bool done,
  }) async {
    await _subtasksCol(
      weekId,
      dayId,
      activityId,
    ).doc(subtaskId).update(<String, dynamic>{
      'done': done,
      'completedAt': done ? Timestamp.now() : null,
      'updatedAt': Timestamp.now(),
    });
  }
}
