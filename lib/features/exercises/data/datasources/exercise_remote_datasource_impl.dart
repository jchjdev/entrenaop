import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseRemoteDataSourceImpl implements ExerciseRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExerciseRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ExerciseModel>> getExercises() async {
    try {
      final response = await supabaseClient.from('exercises').select();
      return (response as List)
          .map((json) => ExerciseModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ExerciseModel>> getExercisesByMuscleGroup(
    String muscleGroup,
  ) async {
    try {
      final response = await supabaseClient
          .from('exercises')
          .select()
          .eq('is_public', true)
          .contains('muscle_groups', [muscleGroup]);
      return (response as List)
          .map((json) => ExerciseModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ExerciseModel?> getExerciseById(String id) async {
    try {
      final response = await supabaseClient
          .from('exercises')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return ExerciseModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ExerciseModel> createExercise(PersonalExerciseDraft exercise) async {
    try {
      final exerciseId = await supabaseClient.rpc(
        'create_personal_exercise',
        params: {
          'p_name': exercise.name,
          'p_description': exercise.description,
          'p_video_url': exercise.videoUrl,
          'p_muscle_groups': exercise.muscleGroups,
          'p_equipment': exercise.equipment,
          'p_difficulty': exercise.difficulty,
          'p_exercise_type': exercise.exerciseType,
        },
      );
      final created = await getExerciseById(exerciseId as String);
      if (created == null) {
        throw const ServerException('El ejercicio creado no está disponible.');
      }
      return created;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateExercise(ExerciseModel exercise) async {
    try {
      await supabaseClient
          .from('exercises')
          .update(exercise.toJson())
          .eq('id', exercise.id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteExercise(String id) async {
    try {
      await supabaseClient.from('exercises').delete().eq('id', id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
