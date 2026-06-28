import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/fitness_exercise.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';

class FitnessService {
  final FirebaseFirestore _db;
  final String? _profileIdOverride;

  FitnessService({FirebaseFirestore? firestore, String? profileId})
    : _db = firestore ?? FirebaseFirestore.instance,
      _profileIdOverride = profileId;

  String get profileId =>
      _profileIdOverride ?? FirebaseAuth.instance.currentUser?.uid ?? 'default';

  DocumentReference<Map<String, dynamic>> _profileRef() {
    return _db.collection('profiles').doc(profileId);
  }

  DocumentReference<Map<String, dynamic>> _fitnessRef() {
    return _profileRef().collection('fitness').doc('data');
  }

  CollectionReference<Map<String, dynamic>> _workoutsCol() {
    return _fitnessRef().collection('workouts');
  }

  DocumentReference<Map<String, dynamic>> _workoutRef(String workoutId) {
    return _workoutsCol().doc(workoutId);
  }

  CollectionReference<Map<String, dynamic>> _workoutExercisesCol(
    String workoutId,
  ) {
    return _workoutRef(workoutId).collection('exercises');
  }

  CollectionReference<Map<String, dynamic>> _libraryCol() {
    return _fitnessRef().collection('exercises');
  }

  DocumentReference<Map<String, dynamic>> _libraryExerciseRef(String id) {
    return _libraryCol().doc(id);
  }

  CollectionReference<Map<String, dynamic>> _sessionsCol() {
    return _fitnessRef().collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> _historyCol() {
    return _fitnessRef().collection('history');
  }

  void _sortWorkoutsInPlace(List<Workout> items) {
    items.sort((a, b) {
      final c1 = a.order.compareTo(b.order);
      if (c1 != 0) return c1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  void _sortWorkoutExercisesInPlace(List<WorkoutExercise> items) {
    items.sort((a, b) => a.order.compareTo(b.order));
  }

  void _sortLibraryInPlace(List<FitnessExercise> items) {
    items.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Stream<List<Workout>> watchWorkouts() {
    return _workoutsCol().snapshots().map((snapshot) {
      final items = snapshot.docs.map(Workout.fromDoc).toList();
      _sortWorkoutsInPlace(items);
      return items;
    });
  }

  Future<List<Workout>> getWorkouts() async {
    final snapshot = await _workoutsCol().get();
    final items = snapshot.docs.map(Workout.fromDoc).toList();
    _sortWorkoutsInPlace(items);
    return items;
  }

  Future<String> createWorkout(Workout workout) async {
    final now = DateTime.now();
    final doc = await _workoutsCol().add(
      workout
          .copyWith(
            createdAt: workout.createdAt ?? now,
            updatedAt: now,
            order: workout.order == 0
                ? now.millisecondsSinceEpoch
                : workout.order,
          )
          .toFirestore(),
    );
    return doc.id;
  }

  Future<void> updateWorkout(Workout workout) async {
    final id = workout.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Workout.id is required for updateWorkout');
    }

    await _workoutRef(id).set(
      workout.copyWith(updatedAt: DateTime.now()).toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteWorkout(String workoutId) async {
    final batch = _db.batch();

    final items = await _workoutExercisesCol(workoutId).get();
    for (final item in items.docs) {
      batch.delete(item.reference);
    }

    batch.delete(_workoutRef(workoutId));
    await batch.commit();
  }

  Future<String> duplicateWorkout(String workoutId) async {
    final sourceDoc = await _workoutRef(workoutId).get();
    if (!sourceDoc.exists) throw ArgumentError('Workout not found');

    final source = Workout.fromDoc(sourceDoc);
    final now = DateTime.now();
    final copyRef = _workoutsCol().doc();

    final batch = _db.batch();
    batch.set(
      copyRef,
      source
          .copyWith(
            id: copyRef.id,
            name: '${source.name} (cópia)',
            order: now.millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
          )
          .toFirestore(),
    );

    final exercises = await _workoutExercisesCol(workoutId).get();
    for (final doc in exercises.docs) {
      final item = WorkoutExercise.fromDoc(doc);
      batch.set(
        _workoutExercisesCol(copyRef.id).doc(),
        item.copyWith(createdAt: now, updatedAt: now).toFirestore(),
      );
    }

    await batch.commit();
    return copyRef.id;
  }

  Stream<List<WorkoutExercise>> watchWorkoutExercises(String workoutId) {
    return _workoutExercisesCol(workoutId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(WorkoutExercise.fromDoc).toList();
      _sortWorkoutExercisesInPlace(items);
      return items;
    });
  }

  Future<List<WorkoutExercise>> getWorkoutExercises(String workoutId) async {
    final snapshot = await _workoutExercisesCol(workoutId).get();
    final items = snapshot.docs.map(WorkoutExercise.fromDoc).toList();
    _sortWorkoutExercisesInPlace(items);
    return items;
  }

  Future<String> upsertWorkoutExercise({
    required String workoutId,
    required WorkoutExercise item,
  }) async {
    final now = DateTime.now();
    final id = item.id;
    if (id == null || id.isEmpty) {
      final doc = await _workoutExercisesCol(
        workoutId,
      ).add(item.copyWith(createdAt: now, updatedAt: now).toFirestore());
      await markExerciseUsed(item.exerciseId);
      return doc.id;
    }

    await _workoutExercisesCol(workoutId)
        .doc(id)
        .set(
          item.copyWith(updatedAt: now).toFirestore(),
          SetOptions(merge: true),
        );
    await markExerciseUsed(item.exerciseId);
    return id;
  }

  Future<void> deleteWorkoutExercise({
    required String workoutId,
    required String itemId,
  }) async {
    await _workoutExercisesCol(workoutId).doc(itemId).delete();
  }

  Future<void> duplicateWorkoutExercise({
    required String workoutId,
    required WorkoutExercise item,
  }) async {
    final now = DateTime.now();
    await _workoutExercisesCol(workoutId).add(
      item
          .copyWith(
            order: now.millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
          )
          .toFirestore(),
    );
  }

  Future<void> reorderWorkoutExercises({
    required String workoutId,
    required List<WorkoutExercise> items,
  }) async {
    final batch = _db.batch();
    final now = Timestamp.now();

    for (var index = 0; index < items.length; index++) {
      final id = items[index].id;
      if (id == null) continue;
      batch.update(_workoutExercisesCol(workoutId).doc(id), <String, dynamic>{
        'order': index,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }

  Stream<List<FitnessExercise>> watchLibraryExercises() {
    return _libraryCol().snapshots().map((snapshot) {
      final items = snapshot.docs.map(FitnessExercise.fromDoc).toList();
      _sortLibraryInPlace(items);
      return items;
    });
  }

  Future<List<FitnessExercise>> getLibraryExercises() async {
    final snapshot = await _libraryCol().get();
    final items = snapshot.docs.map(FitnessExercise.fromDoc).toList();
    _sortLibraryInPlace(items);
    return items;
  }

  Future<String> upsertLibraryExercise(FitnessExercise exercise) async {
    final now = DateTime.now();
    final id = exercise.id;
    if (id == null || id.isEmpty) {
      final doc = await _libraryCol().add(
        exercise.copyWith(createdAt: now, updatedAt: now).toFirestore(),
      );
      return doc.id;
    }

    await _libraryExerciseRef(id).set(
      exercise.copyWith(updatedAt: now).toFirestore(),
      SetOptions(merge: true),
    );
    return id;
  }

  Future<void> deleteLibraryExercise(String exerciseId) async {
    await _libraryExerciseRef(exerciseId).delete();
  }

  Future<void> toggleFavoriteExercise({
    required String exerciseId,
    required bool favorite,
  }) async {
    await _libraryExerciseRef(exerciseId).set(<String, dynamic>{
      'favorite': favorite,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> markExerciseUsed(String exerciseId) async {
    if (exerciseId.isEmpty) return;
    await _libraryExerciseRef(exerciseId).set(<String, dynamic>{
      'useCount': FieldValue.increment(1),
      'lastUsedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Stream<List<WorkoutSession>> watchRecentSessions({int limit = 30}) {
    return _sessionsCol()
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(WorkoutSession.fromDoc).toList());
  }

  Stream<List<ExerciseHistory>> watchHistory({int limit = 250}) {
    return _historyCol()
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ExerciseHistory.fromDoc).toList());
  }

  Future<void> saveCompletedSession({
    required WorkoutSession session,
    required List<ExerciseHistory> history,
  }) async {
    final sessionRef = _sessionsCol().doc();
    final batch = _db.batch();

    batch.set(sessionRef, session.toFirestore());

    for (final item in history) {
      batch.set(
        _historyCol().doc(),
        item.copyWithSessionId(sessionRef.id).toFirestore(),
      );
      if (item.exerciseId.isNotEmpty) {
        batch.set(_libraryExerciseRef(item.exerciseId), <String, dynamic>{
          'useCount': FieldValue.increment(1),
          'lastUsedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }
}

extension on ExerciseHistory {
  ExerciseHistory copyWithSessionId(String sessionId) {
    return ExerciseHistory(
      id: id,
      sessionId: sessionId,
      workoutId: workoutId,
      workoutName: workoutName,
      workoutExerciseId: workoutExerciseId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      date: date,
      setNumber: setNumber,
      reps: reps,
      loadKg: loadKg,
      executionSeconds: executionSeconds,
      restSeconds: restSeconds,
      rpe: rpe,
      failure: failure,
      notes: notes,
    );
  }
}
