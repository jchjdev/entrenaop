import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_catalog_panel.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_page.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_session_page.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';

import '../../support/guided_program_fixture.dart';
import '../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  for (final view in [
    (390.0, 844.0, 1.0),
    (320.0, 780.0, 2.0),
    (1100.0, 850.0, 1.0),
  ]) {
    testWidgets(
      'Biblioteca conserva sesiones y añade catálogo acotado a $view',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(view.$1, view.$2));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = GuidedTestRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(view.$3)),
              child: RepaintBoundary(
                key: const ValueKey('review-boundary'),
                child: child!,
              ),
            ),
            home: LibraryHubPage(guided: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sesiones EntrenaOP'), findsOneWidget);
        await tester.ensureVisible(find.text('Programas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Programas'));
        await tester.pumpAndSettle();
        expect(find.text('Hipertrofia básica'), findsOneWidget);
        expect(find.text('Rutina'), findsOneWidget);
        if (capturePerformanceReview) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
        }
        await capturePerformanceWidget(
          tester,
          'programas-biblioteca-${view.$1}-${view.$3}',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Buscar programas'),
          'Sin coincidencias',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(
          find.text('No hay programas con estos criterios.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('un catálogo de una página no muestra el paginador', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedCatalogPanel(
            repository: GuidedTestRepository()..morePages = false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hipertrofia básica'), findsOneWidget);
    expect(find.text('Página 1'), findsNothing);
    expect(find.byTooltip('Página siguiente'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Rutinas'), findsWidgets);
    expect(find.text('Por fases'), findsWidgets);
  });
  testWidgets('la última página conserva la vuelta a la anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidedCatalogPanel(repository: GuidedTestRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Página anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Página 1'), findsOneWidget);
  });
  testWidgets('seguir un programa conserva el acceso para entrenar', (
    tester,
  ) async {
    final repo = GuidedTestRepository()..followed = false;
    final cubit = GuidedDetailCubit(repo, 'program')..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const GuidedProgramPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar programa'));
    await tester.pumpAndSettle();
    expect(
      find.text('Siguiente en la secuencia · Calentamiento opcional'),
      findsOneWidget,
    );
    expect(find.text('Iniciar programa'), findsNothing);
  });
  testWidgets(
    'la vista previa sin seguimiento no inicia una sesión suelta por accidente',
    (tester) async {
      final repo = GuidedTestRepository()..followed = false;
      final workouts = GuidedTestWorkouts();
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedSessionPage(
            repository: repo,
            workouts: workouts,
            programId: 'program',
            phaseIndex: 0,
            sessionIndex: 0,
            getTemplate: GetWorkoutTemplateUseCase(workouts),
            startDefault: StartWorkoutExecutionUseCase(workouts),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('workout-preview-start')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Inicia el programa desde su ficha para entrenar con seguimiento.',
        ),
        findsOneWidget,
      );
      expect(repo.starts, isEmpty);
    },
  );
  testWidgets(
    'los ajustes llegan al inicio guiado y abren el ejecutor por su URL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = GuidedTestRepository(), workouts = GuidedTestWorkouts();
      const base = '/library/programs/program/session/0/0';
      final router = GoRouter(
        initialLocation: base,
        routes: [
          GoRoute(
            path: base,
            builder: (_, _) => GuidedSessionPage(
              repository: repo,
              workouts: workouts,
              programId: 'program',
              phaseIndex: 0,
              sessionIndex: 0,
              getTemplate: GetWorkoutTemplateUseCase(workouts),
              startDefault: StartWorkoutExecutionUseCase(workouts),
            ),
            routes: [
              GoRoute(
                path: 'active/:executionId',
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: [
                      Text('Ejecutor ${state.pathParameters['executionId']}'),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Volver tras cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Press de banca'), findsOneWidget);
      await tester.tap(find.text('Ajustes de esta sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calentamiento guiado'));
      await tester.tap(find.text('Descansos según la pauta'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Descanso entre series (segundos)'),
        '300',
      );
      await tester.tap(find.text('Aplicar ajustes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Introduce un descanso dentro del rango.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Descanso entre series (segundos)'),
        '120',
      );
      await tester.tap(find.text('Aplicar ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Ejecutor execution-guided'), findsOneWidget);
      expect(repo.starts.single.omit, isTrue);
      expect(repo.starts.single.rest, 120);
      expect(workouts.defaultStarts, 0);
      await tester.tap(find.text('Volver tras cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar sesión'));
      await tester.pumpAndSettle();
      expect(repo.starts.length, 2);
      expect(repo.starts[0].operation, isNot(repo.starts[1].operation));
      expect(tester.takeException(), isNull);
    },
  );
}
