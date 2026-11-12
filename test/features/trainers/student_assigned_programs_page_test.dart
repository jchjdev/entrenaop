import 'package:entrenaop/features/trainers/domain/student_assigned_programs.dart';
import 'package:entrenaop/features/trainers/presentation/pages/student_assigned_programs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Programs implements StudentAssignedProgramsRepository {
  bool completed = false;

  @override
  Future<StudentAssignedProgram?> get(String deliveryId) async =>
      StudentAssignedProgram(
        id: 'delivery',
        createdAt: DateTime.utc(2026, 11, 12),
        name: 'Fuerza de Isabel',
        trainerName: 'Javier',
        total: 1,
        completed: completed ? 1 : 0,
        phases: [
          StudentAssignedPhase('Base', 'Ajusta la carga', [
            StudentAssignedSession(
              'scheduled-id',
              'Superior B',
              DateTime(2026, 11, 16),
              completed ? 'completed' : 'planned',
            ),
          ]),
        ],
      );

  @override
  Future<({List<StudentAssignedProgram> items, bool hasMore})> list({
    AssignedProgramCursor? before,
  }) async => (items: [(await get('delivery'))!], hasMore: false);
}

void main() {
  testWidgets('abre la cita del calendario y relee el progreso al regresar', (
    tester,
  ) async {
    final repository = _Programs();
    final router = GoRouter(
      initialLocation: '/my-trainer/programs',
      routes: [
        GoRoute(
          path: '/my-trainer/programs',
          builder: (_, _) =>
              StudentAssignedProgramsPage(repository: repository),
        ),
        GoRoute(
          path: '/my-trainer/programs/:id',
          builder: (_, state) => StudentAssignedProgramsPage(
            repository: repository,
            deliveryId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/plan/week/session/:id',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () {
                repository.completed = true;
                context.pop();
              },
              child: Text(
                "${state.pathParameters['id']} · ${state.uri.queryParameters['date']}",
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('0 de 1 sesión completada'), findsOneWidget);

    await tester.tap(find.text('Fuerza de Isabel'));
    await tester.pumpAndSettle();
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('Ajusta la carga'), findsOneWidget);
    await tester.tap(find.text('Superior B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('scheduled-id · 2026-11-16'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 sesión completada'), findsNWidgets(2));

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 sesión completada'), findsOneWidget);
  });
}
