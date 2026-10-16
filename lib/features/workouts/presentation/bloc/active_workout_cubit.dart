import 'package:entrenaop/features/workouts/domain/services/workout_execution_rest_policy.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';

import '../../domain/services/workout_amrap_draft_store.dart';
import '../../domain/entities/workout_amrap_save_failure.dart';

import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';

class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  ActiveWorkoutCubit({
    required this.executionId,
    required WorkoutSessionDraftStore sessionDraftStore,
    required WorkoutAmrapDraftStore amrapDraftStore,
    CorrectWorkoutSetUseCase? correctSet,
    GetExerciseByIdUseCase? getExercise,
    required GetWorkoutExecutionUseCase getExecution,
    required CompleteWorkoutSetUseCase completeSet,
    required CompleteAmrapBlockUseCase completeAmrap,
    required SkipWorkoutSetUseCase skipSet,
    required FinishWorkoutExecutionUseCase finishExecution,
    required AbandonWorkoutExecutionUseCase abandonExecution,
    required DiscardWorkoutExecutionUseCase discardExecution,
    required GetPendingWorkoutMutationCountUseCase getPendingMutationCount,
    required WorkoutTimerStore timerStore,
    required WorkoutCueService cueService,
  }) : _amrapDraftStore = amrapDraftStore,
       _draftStore = sessionDraftStore,
       _correctSet = correctSet,
       _getExercise = getExercise,
       _getExecution = getExecution,
       _completeSet = completeSet,
       _completeAmrap = completeAmrap,
       _skipSet = skipSet,
       _finishExecution = finishExecution,
       _abandonExecution = abandonExecution,
       _discardExecution = discardExecution,
       _getPendingMutationCount = getPendingMutationCount,
       _timerStore = timerStore,
       _cueService = cueService,
       super(const ActiveWorkoutState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CompleteWorkoutSetUseCase _completeSet;
  final CompleteAmrapBlockUseCase _completeAmrap;
  final SkipWorkoutSetUseCase _skipSet;
  final FinishWorkoutExecutionUseCase _finishExecution;
  final AbandonWorkoutExecutionUseCase _abandonExecution;
  final DiscardWorkoutExecutionUseCase _discardExecution;
  final GetPendingWorkoutMutationCountUseCase _getPendingMutationCount;
  final WorkoutTimerStore _timerStore;
  final WorkoutCueService _cueService;
  Timer? _restTimer;
  final WorkoutSessionDraftStore _draftStore;
  final WorkoutAmrapDraftStore _amrapDraftStore;
  final _amrapDrafts = <int, WorkoutAmrapDraft>{};
  final CorrectWorkoutSetUseCase? _correctSet;
  final GetExerciseByIdUseCase? _getExercise;
  final _drafts = <String, WorkoutSessionSetDraft>{};
  final _exercises = <String, ExerciseEntity>{};
  final _savedSetIds = <String>{};
  bool _draftBusy = false;

  // La proyección local permite seguir entrenando; nunca se envía al motor
  // una serie sin confirmar ni se altera su prescripción histórica.
  WorkoutExecution _projectExecution(WorkoutExecution execution) {
    if (execution.status != WorkoutExecutionStatus.inProgress) return execution;
    var projected = execution;
    for (final draft in _drafts.values.where((d) => d.endedAt != null)) {
      projected = _completeLocally(
        projected,
        draft.result.resultId,
        draft.result,
        completedAt: draft.endedAt,
      );
    }
    return projected;
  }

  Future<WorkoutExecution?> _readProjectedExecution() async {
    final execution = await _getExecution(executionId);
    return execution == null ? null : _projectExecution(execution);
  }

  void _publish(ActiveWorkoutState next) {
    if (isClosed) return;
    final execution = next.execution == null
        ? null
        : _projectExecution(next.execution!);
    emit(
      ActiveWorkoutState(
        status: next.status,
        execution: execution,
        restSecondsRemaining: next.restSecondsRemaining,
        restCanBeSkipped: next.restCanBeSkipped,
        pendingSyncCount: next.pendingSyncCount,
        errorMessage: next.errorMessage,
        drafts: Map.unmodifiable(_drafts),
        exercises: Map.unmodifiable(_exercises),
        draftBusy: _draftBusy,
        amrapDrafts: Map.unmodifiable(_amrapDrafts),
      ),
    );
  }

  void _refresh({String? error}) => _publish(
    ActiveWorkoutState(
      status: state.status,
      execution: state.execution,
      restSecondsRemaining: state.restSecondsRemaining,
      restCanBeSkipped: state.restCanBeSkipped,
      pendingSyncCount: state.pendingSyncCount,
      errorMessage: error,
    ),
  );

  Future<void> _loadExercises(WorkoutExecution execution) async {
    final getExercise = _getExercise;
    if (getExercise == null) return;
    final ids = execution.sets.map((s) => s.exerciseId).toSet().toList();
    for (var offset = 0; offset < ids.length; offset += 4) {
      if (isClosed) return;
      await Future.wait(
        ids.skip(offset).take(4).map((id) async {
          try {
            final exercise = await getExercise(id);
            if (!isClosed && exercise != null) _exercises[id] = exercise;
          } catch (_) {
            /* Una foto fallida no bloquea el entrenamiento. */
          }
        }),
      );
      if (!isClosed) _refresh(error: state.errorMessage);
    }
  }

  Future<void> updateDraft(
    WorkoutSetResultInput result,
    Map<String, String> fields,
  ) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final execution = state.execution;
    if (execution == null ||
        execution.status != WorkoutExecutionStatus.inProgress) {
      return;
    }
    final matches = execution.sets.where((s) => s.id == result.resultId);
    if (matches.isEmpty || matches.first.performancePrescription != null) {
      return;
    }
    final set = matches.first;
    final old = _drafts[result.resultId];
    _drafts[result.resultId] = WorkoutSessionSetDraft(
      result: result,
      fields: Map.unmodifiable(fields),
      endedAt:
          old?.endedAt ??
          (set.status == WorkoutSetStatus.completed ? set.completedAt : null),
      saved: old?.saved ?? _savedSetIds.contains(set.id),
      needsCorrection: (old?.saved ?? _savedSetIds.contains(set.id)),
    );
    try {
      await _draftStore.write(executionId, Map.of(_drafts));
      _refresh();
    } catch (_) {
      _refresh(
        error: 'No se ha podido guardar el borrador en este dispositivo. Reintenta antes de salir.',
      );
    }
  }

  Future<void> endCurrentSet({int? elapsedSeconds}) async {
    if (_draftBusy ||
        state.status == ActiveWorkoutStatus.saving ||
        state.status == ActiveWorkoutStatus.resting) {
      return;
    }
    final execution = state.execution;
    final set = execution?.currentSet;
    if (execution == null ||
        set == null ||
        set.performancePrescription != null ||
        set.blockFormat == WorkoutBlockFormat.amrap) {
      return;
    }
    _draftBusy = true;
    _refresh();
    final old = _drafts[set.id];
    _drafts[set.id] =
        (old ??
                WorkoutSessionSetDraft(
                  result: WorkoutSetResultInput(resultId: set.id),
                ))
            .copyWith(endedAt: DateTime.now().toUtc());
    try {
      await _draftStore.write(executionId, Map.of(_drafts));
      await _timerStore.clear(_timerId(set.id));
      var updated = _completeLocally(
        execution,
        set.id,
        _drafts[set.id]!.result,
      );
      _draftBusy = false;
      final rest = workoutRestAfterSet(set, elapsedSeconds: elapsedSeconds);
      if (updated.currentSet != null && rest > 0) {
        _startRest(
          updated,
          rest,
          state.pendingSyncCount,
          canBeSkipped: set.blockFormat != WorkoutBlockFormat.emom,
        );
      } else {
        _publish(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: updated,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      }
    } catch (_) {
      if (old == null) {
        _drafts.remove(set.id);
      } else {
        _drafts[set.id] = old;
      }
      _draftBusy = false;
      _refresh(
        error:
            'No se ha podido conservar la serie. Reintenta antes de continuar.',
      );
    }
  }

  /// Confirma una serie pendiente sin reiniciar ni detener su descanso.
  /// Los retoques de una serie ya enviada se consolidan una vez al cerrar.
  Future<bool> confirmDraft(
    WorkoutSetResultInput result,
    Map<String, String> fields,
  ) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return false;
    final set = state.execution?.sets
        .where((s) => s.id == result.resultId)
        .firstOrNull;
    if (set == null ||
        !WorkoutSessionSetDraft(result: result).canConfirm(set)) {
      _refresh(
        error:
            'Revisa los datos: faltan valores válidos para confirmar la serie.',
      );
      return false;
    }
    final old =
        _drafts[result.resultId] ??
        (set.status == WorkoutSetStatus.completed
            ? WorkoutSessionSetDraft(
                result: result,
                endedAt: set.completedAt ?? DateTime.now().toUtc(),
                saved: true,
                needsCorrection: true,
              )
            : null);
    if (old?.endedAt == null) return false;
    _draftBusy = true;
    _refresh();
    try {
      var draft = old!.copyWith(
        result: result,
        fields: Map.unmodifiable(fields),
        confirmed: true,
      );
      _drafts[result.resultId] = draft;
      await _draftStore.write(executionId, Map.of(_drafts));
      if (!draft.saved) {
        await _completeSet(result);
        _savedSetIds.add(result.resultId);
        draft = draft.copyWith(saved: true, needsCorrection: false);
        _drafts[result.resultId] = draft;
        await _draftStore.write(executionId, Map.of(_drafts));
      }
      _draftBusy = false;
      _publish(
        ActiveWorkoutState(
          status: state.status,
          execution: state.execution,
          restSecondsRemaining: state.restSecondsRemaining,
          restCanBeSkipped: state.restCanBeSkipped,
          pendingSyncCount: await _getPendingMutationCount(),
        ),
      );
      return true;
    } catch (_) {
      // La respuesta remota puede ser incierta: se conserva el dato y se
      // reintenta mediante el registro idempotente existente.
      _drafts[result.resultId] = _drafts[result.resultId]!.copyWith(
        confirmed: false,
      );
      await _draftStore
          .write(executionId, Map.of(_drafts))
          .catchError((Object _) {});
      _draftBusy = false;
      _refresh(
        error: 'No se han podido confirmar los datos. Se conserva el borrador para reintentar.',
      );
      return false;
    }
  }

  Future<void> _flushSessionEdits() async {
    for (final draft in _drafts.values.toList()) {
      if (draft.endedAt == null) continue;
      if (!draft.confirmed) {
        throw StateError('Hay series con datos pendientes de confirmar.');
      }
      if (!draft.saved) {
        await _completeSet(draft.result);
        _drafts[draft.result.resultId] = draft.copyWith(saved: true);
      } else if (draft.needsCorrection) {
        final correct = _correctSet;
        if (correct == null) {
          throw StateError('La corrección no está disponible.');
        }
        // Sincroniza antes el registro inicial, también si estaba en cola.
        await _getExecution(executionId);
        final r = draft.result;
        await correct(
          WorkoutSetCorrectionInput(
            resultId: r.resultId,
            reason: 'Revisión de datos durante el entrenamiento',
            actualReps: r.actualReps,
            actualDurationSeconds: r.actualDurationSeconds,
            actualDistanceMeters: r.actualDistanceMeters,
            actualLoadKg: r.actualLoadKg,
            actualRpe: r.actualRpe,
            actualRir: r.actualRir,
            actualRecoveryDurationSeconds: r.actualRecoveryDurationSeconds,
            actualRecoveryDistanceMeters: r.actualRecoveryDistanceMeters,
            performanceResult: r.performanceResult,
          ),
        );
        _drafts[r.resultId] = draft.copyWith(needsCorrection: false);
      }
      await _draftStore.write(executionId, Map.of(_drafts));
    }
  }

  Future<void> load() async {
    _publish(const ActiveWorkoutState(status: ActiveWorkoutStatus.loading));
    try {
      var execution = await _getExecution(executionId);
      if (execution != null) {
        _savedSetIds.addAll(
          execution.sets
              .where((s) => s.status == WorkoutSetStatus.completed)
              .map((s) => s.id),
        );
        final loaded = await _draftStore.read(executionId);
        final amrapLoaded = await _amrapDraftStore.read(executionId);
        final pendingAmrap = execution.sets
            .where(
              (s) =>
                  s.blockFormat == WorkoutBlockFormat.amrap &&
                  s.status == WorkoutSetStatus.pending,
            )
            .map((s) => s.blockOrder)
            .toSet();
        _amrapDrafts.addAll(
          Map.fromEntries(
            amrapLoaded.entries.where(
              (entry) => pendingAmrap.contains(entry.key),
            ),
          ),
        );
        final ids = execution.sets.map((s) => s.id).toSet();
        _drafts.addAll(
          Map.fromEntries(loaded.entries.where((e) => ids.contains(e.key))),
        );
        for (final entry in _drafts.entries.toList()) {
          if (_savedSetIds.contains(entry.key) && !entry.value.saved) {
            _drafts[entry.key] = entry.value.copyWith(
              saved: true,
              needsCorrection: true,
            );
          }
        }
        unawaited(_loadExercises(execution));
      }
      final pendingSyncCount = await _getPendingMutationCount();
      if (execution == null) {
        _publish(
          const ActiveWorkoutState(
            status: ActiveWorkoutStatus.failure,
            errorMessage: 'No encontramos esta ejecución.',
          ),
        );
        return;
      }
      if (execution.status == WorkoutExecutionStatus.inProgress) {
        for (final draft in _drafts.values.where((d) => d.endedAt != null)) {
          execution = _completeLocally(
            execution!,
            draft.result.resultId,
            draft.result,
          );
        }
      } else {
        _drafts.clear();
        await _draftStore.clear(executionId).catchError((Object _) {});
        _amrapDrafts.clear();
        await _amrapDraftStore.clear(executionId).catchError((Object _) {});
      }
      final activeExecution = execution!;
      final restSnapshot = await _timerStore.read(_restTimerId);
      if (activeExecution.status == WorkoutExecutionStatus.inProgress &&
          activeExecution.currentSet != null &&
          restSnapshot?.phase == WorkoutTimerPhase.running) {
        final elapsedSinceWrite = DateTime.now().toUtc().difference(
          restSnapshot!.phaseStartedAt,
        );
        final elapsed =
            restSnapshot.elapsedBeforeRun +
            (elapsedSinceWrite.isNegative ? Duration.zero : elapsedSinceWrite);
        final remaining = restSnapshot.targetSeconds - elapsed.inSeconds;
        if (remaining > 0) {
          _startRest(
            activeExecution,
            remaining,
            pendingSyncCount,
            canBeSkipped: restSnapshot.restCanBeSkipped,
            totalSeconds: restSnapshot.targetSeconds,
          );
          return;
        }
      }
      if (restSnapshot != null) await _timerStore.clear(_restTimerId);
      _publish(
        ActiveWorkoutState(
          status: switch (activeExecution.status) {
            WorkoutExecutionStatus.completed => ActiveWorkoutStatus.completed,
            WorkoutExecutionStatus.abandoned => ActiveWorkoutStatus.abandoned,
            WorkoutExecutionStatus.inProgress => ActiveWorkoutStatus.ready,
          },
          execution: activeExecution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      _publish(
        const ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          errorMessage: 'No hemos podido recuperar la sesión.',
        ),
      );
    }
  }

  Future<void> completeCurrentSet(
    WorkoutSetResultInput result, {
    int? restSecondsOverride,
  }) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final execution = state.execution;
    final currentSet = execution?.currentSet;
    if (execution == null || currentSet == null) return;

    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _completeSet(result);
      _savedSetIds.add(result.resultId);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = disposition == WorkoutMutationDisposition.queued
          ? _completeLocally(execution, currentSet.id, result)
          : await _readProjectedExecution();
      if (updated == null) throw StateError('Execution disappeared');
      final pendingSyncCount = await _getPendingMutationCount();
      final restSeconds = (restSecondsOverride ?? currentSet.restAfterSeconds)
          .clamp(0, 3600)
          .toInt();
      if (updated.currentSet == null || restSeconds == 0) {
        await _timerStore.clear(_restTimerId);
        _publish(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: updated,
            pendingSyncCount: pendingSyncCount,
          ),
        );
        return;
      }
      _startRest(
        updated,
        restSeconds,
        pendingSyncCount,
        canBeSkipped: currentSet.blockFormat != WorkoutBlockFormat.emom,
      );
    } catch (_) {
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido guardar la serie.',
        ),
      );
      await _timerStore.clear(_restTimerId);
    }
  }

  Future<void> changeAmrapRounds(int blockOrder, int delta) => updateAmrapDraft(
    blockOrder,
    (_amrapDrafts[blockOrder] ?? const WorkoutAmrapDraft()).changeRounds(delta),
  );

  Future<void> updateAmrapDraft(int blockOrder, WorkoutAmrapDraft draft) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final current = state.execution?.currentSet;
    if (current?.blockFormat != WorkoutBlockFormat.amrap ||
        current?.blockOrder != blockOrder) {
      return;
    }
    _amrapDrafts[blockOrder] = draft;
    _refresh();
    try {
      await _amrapDraftStore.write(executionId, Map.of(_amrapDrafts));
    } catch (_) {
      _refresh(
        error: 'No se ha podido guardar la cuenta en este dispositivo. Conservamos los datos abiertos; reintenta antes de salir.',
      );
    }
  }

  Future<bool> completeCurrentAmrap(WorkoutAmrapResultInput result) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return false;
    final execution = state.execution;
    final current = execution?.currentSet;
    if (execution == null ||
        result.executionId != executionId ||
        current == null ||
        current.blockFormat != WorkoutBlockFormat.amrap ||
        current.blockOrder != result.blockOrder) {
      return false;
    }
    final sequence = execution.sets
        .where((s) => s.blockOrder == result.blockOrder)
        .toList();
    final draft = WorkoutAmrapDraft(
      rounds: '${result.completedRounds}',
      hasPartial: result.partialItemOrder != null,
      partialItemOrder: result.partialItemOrder,
      partialReps: '${result.partialReps}',
    );
    final error = draft.validate(sequence);
    if (error != null ||
        (result.partialItemOrder == null && result.partialReps != 0)) {
      _refresh(error: error ?? 'Selecciona el ejercicio del parcial.');
      return false;
    }
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    var disposition = WorkoutMutationDisposition.synced;
    try {
      disposition = await _completeAmrap(result);
    } catch (error) {
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: error is WorkoutAmrapSaveFailure
              ? '${error.message} Tus datos se conservan.'
              : 'No hemos podido guardar el resultado AMRAP. Tus datos se conservan; comprueba la conexión y reintenta.',
        ),
      );
      return false;
    }
    // Una escritura aceptada o encolada no depende de otra lectura para tener
    // éxito. Tampoco se vuelve a enviar si falla la limpieza del reloj/disco.
    final updated = _completeAmrapLocally(execution, result);
    _amrapDrafts.remove(result.blockOrder);
    String? warning;
    try {
      await _timerStore.clear(_amrapTimerId(result.blockOrder));
      await _amrapDraftStore.write(executionId, Map.of(_amrapDrafts));
    } catch (_) {
      warning =
          'Resultado registrado. No se ha podido limpiar el borrador local.';
    }
    var pending =
        state.pendingSyncCount +
        (disposition == WorkoutMutationDisposition.queued ? 1 : 0);
    try {
      pending = await _getPendingMutationCount();
    } catch (_) {
      warning = 'Resultado registrado. No hemos podido actualizar el estado de sincronización.';
    }
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.ready,
        execution: updated,
        pendingSyncCount: pending,
        errorMessage: warning,
      ),
    );
    return true;
  }

  /// Omitir el guiado no escribe resultados de capacidad ni omite trabajo.
  Future<void> skipWarmUp() async {
    final current = state.execution?.currentSet;
    if (current?.blockFormat != WorkoutBlockFormat.warmUp ||
        state.status == ActiveWorkoutStatus.saving) {
      return;
    }
    final blockOrder = current!.blockOrder;
    while (!isClosed &&
        state.execution?.currentSet?.blockOrder == blockOrder &&
        state.execution?.currentSet?.blockFormat == WorkoutBlockFormat.warmUp) {
      await skipCurrentSet();
      if (state.status == ActiveWorkoutStatus.failure) return;
    }
  }

  Future<void> skipCurrentSet({int? restSecondsOverride}) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final execution = state.execution;
    final currentSet = execution?.currentSet;
    if (execution == null || currentSet == null) return;

    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _skipSet(currentSet.id);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = disposition == WorkoutMutationDisposition.queued
          ? _skipLocally(execution, currentSet.id)
          : await _readProjectedExecution();
      if (updated == null) throw StateError('Execution disappeared');
      final pendingSyncCount = await _getPendingMutationCount();
      final restSeconds = (restSecondsOverride ?? 0).clamp(0, 3600).toInt();
      if (updated.currentSet != null && restSeconds > 0) {
        _startRest(
          updated,
          restSeconds,
          pendingSyncCount,
          canBeSkipped: currentSet.blockFormat != WorkoutBlockFormat.emom,
        );
        return;
      }
      await _timerStore.clear(_restTimerId);
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.ready,
          execution: updated,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido saltar la serie.',
        ),
      );
    }
  }

  void _startRest(
    WorkoutExecution execution,
    int seconds,
    int pendingSyncCount, {
    bool canBeSkipped = true,
    int? totalSeconds,
  }) {
    final total = totalSeconds ?? seconds;
    _restTotalSeconds = total;
    _restTimer?.cancel();
    unawaited(
      _timerStore.write(
        _restTimerId,
        WorkoutTimerSnapshot(
          phase: WorkoutTimerPhase.running,
          targetSeconds: total,
          preparationSeconds: 0,
          phaseStartedAt: DateTime.now().toUtc(),
          elapsedBeforeRun: Duration(seconds: total - seconds),
          restCanBeSkipped: canBeSkipped,
        ),
      ),
    );
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.resting,
        execution: execution,
        restSecondsRemaining: seconds,
        restCanBeSkipped: canBeSkipped,
        pendingSyncCount: pendingSyncCount,
      ),
    );
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.restSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_timerStore.clear(_restTimerId));
        unawaited(_cueService.signal(WorkoutCue.restFinished));
        _publish(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: state.execution,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      } else {
        if (total > 10 && remaining == 10) {
          unawaited(_cueService.signal(WorkoutCue.tenSecondsRemaining));
        } else if (total >= 20 && remaining == total ~/ 2) {
          unawaited(_cueService.signal(WorkoutCue.halfway));
        }
        _publish(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.resting,
            execution: state.execution,
            restSecondsRemaining: remaining,
            restCanBeSkipped: state.restCanBeSkipped,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      }
    });
  }

  void skipRest() {
    if (state.status != ActiveWorkoutStatus.resting ||
        !state.restCanBeSkipped) {
      return;
    }
    _restTimer?.cancel();
    unawaited(_timerStore.clear(_restTimerId));
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.ready,
        execution: state.execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
  }

  Future<void> finish({
    required int finalRpe,
    String? notes,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
  }) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final execution = state.execution;
    if (execution == null || execution.currentSet != null) return;
    if (state.unconfirmedDraftCount > 0) {
      _refresh(
        error: 'Revisa las series con datos pendientes antes de finalizar.',
      );
      return;
    }
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      await _flushSessionEdits();
      final disposition = await _finishExecution(
        executionId,
        finalRpe: finalRpe,
        notes: notes,
        averageHeartRateBpm: averageHeartRateBpm,
        maxHeartRateBpm: maxHeartRateBpm,
      );
      final updated = disposition == WorkoutMutationDisposition.queued
          ? execution.copyWith(
              status: WorkoutExecutionStatus.completed,
              completedAt: DateTime.now().toUtc(),
              finalRpe: finalRpe,
              notes: notes?.trim(),
              averageHeartRateBpm: averageHeartRateBpm,
              maxHeartRateBpm: maxHeartRateBpm,
              resultSource: WorkoutResultSource.manual,
            )
          : await _readProjectedExecution();
      _drafts.clear();
      await _draftStore.clear(executionId).catchError((Object _) {});
      _amrapDrafts.clear();
      await _amrapDraftStore.clear(executionId).catchError((Object _) {});
      final pendingSyncCount = await _getPendingMutationCount();
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.completed,
          execution: updated ?? execution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido finalizar la sesión. Si hay correcciones pendientes, comprueba la conexión y reintenta; tus datos se conservan.',
        ),
      );
    }
  }

  Future<void> abandon(WorkoutAbandonmentReason reason) async {
    if (_draftBusy || state.status == ActiveWorkoutStatus.saving) return;
    final execution = state.execution;
    if (execution == null ||
        execution.status != WorkoutExecutionStatus.inProgress) {
      return;
    }
    if (_amrapDrafts.values.any(
      (draft) => draft.rounds != '0' || draft.hasPartial,
    )) {
      _refresh(
        error: 'Revisa el resultado AMRAP antes de cerrar conservando lo realizado. Puedes salir y retomar después.',
      );
      return;
    }
    if (state.unconfirmedDraftCount > 0) {
      _refresh(
        error: 'Confirma los datos pendientes antes de cerrar conservando lo realizado. Puedes salir y retomar después.',
      );
      return;
    }
    _restTimer?.cancel();
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      await _timerStore.clear(_restTimerId);
      await _flushSessionEdits();
      final disposition = await _abandonExecution(executionId, reason);
      final currentSet = execution.currentSet;
      if (currentSet != null) {
        await _timerStore.clear(_timerId(currentSet.id));
      }
      final updated = disposition == WorkoutMutationDisposition.queued
          ? execution.copyWith(
              status: WorkoutExecutionStatus.abandoned,
              completedAt: DateTime.now().toUtc(),
              abandonmentReason: reason,
            )
          : await _readProjectedExecution();
      _drafts.clear();
      await _draftStore.clear(executionId).catchError((Object _) {});
      _amrapDrafts.clear();
      await _amrapDraftStore.clear(executionId).catchError((Object _) {});
      final pendingSyncCount = await _getPendingMutationCount();
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.abandoned,
          execution: updated ?? execution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      _publish(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido abandonar la sesión.',
        ),
      );
    }
  }

  String _timerId(String resultId) => '$executionId:$resultId';

  Future<bool> discard() async {
    final previous = state;
    final execution = previous.execution;
    if (execution == null ||
        execution.status != WorkoutExecutionStatus.inProgress ||
        previous.status == ActiveWorkoutStatus.saving ||
        _draftBusy) {
      return false;
    }
    _restTimer?.cancel();
    final elapsed = Stopwatch()..start();
    _publish(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: previous.pendingSyncCount,
      ),
    );
    try {
      await _discardExecution(executionId);
    } catch (_) {
      if (isClosed) return false;
      final remaining =
          previous.restSecondsRemaining - elapsed.elapsed.inSeconds;
      final resumeRest =
          previous.status == ActiveWorkoutStatus.resting && remaining > 0;
      if (resumeRest) {
        _startRest(
          execution,
          remaining,
          previous.pendingSyncCount,
          canBeSkipped: previous.restCanBeSkipped,
          totalSeconds: _restTotalSeconds,
        );
      }
      _publish(
        ActiveWorkoutState(
          status: previous.status == ActiveWorkoutStatus.resting
              ? (resumeRest
                    ? ActiveWorkoutStatus.resting
                    : ActiveWorkoutStatus.ready)
              : previous.status,
          execution: execution,
          restSecondsRemaining: resumeRest ? remaining : 0,
          restCanBeSkipped: previous.restCanBeSkipped,
          pendingSyncCount: previous.pendingSyncCount,
          errorMessage: 'No se ha podido confirmar el descarte. Comprueba la conexión y vuelve a intentarlo.',
        ),
      );
      return false;
    }
    _restTimer?.cancel();
    // Una limpieza local fallida no puede deshacer un descarte remoto confirmado.
    try {
      await _timerStore.clear(_restTimerId);
      for (final set in execution.sets) {
        await _timerStore.clear(_timerId(set.id));
        await _timerStore.clear(_amrapTimerId(set.blockOrder));
      }
    } catch (_) {}
    _drafts.clear();
    await _draftStore.clear(executionId).catchError((Object _) {});
    _amrapDrafts.clear();
    await _amrapDraftStore.clear(executionId).catchError((Object _) {});
    if (!isClosed) {
      _publish(const ActiveWorkoutState(status: ActiveWorkoutStatus.discarded));
    }
    return true;
  }

  String get _restTimerId => '$executionId:rest';

  int _restTotalSeconds = 0;

  String _amrapTimerId(int blockOrder) => '$executionId:amrap:$blockOrder';

  WorkoutExecution _completeLocally(
    WorkoutExecution execution,
    String resultId,
    WorkoutSetResultInput result, {
    DateTime? completedAt,
  }) => execution.copyWith(
    sets: execution.sets
        .map(
          (set) => set.id == resultId
              ? set.copyWith(
                  status: WorkoutSetStatus.completed,
                  replaceResult: true,
                  actualReps: result.actualReps,
                  actualDurationSeconds: result.actualDurationSeconds,
                  actualDistanceMeters: result.actualDistanceMeters,
                  actualLoadKg: result.actualLoadKg,
                  actualRpe: result.actualRpe,
                  actualRir: result.actualRir,
                  performanceResult: result.performanceResult,
                  actualRecoveryDurationSeconds:
                      result.actualRecoveryDurationSeconds,
                  actualRecoveryDistanceMeters:
                      result.actualRecoveryDistanceMeters,
                  resultSource: result.resultSource,
                  completedAt:
                      completedAt ?? set.completedAt ?? DateTime.now().toUtc(),
                )
              : set,
        )
        .toList(growable: false),
  );

  WorkoutExecution _skipLocally(WorkoutExecution execution, String resultId) =>
      execution.copyWith(
        sets: execution.sets
            .map(
              (set) => set.id == resultId
                  ? set.copyWith(status: WorkoutSetStatus.skipped)
                  : set,
            )
            .toList(growable: false),
      );

  WorkoutExecution _completeAmrapLocally(
    WorkoutExecution execution,
    WorkoutAmrapResultInput result,
  ) => execution.copyWith(
    sets: execution.sets
        .map(
          (set) => set.blockOrder == result.blockOrder
              ? set.copyWith(
                  status: WorkoutSetStatus.completed,
                  completedAt: DateTime.now().toUtc(),
                )
              : set,
        )
        .toList(growable: false),
    amrapResults: [
      ...execution.amrapResults,
      WorkoutAmrapResult(
        blockOrder: result.blockOrder,
        completedRounds: result.completedRounds,
        partialItemOrder: result.partialItemOrder,
        partialReps: result.partialReps,
        completedAt: DateTime.now().toUtc(),
      ),
    ],
  );

  @override
  Future<void> close() async {
    _restTimer?.cancel();
    await super.close();
  }
}
