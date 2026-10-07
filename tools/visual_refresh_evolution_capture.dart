// Capturas de las pantallas actuales. Los datos son ficticios; no usa cuentas.
import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/evolution_fixtures.dart';
import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_refresh_evolution_capture.dart';
  for (final width in [390.0, 1280.0]) {
    atlasTestWidgets('Evolución $width', (t) async {
      _size(t, width);
      final repo = _Sessions();
      final cubit = WorkoutHistoryCubit(
        getHistory: GetWorkoutHistoryUseCase(repo),
      )..load();
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/assessment/history',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppShell(navigationShell: shell),
            branches: [
              for (final path in [
                '/home',
                '/plan',
                '/library',
                '/assessment/history',
                '/profile',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => path == '/assessment/history'
                          ? BlocProvider.value(
                              value: cubit,
                              child: WorkoutHistoryPage(
                                loadPreparations: () async => [
                                  evolutionTroop,
                                  evolutionFas,
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await atlasPumpWidget(
        t,
        MaterialApp.router(
          theme: _theme(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      );
      await atlasSettle(t); // 1: raíz
      await t.ensureVisible(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Filtrar historial'));
      await atlasSettle(t); // 2: filtros
      await cubit.filter(
        WorkoutHistoryQuery(
          preparationGoalId: 'fas',
          from: DateTime(2026, 9, 1),
          through: DateTime(2026, 10, 7),
          status: WorkoutExecutionStatus.completed,
        ),
      );
      await t.ensureVisible(find.text('Filtrar historial'));
      await atlasSettle(t); // 3: criterios aplicados
      await cubit.filter(const WorkoutHistoryQuery());
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Cargar más sesiones'));
      await t.pumpAndSettle();
      repo.failMore = true;
      await t.tap(find.text('Cargar más sesiones'));
      await atlasSettle(t); // 4: fallo de otra página conservado
      repo.failMore = false;
      await t.tap(find.text('Reintentar cargar más'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Cargar más sesiones'));
      await atlasSettle(t); // 5: sesiones antiguas, 60 cargadas
      expect(cubit.state.executions, hasLength(60));
      expect(t.takeException(), isNull);
    });
  }
  for (final type in ['troop', 'fas', 'generic', 'empty', 'error']) {
    atlasTestWidgets('Marcas $type', (t) async {
      _size(t, 390);
      final data = type == 'fas'
          ? (await t.runAsync(evolutionFasData))!
          : type == 'troop'
          ? evolutionTroopData()
          : type == 'empty'
          ? const PreparationMarksData(goal: evolutionGeneric)
          : evolutionGenericData();
      var calls = 0;
      await atlasPumpWidget(
        t,
        MaterialApp(
          theme: EntrenaTheme.dark,
          debugShowCheckedModeBanner: false,
          home: PreparationMarksPage(
            goalId: data.goal.id!,
            load: (_) async {
              if (type == 'error' && ++calls > 1) throw StateError('offline');
              return data;
            },
          ),
        ),
      );
      await atlasSettle(t); // 1: resultados
      if (type == 'error') {
        final refresh = t
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await t.pumpAndSettle();
        await refresh;
      } else if (type == 'troop') {
        await t.ensureVisible(find.text('Controles de carrera'));
        await t.pumpAndSettle();
      } else if (type == 'generic') {
        await t.tap(find.text('22/09/2026 · Apto'));
      } else if (type == 'fas') {
        await t.tap(find.byType(ExpansionTile).first);
      }
      await atlasSettle(t); // 2: detalle o error
      expect(t.takeException(), isNull);
    });
  }
  for (final fail in [false, true]) {
    atlasTestWidgets('FAS personal $fail', (t) async {
      _size(t, 390);
      final data = (await t.runAsync(evolutionFasData))!;
      final repo = _Fas(data.fas);
      await atlasPumpWidget(
        t,
        MaterialApp(
          theme: EntrenaTheme.dark,
          debugShowCheckedModeBanner: false,
          home: FasPeriodicHistoryPage(
            repository: repo,
            reference: data.fasReference,
          ),
        ),
      );
      await atlasSettle(t);
      await t.tap(find.byType(ExpansionTile).first);
      await t.pumpAndSettle();
      if (fail) {
        repo.fail = true;
        final refresh = t
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await t.pumpAndSettle();
        await refresh;
      }
      await atlasSettle(t);
      expect(t.takeException(), isNull);
    });
  }
}

void _size(WidgetTester t, double width) {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

ThemeData _theme() => EntrenaTheme.dark.copyWith(
  navigationRailTheme: EntrenaTheme.dark.navigationRailTheme.copyWith(
    selectedLabelTextStyle: EntrenaTheme
        .dark
        .navigationRailTheme
        .selectedLabelTextStyle
        ?.copyWith(fontFamily: 'Roboto'),
  ),
);

class _Sessions implements WorkoutRepository {
  final rows = evolutionSessions();
  bool failMore = false;
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async {
    if (failMore && query.before != null) throw StateError('offline');
    final filtered = rows
        .where((e) => query.status == null || e.status == query.status)
        .where(
          (e) =>
              (query.from == null || !e.startedAt.isBefore(query.from!)) &&
              (query.through == null ||
                  e.startedAt.isBefore(
                    query.through!.add(const Duration(days: 1)),
                  )),
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

class _Fas implements FasPeriodicAssessmentRepository {
  _Fas(this.rows);
  final List<FasPeriodicAssessmentEntry> rows;
  bool fail = false;
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async {
    if (fail) throw StateError('offline');
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
