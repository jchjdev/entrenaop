import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_operations_repository.dart';
import 'package:entrenaop_trainer/trainer_review_navigation.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/helpers/performance_visual_review.dart';
import 'trainer_operations_flow_test.dart' show OperationsFixture;
import 'trainer_workout_flow_test.dart' show WorkoutFixture, resultFixture;

Map<String, dynamic> assignment(String id, String client) => {
  'id': id,
  'template_id': 'template',
  'template_name': 'Entrenamiento $id',
  'template_version': 3,
  'scheduled_date': '2026-10-30',
  'created_at': '2026-10-30T10:00:00Z',
  'status': 'completed',
  'execution_id': 'execution-$id',
  'result_revision': 2,
  'client_id': client,
  'client_name': client == 'ana' ? 'Ana' : 'Luis',
  'relation_id': 'relation-$client',
  'result_changed_at': '2026-10-30T10:00:00Z',
};
TrainerReviewItem pending(String id, String client) =>
    TrainerReviewItem.fromJson(assignment(id, client));

class ReviewOperations extends OperationsFixture {
  ReviewOperations() {
    this.fail = false;
  }
  final clients = {'first': 'ana', 'second': 'ana', 'other': 'luis'};
  final reviewed = <String>{};
  final calls = <({String id, String op, int revision})>[];
  final cursors = <String?>[];
  bool corrected = false;
  List<TrainerReviewItem> firstPage = [
    pending('other', 'luis'),
    pending('second', 'ana'),
  ];
  List<TrainerReviewItem> lastPage = [];
  @override
  Future<TrainerAssignmentContext> assignment(String id) async =>
      TrainerAssignmentContext.fromJson(
        // El nombre de la función de fixture no se confunde con el método del adaptador.
        reviewAssignment(id, clients[id] ?? 'ana'),
      );
  @override
  Future<List<TrainerReviewItem>> reviews({TrainerReviewItem? before}) async {
    cursors.add(before?.assignment.id);
    return before == null ? firstPage : lastPage;
  }

  @override
  Future<void> markReviewed({
    required String operationId,
    required String assignmentId,
    required int resultRevision,
    String? privateNote,
  }) async {
    calls.add((id: assignmentId, op: operationId, revision: resultRevision));
    if (this.fail) throw StateError('Respuesta incierta');
    reviewed.add(assignmentId);
  }
}

Map<String, dynamic> reviewAssignment(String id, String client) =>
    assignment(id, client);

class ReviewWorkouts extends WorkoutFixture {
  ReviewWorkouts(this.operations);
  final ReviewOperations operations;
  @override
  Future<WorkoutJson?> result(String id) async => {
    ...resultFixture,
    'id': 'execution-$id',
    'template_id': 'template',
    'user_id': operations.clients[id] ?? 'ana',
    'template_name': 'Entrenamiento $id',
    'result_revision': operations.corrected && operations.reviewed.contains(id)
        ? 3
        : 2,
    'review': operations.reviewed.contains(id)
        ? {'result_revision': 2, 'private_note': 'Nota'}
        : null,
  };
}

Future<GoRouter> mount(
  WidgetTester t,
  ReviewOperations operations, {
  bool all = false,
  double width = 1440,
  double scale = 1,
}) async {
  final reflect = GoRouter.optionURLReflectsImperativeAPIs;
  GoRouter.optionURLReflectsImperativeAPIs = true;
  addTearDown(() => GoRouter.optionURLReflectsImperativeAPIs = reflect);
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final workouts = ReviewWorkouts(operations);
  final router = GoRouter(
    initialLocation: '/origin',
    routes: [
      GoRoute(
        path: '/origin',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Agenda de origen')),
          body: TextButton(
            onPressed: () => context.push(
              '/clients/ana/workouts/first/result${all ? '?review=all' : ''}',
            ),
            child: const Text('Abrir resultado'),
          ),
        ),
      ),
      GoRoute(
        path: '/clients/:client/workouts/:id/result',
        builder: (_, state) => ProfessionalWorkspaceScope(
          desktop: width >= 900,
          child: TrainerWorkoutResultPage(
            key: ValueKey(state.pathParameters['id']),
            repository: workouts,
            operations: operations,
            assignmentId: state.pathParameters['id']!,
            clientId: state.pathParameters['client'],
            reviewAllClients: state.uri.queryParameters['review'] == 'all',
          ),
        ),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text('Conversación ${state.pathParameters['id']}'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(
      theme: EntrenaTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: child!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Abrir resultado'));
  await t.pumpAndSettle();
  return router;
}

Future<void> tap(WidgetTester t, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    final actions = find.descendant(
      of: find.byKey(const ValueKey('result-review-actions')),
      matching: find.byType(Scrollable),
    );
    await t.scrollUntilVisible(
      finder,
      250,
      scrollable: actions.evaluate().isNotEmpty
          ? actions.first
          : find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(finder.last);
  await t.pumpAndSettle();
  await t.tap(finder.last);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFont);

  test(
    'paginación conserva cursor bruto cuando ningún resultado es del alumno',
    () async {
      final operations = ReviewOperations()
        ..firstPage = List.generate(100, (i) => pending('other-$i', 'luis'))
        ..lastPage = [pending('second', 'ana')];
      final first = await loadTrainerNextReviewPage(
        operations,
        currentAssignmentId: 'first',
        clientId: 'ana',
      );
      expect(first.next, isNull);
      expect(first.hasMore, isTrue);
      expect(first.cursor!.assignment.id, 'other-99');
      final next = await loadTrainerNextReviewPage(
        operations,
        currentAssignmentId: 'first',
        clientId: 'ana',
        after: first.cursor,
      );
      expect(next.next!.assignment.id, 'second');
      expect(operations.cursors, [null, 'other-99']);
    },
  );

  testWidgets(
    'revisar y siguiente conserva el alumno y vuelve directamente al origen',
    (t) async {
      final operations = ReviewOperations();
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      expect(operations.calls, isEmpty);
      await tap(t, 'Guardar revisión y continuar');
      expect(operations.calls.single.id, 'first');
      expect(operations.calls.single.revision, 2);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/second/result',
      );
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('Agenda de origen'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('desde la bandeja general avanza a otro alumno sin marcarlo', (
    t,
  ) async {
    final operations = ReviewOperations();
    final router = await mount(t, operations, all: true);
    await tap(t, 'Revisar y siguiente');
    await tap(t, 'Guardar revisión y continuar');
    expect(
      router.routeInformationProvider.value.uri.path,
      '/clients/luis/workouts/other/result',
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['review'],
      'all',
    );
    expect(operations.calls.map((c) => c.id), ['first']);
    expect(find.text('Luis'), findsOneWidget);
  });

  testWidgets(
    'cancelar revisión no guarda, no consulta la cola ni cambia de sesión',
    (t) async {
      final operations = ReviewOperations();
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      await tap(t, 'Volver');
      expect(operations.calls, isEmpty);
      expect(operations.cursors, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/first/result',
      );
    },
  );

  testWidgets(
    'respuesta incierta reintenta el mismo UUID y no avanza hasta confirmar',
    (t) async {
      final operations = ReviewOperations()..fail = true;
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      await tap(t, 'Guardar revisión y continuar');
      expect(operations.cursors, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/first/result',
      );
      operations.fail = false;
      await tap(t, 'Reintentar la revisión');
      expect(operations.calls.length, 2);
      expect(operations.calls.first, operations.calls.last);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/second/result',
      );
    },
  );

  testWidgets(
    'una corrección tras revisar mantiene abierto el resultado nuevo',
    (t) async {
      final operations = ReviewOperations()..corrected = true;
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      await tap(t, 'Guardar revisión y continuar');
      expect(operations.cursors, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/first/result',
      );
      expect(
        find.textContaining('ha actualizado los resultados'),
        findsOneWidget,
      );
      expect(find.text('Pendiente de revisión'), findsOneWidget);
    },
  );

  testWidgets(
    'página sin coincidencias permite continuar sin afirmar que no hay pendientes',
    (t) async {
      final operations = ReviewOperations()
        ..firstPage = List.generate(100, (i) => pending('other-$i', 'luis'))
        ..lastPage = [pending('second', 'ana')];
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      await tap(t, 'Guardar revisión y continuar');
      expect(find.text('Cargar más pendientes'), findsOneWidget);
      expect(
        find.text(
          'No quedan resultados pendientes de revisión de este alumno.',
        ),
        findsNothing,
      );
      await tap(t, 'Cargar más pendientes');
      expect(operations.cursors, [null, 'other-99']);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/clients/ana/workouts/second/result',
      );
    },
  );

  testWidgets(
    'sin siguiente confirma el fin de la selección y comentar abre la relación correcta',
    (t) async {
      final operations = ReviewOperations()..firstPage = [];
      final router = await mount(t, operations);
      await tap(t, 'Revisar y siguiente');
      await tap(t, 'Guardar revisión y continuar');
      expect(
        find.text(
          'No quedan resultados pendientes de revisión de este alumno.',
        ),
        findsOneWidget,
      );
      await tap(t, 'Comentar con el alumno');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/conversations/relation-ana',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['assignment'],
        'first',
      );
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'resumen y acciones se pueden consultar a $width con texto doble',
      (t) async {
        await mount(t, ReviewOperations(), width: width, scale: 2);
        expect(t.takeException(), isNull);
        await tap(t, 'Revisar y siguiente');
        expect(t.takeException(), isNull);
        await tap(t, 'Volver');
        await capturePerformanceWidget(
          t,
          'trainer-review-${width.toInt()}-large',
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
