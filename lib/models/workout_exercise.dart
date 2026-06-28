import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

class WorkoutExercise {
  final String? id;
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String? notes;
  final String? imageUrl;
  final String? videoUrl;
  final String? youtubeUrl;
  final int sets;
  final int reps;
  final double loadKg;
  final int restSeconds;
  final int executionSeconds;
  final int secondsPerRep;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkoutExercise({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    this.notes,
    this.imageUrl,
    this.videoUrl,
    this.youtubeUrl,
    required this.sets,
    required this.reps,
    required this.loadKg,
    required this.restSeconds,
    required this.executionSeconds,
    required this.secondsPerRep,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    String? muscleGroup,
    String? notes,
    String? imageUrl,
    String? videoUrl,
    String? youtubeUrl,
    int? sets,
    int? reps,
    double? loadKg,
    int? restSeconds,
    int? executionSeconds,
    int? secondsPerRep,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      loadKg: loadKg ?? this.loadKg,
      restSeconds: restSeconds ?? this.restSeconds,
      executionSeconds: executionSeconds ?? this.executionSeconds,
      secondsPerRep: secondsPerRep ?? this.secondsPerRep,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WorkoutExercise.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return WorkoutExercise(
      id: doc.id,
      exerciseId: FirestoreSerializers.stringOrNull(data['exerciseId']) ?? '',
      exerciseName:
          FirestoreSerializers.stringOrNull(data['exerciseName']) ?? '',
      muscleGroup:
          FirestoreSerializers.stringOrNull(data['muscleGroup']) ?? 'Peito',
      notes: FirestoreSerializers.stringOrNull(data['notes']),
      imageUrl: FirestoreSerializers.stringOrNull(data['imageUrl']),
      videoUrl: FirestoreSerializers.stringOrNull(data['videoUrl']),
      youtubeUrl: FirestoreSerializers.stringOrNull(data['youtubeUrl']),
      sets: FirestoreSerializers.intOrZero(data['sets']),
      reps: FirestoreSerializers.intOrZero(data['reps']),
      loadKg: _doubleOrZero(data['loadKg']),
      restSeconds: FirestoreSerializers.intOrZero(data['restSeconds']),
      executionSeconds: FirestoreSerializers.intOrZero(
        data['executionSeconds'],
      ),
      secondsPerRep: FirestoreSerializers.intOrZero(data['secondsPerRep']),
      order: FirestoreSerializers.intOrZero(data['order']),
      createdAt: FirestoreSerializers.dateTimeFromTimestamp(data['createdAt']),
      updatedAt: FirestoreSerializers.dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  static double _doubleOrZero(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'muscleGroup': muscleGroup,
      'notes': notes,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'youtubeUrl': youtubeUrl,
      'sets': sets,
      'reps': reps,
      'loadKg': loadKg,
      'restSeconds': restSeconds,
      'executionSeconds': executionSeconds,
      'secondsPerRep': secondsPerRep,
      'order': order,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
