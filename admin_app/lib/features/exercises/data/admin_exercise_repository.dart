import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_core/workout_template.dart';

class AdminCatalogExercise {
  const AdminCatalogExercise({
    required this.id,
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    required this.difficulty,
    required this.exerciseType,
    this.description,
    this.videoUrl,
    this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? imagePath;
  final String? imageUrl;
  final List<String> muscleGroups;
  final List<String> equipment;
  final String difficulty;
  final String exerciseType;

  ExerciseDraft toDraft() => ExerciseDraft(
    name: name,
    description: description,
    videoUrl: videoUrl,
    muscleGroups: muscleGroups,
    equipment: equipment,
    difficulty: difficulty,
    exerciseType: exerciseType,
  );

  factory AdminCatalogExercise.fromJson(Map<String, dynamic> json) =>
      AdminCatalogExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        videoUrl: json['video_url'] as String?,
        imagePath: json['image_path'] as String?,
        muscleGroups: (json['muscle_groups'] as List? ?? const [])
            .cast<String>(),
        equipment: (json['equipment'] as List? ?? const []).cast<String>(),
        difficulty: json['difficulty'] as String,
        exerciseType: json['exercise_type'] as String,
      );
}

abstract class AdminExerciseRepository {
  Future<List<AdminCatalogExercise>> listOfficial();
  Future<void> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  });
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  });
}

class SupabaseAdminExerciseRepository implements AdminExerciseRepository {
  const SupabaseAdminExerciseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async {
    final rows = await _client
        .from('exercises')
        .select(
          'id,name,description,video_url,image_path,muscle_groups,equipment,difficulty,exercise_type',
        )
        .eq('origin', 'system')
        .order('name');
    return rows.where((row) => row['id'] != runningExerciseId).map((row) {
      final exercise = AdminCatalogExercise.fromJson(row);
      final path = exercise.imagePath;
      return AdminCatalogExercise(
        id: exercise.id,
        name: exercise.name,
        description: exercise.description,
        videoUrl: exercise.videoUrl,
        imagePath: path,
        imageUrl: path == null
            ? null
            : _client.storage.from(_publicBucket).getPublicUrl(path),
        muscleGroups: exercise.muscleGroups,
        equipment: exercise.equipment,
        difficulty: exercise.difficulty,
        exerciseType: exercise.exerciseType,
      );
    }).toList();
  }

  @override
  Future<void> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    final id = await _client.rpc(
      'create_admin_exercise',
      params: _params(value),
    );
    if (image == null) return;
    String? uploadedPath;
    try {
      uploadedPath = await _upload(id as String, image);
      await _client.rpc(
        'set_admin_exercise_image',
        params: {'p_exercise_id': id, 'p_image_path': uploadedPath},
      );
    } catch (_) {
      await _removeBestEffort(uploadedPath);
      await _client.from('exercises').delete().eq('id', id);
      rethrow;
    }
  }

  @override
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    await _client.rpc(
      'update_admin_exercise',
      params: {'p_exercise_id': id, ..._params(value)},
    );
    if (image != null) {
      final path = await _upload(id, image);
      try {
        final previous = await _client.rpc(
          'set_admin_exercise_image',
          params: {'p_exercise_id': id, 'p_image_path': path},
        );
        await _removeBestEffort(previous as String?);
      } catch (_) {
        await _removeBestEffort(path);
        rethrow;
      }
    } else if (removeImage) {
      final previous = await _client.rpc(
        'set_admin_exercise_image',
        params: {'p_exercise_id': id, 'p_image_path': null},
      );
      await _removeBestEffort(previous as String?);
    }
  }

  Future<String> _upload(String exerciseId, ExerciseImageUpload image) async {
    final path =
        'official/$exerciseId/'
        '${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    await _client.storage
        .from(_publicBucket)
        .uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            contentType: image.contentType,
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _removeBestEffort(String? path) async {
    if (path == null) return;
    try {
      await _client.storage.from(_publicBucket).remove([path]);
    } catch (_) {
      // La referencia ya apunta a la nueva imagen; el huérfano puede limpiarse.
    }
  }
}

const _publicBucket = 'exercise-images-public';

Map<String, Object?> _params(ExerciseDraft draft) => {
  'p_name': draft.name,
  'p_description': draft.description,
  'p_video_url': draft.videoUrl,
  'p_muscle_groups': draft.muscleGroups,
  'p_equipment': draft.equipment,
  'p_difficulty': draft.difficulty,
  'p_exercise_type': draft.exerciseType,
};
