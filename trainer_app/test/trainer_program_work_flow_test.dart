import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_program_work_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_program_flow_test.dart'
    show ChangingLibraryFixture, ProgramFixture, privateProgram, visibleTap;
import 'trainer_program_work_repository_test.dart' show rawState, workId;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

GuidedWork checkpoint({
  int revision = 3,
  String name = 'Montaje recuperable',
  String? base = 'program',
  String? finalized,
  bool discarded = false,
  bool deleted = false,
}) => GuidedWork(
  id: workId,
  state: rawState(name),
  revision: revision,
  baseProgramId: base,
  finalizedProgramId: finalized,
  discarded: discarded,
  permanentlyDeleted: deleted,
);

class WorkFixture implements GuidedWorkRepository {
  GuidedWork? stored;
  List<GuidedWork> rows = [];
  int loads = 0, lists = 0;
  bool failSave = false, failDiscard = false;
  final saved = <({GuidedWork work, Map<String, dynamic> state})>[];
  final discarded = <GuidedWork>[];
  final finalized = <({GuidedWork work, GuidedProgram program})>[];

  @override
  Future<List<GuidedWork>> list() async {
    lists++;
    return List.of(rows);
  }

  @override
  Future<GuidedWork?> load(String id) async {
    loads++;
    return stored;
  }

  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    final raw = Map<String, dynamic>.from(jsonDecode(jsonEncode(state)) as Map);
    saved.add((work: work, state: raw));
    if (failSave) throw StateError('Respuesta incierta');
    return stored = GuidedWork(
      id: work.id,
      state: raw,
      revision: work.revision + 1,
      baseProgramId: work.baseProgramId,
    );
  }

  @override
  Future<String> finalize(GuidedWork work, GuidedProgram program) async {
    finalized.add((work: work, program: program));
    return 'receipt-v1';
  }

  @override
  Future<void> discard(GuidedWork work) async {
    discarded.add(work);
    if (failDiscard) throw StateError('Respuesta incierta');
    rows.removeWhere((item) => item.id == work.id);
  }
}

class TrackedPrograms extends ProgramFixture {
  final loaded = <String>[];
  final versions = <String, GuidedProgram>{
    'program': privateProgram,
    'receipt-v1': const GuidedProgram(
      id: 'receipt-v1',
      status: 'archived',
      name: 'La versión exacta del recibo',
      mode: GuidedProgramMode.guide,
      phases: [GuidedPhase(name: 'Entrenamiento', sessions: [])],
    ),
  };

  @override
  Future<GuidedProgram> program(String id) async {
    loaded.add(id);
    return versions[id]!;
  }
}

GoRouter workRouter(
  WorkFixture work,
  TrackedPrograms programs,
  WorkoutFixture workouts, {
  String? initial,
  FakeTrainerRepository? access,
}) => GoRouter(
  initialLocation: initial ?? '/programs/work/$workId',
  routes: [
    GoRoute(
      path: '/programs',
      builder: (_, _) => TrainerProgramLibraryPage(
        repository: programs,
        access: access ?? FakeTrainerRepository(),
        workRepository: work,
      ),
      routes: [
        GoRoute(
          path: 'work/:workId',
          builder: (_, state) => TrainerProgramWorkPage(
            repository: programs,
            workouts: workouts,
            workRepository: work,
            workId: state.pathParameters['workId']!,
            initialBaseProgramId: state.uri.queryParameters['base'],
          ),
        ),
      ],
    ),
  ],
);

Widget routed(GoRouter router, {double scale = 1}) => MaterialApp.router(
  theme: EntrenaTheme.dark,
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
);

void main() {
  testWidgets(
    'recupera texto crudo y autosave utiliza el controlador compartido',
    (tester) async {
      final work = WorkFixture()..stored = checkpoint();
      final router = workRouter(work, TrackedPrograms(), WorkoutFixture());
      addTearDown(router.dispose);
      await tester.pumpWidget(routed(router));
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('program-field-Duración orientativa (semanas)'),
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const ValueKey('program-field-Duración orientativa (semanas)'),
              ),
            )
            .controller!
            .text,
        'sin terminar',
      );
      final nameField = find.byKey(
        const ValueKey('program-field-Nombre del programa'),
      );
      await tester.scrollUntilVisible(
        nameField,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(nameField, 'Nombre incompleto conservado');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(work.saved.single.work.revision, 3);
      expect(work.saved.single.state['name'], 'Nombre incompleto conservado');
      expect(
        (work.saved.single.state['phases'] as List).single['weeks'],
        'sin terminar',
      );
      expect(
        (work.saved.single.state['phases'] as List)
            .single['sessions'][0]['minimum'],
        '-',
      );
      expect(work.finalized, isEmpty);
    },
  );

  testWidgets('base persistida manda sobre query y no carga otro programa', (
    tester,
  ) async {
    final work = WorkFixture()..stored = checkpoint();
    final programs = TrackedPrograms();
    final router = workRouter(
      work,
      programs,
      WorkoutFixture(),
      initial: '/programs/work/$workId?base=otra-base',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(routed(router));
    await tester.pumpAndSettle();
    expect(programs.loaded, ['program']);
    expect(
      tester
          .widget<TrainerProgramEditorPage>(
            find.byType(TrainerProgramEditorPage),
          )
          .work!
          .baseProgramId,
      'program',
    );
  });

  testWidgets(
    'query/refresh ajeno no reinicia campos ni controller del mismo trabajo',
    (tester) async {
      final work = WorkFixture()..stored = checkpoint();
      final programs = TrackedPrograms();
      final workouts = WorkoutFixture();
      Widget page(String base) => MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerProgramWorkPage(
          repository: programs,
          workouts: workouts,
          workRepository: work,
          workId: workId,
          initialBaseProgramId: base,
        ),
      );
      await tester.pumpWidget(page('program'));
      await tester.pumpAndSettle();
      final editor = tester.state(find.byType(GuidedProgramEditorPage));
      await tester.enterText(
        find.byKey(const ValueKey('program-field-Nombre del programa')),
        'Escribiendo sin reset',
      );
      await tester.pumpWidget(page('query-alterada'));
      await tester.pumpAndSettle();
      expect(work.loads, 1);
      expect(tester.state(find.byType(GuidedProgramEditorPage)), same(editor));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('program-field-Nombre del programa')),
            )
            .controller!
            .text,
        'Escribiendo sin reset',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(work.saved.single.work.baseProgramId, 'program');
    },
  );

  testWidgets(
    'reload rev0 conserva base de URL sin fingir checkpoint guardado',
    (tester) async {
      final work = WorkFixture();
      final programs = TrackedPrograms();
      for (var i = 0; i < 2; i++) {
        final router = workRouter(
          work,
          programs,
          WorkoutFixture(),
          initial: '/programs/work/$workId?base=program',
        );
        await tester.pumpWidget(routed(router));
        await tester.pumpAndSettle();
        final editor = tester.widget<TrainerProgramEditorPage>(
          find.byType(TrainerProgramEditorPage),
        );
        expect(editor.work!.id, workId);
        expect(editor.work!.revision, 0);
        expect(editor.work!.baseProgramId, 'program');
        expect(work.saved, isEmpty);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    },
  );

  testWidgets('base nueva retirada se bloquea antes de montar el editor', (
    tester,
  ) async {
    final work = WorkFixture();
    final router = workRouter(
      work,
      TrackedPrograms(),
      WorkoutFixture(),
      initial: '/programs/work/$workId?base=receipt-v1',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(routed(router));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedProgramEditorPage), findsNothing);
    expect(find.textContaining('ya no está publicado'), findsOneWidget);
    expect(work.saved, isEmpty);
  });

  testWidgets(
    'finalized abre versión exacta archivada y nunca editor/head nuevo',
    (tester) async {
      final work = WorkFixture()..stored = checkpoint(finalized: 'receipt-v1');
      final programs = TrackedPrograms();
      final router = workRouter(
        work,
        programs,
        WorkoutFixture(),
        initial: '/programs/work/$workId?base=otra-base',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(routed(router));
      await tester.pumpAndSettle();
      expect(programs.loaded, ['receipt-v1']);
      expect(find.text('La versión exacta del recibo'), findsOneWidget);
      expect(find.byType(GuidedProgramEditorPage), findsNothing);
      expect(work.saved, isEmpty);
    },
  );

  for (final deleted in [false, true]) {
    testWidgets('trabajo cerrado deleted=$deleted no se recrea', (
      tester,
    ) async {
      final work = WorkFixture()
        ..stored = checkpoint(discarded: !deleted, deleted: deleted);
      final router = workRouter(work, TrackedPrograms(), WorkoutFixture());
      addTearDown(router.dispose);
      await tester.pumpWidget(routed(router));
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramEditorPage), findsNothing);
      expect(
        find.text(
          deleted
              ? 'Este trabajo se ha eliminado definitivamente.'
              : 'Este trabajo está descartado.',
        ),
        findsOneWidget,
      );
      expect(work.saved, isEmpty);
    });
  }

  testWidgets('biblioteca permite leer deshabilitado y no descartar ni crear', (
    tester,
  ) async {
    final work = WorkFixture()..rows = [checkpoint()];
    final access = FakeTrainerRepository()
      ..current = TrainerAccess.fromJson({
        'trainer_id': 'trainer-a',
        'enabled': false,
        'effective': false,
        'client_limit': 0,
        'active_clients': 0,
        'revision': 1,
      });
    final router = workRouter(
      work,
      TrackedPrograms(),
      WorkoutFixture(),
      initial: '/programs',
      access: access,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(routed(router));
    await tester.pumpAndSettle();
    expect(work.lists, 1);
    expect(find.text('Montaje recuperable'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Descartar trabajo Montaje recuperable',
            ),
          )
          .onPressed,
      isNull,
    );
    await visibleTap(tester, find.text('Montaje recuperable'));
    expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
  });

  testWidgets(
    'descartar requiere confirmación y reintenta misma revisión incierta',
    (tester) async {
      final work = WorkFixture()
        ..rows = [checkpoint()]
        ..failDiscard = true;
      final router = workRouter(
        work,
        TrackedPrograms(),
        WorkoutFixture(),
        initial: '/programs',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(routed(router));
      await tester.pumpAndSettle();
      await visibleTap(
        tester,
        find.byTooltip('Descartar trabajo Montaje recuperable'),
      );
      await tester.tap(find.text('Conservar'));
      await tester.pumpAndSettle();
      expect(work.discarded, isEmpty);
      await visibleTap(
        tester,
        find.byTooltip('Descartar trabajo Montaje recuperable'),
      );
      await tester.tap(find.text('Descartar trabajo'));
      await tester.pumpAndSettle();
      expect(work.discarded.length, 1);
      work.failDiscard = false;
      await visibleTap(tester, find.text('Reintentar mismo descarte'));
      expect(work.discarded.length, 2);
      expect(work.discarded[0], same(work.discarded[1]));
      expect(work.discarded.last.revision, 3);
      expect(find.text('Montaje recuperable'), findsNothing);
    },
  );

  for (final width in [320.0, 1200.0]) {
    testWidgets('recuperación y listado caben a $width con texto doble', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final work = WorkFixture()
        ..stored = checkpoint()
        ..rows = [checkpoint()];
      final router = workRouter(
        work,
        TrackedPrograms(),
        ChangingLibraryFixture()..retired = true,
        initial: '/programs',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(routed(router, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await visibleTap(tester, find.text('Montaje recuperable'));
      expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
