import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

/// Activity completion status.
///
/// Stored as a string in Firestore for easy querying and debugging.
enum ActivityStatus {
  pending('pending'),
  done('done'),
  skipped('skipped');

  final String value;

  const ActivityStatus(this.value);

  static ActivityStatus fromFirestore(Object? value) {
    final asString = FirestoreSerializers.stringOrNull(value);
    return ActivityStatus.values.firstWhere(
      (s) => s.value == asString,
      orElse: () => ActivityStatus.pending,
    );
  }
}

/// Activity model.
///
/// Stored under:
/// profiles/default/weeks/{weekId}/days/{dayId}/activities/{activityId}
///
/// Notes:
/// - `scheduledTime` is stored as "HH:mm" (string) to keep it stable and simple.
/// - `reminder` is a map to allow evolution without breaking the schema.
class Activity {
  /// Firestore document id.
  ///
  /// When creating a new activity (before writing to Firestore), this can be null.
  final String? id;
  final String title;
  final String? description;

  final ActivityStatus status;
  final int order;

  /// Example: "08:30".
  final String? scheduledTime;

  /// Reminder config (kept in a map for flexibility).
  /// Typical keys: enabled (bool), remindAt (Timestamp), notificationId (int).
  final Map<String, dynamic> reminder;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const Activity({
    this.id,
    required this.title,
    required this.status,
    required this.order,
    this.description,
    this.scheduledTime,
    this.reminder = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    ActivityStatus? status,
    int? order,
    String? scheduledTime,
    Map<String, dynamic>? reminder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      order: order ?? this.order,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      reminder: reminder ?? this.reminder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isDone => status == ActivityStatus.done;

  /// Resets completion state (used when duplicating days).
  Activity resetCompletion() {
    return copyWith(status: ActivityStatus.pending, completedAt: null);
  }

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final reminderMap = FirestoreSerializers.mapOrEmpty(data['reminder']);

    return Activity(
      id: doc.id,
      title: FirestoreSerializers.stringOrNull(data['title']) ?? '',
      description: FirestoreSerializers.stringOrNull(data['description']),
      status: ActivityStatus.fromFirestore(data['status']),
      order: FirestoreSerializers.intOrZero(data['order']),
      scheduledTime: FirestoreSerializers.stringOrNull(data['scheduledTime']),
      reminder: reminderMap,
      createdAt: FirestoreSerializers.dateTimeFromTimestamp(data['createdAt']),
      updatedAt: FirestoreSerializers.dateTimeFromTimestamp(data['updatedAt']),
      completedAt: FirestoreSerializers.dateTimeFromTimestamp(data['completedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'status': status.value,
      'order': order,
      'scheduledTime': scheduledTime,
      'reminder': reminder,
      if (createdAt != null)
        'createdAt': FirestoreSerializers.timestampFromDateTime(createdAt),
      if (updatedAt != null)
        'updatedAt': FirestoreSerializers.timestampFromDateTime(updatedAt),
      if (completedAt != null)
        'completedAt': FirestoreSerializers.timestampFromDateTime(completedAt),
    };
  }

  /// Creates a Firestore payload intended for duplicating this activity into another day.
  ///
  /// Applies your business rules:
  /// - Copies schedule (`scheduledTime`) and `reminder`
  /// - Resets completion (`status`, `completedAt`)
  Map<String, dynamic> toFirestoreForCopy({required DateTime now}) {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'status': ActivityStatus.pending.value,
      'order': order,
      'scheduledTime': scheduledTime,
      'reminder': reminder,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      // completedAt intentionally omitted
    };
  }
}
