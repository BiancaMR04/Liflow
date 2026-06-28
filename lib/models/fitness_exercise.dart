import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

class MuscleGroups {
  static const List<String> all = <String>[
    'Peito',
    'Costas',
    'Ombro',
    'Bíceps',
    'Tríceps',
    'Quadríceps',
    'Posterior',
    'Glúteo',
    'Panturrilha',
    'Abdômen',
    'Cardio',
  ];
}

class FitnessExercise {
  final String? id;
  final String name;
  final String muscleGroup;
  final String? notes;
  final String? imageUrl;
  final String? videoUrl;
  final String? youtubeUrl;
  final bool favorite;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FitnessExercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    this.notes,
    this.imageUrl,
    this.videoUrl,
    this.youtubeUrl,
    this.favorite = false,
    this.useCount = 0,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
  });

  FitnessExercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? notes,
    String? imageUrl,
    String? videoUrl,
    String? youtubeUrl,
    bool? favorite,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      favorite: favorite ?? this.favorite,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FitnessExercise.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return FitnessExercise(
      id: doc.id,
      name: FirestoreSerializers.stringOrNull(data['name']) ?? '',
      muscleGroup:
          FirestoreSerializers.stringOrNull(data['muscleGroup']) ?? 'Peito',
      notes: FirestoreSerializers.stringOrNull(data['notes']),
      imageUrl: FirestoreSerializers.stringOrNull(data['imageUrl']),
      videoUrl: FirestoreSerializers.stringOrNull(data['videoUrl']),
      youtubeUrl: FirestoreSerializers.stringOrNull(data['youtubeUrl']),
      favorite: FirestoreSerializers.boolOrFalse(data['favorite']),
      useCount: FirestoreSerializers.intOrZero(data['useCount']),
      lastUsedAt: FirestoreSerializers.dateTimeFromTimestamp(
        data['lastUsedAt'],
      ),
      createdAt: FirestoreSerializers.dateTimeFromTimestamp(data['createdAt']),
      updatedAt: FirestoreSerializers.dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'muscleGroup': muscleGroup,
      'notes': notes,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'youtubeUrl': youtubeUrl,
      'favorite': favorite,
      'useCount': useCount,
      if (lastUsedAt != null) 'lastUsedAt': Timestamp.fromDate(lastUsedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
