import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_session_work_editor.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

const workId = '20000000-0000-4000-8000-000000000021';

Map<String, dynamic> rawState() => {
  'schema': 1,
  'context': <String, dynamic>{},
  'editor': {
    'schema': 1,
    'running': false,
    'nameText': 'Sesión recuperable',
    'descriptionText': 'Texto sin recortar  ',
    'durationText': '30',
    'segments': [
      {
        'countText': '-',
        'targetText': 'pendiente',
        'paceText': '',
        'paceMaxText': 'incorrecto',
        'recoveryTimeText': '?',
        'byDistance': false,
        'recoveryByDistance': true,
        'recoveryType': null,
      },
    ],
    'blocks': [
      {
        'nameText': 'Fuerza',
        'format': 'straightSets',
        'roundsText': '1',
        'restText': '0',
        'capText': '',
        'exercises': [
          {
            'exerciseId': 'exercise',
            'targetType': 'repetitions',
            'automaticSlot': false,
            'customSets': false,
            'countText': '2',
            'targetText': '8',
            'restText': '60',
            'loadText': '',
            'rirText': '',
            'amrapRepetitionsText': '',
            'amrapRirText': '',
            'variations': [],
          },
        ],
      },
    ],
  },
};

class SessionWorkFixture implements WorkoutEditorWorkRepository {
  WorkoutEditorWork? stored;
  List<WorkoutEditorWork> rows = [];
  bool failLoad = false,
      failBeforeCommit = false,
      loseFinalResponse = false,
      failDiscard = false;
  int loads = 0;
  final saved = <WorkoutEditorWork>[];
  final finalized = <WorkoutEditorWork>[];
  final discarded = <WorkoutEditorWork>[];

  @override
  Future<List<WorkoutEditorWork>> list() async => List.unmodifiable(rows);
  @override
  Future<WorkoutEditorWork?> load(String id) async {
    loads++;
    if (failLoad) throw StateError('Conexión interrumpida');
    return stored;
  }

  @override
  Future<WorkoutEditorWork> save(
    WorkoutEditorWork work,
    Map<String, dynamic> state,
  ) async {
    final copy = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(state)) as Map,
    );
    stored = WorkoutEditorWork(
      id: work.id,
      origin: work.origin,
      state: copy,
      revision: work.revision + 1,
    );
    saved.add(stored!);
    return stored!;
  }

  @override
  Future<String> finalize(WorkoutEditorWork work) async {
    finalized.add(work);
    expect(work.state.containsKey('intent'), true);
    expect(stored!.state, work.state);
    if (failBeforeCommit) {
      failBeforeCommit = false;
      throw StateError('Petición sin confirmar');
    }
    stored = WorkoutEditorWork(
      id: work.id,
      origin: work.origin,
      state: work.state,
      revision: work.revision + 1,
      resultId: 'receipt-v1',
    );
    if (loseFinalResponse) {
      loseFinalResponse = false;
      throw StateError('El servidor confirmó pero la respuesta se perdió');
    }
    return 'receipt-v1';
  }

  @override
  Future<void> discard(WorkoutEditorWork work) async {
    discarded.add(work);
    if (failDiscard) throw StateError('Respuesta incierta');
    rows.removeWhere((row) => row.id == work.id);
  }

  @override
  Future<WorkoutEditorWork> reopen(WorkoutEditorWork work) async =>
      throw UnimplementedError();
}

class TrackingWorkouts extends WorkoutFixture {
  bool failCatalog = false;
  @override
  Future<List<TrainerWorkout>> workouts({
    TrainerWorkout? before,
    String query = '',
    bool? running,
    String? format,
  }) async {
    if (failCatalog) throw StateError('Catálogo no disponible');
    return super.workouts(before: before);
  }
}

Widget editor(
  SessionWorkFixture works,
  WorkoutFixture workouts, {
  Future<void> Function(String)? onSaved,
  Map<String, dynamic>? initialOrigin,
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  home: TrainerSessionWorkEditor(
    workId: workId,
    repository: works,
    workouts: workouts,
    initialOrigin: initialOrigin,
    onSaved: onSaved ?? (_) async {},
  ),
);

WorkoutEditorWork checkpoint({
  Map<String, dynamic>? state,
  String? base,
  String? result,
}) => WorkoutEditorWork(
  id: workId,
  origin: trainerSessionWorkOrigin(baseId: base),
  state: state ?? rawState(),
  revision: 3,
  resultId: result,
);

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target.last);
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

void main() {
  for (final contextualOrigin in [
    trainerSessionWorkOrigin(
      parentWorkId: 'program-work',
      phaseId: 'phase',
      positionId: 'position',
    ),
    trainerSessionWorkOrigin(
      baseId: 'base',
      assignmentId: 'assignment',
      planningRevision: 2,
    ),
  ]) {
    testWidgets('recupera contexto $contextualOrigin sin reconstruir campos', (
      tester,
    ) async {
      final works = SessionWorkFixture()
        ..stored = WorkoutEditorWork(
          id: workId,
          origin: contextualOrigin,
          state: rawState(),
          revision: 4,
        );
      await tester.pumpWidget(editor(works, WorkoutFixture()));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutEditorPage), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Cambio recuperable',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(works.saved.last.origin, contextualOrigin);
      expect(
        works.saved.last.state['editor']['segments'],
        rawState()['editor']['segments'],
      );
    });
  }

  testWidgets('fallar carga conserva trabajo y no abre formulario nuevo', (
    tester,
  ) async {
    final works = SessionWorkFixture()
      ..failLoad = true
      ..stored = checkpoint();
    await tester.pumpWidget(
      editor(
        works,
        WorkoutFixture(),
        initialOrigin: trainerSessionWorkOrigin(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutEditorPage), findsNothing);
    expect(find.text('Reintentar recuperación'), findsOneWidget);
    works.failLoad = false;
    await tapLabel(tester, 'Reintentar recuperación');
    expect(find.byType(WorkoutEditorPage), findsOneWidget);
    expect(works.saved, isEmpty);
  });

  testWidgets(
    'base persistida manda sobre query inicial y no rehidrata raw desde plantilla',
    (tester) async {
      final works = SessionWorkFixture()
        ..stored = checkpoint(base: 'persistida');
      await tester.pumpWidget(
        editor(
          works,
          WorkoutFixture(),
          initialOrigin: trainerSessionWorkOrigin(baseId: 'query-antigua'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Revisar sesión privada'), findsOneWidget);
      expect(find.text('Sesión recuperable'), findsOneWidget);
      expect(works.saved, isEmpty);
    },
  );

  testWidgets('autosave conserva modalidad oculta y textos inválidos', (
    tester,
  ) async {
    final raw = rawState();
    raw['editor']['durationText'] = 'pendiente';
    final works = SessionWorkFixture()..stored = checkpoint(state: raw);
    await tester.pumpWidget(editor(works, WorkoutFixture()));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, 'Nombre de la sesión');
    await tester.enterText(name, 'Conservada tras salir');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(works.saved.last.state['editor']['durationText'], 'pendiente');
    expect(
      works.saved.last.state['editor']['segments'],
      raw['editor']['segments'],
    );
    expect(works.saved.last.state['context'], isEmpty);
  });

  testWidgets(
    'guardar genera intención mediante la única proyección común y evita motor legacy',
    (tester) async {
      final works = SessionWorkFixture()..stored = checkpoint();
      final workouts = WorkoutFixture();
      String? result;
      await tester.pumpWidget(
        editor(works, workouts, onSaved: (id) async => result = id),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Guardar sesión privada');
      expect(works.finalized, hasLength(1));
      final submitted = works.finalized.single;
      expect(
        submitted.state['intent'],
        workoutDraftToJson(
          projectWorkoutEditorSnapshot(
            WorkoutEditorSnapshot(
              Map<String, dynamic>.from(submitted.state['editor'] as Map),
            ),
          ),
        ),
      );
      expect(
        submitted.state['editor']['segments'][0]['targetText'],
        'pendiente',
      );
      expect(workouts.saved, isEmpty);
      expect(result, 'receipt-v1');
    },
  );

  testWidgets('reload recupera envío incierto con mismo UUID/revisión/receta', (
    tester,
  ) async {
    final works = SessionWorkFixture()
      ..stored = checkpoint()
      ..failBeforeCommit = true;
    final workouts = WorkoutFixture();
    await tester.pumpWidget(editor(works, workouts));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Guardar sesión privada');
    final attempt = works.finalized.single;
    expect(works.stored!.state['intent'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(editor(works, workouts));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Confirmar guardado');
    expect(works.finalized, hasLength(2));
    expect(works.finalized.last.id, attempt.id);
    expect(works.finalized.last.revision, attempt.revision);
    expect(works.finalized.last.state, attempt.state);
    expect(workouts.saved, isEmpty);
  });

  testWidgets(
    'recibo final confirmado sobrevive reload sin crear otra versión',
    (tester) async {
      final works = SessionWorkFixture()
        ..stored = checkpoint()
        ..loseFinalResponse = true;
      final workouts = WorkoutFixture();
      await tester.pumpWidget(editor(works, workouts));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Guardar sesión privada');
      expect(works.stored!.resultId, 'receipt-v1');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      String? result;
      await tester.pumpWidget(
        editor(works, workouts, onSaved: (id) async => result = id),
      );
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Confirmar guardado');
      expect(result, 'receipt-v1');
      expect(works.finalized, hasLength(1));
    },
  );

  testWidgets(
    'reconstrucción por renovar sesión conserva controlador y texto local',
    (tester) async {
      final works = SessionWorkFixture()..stored = checkpoint();
      final workouts = WorkoutFixture();
      await tester.pumpWidget(editor(works, workouts));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Nombre de la sesión');
      final controller = tester.widget<TextField>(field).controller;
      await tester.enterText(field, 'Pendiente del timer');
      await tester.pumpWidget(editor(works, workouts));
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller!.text, 'Pendiente del timer');
      expect(works.loads, 1);
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('biblioteca permite recuperar aunque falle catálogo', (
    tester,
  ) async {
    final works = SessionWorkFixture()
      ..rows = [checkpoint()]
      ..failDiscard = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerWorkoutLibraryPage(
          repository: TrackingWorkouts()..failCatalog = true,
          accessRepository: FakeTrainerRepository(),
          workRepository: works,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sesión recuperable'), findsOneWidget);
    // El acceso se ha consultado antes del fallo del catálogo: la recuperación
    // queda visible, pero no se infiere derecho para descartar desde ese fallo.
    expect(find.text('Trabajos incompletos'), findsOneWidget);
  });

  testWidgets('descarte incierto reintenta el mismo UUID y revisión', (
    tester,
  ) async {
    final pending = checkpoint();
    final works = SessionWorkFixture()
      ..rows = [pending]
      ..failDiscard = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerWorkoutLibraryPage(
          repository: WorkoutFixture(),
          accessRepository: FakeTrainerRepository(),
          workRepository: works,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Descartar trabajo Sesión recuperable'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Descartar trabajo');
    expect(works.discarded.single, same(pending));
    expect(find.text('Reintentar mismo descarte'), findsOneWidget);
    works.failDiscard = false;
    await tapLabel(tester, 'Reintentar mismo descarte');
    expect(works.discarded, hasLength(2));
    expect(works.discarded.last, same(pending));
    expect(find.text('Sesión recuperable'), findsNothing);
  });

  testWidgets('intención pendiente se retoma sin ofrecer descarte', (
    tester,
  ) async {
    final works = SessionWorkFixture()
      ..rows = [
        checkpoint(state: rawState()..['intent'] = {'name': 'Final'}),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerWorkoutLibraryPage(
          repository: WorkoutFixture(),
          accessRepository: FakeTrainerRepository(),
          workRepository: works,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardado pendiente de confirmar'), findsOneWidget);
    expect(
      find.byTooltip('Descartar trabajo Sesión recuperable'),
      findsNothing,
    );
  });
}
