import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/evolution_fixtures.dart';

void main() {
  Future<WorkoutHistoryCubit> mount(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(_Repository()),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await t.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: BlocProvider.value(
          value: cubit,
          child: WorkoutHistoryPage(
            loadPreparations: () async => [evolutionTroop, evolutionFas],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return cubit;
  }

  testWidgets(
    'combina preparación, fechas y estado y permite limpiar un resultado vacío',
    (t) async {
      final cubit = await mount(t);
      final from = DateTime(2026, 9, 1);
      final through = DateTime(2026, 9, 30);
      await cubit.filter(WorkoutHistoryQuery(from: from, through: through));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Todas las sesiones'));
      await t.pumpAndSettle();
      await t.tap(find.text('Todas las sesiones'));
      await t.pumpAndSettle();
      await t.tap(find.text(evolutionFas.program.name).last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Todos los estados'));
      await t.pumpAndSettle();
      await t.tap(find.text('Todos los estados'));
      await t.pumpAndSettle();
      await t.tap(find.text('Completadas').last);
      await t.pumpAndSettle();
      expect(cubit.state.query.preparationGoalId, 'fas');
      expect(cubit.state.query.status, WorkoutExecutionStatus.completed);
      expect(cubit.state.query.from, from);
      expect(cubit.state.query.through, through);
      expect(
        find.text('No hay sesiones que coincidan con estos filtros.'),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Limpiar filtros'));
      await t.pumpAndSettle();
      await t.tap(find.text('Limpiar filtros'));
      await t.pumpAndSettle();
      expect(cubit.state.query.hasFilters, isFalse);
      expect(find.text('Entrenamiento 1 · Fuerza y carrera'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final width in [320.0, 1100.0]) {
    testWidgets(
      'Evolución y filtros sin desbordamiento con texto 2× en $width px',
      (t) async {
        await mount(t, width: width, scale: 2);
        await t.ensureVisible(find.text('Filtrar historial'));
        await t.pumpAndSettle();
        await t.tap(find.text('Filtrar historial'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Entrenamiento 1 · Fuerza y carrera'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}

class _Repository implements WorkoutRepository {
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async => query.hasFilters ? [] : evolutionSessions(count: 1);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
