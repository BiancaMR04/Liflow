import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

/// Subtask model.
///
/// Stored under:
/// profiles/default/weeks/{weekId}/days/{dayId}/activities/{activityId}/subtasks/{subtaskId}
class Subtask {
  /// Firestore document id.
  ///
  /// When creating a new subtask (before writing to Firestore), this can be null.
  final String? id;
  final String title;
  final bool done;
  final int order;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const Subtask({
    this.id,
    required this.title,
    required this.done,
    required this.order,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  Subtask copyWith({
    String? id,
    String? title,
    bool? done,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Resets completion state (used when duplicating days).
  Subtask resetCompletion() {
    return copyWith(done: false, completedAt: null);
  }

  /// Creates a Subtask from a Firestore document.
  factory Subtask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Subtask(
      id: doc.id,
      title: FirestoreSerializers.stringOrNull(data['title']) ?? '',
      done: FirestoreSerializers.boolOrFalse(data['done']),
      order: FirestoreSerializers.intOrZero(data['order']),
      createdAt: FirestoreSerializers.dateTimeFromTimestamp(data['createdAt']),
      updatedAt: FirestoreSerializers.dateTimeFromTimestamp(data['updatedAt']),
      completedAt: FirestoreSerializers.dateTimeFromTimestamp(data['completedAt']),
    );
  }

  /// Firestore payload (does not include id).
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'title': title,
      'done': done,
      'order': order,
      if (createdAt != null)
        'createdAt': FirestoreSerializers.timestampFromDateTime(createdAt),
      if (updatedAt != null)
        'updatedAt': FirestoreSerializers.timestampFromDateTime(updatedAt),
      if (completedAt != null)
        'completedAt': FirestoreSerializers.timestampFromDateTime(completedAt),
    };
  }

  /// Creates a payload with completion reset. Useful for copying.
  Map<String, dynamic> toFirestoreResetCompletion({required DateTime now}) {
    return <String, dynamic>{
      'title': title,
      'done': false,
      'order': order,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      // completedAt intentionally omitted
    };
  }
}
