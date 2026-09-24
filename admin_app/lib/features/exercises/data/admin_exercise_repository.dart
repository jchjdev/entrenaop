import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_draft.dart';
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
  });

  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
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
        muscleGroups: (json['muscle_groups'] as List? ?? const [])
            .cast<String>(),
        equipment: (json['equipment'] as List? ?? const []).cast<String>(),
        difficulty: json['difficulty'] as String,
        exerciseType: json['exercise_type'] as String,
      );
}

abstract class AdminExerciseRepository {
  Future<List<AdminCatalogExercise>> listOfficial();
  Future<void> createOfficial(ExerciseDraft draft);
  Future<void> updateOfficial(String id, ExerciseDraft draft);
}

class SupabaseAdminExerciseRepository implements AdminExerciseRepository {
  const SupabaseAdminExerciseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async {
    final rows = await _client
        .from('exercises')
        .select(
          'id,name,description,video_url,muscle_groups,equipment,difficulty,exercise_type',
        )
        .eq('origin', 'system')
        .order('name');
    return rows
        .where((row) => row['id'] != runningExerciseId)
        .map(AdminCatalogExercise.fromJson)
        .toList();
  }

  @override
  Future<void> createOfficial(ExerciseDraft draft) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    await _client.rpc('create_admin_exercise', params: _params(value));
  }

  @override
  Future<void> updateOfficial(String id, ExerciseDraft draft) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    await _client.rpc(
      'update_admin_exercise',
      params: {'p_exercise_id': id, ..._params(value)},
    );
  }
}

Map<String, Object?> _params(ExerciseDraft draft) => {
  'p_name': draft.name,
  'p_description': draft.description,
  'p_video_url': draft.videoUrl,
  'p_muscle_groups': draft.muscleGroups,
  'p_equipment': draft.equipment,
  'p_difficulty': draft.difficulty,
  'p_exercise_type': draft.exerciseType,
};
