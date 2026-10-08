import 'dart:async';

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Repository repo;
  late WorkoutHistoryCubit cubit;
  setUp(() {
    repo = _Repository();
    cubit = WorkoutHistoryCubit(getHistory: GetWorkoutHistoryUseCase(repo));
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('consulta 65 sesiones, incluidas fechas iguales, sin corte a 30 ni duplicados', () async {
    await cubit.load();
    expect(cubit.state.executions, hasLength(30));
    expect(cubit.state.hasMore, isTrue);
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(60));
    expect(repo.queries.last.before?.id, repo.rows[29].id);
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(65));
    expect(cubit.state.executions.map((e) => e.id).toSet(), hasLength(65));
    expect(cubit.state.hasMore, isFalse);
    await cubit.loadMore();
    expect(repo.queries, hasLength(3));
  });
  test('refrescar conserva la profundidad del historial consultado', () async {
    await cubit.load();
    await cubit.loadMore();
    await cubit.load();
    expect(cubit.state.executions, hasLength(60));
    expect(repo.queries.skip(2).map((q) => q.limit), [31, 31]);
    expect(repo.queries[2].before, isNull);
    expect(repo.queries.last.before?.id, repo.rows[29].id);
  });
  test('tipo se mantiene en todas las páginas, refresco y fallo', () async {
    await cubit.filter(
      const WorkoutHistoryQuery(sessionType: WorkoutSessionType.running),
    );
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(33));
    expect(
      cubit.state.executions.every(
        (e) => e.sessionType == WorkoutSessionType.running,
      ),
      isTrue,
    );
    expect(cubit.state.hasMore, isFalse);
    repo.next = (_) async => throw StateError('offline');
    await cubit.load();
    expect(cubit.state.query.sessionType, WorkoutSessionType.running);
    expect(cubit.state.executions, hasLength(33));
    repo.next = null;
    await cubit.load();
    expect(cubit.state.executions, hasLength(33));
    expect(
      repo.queries.every((q) => q.sessionType == WorkoutSessionType.running),
      isTrue,
    );
    await cubit.filter(
      const WorkoutHistoryQuery(sessionType: WorkoutSessionType.unclassified),
    );
    expect(cubit.state.executions, isEmpty);
    expect(cubit.state.query.hasFilters, isTrue);
  });
  test(
    'un historial de más de mil sesiones tampoco se trunca al refrescar',
    () async {
      final base = repo.rows.first;
      repo.rows.clear();
      repo.rows.addAll(
        List.generate(
          1205,
          (i) => WorkoutExecution(
            id: 'entry-$i',
            templateId: base.templateId,
            templateName: base.templateName,
            templateVersion: 1,
            status: base.status,
            startedAt: base.startedAt,
            completedAt: base.completedAt,
            sets: const [],
          ),
        ),
      );
      await cubit.load();
      while (cubit.state.hasMore) {
        await cubit.loadMore();
      }
      expect(cubit.state.executions, hasLength(1205));
      await cubit.load();
      expect(cubit.state.executions, hasLength(1205));
      expect(cubit.state.hasMore, isFalse);
      expect(repo.queries.every((q) => q.limit <= 31), isTrue);
    },
  );
  test('fallar al cargar más conserva sesiones y permite reintentar', () async {
    await cubit.load();
    repo.next = (_) async => throw StateError('offline');
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(30));
    expect(cubit.state.moreError, isNotNull);
    expect(cubit.state.isLoadingMore, isFalse);
    repo.next = null;
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(60));
    expect(cubit.state.moreError, isNull);
  });
  test('cargar otra página no oculta un fallo pendiente de refresco', () async {
    await cubit.load();
    repo.next = (_) async => throw StateError('offline');
    await cubit.load();
    final message = cubit.state.errorMessage;
    expect(message, isNotNull);
    repo.next = null;
    await cubit.loadMore();
    expect(cubit.state.executions, hasLength(60));
    expect(cubit.state.errorMessage, message);
    await cubit.load();
    expect(cubit.state.errorMessage, isNull);
  });
  test('cambiar filtros descarta una página antigua pendiente y conserva criterios', () async {
    await cubit.load();
    final old = Completer<List<WorkoutExecution>>();
    repo.next = (_) => old.future;
    final more = cubit.loadMore();
    repo.next = (_) async => [];
    final query = WorkoutHistoryQuery(
      preparationGoalId: 'goal',
      from: DateTime(2026, 9, 1),
      through: DateTime(2026, 9, 30),
      status: WorkoutExecutionStatus.abandoned,
      sessionType: WorkoutSessionType.mixed,
    );
    await cubit.filter(query);
    old.complete(repo.rows.skip(30).take(31).toList());
    await more;
    expect(cubit.state.query, query);
    expect(cubit.state.executions, isEmpty);
    expect(cubit.state.isLoadingMore, isFalse);
    expect(repo.queries.last.preparationGoalId, 'goal');
    expect(repo.queries.last.status, WorkoutExecutionStatus.abandoned);
    expect(repo.queries.last.sessionType, WorkoutSessionType.mixed);
  });
  test(
    'cerrar durante la carga de otra página no emite ni repite consultas',
    () async {
      await cubit.load();
      final pending = Completer<List<WorkoutExecution>>();
      repo.next = (_) => pending.future;
      final more = cubit.loadMore();
      await cubit.loadMore();
      expect(repo.queries, hasLength(2));
      await cubit.close();
      pending.complete([]);
      await more;
    },
  );
}

class _Repository implements WorkoutRepository {
  final queries = <WorkoutHistoryQuery>[];
  final rows = List.generate(
    65,
    (index) => WorkoutExecution(
      id: (100 - index).toString(),
      templateId: 'template',
      templateName: 'Sesión $index',
      templateVersion: 1,
      sessionType: index.isEven
          ? WorkoutSessionType.running
          : WorkoutSessionType.strength,
      sessionTypePolicy: 'block_format_v1',
      status: WorkoutExecutionStatus.completed,
      startedAt: DateTime.utc(2026, 9, 20),
      completedAt: DateTime.utc(2026, 9, 20, 1),
      sets: const [],
    ),
  );
  Future<List<WorkoutExecution>> Function(WorkoutHistoryQuery)? next;
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async {
    queries.add(query);
    if (next != null) return next!(query);
    final filtered = rows
        .where(
          (e) =>
              query.sessionType == null || e.sessionType == query.sessionType,
        )
        .toList();
    final start = query.before == null
        ? 0
        : filtered.indexWhere((e) => e.id == query.before!.id) + 1;
    return filtered.skip(start).take(query.limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
