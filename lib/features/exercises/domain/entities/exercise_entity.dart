import 'package:equatable/equatable.dart';

enum ExerciseOrigin { system, user }

class ExerciseEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? thumbnailUrl;
  final List<String> muscleGroups;
  final List<String> equipment;
  final String difficulty;
  final String exerciseType;
  final bool isPublic;
  final String? createdBy;
  final ExerciseOrigin origin;

  const ExerciseEntity({
    required this.id,
    required this.name,
    this.description,
    this.videoUrl,
    this.thumbnailUrl,
    required this.muscleGroups,
    required this.equipment,
    required this.difficulty,
    required this.exerciseType,
    required this.isPublic,
    required this.origin,
    this.createdBy,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    videoUrl,
    thumbnailUrl,
    muscleGroups,
    equipment,
    difficulty,
    exerciseType,
    isPublic,
    createdBy,
    origin,
  ];
}
