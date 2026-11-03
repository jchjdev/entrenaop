import 'dart:async';

import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _goal = PreparationGoal(
  id: 'goal',
  program: PreparationProgram(
    id: 'program',
    name: 'Preparación',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
final _week = DateTime(2026, 11, 2);

void main() {
  test('la semana recibida prevalece y se normaliza a lunes', () async {
    final loader = _Loader();
    final cubit = PreparationDetailCubit(
      goalId: 'goal',
      getDetail: loader,
      initialWeek: DateTime(2026, 11, 12, 17),
      now: () => DateTime(2027, 1, 1),
    );
    addTearDown(cubit.close);
    final pending = cubit.load();
    expect(loader.requests.single.week, DateTime(2026, 11, 9));
    expect(loader.requests.single.end, DateTime(2026, 11, 15));
    loader.requests.single.complete();
    await pending;
    expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
  });

  test(
    'volver de otro recorrido selecciona directamente su semana civil',
    () async {
      final loader = _Loader();
      final cubit = PreparationDetailCubit(
        goalId: 'goal',
        getDetail: loader,
        now: () => _week,
      );
      addTearDown(cubit.close);
      final pending = cubit.selectWeek(DateTime(2026, 10, 25, 13));
      expect(loader.requests.single.week, DateTime(2026, 10, 19));
      expect(loader.requests.single.end, DateTime(2026, 10, 25));
      loader.requests.single.complete();
      await pending;
      expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
    },
  );

  test(
    'las flechas conservan el lunes civil al cruzar un cambio de horario',
    () async {
      final loader = _Loader();
      final cubit = PreparationDetailCubit(
        goalId: 'goal',
        getDetail: loader,
        initialWeek: DateTime(2026, 10, 19),
      );
      addTearDown(cubit.close);
      final forward = cubit.changeWeek(1);
      expect(loader.requests[0].week, DateTime(2026, 10, 26));
      expect(loader.requests[0].week.hour, 0);
      expect(loader.requests[0].week.weekday, DateTime.monday);
      loader.requests[0].complete();
      await forward;
      final backward = cubit.changeWeek(-1);
      expect(loader.requests[1].week, DateTime(2026, 10, 19));
      loader.requests[1].complete();
      await backward;
      expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
    },
  );

  test('sin semana recibida abre la semana civil actual', () {
    final cubit = PreparationDetailCubit(
      goalId: 'goal',
      getDetail: _Loader(),
      now: () => DateTime(2026, 11, 5, 23),
    );
    addTearDown(cubit.close);
    expect(cubit.state.weekStart, _week);
  });

  test('una carga anterior no sustituye la nueva semana consultada', () async {
    final loader = _Loader();
    final cubit = PreparationDetailCubit(
      goalId: 'goal',
      getDetail: loader,
      now: () => _week,
    );
    addTearDown(cubit.close);
    final initial = cubit.load();
    final forward = cubit.changeWeek(1);
    loader.requests[1].complete();
    await forward;
    loader.requests[0].complete();
    await initial;
    expect(cubit.state.weekStart, _week.add(const Duration(days: 7)));
    expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
    expect(cubit.state.detail!.weekEnd, cubit.state.weekEnd);
  });

  test(
    'avanzar y volver conserva el último intervalo aunque responda antes',
    () async {
      final loader = _Loader();
      final cubit = PreparationDetailCubit(
        goalId: 'goal',
        getDetail: loader,
        now: () => _week,
      );
      addTearDown(cubit.close);
      final initial = cubit.load();
      loader.requests[0].complete();
      await initial;
      final forward = cubit.changeWeek(1);
      final backward = cubit.changeWeek(-1);
      loader.requests[2].complete();
      await backward;
      loader.requests[1].complete();
      await forward;
      expect(cubit.state.weekStart, _week);
      expect(cubit.state.detail!.weekStart, _week);
      expect(cubit.state.status, PreparationDetailStatus.ready);
    },
  );

  test(
    'un error obsoleto no tapa el éxito de la semana más reciente',
    () async {
      final loader = _Loader();
      final cubit = PreparationDetailCubit(
        goalId: 'goal',
        getDetail: loader,
        now: () => _week,
      );
      addTearDown(cubit.close);
      final initial = cubit.load();
      final forward = cubit.changeWeek(1);
      loader.requests[1].complete();
      await forward;
      loader.requests[0].answer.completeError(StateError('Respuesta vieja'));
      await initial;
      expect(cubit.state.status, PreparationDetailStatus.ready);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
    },
  );

  test('fallar la nueva semana no deja resultados de la anterior y permite reintentar', () async {
    final loader = _Loader();
    final cubit = PreparationDetailCubit(
      goalId: 'goal',
      getDetail: loader,
      now: () => _week,
    );
    addTearDown(cubit.close);
    final initial = cubit.load();
    loader.requests[0].complete();
    await initial;
    expect(cubit.state.detail, isNotNull);
    final next = cubit.changeWeek(1);
    expect(cubit.state.detail, isNull);
    expect(cubit.state.weekStart, _week.add(const Duration(days: 7)));
    loader.requests[1].answer.completeError(
      StateError('Falló la nueva semana'),
    );
    await next;
    expect(cubit.state.status, PreparationDetailStatus.failure);
    expect(cubit.state.detail, isNull);
    final retry = cubit.load();
    expect(loader.requests[2].week, _week.add(const Duration(days: 7)));
    loader.requests[2].complete();
    await retry;
    expect(cubit.state.status, PreparationDetailStatus.ready);
    expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
  });

  test(
    'refrescar la misma semana conserva su contenido incluso si falla',
    () async {
      final loader = _Loader();
      final cubit = PreparationDetailCubit(
        goalId: 'goal',
        getDetail: loader,
        now: () => _week,
      );
      addTearDown(cubit.close);
      final initial = cubit.load();
      loader.requests[0].complete();
      await initial;
      final previous = cubit.state.detail;
      final refresh = cubit.load();
      expect(cubit.state.detail, same(previous));
      loader.requests[1].answer.completeError(StateError('Error de refresco'));
      await refresh;
      expect(cubit.state.status, PreparationDetailStatus.failure);
      expect(cubit.state.detail, same(previous));
      expect(cubit.state.detail!.weekStart, cubit.state.weekStart);
    },
  );

  for (final fail in [false, true]) {
    test(
      'cerrar la ficha ignora su respuesta pendiente, fallo=$fail',
      () async {
        final loader = _Loader();
        final cubit = PreparationDetailCubit(
          goalId: 'goal',
          getDetail: loader,
          now: () => _week,
        );
        final pending = cubit.load();
        await cubit.close();
        if (fail) {
          loader.requests.single.answer.completeError(
            StateError('Respuesta tardía'),
          );
        } else {
          loader.requests.single.complete();
        }
        await pending;
        expect(cubit.isClosed, isTrue);
      },
    );
  }
}

class _Loader implements GetPreparationDetailUseCase {
  final requests = <_Request>[];
  @override
  Future<PreparationDetail> call(
    String goalId,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    expect(goalId, _goal.id);
    final request = _Request(weekStart, weekEnd);
    requests.add(request);
    return request.answer.future;
  }
}

class _Request {
  _Request(this.week, this.end);
  final DateTime week, end;
  final answer = Completer<PreparationDetail>();
  void complete() => answer.complete(
    PreparationDetail(
      goal: _goal,
      weekStart: week,
      weekEnd: end,
      weeklyWorkouts: const [],
    ),
  );
}
