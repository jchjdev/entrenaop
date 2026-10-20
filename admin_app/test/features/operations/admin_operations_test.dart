import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/operations/data/admin_operations_repository.dart';
import 'package:entrenaop_admin/features/operations/presentation/admin_editorial_diff.dart';
import 'package:entrenaop_admin/features/operations/presentation/admin_operations_pages.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../test/helpers/performance_visual_review.dart';

class _Operations extends Fake implements AdminOperationsRepository {
  int historyReads = 0;
  final kinds = <String?>[];
  final requests = <String>[];
  final states = <bool>[];
  bool failRestore = true;
  @override
  Future<List<Map<String, dynamic>>> history({
    String? kind,
    int? beforeId,
  }) async {
    historyReads++;
    kinds.add(kind);
    return [
      {
        'id': 7,
        'name': 'Sesión de fuerza',
        'resource_type': 'session',
        'resource_id': 's',
        'occurred_at': '2026-10-20T17:00:00Z',
        'action': 'updated',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>?> event(int id) async => {
    'resource_type': 'session',
    'resource_id': 's',
    'occurred_at': '2026-10-20T17:00:00Z',
    'before': {
      'name': 'Base',
      'payload': {'name': 'Base', 'reps': 10},
    },
    'after': {
      'name': 'Base',
      'payload': {'name': 'Base', 'reps': 12},
    },
  };
  @override
  Future<String> restore(
    int id,
    String requestId, {
    required bool useBefore,
  }) async {
    requests.add(requestId);
    states.add(useBefore);
    if (failRestore) {
      failRestore = false;
      throw StateError('Respuesta perdida');
    }
    return 'draft-new';
  }

  @override
  Future<List<Map<String, dynamic>>> quality() async => [
    {
      'resource_type': 'exercise',
      'resource_id': 'ex',
      'name': 'Press de glúteos',
      'severity': 'attention',
      'code': 'missing_media',
      'message': 'Sin imagen asignada.',
    },
    {
      'resource_type': 'program',
      'resource_id': 'p',
      'name': 'Referencia retirada',
      'severity': 'error',
      'code': 'unavailable_session',
      'message': 'Sesión retirada.',
    },
    {
      'resource_type': 'session',
      'resource_id': 's',
      'name': 'Borrador pendiente',
      'severity': 'pending',
      'code': 'draft_session',
      'message': 'Pendiente de publicar.',
    },
  ];
  @override
  Future<Map<String, dynamic>> status() async => {
    'checked_at': '2026-10-20T17:00:00Z',
    'database': 'reachable',
    'history_events': 3,
    'failed_videos': 0,
    'backups': 'unverified',
  };
  @override
  Future<Map<String, dynamic>?> deployment() async => null;
  @override
  Future<Map<String, dynamic>> support(String userId) async => {
    'checked_at': '2026-10-20T17:00:00Z',
    'last_sign_in_at': null,
    'programs': [
      {
        'id': 'p',
        'name': 'Programa de $userId',
        'version': 1,
        'phase_index': 0,
        'state': 'paused',
      },
    ],
  };
}

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => false;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

class _Workouts extends Fake implements AdminWorkoutRepository {}

Future<void> _mount(
  WidgetTester tester,
  Widget page, {
  double width = 1100,
  double scale = 1,
  GoRouter? router,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('review-boundary'),
      child: router == null
          ? MaterialApp(
              theme: EntrenaTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: page,
            )
          : MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  test('comparación respeta claves, orden y valores anidados', () {
    expect(editorialDifferences({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isEmpty);
    final diff = editorialDifferences(
      {
        'payload': {
          'sets': [
            {'target_reps': 10},
          ],
        },
      },
      {
        'payload': {
          'sets': [
            {'target_reps': 12},
          ],
        },
      },
    );
    expect(diff.single.path, 'Contenido / Series / 1 / Repeticiones');
    expect(diff.single.before, '10');
    expect(diff.single.after, '12');
    expect(editorialDifferences(null, {'name': 'Base'}).single.after, 'Base');
  });
  testWidgets('historial filtra y no ofrece paginación cuando termina', (
    tester,
  ) async {
    final repo = _Operations();
    await _mount(tester, AdminHistoryPage(repository: repo));
    expect(find.text('Sesión de fuerza'), findsOneWidget);
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Programas'));
    expect(repo.kinds, [null, 'program']);
    expect(find.text('Cargar cambios anteriores'), findsNothing);
  });
  testWidgets(
    'recuperación conserva la clave tras respuesta perdida y abre el nuevo borrador',
    (tester) async {
      final repo = _Operations();
      final router = GoRouter(
        initialLocation: '/history/7',
        routes: [
          GoRoute(
            path: '/history/7',
            builder: (_, _) =>
                AdminHistoryDetailPage(repository: repo, eventId: 7),
          ),
          GoRoute(
            path: '/sessions/draft-new',
            builder: (_, _) =>
                const Scaffold(body: Text('Borrador recuperado visible')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _mount(tester, const SizedBox(), router: router);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Estado anterior'));
      for (var i = 0; i < 2; i++) {
        await _tap(tester, find.text('Recuperar como borrador'));
        await _tap(tester, find.text('Crear borrador'));
      }
      expect(repo.requests, hasLength(2));
      expect(repo.requests.first, repo.requests.last);
      expect(repo.states, [true, true]);
      await _tap(tester, find.text('Abrir borrador recuperado'));
      expect(find.text('Borrador recuperado visible'), findsOneWidget);
    },
  );
  for (final (width, scale) in [(1100.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'calidad a $width/$scale separa pendientes y enlaza ejercicio',
      (tester) async {
        final repo = _Operations();
        final router = GoRouter(
          initialLocation: '/quality',
          routes: [
            GoRoute(
              path: '/quality',
              builder: (_, _) => AdminQualityPage(repository: repo),
            ),
            GoRoute(
              path: '/exercises',
              builder: (_, state) => Scaffold(
                body: Text('Editar ${state.uri.queryParameters['edit']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _mount(
          tester,
          AdminQualityPage(repository: repo),
          width: width,
          scale: scale,
        );
        await _tap(tester, find.widgetWithText(ChoiceChip, 'Pendientes (1)'));
        expect(find.text('Sesión · Borrador pendiente'), findsOneWidget);
        expect(find.text('Programa · Referencia retirada'), findsNothing);
        await _tap(
          tester,
          find.widgetWithText(ChoiceChip, 'Por completar (1)'),
        );
        final filterLabel = tester.renderObject<RenderParagraph>(
          find.text('Por completar (1)'),
        );
        expect(filterLabel.didExceedMaxLines, isFalse);
        await tester.enterText(find.byType(TextField), 'GLUTEOS');
        await tester.pumpAndSettle();
        expect(find.text('Ejercicio · Press de glúteos'), findsOneWidget);
        await capturePerformanceWidget(
          tester,
          'admin-quality-${width.toInt()}-${scale.toInt()}',
        );
        expect(tester.takeException(), isNull);
        // Prueba el destino con el router real de navegación de la página.
        await _mount(tester, const SizedBox(), router: router);
        await _tap(
          tester,
          find.widgetWithText(ChoiceChip, 'Por completar (1)'),
        );
        await _tap(tester, find.text('Abrir recurso'));
        expect(find.text('Editar ex'), findsOneWidget);
      },
    );
    testWidgets('sistema a $width/$scale mantiene copias sin verificar', (
      tester,
    ) async {
      await _mount(
        tester,
        AdminSystemPage(repository: _Operations()),
        width: width,
        scale: scale,
      );
      expect(
        find.text('Compilación local sin manifiesto de despliegue.'),
        findsOneWidget,
      );
      final copies = find.text('Copias de seguridad: sin verificar');
      if (copies.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          copies,
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
      }
      await tester.ensureVisible(copies);
      await tester.pumpAndSettle();
      expect(find.text('Copias de seguridad: sin verificar'), findsOneWidget);
      await capturePerformanceWidget(
        tester,
        'admin-system-${width.toInt()}-${scale.toInt()}',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'soporte se consulta a demanda y cambiar de cuenta descarta sus datos',
    (tester) async {
      final repo = _Operations();
      await _mount(
        tester,
        Scaffold(
          body: AdminAccountSupport(
            key: const ValueKey('u1'),
            repository: repo,
            userId: 'u1',
          ),
        ),
      );
      expect(find.text('Programa de u1 · v1'), findsNothing);
      await _tap(tester, find.text('Diagnóstico de acceso y programas'));
      expect(find.text('Programa de u1 · v1'), findsOneWidget);
      await _mount(
        tester,
        Scaffold(
          body: AdminAccountSupport(
            key: const ValueKey('u2'),
            repository: repo,
            userId: 'u2',
          ),
        ),
      );
      expect(find.text('Programa de u1 · v1'), findsNothing);
      await _tap(tester, find.text('Diagnóstico de acceso y programas'));
      expect(find.text('Programa de u2 · v1'), findsOneWidget);
    },
  );
  for (final path in ['/history', '/quality', '/system']) {
    testWidgets(
      'sin acceso administrativo la ruta $path no consulta operaciones',
      (tester) async {
        final repo = _Operations();
        final router = createAdminRouter(
          programs: _Programs(),
          workouts: _Workouts(),
          exercises: _Exercises(),
          operations: repo,
          onSignOut: () {},
          initialLocation: path,
        );
        addTearDown(router.dispose);
        await _mount(tester, const SizedBox(), router: router);
        expect(
          find.text('Esta cuenta no tiene permiso de administración.'),
          findsOneWidget,
        );
        expect(repo.historyReads, 0);
        expect(find.byType(AdminQualityPage), findsNothing);
        expect(find.byType(AdminSystemPage), findsNothing);
      },
    );
  }
}
