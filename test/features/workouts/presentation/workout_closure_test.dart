import 'package:entrenaop/features/workouts/presentation/widgets/workout_closure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter router(String initial, {int pending = 0, String notes = ''}) =>
      GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/library',
            builder: (_, _) =>
                const Scaffold(body: Text('Biblioteca de origen')),
            routes: [
              GoRoute(
                path: 'active',
                builder: (_, _) => Scaffold(
                  body: WorkoutClosureLayout(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(notes),
                        WorkoutClosureActions(
                          executionId: 'execution-id',
                          pendingSyncCount: pending,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/closed',
            builder: (_, _) => const Scaffold(
              body: WorkoutClosureActions(
                executionId: 'execution-id',
                pendingSyncCount: 0,
              ),
            ),
          ),
          GoRoute(
            path: '/plan/week',
            builder: (_, _) => const Scaffold(body: Text('Agenda')),
          ),
          GoRoute(
            path: '/assessment/history/workouts/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Resultado ${state.pathParameters['id']}')),
          ),
        ],
      );

  testWidgets('volver respeta el origen y no fuerza Mi plan', (tester) async {
    final config = router('/library/active');
    addTearDown(config.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca de origen'), findsOneWidget);
  });

  testWidgets('entrada directa ofrece agenda y enlace al resultado real', (
    tester,
  ) async {
    final config = router('/closed');
    addTearDown(config.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Mi semana'), findsOneWidget);
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado execution-id'), findsOneWidget);
  });

  testWidgets(
    'notas largas y texto grande permiten llegar a las acciones; no abre un resultado aún sin sincronizar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = router(
        '/library/active',
        pending: 1,
        notes: List.filled(
          80,
          'Una nota larga para el entrenamiento.',
        ).join(' '),
      );
      addTearDown(config.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: config,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text('Resultado pendiente de sincronizar'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Volver'));
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca de origen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
