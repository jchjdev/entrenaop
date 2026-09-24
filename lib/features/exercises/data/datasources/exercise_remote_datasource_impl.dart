import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_image.dart';

class ExerciseRemoteDataSourceImpl implements ExerciseRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExerciseRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ExerciseModel>> getExercises() async {
    try {
      final response = await supabaseClient.from('exercises').select();
      return await Future.wait(
        (response as List).map(
          (json) async => ExerciseModel.fromJson(await _resolveImage(json)),
        ),
      );
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
      return await Future.wait(
        (response as List).map(
          (json) async => ExerciseModel.fromJson(await _resolveImage(json)),
        ),
      );
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
      return ExerciseModel.fromJson(await _resolveImage(response));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ExerciseModel> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  }) async {
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
      if (image != null) {
        await _uploadPersonalImage(exerciseId as String, image);
      }
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

  Future<void> _uploadPersonalImage(
    String exerciseId,
    ExerciseImageUpload image,
  ) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) throw const ServerException('Debes iniciar sesión.');
    final path =
        '$userId/$exerciseId/'
        '${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    try {
      await supabaseClient.storage
          .from(_privateBucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          );
      await supabaseClient.rpc(
        'set_personal_exercise_image',
        params: {'p_exercise_id': exerciseId, 'p_image_path': path},
      );
    } catch (_) {
      try {
        await supabaseClient.storage.from(_privateBucket).remove([path]);
        await supabaseClient.from('exercises').delete().eq('id', exerciseId);
      } catch (_) {
        // Se conserva el error original de la subida o vinculación.
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _resolveImage(Map<String, dynamic> row) async {
    final path = row['image_path'] as String?;
    if (path == null) return row;
    final resolved = Map<String, dynamic>.of(row);
    if (row['origin'] == 'system') {
      resolved['thumbnail_url'] = supabaseClient.storage
          .from(_publicBucket)
          .getPublicUrl(path);
    } else {
      resolved['thumbnail_url'] = await supabaseClient.storage
          .from(_privateBucket)
          .createSignedUrl(path, 3600);
    }
    return resolved;
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

const _publicBucket = 'exercise-images-public';
const _privateBucket = 'exercise-images-private';
