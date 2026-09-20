import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';

class ExerciseModel extends ExerciseEntity {
  const ExerciseModel({
    required super.id,
    required super.name,
    super.description,
    super.videoUrl,
    super.thumbnailUrl,
    required super.muscleGroups,
    required super.equipment,
    required super.difficulty,
    required super.exerciseType,
    required super.isPublic,
    required super.origin,
    super.createdBy,
  });

  factory ExerciseModel.fromEntity(ExerciseEntity entity) {
    return ExerciseModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      videoUrl: entity.videoUrl,
      thumbnailUrl: entity.thumbnailUrl,
      muscleGroups: entity.muscleGroups,
      equipment: entity.equipment,
      difficulty: entity.difficulty,
      exerciseType: entity.exerciseType,
      isPublic: entity.isPublic,
      createdBy: entity.createdBy,
      origin: entity.origin,
    );
  }

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      videoUrl: json['video_url'],
      thumbnailUrl: json['thumbnail_url'],
      muscleGroups: List<String>.from(json['muscle_groups'] ?? []),
      equipment: List<String>.from(json['equipment'] ?? []),
      difficulty: json['difficulty'],
      exerciseType: json['exercise_type'],
      isPublic: json['is_public'],
      createdBy: json['created_by'],
      origin: switch (json['origin']) {
        'system' => ExerciseOrigin.system,
        'user' => ExerciseOrigin.user,
        final value => throw FormatException(
          'Origen de ejercicio desconocido: $value',
        ),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'muscle_groups': muscleGroups,
      'equipment': equipment,
      'difficulty': difficulty,
      'exercise_type': exerciseType,
      'is_public': isPublic,
      'created_by': createdBy,
      'origin': origin.name,
    };
  }
}
