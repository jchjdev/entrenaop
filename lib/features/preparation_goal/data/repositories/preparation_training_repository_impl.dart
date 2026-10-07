import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/training_scope.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

class SupabasePreparationTrainingRepository
    implements PreparationTrainingRepository {
  const SupabasePreparationTrainingRepository(
    this.client, {
    bool Function()? readOnlyPreview,
  }) : _readOnlyPreview = readOnlyPreview;
  final SupabaseClient client;
  final bool Function()? _readOnlyPreview;

  /// La vista Free de desarrollo consulta el estado sin avanzar ni generar.
  Future<List<AdaptiveProgramProgress>> readPrograms() async {
    final rows = await client
        .from('preparation_goals')
        .select(
          'id, preparation_programs!inner(name), adaptive_program_states(status, message, last_generated_week, next_generation_on)',
        )
        .eq('status', 'active')
        .order('created_at');
    return rows
        .map((row) {
          final program = Map<String, dynamic>.from(
            row['preparation_programs'] as Map,
          );
          final state = Map<String, dynamic>.from(
            row['adaptive_program_states'] as Map? ?? {},
          );
          return AdaptiveProgramProgress(
            goalId: row['id'] as String,
            name: program['name'] as String,
            status: state['status'] as String? ?? 'draft',
            message:
                state['message'] as String? ??
                'Completa los datos iniciales para empezar tu programa.',
            currentWeek: DateTime.tryParse(
              state['last_generated_week'] as String? ?? '',
            ),
            nextGenerationOn: DateTime.tryParse(
              state['next_generation_on'] as String? ?? '',
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<AdaptiveProgramProgress>> refreshPrograms() async =>
      _readOnlyPreview?.call() == true
      ? readPrograms()
      : _rows(await _rpc('refresh_adaptive_programs'))
            .map(
              (row) => AdaptiveProgramProgress(
                goalId: row['goal_id'] as String,
                name: row['name'] as String,
                status: row['status'] as String,
                message: row['message'] as String,
                currentWeek: DateTime.tryParse(
                  row['current_week'] as String? ?? '',
                ),
                nextGenerationOn: DateTime.tryParse(
                  row['next_generation_on'] as String? ?? '',
                ),
              ),
            )
            .toList(growable: false);
  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) async {
    // Guarda de simulación, no autorización comercial: esta última es del servidor.
    if (_readOnlyPreview?.call() == true &&
        name != 'get_preparation_training_setup') {
      throw const PreparationTrainingException(
        'Los programas adaptativos forman parte de Pro.',
      );
    }
    try {
      return await client.rpc(name, params: params);
    } on PostgrestException catch (e) {
      throw PreparationTrainingException(
        const ['22023', '42501', 'P0001'].contains(e.code) ? e.message : 'No se han podido guardar o consultar los datos. Vuelve a intentarlo.',
      );
    } on AuthException {
      throw const PreparationTrainingException(
        'Vuelve a iniciar sesión para continuar.',
      );
    }
  }

  @override
  Future<PreparationTrainingData> load(String goalId) async {
    final j = Map<String, dynamic>.from(
      await _rpc(
        'get_preparation_training_setup',
        params: {'p_goal_id': goalId},
      ) as Map,
    );
    return PreparationTrainingData(
      availableRunning: j['available_running'] == true,
      availablePerformance: j['available_performance'] == true,
      trainingScope: TrainingScope.parse(j['training_scope']),
      programName: j['program_name'] as String?,
      activeProgram: j['active_program'] == null
          ? null
          : Map<String, dynamic>.from(j['active_program'] as Map),
      canResetTrial: j['can_reset_trial'] == true,
      updateOptions: Map<String, dynamic>.from(
        j['update_options'] as Map? ?? {},
      ),
      pendingSessions: _rows(j['pending_sessions']),
      programPath: AdaptiveProgramPath.fromJson(
        Map<String, dynamic>.from(j['program_path'] as Map? ?? {}),
      ),
      calibrationOptions: _rows(j['calibration_options']),
      targetDate: DateTime.tryParse(j['target_date'] as String? ?? ''),
      programState: Map<String, dynamic>.from(j['program_state'] as Map? ?? {}),
      hasRunning: j['has_running'] == true,
      catalog: _rows(j['catalog'])
          .map(
            (r) => StrengthExerciseCatalogCodec.decodeDefinition(
              Map<String, dynamic>.from(r['definition'] as Map),
              definitionVersion: r['version'] as int,
            ),
          )
          .toList(),
      context: j['context'] == null
          ? null
          : Map<String, dynamic>.from(j['context'] as Map),
      runningContext: j['running_context'] == null
          ? null
          : Map<String, dynamic>.from(j['running_context'] as Map),
      references: _rows(j['references']),
      objectives: _rows(j['objectives']),
      relations: _rows(j['relations']),
      publishedWeeks: (j['published_weeks'] as List)
          .map((v) => DateTime.parse(v as String))
          .toList(),
    );
  }

  static List<Map<String, dynamic>> _rows(Object? v) => (v as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  @override
  Future<void> saveContext(
    Map<String, int> availability,
    Set<String> equipment, {
    required bool reportsPain,
    required bool capacityConfirmed,
  }) async {
    await _rpc(
      'save_performance_context',
      params: {
        'p_availability': availability,
        'p_equipment': equipment.toList(),
        'p_reports_pain': reportsPain,
        'p_capacity_confirmed': capacityConfirmed,
      },
    );
  }

  @override
  Future<void> saveReference(
    String goalId,
    Map<String, dynamic> reference, {
    String? testId,
  }) async {
    await _rpc(
      'save_performance_reference',
      params: {
        'p_goal_id': goalId,
        'p_reference': reference,
        'p_test_id': testId,
      },
    );
  }

  @override
  Future<void> deactivateReference(String id) async {
    await _rpc(
      'deactivate_performance_reference',
      params: {'p_reference_id': id},
    );
  }

  @override
  Future<Map<String, dynamic>> calculate(
    String goalId,
    DateTime week, {
    bool revise = false,
    bool activation = false,
  }) async => Map<String, dynamic>.from(
    await _rpc(
      activation
          ? 'preview_adaptive_program_activation'
          : revise
          ? 'preview_preparation_week_revision'
          : 'calculate_preparation_week',
      params: {'p_goal_id': goalId, 'p_week_start': _date(week)},
    ) as Map,
  );
  @override
  Future<Map<String, dynamic>> publish(
    String goalId,
    DateTime week,
    Map<String, dynamic> reviewed,
  ) async => Map<String, dynamic>.from(
    await _rpc(
      reviewed['revision'] != null
          ? 'publish_preparation_week_revision'
          : 'publish_preparation_week',
      params: {
        'p_goal_id': goalId,
        'p_week_start': _date(week),
        'p_expected_proposal': reviewed,
      },
    ) as Map,
  );
  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> resetTrial(String goalId, String confirmation) async {
    await _rpc(
      'reset_adaptive_program_trial',
      params: {'p_goal_id': goalId, 'p_confirmation': confirmation},
    );
  }

  @override
  Future<void> saveProgram(
    String goalId,
    DateTime targetDate,
    Map<String, dynamic> targets, {
    TrainingScope scope = TrainingScope.full,
  }) async {
    await _rpc(
      'save_adaptive_program_preferences',
      params: {
        'p_goal_id': goalId,
        'p_target_date': _date(targetDate),
        'p_targets': targets,
        'p_training_scope': scope.value,
      },
    );
  }

  @override
  Future<void> advance(String goalId) async {
    await _rpc('advance_adaptive_program', params: {'p_goal_id': goalId});
  }

  @override
  Future<void> pause(String goalId) async {
    await _rpc('pause_adaptive_program', params: {'p_goal_id': goalId});
  }

  @override
  Future<void> skipSession(String id) async {
    await _rpc('skip_preparation_session', params: {'p_session_id': id});
  }

  @override
  Future<Map<String, dynamic>> activate(
    String goalId,
    DateTime week,
    Map<String, dynamic> reviewed,
  ) async => Map<String, dynamic>.from(
    await _rpc(
      'activate_adaptive_program',
      params: {
        'p_goal_id': goalId,
        'p_week_start': _date(week),
        'p_expected_proposal': reviewed,
      },
    ) as Map,
  );
}
