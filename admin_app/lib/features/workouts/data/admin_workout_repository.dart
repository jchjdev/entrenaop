import 'package:trainer_access/published_warmup_catalog.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/workout_template_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:workout_editor_ui/program_session_catalog.dart'
    show ProgramSessionSummary, ProgramSessionUsage;
import 'package:workout_editor_ui/program_session_catalog.dart';

typedef AdminWorkoutSummary = ProgramSessionSummary;
typedef AdminWorkoutProgramUsage = ProgramSessionUsage;

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

abstract class AdminWorkoutRepository implements ProgramSessionCatalog {
  Future<List<WorkoutTemplate>> warmups() async => [];
  Future<List<AdminWorkoutSummary>> listForProgram(String programId);
  @override
  Future<List<AdminWorkoutSummary>> listGeneral();
  Future<List<AdminExercise>> listPublicExercises();
  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId);
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input, {
    bool showInLibrary = true,
  });
  @override
  Future<void> setLibraryVisibility(
    String templateId,
    bool value, {
    required bool expected,
  });
  Future<void> publishDraft(String templateId);
  Future<void> remove(String templateId);
  Future<String> revise(String templateId, CreatePersonalWorkoutInput input);
}

/// Consulta los metadatos ya usados por un trabajo sin ofrecerlos como nuevos.
abstract interface class AdminRetainedExerciseRepository {
  Future<List<AdminExercise>> listRetainedExercises(Set<String> ids);
}

class SupabaseAdminWorkoutRepository
    implements AdminWorkoutRepository, AdminRetainedExerciseRepository {
  const SupabaseAdminWorkoutRepository(this._client);

  final SupabaseClient _client;
  @override
  Future<List<WorkoutTemplate>> warmups() {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw StateError('La sesión ha cambiado.');
    return SupabasePublishedWarmupCatalog(_client, owner).load();
  }

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
        .select('id,name,status,version,show_in_library')
        .isFilter('trashed_at', null)
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    final blockRows = await _client
        .from('workout_blocks')
        .select('template_id,format')
        .inFilter('template_id', ids)
        .inFilter('format', ['running', 'warm_up', 'straight_sets']);
    final runningIds = blockRows
        .where((row) => row['format'] == 'running')
        .map((row) => row['template_id'] as String)
        .toSet();
    final warmupIds = blockRows
        .where((row) => row['format'] == 'warm_up')
        .map((row) => row['template_id'] as String)
        .toSet();
    final adjustableIds = blockRows
        .where((row) => row['format'] == 'straight_sets')
        .map((row) => row['template_id'] as String)
        .toSet();
    final usages = <String, Map<String, AdminWorkoutProgramUsage>>{};
    if (catalogScope == 'general') {
      final programLinks = await _client
          .from('guided_program_links')
          .select(
            'template_id,program:guided_programs!inner(id,name:content->>name,version,status)',
          )
          .inFilter('template_id', ids);
      for (final link in programLinks) {
        final program = link['program'] as Map<String, dynamic>;
        final id = program['id'] as String;
        // Una versión puede repetir la sesión en varias fases: se muestra una vez.
        (usages[link['template_id'] as String] ??=
            {})[id] = AdminWorkoutProgramUsage(
          id: id,
          name: program['name'] as String,
          version: program['version'] as int,
          status: program['status'] as String,
        );
      }
    }
    return rows
        .map(
          (row) => AdminWorkoutSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            status: row['status'] as String,
            version: row['version'] as int,
            showInLibrary: row['show_in_library'] as bool? ?? true,
            isRunning: runningIds.contains(row['id']),
            catalogScope: catalogScope,
            hasWarmup: warmupIds.contains(row['id']),
            supportsAdjustableRest: adjustableIds.contains(row['id']),
            guidedPrograms: (usages[row['id']]?.values.toList() ?? [])
              ..sort((a, b) {
                final name = a.name.compareTo(b.name);
                return name != 0 ? name : b.version.compareTo(a.version);
              }),
          ),
        )
        .toList();
  }

  @override
  Future<List<AdminExercise>> listPublicExercises() async {
    final rows = await _client
        .from('exercises')
        .select('id,name,muscle_groups,equipment,thumbnail_url,image_path')
        .eq('is_public', true)
        .isFilter('trashed_at', null)
        .order('name');
    return _exercises(rows);
  }

  @override
  Future<List<AdminExercise>> listRetainedExercises(Set<String> ids) async {
    final result = <AdminExercise>[];
    final requested = ids.toList();
    for (var offset = 0; offset < requested.length; offset += 100) {
      final rows = await _client
          .from('exercises')
          .select('id,name,muscle_groups,equipment,thumbnail_url,image_path')
          .eq('origin', 'system')
          .inFilter('id', requested.skip(offset).take(100).toList());
      result.addAll(_exercises(rows));
    }
    return result;
  }

  List<AdminExercise> _exercises(List<Map<String, dynamic>> rows) => rows
      .where((row) => row['id'] != runningExerciseId)
      .map(
        (row) => AdminExercise(
          id: row['id'] as String,
          name: row['name'] as String,
          muscleGroups: (row['muscle_groups'] as List? ?? const [])
              .cast<String>(),
          equipment: (row['equipment'] as List? ?? const []).cast<String>(),
          thumbnailUrl: row['image_path'] == null
              ? row['thumbnail_url'] as String?
              : _client.storage
                    .from('exercise-images-public')
                    .getPublicUrl(row['image_path'] as String),
        ),
      )
      .toList();

  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId) async {
    final row = await _client
        .from('workout_templates')
        .select(workoutTemplateSelect)
        .isFilter('trashed_at', null)
        .eq('id', templateId)
        .maybeSingle();
    return row == null ? null : WorkoutTemplateModel.fromJson(row);
  }

  @override
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input, {
    bool showInLibrary = true,
  }) async {
    validateWorkoutDraft(input);
    final id = await _client.rpc(
      'create_admin_workout_draft',
      params: {
        'p_program_id': programId,
        'p_payload': {
          ...workoutDraftToJson(input),
          'show_in_library': showInLibrary,
        },
      },
    );
    return id as String;
  }

  @override
  Future<void> setLibraryVisibility(
    String templateId,
    bool value, {
    required bool expected,
  }) async {
    await _client.rpc(
      'set_admin_workout_library_visibility',
      params: {
        'p_template_id': templateId,
        'p_show_in_library': value,
        'p_expected': expected,
      },
    );
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
