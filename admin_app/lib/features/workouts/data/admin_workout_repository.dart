import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/workout_template_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWorkoutSummary {
  const AdminWorkoutSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.version,
    required this.isRunning,
    required this.catalogScope,
  });

  final String id;
  final String name;
  final String status;
  final int version;
  final bool isRunning;
  final String catalogScope;
}

class AdminExercise {
  const AdminExercise({
    required this.id,
    required this.name,
    this.muscleGroups = const [],
    this.equipment = const [],
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final List<String> muscleGroups;
  final List<String> equipment;
  final String? thumbnailUrl;
}

abstract class AdminWorkoutRepository {
  Future<List<AdminWorkoutSummary>> listForProgram(String programId);
  Future<List<AdminWorkoutSummary>> listGeneral();
  Future<List<AdminExercise>> listPublicExercises();
  Future<WorkoutTemplate?> getTemplateById(String templateId);
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input,
  );
  Future<void> publishDraft(String templateId);
  Future<void> remove(String templateId);
  Future<String> revise(String templateId, CreatePersonalWorkoutInput input);
}

class SupabaseAdminWorkoutRepository implements AdminWorkoutRepository {
  const SupabaseAdminWorkoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async {
    final links = await _client
        .from('program_workout_templates')
        .select('template_id')
        .eq('program_id', programId)
        .eq('catalog_scope', 'program');
    return _listFromLinks(links, 'program');
  }

  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async {
    final links = await _client
        .from('program_workout_templates')
        .select('template_id')
        .eq('catalog_scope', 'general');
    return _listFromLinks(links, 'general');
  }

  Future<List<AdminWorkoutSummary>> _listFromLinks(
    List<Map<String, dynamic>> links,
    String catalogScope,
  ) async {
    final ids = links.map((row) => row['template_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('workout_templates')
        .select('id,name,status,version')
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    final runningRows = await _client
        .from('workout_blocks')
        .select('template_id')
        .inFilter('template_id', ids)
        .eq('format', 'running');
    final runningIds = runningRows
        .map((row) => row['template_id'] as String)
        .toSet();
    return rows
        .map(
          (row) => AdminWorkoutSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            status: row['status'] as String,
            version: row['version'] as int,
            isRunning: runningIds.contains(row['id']),
            catalogScope: catalogScope,
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminExercise>> listPublicExercises() async {
    final rows = await _client
        .from('exercises')
        .select('id,name,muscle_groups,equipment,thumbnail_url')
        .eq('is_public', true)
        .order('name');
    return rows
        .where((row) => row['id'] != runningExerciseId)
        .map(
          (row) => AdminExercise(
            id: row['id'] as String,
            name: row['name'] as String,
            muscleGroups: (row['muscle_groups'] as List? ?? const [])
                .cast<String>(),
            equipment: (row['equipment'] as List? ?? const []).cast<String>(),
            thumbnailUrl: row['thumbnail_url'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId) async {
    final row = await _client
        .from('workout_templates')
        .select(workoutTemplateSelect)
        .eq('id', templateId)
        .maybeSingle();
    return row == null ? null : WorkoutTemplateModel.fromJson(row);
  }

  @override
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input,
  ) async {
    validateWorkoutDraft(input);
    final id = await _client.rpc(
      'create_admin_workout_draft',
      params: {
        'p_program_id': programId,
        'p_payload': workoutDraftToJson(input),
      },
    );
    return id as String;
  }

  @override
  Future<void> publishDraft(String templateId) async {
    await _client.rpc(
      'publish_admin_workout_draft',
      params: {'p_template_id': templateId},
    );
  }

  @override
  Future<void> remove(String templateId) async {
    await _client.rpc(
      'remove_admin_workout',
      params: {'p_template_id': templateId},
    );
  }

  @override
  Future<String> revise(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async {
    validateWorkoutDraft(input);
    final id = await _client.rpc(
      'revise_admin_workout',
      params: {
        'p_template_id': templateId,
        'p_payload': workoutDraftToJson(input),
      },
    );
    return id as String;
  }
}
