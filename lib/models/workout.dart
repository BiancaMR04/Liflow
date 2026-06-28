import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_serializers.dart';

class Workout {
  final String? id;
  final String name;
  final String? description;
  final int colorValue;
  final String iconName;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Workout({
    this.id,
    required this.name,
    this.description,
    required this.colorValue,
    required this.iconName,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  Workout copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    String? iconName,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Workout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Workout(
      id: doc.id,
      name: FirestoreSerializers.stringOrNull(data['name']) ?? '',
      description: FirestoreSerializers.stringOrNull(data['description']),
      colorValue: FirestoreSerializers.intOrZero(data['colorValue']),
      iconName:
          FirestoreSerializers.stringOrNull(data['iconName']) ?? 'fitness',
      order: FirestoreSerializers.intOrZero(data['order']),
      createdAt: FirestoreSerializers.dateTimeFromTimestamp(data['createdAt']),
      updatedAt: FirestoreSerializers.dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'iconName': iconName,
      'order': order,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
