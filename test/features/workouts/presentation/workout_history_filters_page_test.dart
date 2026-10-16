import 'dart:async';
import 'dart:io';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/evolution_fixtures.dart';
import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(() async {
    // El calendario nativo no cabe con las métricas artificiales de Ahem.
    // Usar la fuente del SDK conserva las medidas reales sin añadir recursos.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/material_fonts').existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('No se encontraron las fuentes del SDK de Flutter.');
      }
      directory = parent;
    }
    final bytes = await File(
      '${directory.path}/material_fonts/Roboto-Regular.ttf',
    ).readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });
  Future<WorkoutHistoryCubit> mount(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
    WorkoutRepository? repository,
  }) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(repository ?? _Repository()),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp(
          theme: EntrenaTheme.dark.copyWith(
            textTheme: EntrenaTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          locale: const Locale('es', 'ES'),
          supportedLocales: const [Locale('es', 'ES')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      ),
    );
    await t.pumpAndSettle();
    return cubit;
  }

  for (final fails in [false, true]) {
    testWidgets(
      'aplicar fechas con red ${fails ? 'fallida' : 'lenta'} conserva los filtros y la vista',
      (t) async {
        final repository = _PendingRepository();
        final cubit = await mount(t, repository: repository);
        await t.ensureVisible(find.text('Filtrar historial'));
        await t.pumpAndSettle();
        await t.tap(find.text('Filtrar historial'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Elegir fechas'));
        await t.pumpAndSettle();
        await t.tap(find.text('Elegir fechas'));
        await t.pumpAndSettle();
        await capturePerformanceWidget(t, 'evolution-calendar-es');
        expect(find.text('Guardar'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
        // Cancelar no aplica una consulta ni desmonta los filtros.
        await t.tap(find.byType(CloseButton));
        await t.pumpAndSettle();
        expect(cubit.state.query.hasFilters, isFalse);
        await t.tap(find.text('Elegir fechas'));
        await t.pumpAndSettle();
        final today = DateTime.now();
        await t.tap(find.text('1').last);
        await t.pumpAndSettle();
        await t.tap(find.text('${today.day}').last);
        await t.pumpAndSettle();
        await t.tap(find.text('Guardar'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        expect(cubit.state.query.from, DateTime(today.year, today.month, 1));
        expect(
          cubit.state.query.through,
          DateTime(today.year, today.month, today.day),
        );
        expect(find.text('Todas las sesiones'), findsOneWidget);
        if (fails) {
          repository.pending.completeError(StateError('Sin conexión'));
        } else {
          repository.pending.complete([]);
        }
        await t.pumpAndSettle();
        expect(find.text('Todas las sesiones'), findsOneWidget);
        expect(
          find.text(
            fails
                ? 'No hemos podido cargar tus sesiones.'
                : 'No hay sesiones que coincidan con estos filtros.',
          ),
          findsOneWidget,
        );
        await t.ensureVisible(find.text('Limpiar filtros'));
        await t.pumpAndSettle();
        await t.tap(find.text('Limpiar filtros'));
        await t.pumpAndSettle();
        expect(cubit.state.query.hasFilters, isFalse);
        expect(find.text('Entrenamiento 1 · Fuerza y carrera'), findsOneWidget);
        expect(find.text('Todas las sesiones'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Otros historiales y filtros conservan aperturas independientes al recargar',
    (t) async {
      final cubit = await mount(t);
      await t.ensureVisible(find.text('Otros historiales'));
      await t.pumpAndSettle();
      await t.tap(find.text('Otros historiales'));
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
      expect(find.text('Historial físico · Tropa'), findsOneWidget);
      expect(find.text('Todos los tipos'), findsOneWidget);
      await cubit.load();
      await t.pumpAndSettle();
      expect(find.text('Historial físico · Tropa'), findsOneWidget);
      expect(find.text('Todos los tipos'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'combina preparación, fechas y estado y permite limpiar un resultado vacío',
    (t) async {
      final cubit = await mount(t);
      final from = DateTime(2026, 9, 1);
      final through = DateTime(2026, 9, 30);
      await cubit.filter(
        WorkoutHistoryQuery(
          from: from,
          through: through,
          sessionType: WorkoutSessionType.strength,
        ),
      );
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
      expect(cubit.state.query.sessionType, WorkoutSessionType.strength);
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
  for (final type in WorkoutSessionType.values) {
    testWidgets('selecciona ${type.label} a 320 px y texto 2× sin recortar', (
      t,
    ) async {
      final cubit = await mount(t, width: 320, scale: 2);
      await t.ensureVisible(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Filtrar historial'));
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('history-type-null'));
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.tap(field);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(type.label).last);
      await t.tap(find.text(type.label).last);
      await t.pumpAndSettle();
      expect(cubit.state.query.sessionType, type);
      final selected = find.byKey(ValueKey('history-type-$type'));
      await t.ensureVisible(selected);
      await t.pumpAndSettle();
      final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: selected, matching: find.text(type.label)).first,
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      painter.dispose();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('preparación y estado completos a 320 px y texto 2×', (t) async {
    final cubit = await mount(t, width: 320, scale: 2);
    await t.ensureVisible(find.text('Filtrar historial'));
    await t.pumpAndSettle();
    await t.tap(find.text('Filtrar historial'));
    await t.pumpAndSettle();

    Future<void> expectFullLabel(Finder field, String label) async {
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: field, matching: find.text(label)).first,
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      painter.dispose();
    }

    await expectFullLabel(
      find.byKey(const ValueKey('history-goal-null')),
      'Todas las sesiones',
    );
    await expectFullLabel(
      find.byKey(const ValueKey('history-status-null')),
      'Todos los estados',
    );
    await cubit.filter(
      const WorkoutHistoryQuery(
        preparationGoalId: 'fas',
        status: WorkoutExecutionStatus.abandoned,
      ),
    );
    await t.pumpAndSettle();
    await expectFullLabel(
      find.byKey(const ValueKey('history-goal-fas')),
      evolutionFas.program.name,
    );
    await expectFullLabel(
      find.byKey(
        const ValueKey('history-status-WorkoutExecutionStatus.abandoned'),
      ),
      'Cerradas sin completar',
    );
    expect(t.takeException(), isNull);
  });
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

class _PendingRepository implements WorkoutRepository {
  final pending = Completer<List<WorkoutExecution>>();
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async => query.hasFilters ? pending.future : evolutionSessions(count: 1);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
