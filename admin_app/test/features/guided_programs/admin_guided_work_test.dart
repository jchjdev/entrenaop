import 'dart:async';
import 'dart:convert';

import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_work.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';

class _Work extends Fake implements AdminGuidedWorkRepository {
  final rows = <String, GuidedWork>{};
  final requests = <Map<String, dynamic>>[];
  bool loseResponse = false, fail = false, loseFinal = false;
  Completer<void>? gate;
  int finalized = 0;
  final results = <String, String>{};
  @override
  Future<List<GuidedWork>> list() async =>
      rows.values.where((w) => !results.containsKey(w.id)).toList();
  @override
  Future<GuidedWork?> load(String id) async => rows[id];
  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    requests.add(state);
    await gate?.future;
    if (fail) throw StateError('Sin conexión');
    final previous = rows[work.id];
    if (previous != null &&
        jsonEncode(previous.state) == jsonEncode(state) &&
        previous.revision == work.revision + 1) {
      return previous;
    }
    if (previous != null && previous.revision != work.revision) {
      throw const GuidedWorkConflict();
    }
    final result = GuidedWork(
      id: work.id,
      state: state,
      revision: work.revision + 1,
      baseProgramId: work.baseProgramId,
      updatedAt: DateTime(2026, 10, 19),
    );
    rows[work.id] = result;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Respuesta perdida');
    }
    return result;
  }

  @override
  Future<String> finalize(GuidedWork work, GuidedProgram program) async {
    final result = results.putIfAbsent(work.id, () => 'program-${++finalized}');
    if (loseFinal) {
      loseFinal = false;
      throw StateError('Respuesta perdida');
    }
    return result;
  }
}

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

class _Guided extends Fake implements AdminGuidedRepository {
  @override
  Future<List<GuidedProgram>> programs() async => [];
  @override
  Future<List<GuidedWarmup>> warmups() async => [];
  @override
  Future<List<GuidedProgramCategory>> categories() async => [];
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => [
    const AdminWorkoutSummary(
      id: 's',
      name: 'Sesión publicada',
      version: 1,
      status: 'published',
      isRunning: false,
      supportsAdjustableRest: true,
      catalogScope: 'general',
    ),
  ];
}

Map<String, dynamic> _state() => {
  'schema': 1,
  'name': 'Glúteos en construcción',
  'description': '',
  'audience': '',
  'equipment': '',
  'mode': 'phased',
  'categories': <String>[],
  'primary': null,
  'phases': [
    {
      'name': 'Base',
      'weeks': 'sin terminar',
      'instructions': '',
      'pending': ['pendiente'],
      'sessions': [
        {
          'id': 's',
          'name': 'Sesión publicada',
          'warmup': null,
          'adjustable': true,
          'minimum': '-',
          'maximum': '180',
        },
      ],
    },
  ],
};

void main() {
  testWidgets(
    'el estado de trabajo y los reintentos caben a 320 px con texto ampliado',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Work()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AdminGuidedEditorPage(
            repository: _Guided(),
            workouts: _Workouts(),
            workRepository: repo,
            work: const GuidedWork(id: 'narrow', state: {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Nombre del programa'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del programa'),
        'Trabajo sin conexión',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se ha guardado el último cambio'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Nombre del programa'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Trabajo sin conexión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('serializa cambios durante una petición y reintenta primero su respuesta incierta', () async {
    final repo = _Work()
      ..loseResponse = true
      ..gate = Completer<void>();
    final c = GuidedWorkController(repo, const GuidedWork(id: 'a', state: {}), {
      'schema': 1,
      'name': 'A',
    });
    addTearDown(c.dispose);
    final first = c.flush();
    final expectation = expectLater(first, throwsStateError);
    c.update({'schema': 1, 'name': 'B'});
    repo.gate!.complete();
    await expectation;
    expect(c.dirty, isTrue);
    expect(c.work.revision, 0);
    await c.flush();
    expect(repo.requests.map((r) => r['name']).toList(), ['A', 'A', 'B']);
    expect(repo.rows['a']!.revision, 2);
    expect(c.dirty, isFalse);
  });
  test(
    'una pestaña obsoleta conserva sus campos y deja de intentar sobrescribir',
    () async {
      final repo = _Work();
      final c = GuidedWorkController(
        repo,
        const GuidedWork(id: 'a', state: {}),
        {'schema': 1},
      );
      addTearDown(c.dispose);
      await c.flush();
      await repo.save(c.work, {'schema': 1, 'name': 'Otra pestaña'});
      c.update({'schema': 1, 'name': 'Mi texto'});
      await expectLater(c.flush(), throwsA(isA<GuidedWorkConflict>()));
      final count = repo.requests.length;
      await expectLater(c.flush(), throwsA(isA<GuidedWorkConflict>()));
      expect(repo.requests.length, count);
      expect(c.dirty, isTrue);
      expect(repo.rows['a']!.state['name'], 'Otra pestaña');
    },
  );
  testWidgets(
    'recarga desde URL estable con semanas y descansos inválidos y sesiones pendientes',
    (tester) async {
      final repo = _Work()
        ..rows['w'] = GuidedWork(id: 'w', state: _state(), revision: 3);
      await tester.binding.setSurfaceSize(const Size(1300, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = createAdminRouter(
        programs: _Programs(),
        workouts: _Workouts(),
        exercises: _Exercises(),
        guided: _Guided(),
        guidedWork: repo,
        onSignOut: () {},
        initialLocation: '/guided-programs/work/w',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(AdminGuidedEditorPage), findsOneWidget);
      expect(find.text('Glúteos en construcción'), findsOneWidget);
      expect(find.text('sin terminar'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.textContaining('pendiente'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del programa'),
        'Glúteos recuperado',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.rows['w']!.state['name'], 'Glúteos recuperado');
      final phase = (repo.rows['w']!.state['phases'] as List).single as Map;
      expect(phase['weeks'], 'sin terminar');
      expect(phase['pending'], ['pendiente']);
      expect((phase['sessions'] as List).single['minimum'], '-');
      router.go('/guided-programs');
      await tester.pumpAndSettle();
      expect(find.text('Continuar trabajando'), findsOneWidget);
      expect(find.text('Glúteos recuperado'), findsOneWidget);
      expect(find.text('¿Salir sin guardar?'), findsNothing);
    },
  );
  testWidgets(
    'crear usa una URL estable y un guardado final incierto no duplica al reintentar',
    (tester) async {
      final state = _state()..['mode'] = 'guide';
      (state['phases'] as List).single['pending'] = <String>[];
      (state['phases'] as List).single['sessions'][0]['adjustable'] = false;
      final repo = _Work()..loseFinal = true;
      final router = createAdminRouter(
        programs: _Programs(),
        workouts: _Workouts(),
        exercises: _Exercises(),
        guided: _Guided(),
        guidedWork: repo,
        onSignOut: () {},
        initialLocation: '/guided-programs/new',
      );
      addTearDown(router.dispose);
      await tester.binding.setSurfaceSize(const Size(1300, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final location = router.routeInformationProvider.value.uri;
      expect(location.path, startsWith('/guided-programs/work/'));
      final id = location.pathSegments.last;
      // Simula recarga en el mismo identificador, ahora con contenido válido.
      repo.rows[id] = GuidedWork(id: id, state: state, revision: 1);
      router.go('/guided-programs');
      await tester.pumpAndSettle();
      router.go(location.toString());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar en catálogo'));
      await tester.tap(find.text('Guardar en catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobar y reintentar guardado'), findsOneWidget);
      await tester.tap(find.text('Comprobar y reintentar guardado'));
      await tester.pumpAndSettle();
      expect(repo.finalized, 1);
      expect(find.text('Comprobar y reintentar guardado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
