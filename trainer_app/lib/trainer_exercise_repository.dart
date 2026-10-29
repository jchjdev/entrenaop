import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

String trainerExerciseError(Object error) {
  if (error is PostgrestException && error.code == '22023') {
    if (error.message == 'Has alcanzado el límite de imágenes profesionales.' ||
        error.message ==
            'Has alcanzado el límite de ejercicios y versiones profesionales.') {
      return error.message;
    }
    return 'Los datos del ejercicio ya no son válidos. Actualiza la biblioteca antes de volver a editar.';
  }
  if (error is StorageException) {
    return 'No se ha podido confirmar la imagen. Comprueba la conexión y reintenta el mismo guardado.';
  }
  return trainerError(error);
}

class TrainerExercise {
  TrainerExercise.fromJson(Map<String, dynamic> row, {this.official = false})
    : id = row['id'] as String,
      version = row['version'] as int,
      current = row['current'] == true,
      imagePath = row['image_path'] as String?,
      imageUrl = row['thumbnail_url'] as String?,
      draft = ExerciseDraft(
        name: row['name'] as String,
        description: row['description'] as String?,
        videoUrl: row['video_url'] as String?,
        muscleGroups: (row['muscle_groups'] as List).cast<String>(),
        equipment: (row['equipment'] as List).cast<String>(),
        difficulty: row['difficulty'] as String,
        exerciseType: row['exercise_type'] as String,
      );
  final String id;
  final int version;
  final bool current;
  final String? imagePath, imageUrl;
  final ExerciseDraft draft;
  final bool official;
}

class TrainerExerciseUsage {
  TrainerExerciseUsage.fromJson(Map<String, dynamic> row)
    : exercises = row['exercise_used'] as int,
      exerciseLimit = row['exercise_limit'] as int,
      images = row['image_used'] as int,
      imageLimit = row['image_limit'] as int;
  final int exercises, exerciseLimit, images, imageLimit;
}

abstract class TrainerExerciseRepository {
  Future<List<TrainerExercise>> list();
  Future<List<TrainerExercise>> officialCatalog();
  Future<TrainerExerciseUsage> usage();
  Future<String> save(
    String operationId,
    ExerciseFormSubmission<ExerciseDraft> submission, {
    TrainerExercise? previous,
  });
}

class SupabaseTrainerExerciseRepository implements TrainerExerciseRepository {
  const SupabaseTrainerExerciseRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  static const bucket = 'trainer-exercise-images';

  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, [Map<String, dynamic>? params]) async {
    _identity();
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: params,
    );
    _identity();
    return result;
  }

  @override
  Future<List<TrainerExercise>> list() async {
    final rows = await _rpc('list_trainer_exercises') as List;
    final paths = rows
        .map((row) => (row as Map)['image_path'])
        .whereType<String>()
        .toSet()
        .toList();
    final signed = <String, String>{};
    for (var start = 0; start < paths.length; start += 100) {
      final results = await client.storage
          .from(bucket)
          .createSignedUrlsResult(
            paths.sublist(
              start,
              start + 100 > paths.length ? paths.length : start + 100,
            ),
            900,
          );
      _identity();
      for (final result in results.whereType<SignedUrlSuccess>()) {
        signed[result.path] = result.signedUrl;
      }
    }
    final result = <TrainerExercise>[];
    for (final value in rows) {
      final row = Map<String, dynamic>.from(value as Map);
      if (row['image_path'] != null) {
        row['thumbnail_url'] = signed[row['image_path']];
      }
      result.add(TrainerExercise.fromJson(row));
    }
    return result;
  }

  @override
  Future<List<TrainerExercise>> officialCatalog() async {
    final result = <TrainerExercise>[];
    for (var offset = 0; ; offset += 500) {
      _identity();
      final rows = await client
          .from('exercises')
          .select(
            'id,name,description,video_url,muscle_groups,equipment,difficulty,exercise_type,thumbnail_url,image_path',
          )
          .eq('is_public', true)
          .eq('origin', 'system')
          .order('id')
          .range(offset, offset + 499);
      _identity();
      for (final row in rows) {
        result.add(
          TrainerExercise.fromJson({
            ...row,
            'version': 1,
            'current': true,
            'thumbnail_url': row['image_path'] == null
                ? row['thumbnail_url']
                : client.storage
                      .from('exercise-images-public')
                      .getPublicUrl(row['image_path'] as String),
          }, official: true),
        );
      }
      if (rows.length < 500) break;
    }
    result.sort(
      (a, b) =>
          a.draft.name.toLowerCase().compareTo(b.draft.name.toLowerCase()),
    );
    return result;
  }

  @override
  Future<TrainerExerciseUsage> usage() async => TrainerExerciseUsage.fromJson(
    Map<String, dynamic>.from(await _rpc('get_trainer_exercise_usage') as Map),
  );

  @override
  Future<String> save(
    String operationId,
    ExerciseFormSubmission<ExerciseDraft> submission, {
    TrainerExercise? previous,
  }) async {
    if (previous?.official == true) {
      throw StateError('El catálogo de EntrenaOP es de solo consulta.');
    }
    final draft = ExerciseDraftValidator.normalizeAndValidate(submission.draft);
    String? path = submission.removeExistingImage ? null : previous?.imagePath;
    final image = submission.image;
    if (image != null) {
      if (image.bytes.length > 500 * 1024) {
        throw const FormatException('La imagen no puede superar 500 KB.');
      }
      path = await _rpc('reserve_trainer_exercise_image', {
        'p_id': operationId,
      }) as String;
      // Una respuesta perdida no autoriza sobrescribir ni borrar la foto. Al
      // reintentar se comprueban los mismos bytes antes de confirmar la receta.
      final exists = await client.storage.from(bucket).exists(path);
      _identity();
      if (exists) {
        final existing = await client.storage.from(bucket).download(path);
        _identity();
        if (!listEquals(existing, image.bytes)) {
          throw StateError('La imagen del reintento no coincide.');
        }
      } else {
        await client.storage
            .from(bucket)
            .uploadBinary(
              path,
              image.bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        _identity();
      }
    }
    return await _rpc('save_trainer_exercise', {
      'p_operation_id': operationId,
      'p_previous_id': previous?.id,
      'p_payload': {
        'name': draft.name,
        'description': draft.description,
        'video_url': draft.videoUrl,
        'muscle_groups': draft.muscleGroups,
        'equipment': draft.equipment,
        'difficulty': draft.difficulty,
        'exercise_type': draft.exerciseType,
        'image_path': path,
      },
    }) as String;
  }
}
