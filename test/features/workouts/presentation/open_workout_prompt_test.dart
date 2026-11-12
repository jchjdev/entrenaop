import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/workouts/domain/entities/open_workout_session.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/open_workout_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('permite continuar o confirmar el descarte antes de reintentar', (
    tester,
  ) async {
    final repository = _WorkoutRepository();
    sl.registerSingleton(DiscardWorkoutExecutionUseCase(repository));
    addTearDown(() => sl.unregister<DiscardWorkoutExecutionUseCase>());
    var starts = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: FilledButton(
              onPressed: () => startWithOpenWorkoutPrompt(context, () async {
                starts++;
                if (repository.discarded == null) {
                  throw const OpenWorkoutConflict('old', 'Fuerza A');
                }
              }),
              child: const Text('Empezar'),
            ),
          ),
        ),
        GoRoute(
          path: '/plan/week/active/:id',
          builder: (_, state) =>
              Scaffold(body: Text(state.pathParameters['id']!)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    Future<void> tap(String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap('Empezar');
    await tap('Continuar sesión abierta');
    expect(find.text('old'), findsOneWidget);
    expect(repository.discarded, isNull);
    router.pop();
    await tester.pumpAndSettle();

    await tap('Empezar');
    await tap('Descartar y empezar esta');
    expect(repository.discarded, isNull);
    await tap('Cancelar');
    expect(starts, 2);

    await tap('Empezar');
    await tap('Descartar y empezar esta');
    await tap('Confirmar descarte');
    expect(repository.discarded, 'old');
    expect(starts, 4);
  });
}

class _WorkoutRepository implements WorkoutRepository {
  String? discarded;

  @override
  Future<void> discardExecution(String executionId) async {
    discarded = executionId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
