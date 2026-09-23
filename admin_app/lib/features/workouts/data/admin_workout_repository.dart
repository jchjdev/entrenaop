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
  });

  final String id;
  final String name;
  final String status;
  final int version;
  final bool isRunning;
}

class AdminExercise {
  const AdminExercise({required this.id, required this.name});

  final String id;
  final String name;
}

abstract class AdminWorkoutRepository {
  Future<List<AdminWorkoutSummary>> listForProgram(String programId);
  Future<List<AdminExercise>> listPublicExercises();
  Future<WorkoutTemplate?> getTemplateById(String templateId);
  Future<String> createDraft(
    String programId,
    CreatePersonalWorkoutInput input,
  );
  Future<void> publishDraft(String templateId);
}

class SupabaseAdminWorkoutRepository implements AdminWorkoutRepository {
  const SupabaseAdminWorkoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async {
    final links = await _client
        .from('program_workout_templates')
        .select('template_id')
        .eq('program_id', programId);
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
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminExercise>> listPublicExercises() async {
    final rows = await _client
        .from('exercises')
        .select('id,name')
        .eq('is_public', true)
        .order('name');
    return rows
        .where((row) => row['id'] != runningExerciseId)
        .map(
          (row) => AdminExercise(
            id: row['id'] as String,
            name: row['name'] as String,
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
    String programId,
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
}
