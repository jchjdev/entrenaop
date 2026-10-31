// Ejecutor de producto con una sesión inventada y servicios solo en memoria.
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../test/helpers/memory_workout_session_draft_store.dart';
import '../../test/helpers/memory_workout_amrap_draft_store.dart';

class DemoActiveWorkout extends StatefulWidget {
  const DemoActiveWorkout({super.key});
  @override
  State<DemoActiveWorkout> createState() => _DemoActiveWorkoutState();
}

class _DemoActiveWorkoutState extends State<DemoActiveWorkout> {
  final repository = DemoExecution();
  final timer = DemoTimerStore();
  final cues = DemoSilentCues();
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ActiveWorkoutCubit(
      executionId: 'demo-execution',
      sessionDraftStore: MemoryWorkoutSessionDraftStore(),
      amrapDraftStore: MemoryWorkoutAmrapDraftStore(),
      getExecution: GetWorkoutExecutionUseCase(repository),
      completeSet: CompleteWorkoutSetUseCase(repository),
      completeAmrap: CompleteAmrapBlockUseCase(repository),
      correctSet: CorrectWorkoutSetUseCase(repository),
      skipSet: SkipWorkoutSetUseCase(repository),
      finishExecution: FinishWorkoutExecutionUseCase(repository),
      abandonExecution: AbandonWorkoutExecutionUseCase(repository),
      discardExecution: DiscardWorkoutExecutionUseCase(repository),
      getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(
        repository,
      ),
      timerStore: timer,
      cueService: cues,
    )..load(),
    child: ActiveWorkoutPage(timerStore: timer, cueService: cues),
  );
}

class DemoExecution implements WorkoutRepository {
  late final execution = WorkoutExecution(
    id: 'demo-execution',
    templateId: 'circuit',
    templateName: 'Fuerza · Circuito completo',
    templateVersion: 2,
    status: WorkoutExecutionStatus.inProgress,
    startedAt: DateTime.now().subtract(const Duration(minutes: 18)),
    sets: [
      for (var i = 0; i < 10; i++)
        WorkoutExecutionSet(
          id: 'completed-$i',
          blockOrder: i == 0 ? 0 : 1,
          blockName: i == 0
              ? 'Preparación del movimiento'
              : 'Circuito de fuerza · 3 rondas',
          blockFormat: i == 0
              ? WorkoutBlockFormat.warmUp
              : WorkoutBlockFormat.circuit,
          itemOrder: i == 0 ? 0 : (i - 1) % 3,
          exerciseId: i == 0
              ? 'mobility'
              : ['pull', 'lunge', 'push'][(i - 1) % 3],
          exerciseName: i == 0
              ? 'Movilidad y activación'
              : ['Dominadas', 'Zancadas', 'Flexiones'][(i - 1) % 3],
          setOrder: i == 0 ? 0 : (i - 1) ~/ 3,
          targetReps: i == 0 ? null : [6, 12, 12][(i - 1) % 3],
          targetDurationSeconds: i == 0 ? 300 : null,
          targetRir: i == 0 ? null : 2,
          restAfterSeconds: 60,
          status: WorkoutSetStatus.completed,
          actualReps: i == 0 ? null : [6, 12, 12][(i - 1) % 3],
          actualDurationSeconds: i == 0 ? 300 : null,
          actualRir: i == 0 ? null : 2,
        ),
      for (var i = 0; i < 3; i++)
        WorkoutExecutionSet(
          id: 'plank-$i',
          blockOrder: 2,
          blockName: 'Estabilidad del core',
          blockFormat: WorkoutBlockFormat.straightSets,
          itemOrder: 0,
          exerciseId: 'plank',
          exerciseName: 'Plancha isométrica',
          exerciseDescription:
              'Mantén una posición estable y respira con normalidad.',
          setOrder: i,
          targetDurationSeconds: 45,
          restAfterSeconds: 45,
          status: WorkoutSetStatus.pending,
        ),
    ],
  );
  @override
  Future<WorkoutExecution?> getExecution(String id) async => execution;
  @override
  Future<int> getPendingMutationCount() async => 0;
  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async => WorkoutMutationDisposition.synced;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Acción fuera del recorrido de filmación.');
}

class DemoTimerStore implements WorkoutTimerStore {
  final values = <String, WorkoutTimerSnapshot>{};
  @override
  Future<WorkoutTimerSnapshot?> read(String id) async => values[id];
  @override
  Future<void> write(String id, WorkoutTimerSnapshot snapshot) async {
    values[id] = snapshot;
  }

  @override
  Future<void> clear(String id) async {
    values.remove(id);
  }
}

class DemoSilentCues implements WorkoutCueService {
  @override
  WorkoutCuePreferences preferences = const WorkoutCuePreferences(
    soundEnabled: false,
    hapticsEnabled: false,
  );
  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async {
    this.preferences = preferences;
  }

  @override
  Future<void> prepare() async {}
  @override
  Future<bool> shouldOfferHapticsPermission() async => false;
  @override
  Future<void> markHapticsPermissionOffered() async {}
  @override
  Future<bool> requestHapticsPermission() async => false;
  @override
  Future<bool> previewSound() async => false;
  @override
  Future<bool> previewHaptics() async => false;
  @override
  Future<void> signal(WorkoutCue cue) async {}
}
