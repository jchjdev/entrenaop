// Widgets actuales y datos ficticios; no abre cuentas ni consulta Supabase.
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

import '../test/helpers/evolution_fixtures.dart';
import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_history_session_type_capture.dart';
  for (final size in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    atlasTestWidgets('Tipo histórico ${size.$1} ${size.$2}', (t) async {
      t.view.physicalSize = Size(size.$1, 1050);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repository = _History();
      final cubit = WorkoutHistoryCubit(
        getHistory: GetWorkoutHistoryUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await atlasPumpWidget(
        t,
        MaterialApp(
          theme: EntrenaTheme.dark,
          debugShowCheckedModeBanner: false,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: Size(size.$1, 1050),
              textScaler: TextScaler.linear(size.$2),
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
      await atlasSettle(t); // 1: raíz actual
      await t.ensureVisible(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Filtrar historial'));
      await atlasSettle(t); // 2: tipos disponibles
      await cubit.filter(
        const WorkoutHistoryQuery(sessionType: WorkoutSessionType.strength),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(
        find.byKey(const ValueKey('history-type-WorkoutSessionType.strength')),
      );
      await atlasSettle(t); // 3: etiqueta larga y resultado
      await cubit.filter(
        const WorkoutHistoryQuery(sessionType: WorkoutSessionType.unclassified),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(
        find.byKey(
          const ValueKey('history-type-WorkoutSessionType.unclassified'),
        ),
      );
      await atlasSettle(t); // 4: historial anterior
      repository.fail = true;
      await cubit.load();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(cubit.state.errorMessage!));
      await atlasSettle(t); // 5: fallo conserva selección y resultado
      expect(
        cubit.state.executions.single.sessionType,
        WorkoutSessionType.unclassified,
      );
      expect(t.takeException(), isNull);
    });
  }
}

class _History implements WorkoutRepository {
  bool fail = false;
  final rows = [
    for (final type in WorkoutSessionType.values)
      WorkoutExecution(
        id: type.name,
        templateId: 'fixture-template',
        templateName: switch (type) {
          WorkoutSessionType.running => 'Carrera continua',
          WorkoutSessionType.strength => 'Fuerza general',
          WorkoutSessionType.mixed => 'Fuerza y carrera',
          WorkoutSessionType.unclassified => 'Sesión guardada anteriormente',
        },
        templateVersion: 1,
        sessionType: type,
        sessionTypePolicy: type == WorkoutSessionType.unclassified
            ? null
            : 'block_format_v1',
        status: WorkoutExecutionStatus.completed,
        startedAt: DateTime(2026, 10, 8, 9),
        completedAt: DateTime(2026, 10, 8, 9, 35),
        finalRpe: 7,
        sets: const [],
      ),
  ];
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async {
    if (fail) throw StateError('offline');
    return rows
        .where(
          (e) =>
              query.sessionType == null || e.sessionType == query.sessionType,
        )
        .take(query.limit)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
