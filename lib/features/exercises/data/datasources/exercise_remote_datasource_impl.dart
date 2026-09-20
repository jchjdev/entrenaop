import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseRemoteDataSourceImpl implements ExerciseRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExerciseRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ExerciseModel>> getExercises() async {
    try {
      final response = await supabaseClient
          .from('exercises')
          .select()
          .eq('is_public', true);
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
  Future<void> createExercise(ExerciseModel exercise) async {
    try {
      await supabaseClient.from('exercises').insert(exercise.toJson());
    } catch (e) {
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
