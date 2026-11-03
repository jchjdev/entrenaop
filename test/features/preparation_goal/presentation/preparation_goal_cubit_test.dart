import 'dart:async';

import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = PreparationProgram(
  id: 'a',
  name: 'A',
  kind: PreparationProgramKind.internalAssessment,
);
const _b = PreparationProgram(
  id: 'b',
  name: 'B',
  kind: PreparationProgramKind.internalAssessment,
);
const _goalA = PreparationGoal(id: 'goal-a', program: _a);
const _goalB = PreparationGoal(id: 'goal-b', program: _b);

void main() {
  test('una respuesta antigua no reemplaza el catálogo más reciente', () async {
    final repository = _Repository();
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    final first = cubit.load();
    final second = cubit.load();
    repository.completeRead(1, [_goalB]);
    await second;
    repository.completeRead(0, [_goalA]);
    await first;
    expect(cubit.state.goals, [_goalB]);
    expect(cubit.state.status, PreparationGoalStatus.ready);
  });

  test(
    'un error antiguo no convierte una carga nueva válida en fallo',
    () async {
      final repository = _Repository();
      final cubit = PreparationGoalCubit(repository: repository);
      addTearDown(cubit.close);
      final first = cubit.load();
      final second = cubit.load();
      repository.completeRead(1, [_goalB]);
      await second;
      repository.goalsReads[0].completeError(StateError('Error antiguo'));
      repository.programReads[0].complete([_a, _b]);
      await first;
      expect(cubit.state.goals, [_goalB]);
      expect(cubit.state.status, PreparationGoalStatus.ready);
      expect(cubit.state.errorMessage, isNull);
    },
  );

  test('recargar conserva el catálogo y los objetivos si falla', () async {
    final repository = _Repository();
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    await _load(cubit, repository, [_goalA, _goalB]);
    final pending = cubit.load();
    expect(cubit.state.goals, [_goalA, _goalB]);
    expect(cubit.state.programs, [_a, _b]);
    repository.goalsReads[1].completeError(StateError('Sin conexión'));
    repository.programReads[1].complete([_a, _b]);
    await pending;
    expect(cubit.state.status, PreparationGoalStatus.failure);
    expect(cubit.state.goals, [_goalA, _goalB]);
    expect(cubit.state.programs, [_a, _b]);
  });

  for (final fail in [false, true]) {
    test(
      'cerrar durante la carga recoge sus dos respuestas, fallo=$fail',
      () async {
        final repository = _Repository();
        final cubit = PreparationGoalCubit(repository: repository);
        final pending = cubit.load();
        await cubit.close();
        if (fail) {
          repository.goalsReads[0].completeError(
            StateError('Error de objetivos'),
          );
          repository.programReads[0].completeError(
            StateError('Error de catálogo'),
          );
        } else {
          repository.completeRead(0, [_goalA]);
        }
        await pending;
        expect(cubit.isClosed, isTrue);
      },
    );
  }

  for (final archive in [false, true]) {
    test(
      'salir mientras se guarda no emite en el controlador cerrado, archivar=$archive',
      () async {
        final repository = _Repository();
        final cubit = PreparationGoalCubit(repository: repository);
        await _load(cubit, repository, [_goalA]);
        final pending = archive ? cubit.archive(_goalA) : cubit.add(_b);
        await cubit.close();
        if (archive) {
          repository.archives.single.complete();
        } else {
          repository.saves.single.complete(_goalB);
        }
        await pending;
        expect(cubit.isClosed, isTrue);
      },
    );
  }

  test(
    'guardar prevalece sobre una recarga anterior y no duplica acciones',
    () async {
      final repository = _Repository();
      final cubit = PreparationGoalCubit(repository: repository);
      addTearDown(cubit.close);
      await _load(cubit, repository, [_goalA]);
      final oldLoad = cubit.load();
      final save = cubit.add(_b);
      await cubit.add(_b);
      await cubit.archive(_goalA);
      await cubit.load();
      expect(repository.saves.length, 1);
      expect(repository.archives, isEmpty);
      expect(repository.goalsReads.length, 2);
      repository.saves.single.complete(_goalB);
      await save;
      repository.completeRead(1, [_goalA]);
      await oldLoad;
      expect(cubit.state.goals, [_goalA, _goalB]);
      expect(cubit.state.status, PreparationGoalStatus.saved);
    },
  );

  test('editar fecha conserva el orden del objetivo en la lista', () async {
    final repository = _Repository();
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    await _load(cubit, repository, [_goalA, _goalB]);
    final updated = PreparationGoal(
      id: _goalA.id,
      program: _a,
      targetDate: DateTime(2027, 1, 1),
    );
    final pending = cubit.updateTargetDate(_goalA, updated.targetDate);
    repository.saves.single.complete(updated);
    await pending;
    expect(cubit.state.goals, [updated, _goalB]);
  });
}

Future<void> _load(
  PreparationGoalCubit cubit,
  _Repository repository,
  List<PreparationGoal> goals,
) async {
  final pending = cubit.load();
  repository.completeRead(repository.goalsReads.length - 1, goals);
  await pending;
}

class _Repository implements PreparationGoalRepository {
  final goalsReads = <Completer<List<PreparationGoal>>>[];
  final programReads = <Completer<List<PreparationProgram>>>[];
  final saves = <Completer<PreparationGoal>>[];
  final archives = <Completer<void>>[];
  @override
  Future<List<PreparationGoal>> getActiveGoals() {
    final answer = Completer<List<PreparationGoal>>();
    goalsReads.add(answer);
    return answer.future;
  }

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() {
    final answer = Completer<List<PreparationProgram>>();
    programReads.add(answer);
    return answer.future;
  }

  @override
  Future<PreparationGoal> save(PreparationGoal goal) {
    final answer = Completer<PreparationGoal>();
    saves.add(answer);
    return answer.future;
  }

  @override
  Future<void> archive(String goalId) {
    final answer = Completer<void>();
    archives.add(answer);
    return answer.future;
  }

  void completeRead(int index, List<PreparationGoal> goals) {
    goalsReads[index].complete(goals);
    programReads[index].complete([_a, _b]);
  }
}
