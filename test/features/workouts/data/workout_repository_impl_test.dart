import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/repositories/workout_repository_impl.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_mutation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingWorkoutRemoteDataSource dataSource;
  late _MemoryMutationQueue mutationQueue;
  late WorkoutRepositoryImpl repository;

  setUp(() {
    dataSource = _RecordingWorkoutRemoteDataSource();
    mutationQueue = _MemoryMutationQueue();
    repository = WorkoutRepositoryImpl(
      remoteDataSource: dataSource,
      mutationQueue: mutationQueue,
    );
  });

  test('envía el resultado real sin sustituirlo por la prescripción', () async {
    const result = WorkoutSetResultInput(
      resultId: 'result-1',
      actualReps: 7,
      actualLoadKg: 12.5,
      actualRir: 2,
    );

    await repository.completeSet(result);

    expect(dataSource.completedValues, {
      'p_result_id': 'result-1',
      'p_actual_reps': 7,
      'p_actual_duration_seconds': null,
      'p_actual_distance_meters': null,
      'p_actual_load_kg': 12.5,
      'p_actual_rpe': null,
      'p_actual_rir': 2,
      'p_actual_recovery_duration_seconds': null,
      'p_actual_recovery_distance_meters': null,
      'p_result_source': 'manual',
    });
  });

  test('convierte las sesiones públicas en resúmenes de biblioteca', () async {
    dataSource.publicTemplates = const [
      {
        'id': 'template-1',
        'name': 'Fuerza base',
        'description': 'Sesión pública',
        'estimated_duration_minutes': 20,
        'origin': 'system',
        'version': 1,
      },
    ];

    final workouts = await repository.getPublicTemplates();

    expect(workouts, hasLength(1));
    expect(workouts.single.name, 'Fuerza base');
    expect(workouts.single.origin, WorkoutTemplateOrigin.system);
  });

  test('envía cada parcial de carrera con su recuperación real', () async {
    await repository.completeSet(
      const WorkoutSetResultInput(
        resultId: 'running-result-1',
        actualDurationSeconds: 88,
        actualDistanceMeters: 400,
        actualRecoveryDurationSeconds: 62,
      ),
    );

    expect(
      dataSource.completedValues,
      containsPair('p_result_id', 'running-result-1'),
    );
    expect(
      dataSource.completedValues,
      containsPair('p_actual_duration_seconds', 88),
    );
    expect(
      dataSource.completedValues,
      containsPair('p_actual_distance_meters', 400),
    );
    expect(
      dataSource.completedValues,
      containsPair('p_actual_recovery_duration_seconds', 62),
    );
  });

  test(
    'serializa una sesión personal sin mezclar sus tipos de objetivo',
    () async {
      const input = CreatePersonalWorkoutInput(
        name: ' Carrera corta ',
        estimatedDurationMinutes: 25,
        blocks: [
          WorkoutBlockDraft(
            name: 'Series de pista',
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: 'exercise-1',
                sets: [
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.distance,
                    targetValue: 400,
                    restAfterSeconds: 90,
                    targetRir: 2,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await repository.createPersonalTemplate(input);

      expect(dataSource.personalPayload, {
        'name': 'Carrera corta',
        'description': null,
        'estimated_duration_minutes': 25,
        'blocks': [
          {
            'name': 'Series de pista',
            'format': 'straight_sets',
            'rounds': 1,
            'rest_after_seconds': 0,
            'exercises': [
              {
                'exercise_id': 'exercise-1',
                'sets': [
                  {
                    'target_reps': null,
                    'target_duration_seconds': null,
                    'target_distance_meters': 400.0,
                    'target_load_kg': null,
                    'target_rir': 2.0,
                    'target_pace_min_seconds_per_km': null,
                    'target_pace_max_seconds_per_km': null,
                    'recovery_type': null,
                    'recovery_duration_seconds': null,
                    'recovery_distance_meters': null,
                    'rest_after_seconds': 90,
                  },
                ],
              },
            ],
          },
        ],
      });
    },
  );

  test('serializa tramos de carrera sin convertirlos en intervalos', () async {
    const input = CreatePersonalWorkoutInput(
      name: 'Series de 400',
      blocks: [
        WorkoutBlockDraft(
          name: 'Carrera',
          format: WorkoutBlockFormat.running,
          exercises: [
            WorkoutExerciseDraft(
              exerciseId: runningExerciseId,
              sets: [
                WorkoutSetDraft(
                  targetType: WorkoutTargetType.distance,
                  targetValue: 400,
                  restAfterSeconds: 0,
                  targetPaceMinSecondsPerKm: 240,
                  targetPaceMaxSecondsPerKm: 255,
                  recoveryType: RunningRecoveryType.jogging,
                  recoveryDistanceMeters: 200,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await repository.createPersonalTemplate(input);

    final block = (dataSource.personalPayload!['blocks'] as List).single as Map;
    final exercise = (block['exercises'] as List).single as Map;
    final segment = (exercise['sets'] as List).single as Map;
    expect(block['format'], 'running');
    expect(segment['target_distance_meters'], 400.0);
    expect(segment['target_pace_min_seconds_per_km'], 240);
    expect(segment['target_pace_max_seconds_per_km'], 255);
    expect(segment['recovery_type'], 'jogging');
    expect(segment['recovery_distance_meters'], 200.0);
  });

  test('delega el duplicado y archivado de sesiones personales', () async {
    final copiedId = await repository.duplicatePersonalTemplate('template-1');
    await repository.archivePersonalTemplate('template-1');

    expect(copiedId, 'personal-template-copy');
    expect(dataSource.duplicatedTemplateId, 'template-1');
    expect(dataSource.archivedTemplateId, 'template-1');
  });

  test('serializa la nueva versión con el identificador original', () async {
    await repository.revisePersonalTemplate(
      'template-v1',
      const CreatePersonalWorkoutInput(
        name: 'Fuerza revisada',
        blocks: [
          WorkoutBlockDraft(
            name: 'Principal',
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: 'exercise-1',
                sets: [
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.repetitions,
                    targetValue: 8,
                    restAfterSeconds: 120,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(dataSource.revisedTemplateId, 'template-v1');
    expect(dataSource.revisedPayload?['name'], 'Fuerza revisada');
  });

  test('envía una corrección con su motivo auditable', () async {
    const correction = WorkoutSetCorrectionInput(
      resultId: 'result-1',
      reason: 'Anoté mal las repeticiones.',
      actualReps: 10,
      actualLoadKg: 20,
    );

    await repository.correctSet(correction);

    expect(dataSource.correctedValues, {
      'p_result_id': 'result-1',
      'p_reason': 'Anoté mal las repeticiones.',
      'p_actual_reps': 10,
      'p_actual_duration_seconds': null,
      'p_actual_distance_meters': null,
      'p_actual_load_kg': 20,
      'p_actual_rpe': null,
      'p_actual_rir': null,
      'p_actual_recovery_duration_seconds': null,
      'p_actual_recovery_distance_meters': null,
      'p_result_source': 'manual',
    });
  });

  test('envía el identificador de la serie omitida', () async {
    await repository.skipSet('result-2');

    expect(dataSource.skippedResultId, 'result-2');
  });

  test('envía el resultado agregado de un AMRAP', () async {
    await repository.completeAmrap(
      const WorkoutAmrapResultInput(
        executionId: 'execution-1',
        blockOrder: 2,
        completedRounds: 5,
        partialItemOrder: 1,
        partialReps: 4,
      ),
    );

    expect(dataSource.completedAmrapValues, {
      'p_execution_id': 'execution-1',
      'p_block_order': 2,
      'p_completed_rounds': 5,
      'p_partial_item_order': 1,
      'p_partial_reps': 4,
    });
  });

  test('envía el esfuerzo y las sensaciones al finalizar', () async {
    await repository.finishExecution(
      'execution-1',
      finalRpe: 8,
      notes: 'Buena técnica, algo fatigado al final.',
      averageHeartRateBpm: 158,
      maxHeartRateBpm: 181,
    );

    expect(dataSource.finishedExecutionId, 'execution-1');
    expect(dataSource.finalRpe, 8);
    expect(dataSource.finalNotes, 'Buena técnica, algo fatigado al final.');
    expect(dataSource.averageHeartRateBpm, 158);
    expect(dataSource.maxHeartRateBpm, 181);
  });

  test(
    'traduce el motivo de abandono al valor estable de base de datos',
    () async {
      await repository.abandonExecution(
        'execution-2',
        WorkoutAbandonmentReason.discomfort,
      );

      expect(dataSource.abandonedExecutionId, 'execution-2');
      expect(dataSource.abandonmentReason, 'discomfort');
    },
  );

  test(
    'encola sin conexión y reintenta la misma operación una sola vez',
    () async {
      dataSource.failComplete = true;

      final disposition = await repository.completeSet(
        const WorkoutSetResultInput(resultId: 'result-offline', actualReps: 9),
      );

      expect(disposition, WorkoutMutationDisposition.queued);
      expect(mutationQueue.mutations, hasLength(1));
      final operationId = mutationQueue.mutations.single.operationId;

      dataSource.failComplete = false;
      await repository.syncPendingMutations();

      expect(mutationQueue.mutations, isEmpty);
      expect(dataSource.completedOperationIds, contains(operationId));
    },
  );
}

class _RecordingWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  Map<String, dynamic>? completedValues;
  Map<String, dynamic>? completedAmrapValues;
  Map<String, dynamic>? correctedValues;
  String? skippedResultId;
  String? abandonedExecutionId;
  String? abandonmentReason;
  String? finishedExecutionId;
  int? finalRpe;
  String? finalNotes;
  int? averageHeartRateBpm;
  int? maxHeartRateBpm;
  bool failComplete = false;
  final List<String> completedOperationIds = [];
  List<Map<String, dynamic>> publicTemplates = const [];
  Map<String, dynamic>? personalPayload;
  String? duplicatedTemplateId;
  String? archivedTemplateId;
  String? revisedTemplateId;
  Map<String, dynamic>? revisedPayload;

  @override
  Future<void> archivePersonalTemplate(String templateId) async {
    archivedTemplateId = templateId;
  }

  @override
  Future<String> createPersonalTemplate(Map<String, dynamic> payload) async {
    personalPayload = payload;
    return 'personal-template-1';
  }

  @override
  Future<String> duplicatePersonalTemplate(String templateId) async {
    duplicatedTemplateId = templateId;
    return 'personal-template-copy';
  }

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    Map<String, dynamic> payload,
  ) async {
    revisedTemplateId = templateId;
    revisedPayload = payload;
    return 'personal-template-v2';
  }

  @override
  Future<void> abandonExecution(
    String operationId,
    String executionId,
    String reason,
  ) async {
    abandonedExecutionId = executionId;
    abandonmentReason = reason;
  }

  @override
  Future<void> completeSet(
    String operationId,
    Map<String, dynamic> values,
  ) async {
    completedOperationIds.add(operationId);
    if (failComplete) throw Exception('sin conexión');
    completedValues = values;
  }

  @override
  Future<void> completeAmrap(
    String operationId,
    Map<String, dynamic> values,
  ) async {
    completedAmrapValues = values;
  }

  @override
  Future<void> correctSet(Map<String, dynamic> values) async {
    correctedValues = values;
  }

  @override
  Future<void> skipSet(String operationId, String resultId) async {
    skippedResultId = resultId;
  }

  @override
  Future<void> finishExecution(
    String operationId,
    String executionId, {
    required int finalRpe,
    String? notes,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
    WorkoutResultSource resultSource = WorkoutResultSource.manual,
  }) async {
    finishedExecutionId = executionId;
    this.finalRpe = finalRpe;
    finalNotes = notes;
    this.averageHeartRateBpm = averageHeartRateBpm;
    this.maxHeartRateBpm = maxHeartRateBpm;
  }

  @override
  Future<Map<String, dynamic>?> getExecution(String executionId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getExecutionHistory() async => const [];

  @override
  Future<Map<String, dynamic>?> getTemplateById(String id) async => null;

  @override
  Future<List<Map<String, dynamic>>> getPublicTemplates() async =>
      publicTemplates;

  @override
  Future<List<Map<String, dynamic>>> getPersonalTemplates() async => const [];

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
}

class _MemoryMutationQueue implements WorkoutMutationQueue {
  final List<PendingWorkoutMutation> mutations = [];

  @override
  Future<void> enqueue(PendingWorkoutMutation mutation) async {
    mutations.add(mutation);
  }

  @override
  Future<List<PendingWorkoutMutation>> readAll() async => List.of(mutations);

  @override
  Future<void> remove(String operationId) async {
    mutations.removeWhere((item) => item.operationId == operationId);
  }
}
