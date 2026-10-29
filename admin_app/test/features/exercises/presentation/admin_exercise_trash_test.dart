import 'dart:async';

import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_trash_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercise_trash_page.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_trash.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';

final _stamp = DateTime.utc(2026, 10, 29, 12, 30, 15, 123, 456);

class _Exercises extends Fake
    implements AdminExerciseRepository, AdminExerciseTrashRepository {
  int reads = 0;
  bool failRestore = false;
  bool failTrash = false;
  Completer<void>? trashGate, restoreGate;
  bool published = false;
  bool trashed = false;
  String? blockReason;
  final restoreIds = <String>[];
  final trashIds = <String>[];
  AdminExerciseTrashEntry? restored;
  List<AdminExerciseTrashEntry> entries = [];

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => [
    if (!trashed)
      AdminCatalogExercise(
        id: 'exercise',
        name: 'Dominada estricta',
        muscleGroups: const ['espalda'],
        equipment: const [],
        difficulty: 'inicial',
        exerciseType: 'repeticiones',
        isPublic: published,
      ),
  ];

  @override
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    published = true;
  }

  @override
  Future<List<AdminExerciseTrashEntry>> listExerciseTrash({
    AdminExerciseTrashEntry? before,
    int limit = 50,
  }) async {
    reads++;
    return List.of(entries);
  }

  @override
  Future<void> trashExercise(String id, {required String operationId}) async {
    trashIds.add(operationId);
    await trashGate?.future;
    trashed = true;
    if (failTrash) throw StateError('Respuesta perdida');
  }

  @override
  Future<void> restoreExercise(
    AdminExerciseTrashEntry entry, {
    required String operationId,
  }) async {
    restoreIds.add(operationId);
    await restoreGate?.future;
    if (failRestore) throw StateError('Respuesta perdida');
    restored = entry;
    entries = [];
  }
}

class _Programs extends Fake implements AdminProgramRepository {
  _Programs(this.allowed);
  final bool allowed;
  @override
  Future<bool> hasAccess() async => allowed;
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => [];
}

class _Guided extends Fake implements AdminGuidedRepository {
  @override
  Future<List<GuidedProgram>> programs() async => [];
}

class _GuidedTrash extends Fake implements AdminGuidedTrashRepository {
  Completer<void>? gate;
  List<GuidedTrashEntry> entries = [
    GuidedTrashEntry(
      id: 'legacy',
      name: 'Contenido conservado',
      isWork: false,
      trashedAt: _stamp,
    ),
  ];
  @override
  Future<List<GuidedTrashEntry>> list() async => entries;
  @override
  Future<List<GuidedTrashEntry>> listSessions() async => [
    for (final entry in entries)
      GuidedTrashEntry(
        id: entry.id,
        name: entry.name,
        isWork: false,
        isSession: true,
        trashedAt: entry.trashedAt,
      ),
  ];
  @override
  Future<void> restore(GuidedTrashEntry entry) async {
    await gate?.future;
    entries = [];
  }
}

Future<GoRouter> _mountRouter(
  WidgetTester tester,
  _Exercises repository, {
  String path = '/exercises',
  _GuidedTrash? guidedTrash,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAdminRouter(
    programs: _Programs(true),
    workouts: _Workouts(),
    exercises: repository,
    ownerKey: 'admin',
    onSignOut: () {},
    isAuthenticated: () => true,
    initialLocation: path,
    guided: guidedTrash == null ? null : _Guided(),
    guidedTrash: guidedTrash,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _requestSidebar(WidgetTester tester) async {
  tester
      .widget<ListTile>(find.byKey(const ValueKey('admin-nav-/sessions')))
      .onTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets(
    'router bloquea sidebar al confirmar y escribir; evita doble confirmación',
    (tester) async {
      final repository = _Exercises()..trashGate = Completer<void>();
      final router = await _mountRouter(tester, repository);
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuButton<String> &&
              widget.tooltip == 'Más opciones de Dominada estricta',
        ),
      );
      menu.onSelected!('trash');
      menu.onSelected!('trash');
      await tester.pumpAndSettle();
      expect(find.text('¿Mover ejercicio a la papelera?'), findsOneWidget);
      await _requestSidebar(tester);
      expect(_path(router), '/exercises');
      expect(repository.trashIds, isEmpty);
      await tester.tap(find.text('Mover a papelera'));
      await tester.pump();
      await _requestSidebar(tester);
      expect(_path(router), '/exercises');
      expect(repository.trashIds, hasLength(1));
      repository.trashGate!.complete();
      await tester.pumpAndSettle();
      await _requestSidebar(tester);
      await tester.pumpAndSettle();
      expect(_path(router), '/sessions');
    },
  );

  testWidgets(
    'refrescar mantiene recibo y banner aunque desaparezca la tarjeta',
    (tester) async {
      final repository = _Exercises()..failTrash = true;
      final router = await _mountRouter(tester, repository);
      tester
          .widget<PopupMenuButton<String>>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is PopupMenuButton<String> &&
                  widget.tooltip == 'Más opciones de Dominada estricta',
            ),
          )
          .onSelected!('trash');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a papelera'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar traslado'), findsOneWidget);
      await tester.tap(find.text('Actualizar catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Dominada estricta'), findsNothing);
      expect(find.text('Reintentar traslado'), findsOneWidget);
      await _requestSidebar(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('¿Salir con un traslado sin confirmar?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(_path(router), '/exercises');
      repository.failTrash = false;
      await tester.tap(find.text('Reintentar traslado'));
      await tester.pumpAndSettle();
      expect(repository.trashIds, hasLength(2));
      expect(repository.trashIds.first, repository.trashIds.last);
      expect(find.text('¿Mover ejercicio a la papelera?'), findsNothing);
      expect(find.text('Reintentar traslado'), findsNothing);
    },
  );

  for (final path in [
    '/exercises/trash',
    '/sessions/trash',
    '/guided-programs/trash',
  ]) {
    testWidgets(
      'papelera real $path bloquea salida durante confirmación y recuperación',
      (tester) async {
        final gate = Completer<void>();
        final repository = _Exercises()
          ..restoreGate = gate
          ..entries = [
            AdminExerciseTrashEntry(
              id: 'exercise',
              name: 'Dominada estricta',
              trashedAt: _stamp,
            ),
          ];
        final legacy = _GuidedTrash()..gate = gate;
        final router = await _mountRouter(
          tester,
          repository,
          path: path,
          guidedTrash: legacy,
        );
        final restore = find.text(
          path == '/exercises/trash'
              ? 'Recuperar ejercicio'
              : path == '/sessions/trash'
              ? 'Recuperar sesión'
              : 'Recuperar programa',
        );
        await tester.tap(restore);
        await tester.pumpAndSettle();
        await _requestSidebar(tester);
        expect(_path(router), path);
        await tester.tap(find.text('Recuperar'));
        await tester.pump();
        await _requestSidebar(tester);
        expect(_path(router), path);
        gate.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _requestSidebar(tester);
        await tester.pumpAndSettle();
        expect(_path(router), '/sessions');
      },
    );
  }

  testWidgets(
    'restaurar conserva el sello y reutiliza recibo si falta respuesta',
    (tester) async {
      final repository = _Exercises()
        ..failRestore = true
        ..entries = [
          AdminExerciseTrashEntry(
            id: 'exercise',
            name: 'Dominada estricta',
            trashedAt: _stamp,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminExerciseTrashPage(
            repository: repository,
            ownerKey: 'admin',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recuperar ejercicio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('como retirado'), findsOneWidget);
      await tester.tap(find.text('Recuperar'));
      await tester.pumpAndSettle();
      expect(find.text('Dominada estricta'), findsOneWidget);
      repository.failRestore = false;
      await tester.tap(find.text('Reintentar recuperación'));
      await tester.pumpAndSettle();
      expect(repository.restoreIds, hasLength(2));
      expect(repository.restoreIds.first, repository.restoreIds.last);
      expect(repository.restored!.trashedAt, _stamp);
      expect(find.text('La papelera está vacía.'), findsOneWidget);
    },
  );

  testWidgets('un uso protegido impide purgar pero permite recuperar', (
    tester,
  ) async {
    final repository = _Exercises()
      ..entries = [
        AdminExerciseTrashEntry(
          id: 'exercise',
          name: 'Dominada estricta',
          trashedAt: _stamp,
          deleteBlockReason: 'Utilizado en una sesión asignada.',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: AdminExerciseTrashPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Utilizado en una sesión asignada.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Borrar definitivamente'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Recuperar ejercicio'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'restaurado requiere revisar y guardar para publicar explícitamente',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Exercises();
      await tester.pumpWidget(
        MaterialApp(home: AdminExercisesPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Retirado · revisar para publicar'),
        findsOneWidget,
      );
      await tester.tap(find.text('Dominada estricta'));
      await tester.pumpAndSettle();
      expect(repository.published, isFalse);
      expect(find.textContaining('al guardar se publicará'), findsOneWidget);
      await tester.ensureVisible(find.text('Guardar y publicar'));
      await tester.tap(find.text('Guardar y publicar'));
      await tester.pumpAndSettle();
      expect(repository.published, isTrue);
      expect(
        find.textContaining('Retirado · revisar para publicar'),
        findsNothing,
      );
    },
  );

  testWidgets('mover exige confirmación y desaparece de la biblioteca activa', (
    tester,
  ) async {
    final repository = _Exercises();
    await tester.pumpWidget(
      MaterialApp(home: AdminExercisesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Más opciones de Dominada estricta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover a papelera'));
    await tester.pumpAndSettle();
    expect(repository.trashIds, isEmpty);
    await tester.tap(find.text('Mover a papelera'));
    await tester.pumpAndSettle();
    expect(repository.trashIds, hasLength(1));
    expect(find.text('Dominada estricta'), findsNothing);
    expect(find.text('Papelera'), findsOneWidget);
  });

  for (final (allowed, mfa) in [(true, false), (false, false), (true, true)]) {
    testWidgets(
      'ruta ejercicios papelera: permiso $allowed, MFA pendiente $mfa',
      (tester) async {
        final repository = _Exercises();
        final router = createAdminRouter(
          programs: _Programs(allowed),
          workouts: _Workouts(),
          exercises: repository,
          ownerKey: 'admin',
          onSignOut: () {},
          isAuthenticated: () => true,
          needsSecurity: () async => mfa,
          securityBuilder: (_) =>
              const Scaffold(body: Text('Validar doble factor')),
          initialLocation: '/exercises/trash',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repository.reads, allowed && !mfa ? 1 : 0);
        if (allowed && !mfa) {
          expect(find.byType(AdminExerciseTrashPage), findsOneWidget);
        }
      },
    );
  }
}
