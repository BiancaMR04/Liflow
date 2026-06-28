import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

class WorkoutSession {
  final String? id;
  final String workoutId;
  final String workoutName;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationSeconds;
  final int exercisesDone;
  final int setsDone;
  final double totalVolume;

  const WorkoutSession({
    this.id,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    required this.completedAt,
    required this.durationSeconds,
    required this.exercisesDone,
    required this.setsDone,
    required this.totalVolume,
  });

  factory WorkoutSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return WorkoutSession(
      id: doc.id,
      workoutId: FirestoreSerializers.stringOrNull(data['workoutId']) ?? '',
      workoutName: FirestoreSerializers.stringOrNull(data['workoutName']) ?? '',
      startedAt:
          FirestoreSerializers.dateTimeFromTimestamp(data['startedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt:
          FirestoreSerializers.dateTimeFromTimestamp(data['completedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: FirestoreSerializers.intOrZero(data['durationSeconds']),
      exercisesDone: FirestoreSerializers.intOrZero(data['exercisesDone']),
      setsDone: FirestoreSerializers.intOrZero(data['setsDone']),
      totalVolume: _doubleOrZero(data['totalVolume']),
    );
  }

  static double _doubleOrZero(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'workoutId': workoutId,
      'workoutName': workoutName,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(completedAt),
      'durationSeconds': durationSeconds,
      'exercisesDone': exercisesDone,
      'setsDone': setsDone,
      'totalVolume': totalVolume,
    };
  }
}

class ExerciseHistory {
  final String? id;
  final String sessionId;
  final String workoutId;
  final String workoutName;
  final String workoutExerciseId;
  final String exerciseId;
  final String exerciseName;
  final DateTime date;
  final int setNumber;
  final int reps;
  final double loadKg;
  final int executionSeconds;
  final int restSeconds;
  final int? rpe;
  final bool failure;
  final String? notes;

  const ExerciseHistory({
    this.id,
    required this.sessionId,
    required this.workoutId,
    required this.workoutName,
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.date,
    required this.setNumber,
    required this.reps,
    required this.loadKg,
    required this.executionSeconds,
    required this.restSeconds,
    this.rpe,
    required this.failure,
    this.notes,
  });

  double get volume => reps * loadKg;

  factory ExerciseHistory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExerciseHistory(
      id: doc.id,
      sessionId: FirestoreSerializers.stringOrNull(data['sessionId']) ?? '',
      workoutId: FirestoreSerializers.stringOrNull(data['workoutId']) ?? '',
      workoutName: FirestoreSerializers.stringOrNull(data['workoutName']) ?? '',
      workoutExerciseId:
          FirestoreSerializers.stringOrNull(data['workoutExerciseId']) ?? '',
      exerciseId: FirestoreSerializers.stringOrNull(data['exerciseId']) ?? '',
      exerciseName:
          FirestoreSerializers.stringOrNull(data['exerciseName']) ?? '',
      date:
          FirestoreSerializers.dateTimeFromTimestamp(data['date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      setNumber: FirestoreSerializers.intOrZero(data['setNumber']),
      reps: FirestoreSerializers.intOrZero(data['reps']),
      loadKg: _doubleOrZero(data['loadKg']),
      executionSeconds: FirestoreSerializers.intOrZero(
        data['executionSeconds'],
      ),
      restSeconds: FirestoreSerializers.intOrZero(data['restSeconds']),
      rpe: data['rpe'] == null
          ? null
          : FirestoreSerializers.intOrZero(data['rpe']),
      failure: FirestoreSerializers.boolOrFalse(data['failure']),
      notes: FirestoreSerializers.stringOrNull(data['notes']),
    );
  }

  static double _doubleOrZero(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'workoutId': workoutId,
      'workoutName': workoutName,
      'workoutExerciseId': workoutExerciseId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'date': Timestamp.fromDate(date),
      'setNumber': setNumber,
      'reps': reps,
      'loadKg': loadKg,
      'executionSeconds': executionSeconds,
      'restSeconds': restSeconds,
      'rpe': rpe,
      'failure': failure,
      'notes': notes,
      'volume': volume,
    };
  }
}
