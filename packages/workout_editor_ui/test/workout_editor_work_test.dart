import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

Map<String, dynamic> raw() => {
  'schema': 1,
  'nameText': ' Incompleta ',
  'descriptionText': ' pendiente ',
  'durationText': 'sin terminar',
  'running': true,
  'segments': [
    {
      'countText': '2',
      'targetText': '4,',
      'paceText': '3:',
      'paceMaxText': '',
      'recoveryTimeText': '01:00',
      'byDistance': true,
      'recoveryByDistance': false,
      'recoveryType': 'walking',
    },
  ],
  'blocks': [
    {
      'nameText': 'Fuerza',
      'format': 'amrap',
      'roundsText': '3',
      'restText': '01:20',
      'capText': '10:',
      'exercises': [
        {
          'exerciseId': null,
          'targetType': 'duration',
          'automaticSlot': true,
          'customSets': true,
          'countText': '3',
          'targetText': '40',
          'restText': '60',
          'loadText': '',
          'rirText': '',
          'amrapRepetitionsText': '12',
          'amrapRirText': '2',
          'variations': [
            {
              'setIndex': 1,
              'targetText': ' ',
              'restText': '90',
              'loadText': '',
              'rirText': '3',
            },
          ],
        },
      ],
    },
  ],
};
Map<String, dynamic> state() => {
  'schema': 1,
  'editor': raw(),
  'context': {'showInLibrary': false},
};
Map<String, dynamic> clone(Map<String, dynamic> v) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(v)) as Map);

class Works extends Fake implements WorkoutEditorWorkRepository {
  WorkoutEditorWork latest = WorkoutEditorWork(
    id: 'work',
    origin: const {},
    state: state(),
    revision: 1,
  );
  bool loseSave = false, loseFinal = false;
  int finalizations = 0;
  final sent = <String>[];
  @override
  Future<WorkoutEditorWork> save(
    WorkoutEditorWork work,
    Map<String, dynamic> data,
  ) async {
    sent.add(jsonEncode(data));
    if (latest.revision == work.revision + 1 &&
        jsonEncode(latest.state) == jsonEncode(data)) {
      return latest;
    }
    if (latest.revision != work.revision) throw const WorkoutWorkConflict();
    latest = WorkoutEditorWork(
      id: work.id,
      origin: work.origin,
      state: clone(data),
      revision: work.revision + 1,
    );
    if (loseSave) {
      loseSave = false;
      throw StateError('Respuesta perdida');
    }
    return latest;
  }

  @override
  Future<String> finalize(WorkoutEditorWork work) async {
    if (latest.resultId != null) return latest.resultId!;
    expect(work.state['intent'], isNotNull);
    finalizations++;
    latest = WorkoutEditorWork(
      id: work.id,
      origin: work.origin,
      state: clone(work.state),
      revision: work.revision,
      resultId: 'saved',
    );
    if (loseFinal) {
      loseFinal = false;
      throw StateError('Respuesta final perdida');
    }
    return 'saved';
  }
}

class Binding extends WorkoutEditorWorkBinding {
  Binding(this.repository, this.work);
  @override
  final Works repository;
  @override
  final WorkoutEditorWork work;
  bool visible = true;
  int acknowledgements = 0;
  @override
  Map<String, dynamic> captureContext() => {'showInLibrary': visible};
  @override
  void restoreContext(Map<String, dynamic> context) {
    visible = context['showInLibrary'] as bool;
  }

  @override
  Future<void> acknowledge(String id) async {
    expect(id, 'saved');
    acknowledgements++;
  }
}

Widget app(Binding binding) => MaterialApp(
  home: WorkoutEditorPage(
    workBinding: binding,
    loadExercises: () async => [],
    onSave: (_) async => throw StateError('Guardado legado duplicado'),
    onSaved: (_) => throw StateError('Callback legado duplicado'),
    title: 'Sesión',
    heading: 'Contenido',
    instructions: 'Prueba',
    saveLabel: 'Guardar receta',
    additionalStateStamp: binding.visible.toString(),
  ),
);

void main() {
  test(
    'codec conserva texto incompleto, rama oculta, AMRAP y hueco automático',
    () {
      final value = raw();
      expect(WorkoutEditorSnapshot(clone(value)).value, value);
      expect(
        () => WorkoutEditorSnapshot({...value, 'schema': 2}),
        throwsFormatException,
      );
      for (final format in [
        'straightSets',
        'superset',
        'circuit',
        'intervals',
        'emom',
        'amrap',
        'tabata',
      ]) {
        final variant = clone(value);
        variant['blocks'][0]['format'] = format;
        expect(WorkoutEditorSnapshot(variant).value, variant);
      }
    },
  );
  test(
    'checkpoint reintenta la petición incierta antes de guardar lo siguiente',
    () async {
      final repo = Works()..loseSave = true;
      final binding = Binding(repo, repo.latest);
      final controller = WorkoutEditorWorkController(
        binding,
        repo.latest.state,
      );
      final first = state()..['context'] = {'showInLibrary': true};
      controller.update(first);
      await expectLater(controller.flush(), throwsStateError);
      final second = clone(first);
      second['editor']['nameText'] = 'Otro cambio';
      controller.update(second);
      await controller.flush();
      expect(repo.sent[0], repo.sent[1]);
      expect(repo.latest.state, second);
      expect(controller.dirty, isFalse);
      controller.dispose();
    },
  );
  test('reinicio con recibo final no vuelve a crear la sesión', () async {
    final repo = Works();
    final binding = Binding(repo, repo.latest);
    final controller = WorkoutEditorWorkController(binding, repo.latest.state);
    final prepared = state()..['intent'] = {'name': 'Receta validada'};
    controller.update(prepared);
    await controller.flush();
    repo.loseFinal = true;
    await expectLater(controller.finish(), throwsStateError);
    expect(repo.finalizations, 1);
    final recovered = Binding(repo, repo.latest);
    final restarted = WorkoutEditorWorkController(recovered, repo.latest.state);
    await restarted.finish();
    expect(recovered.acknowledgements, 1);
    expect(repo.finalizations, 1);
    controller.dispose();
    restarted.dispose();
  });
  testWidgets(
    'autosave restaura campos incompletos y contexto sin convertir la receta',
    (tester) async {
      final repo = Works();
      final binding = Binding(repo, repo.latest);
      await tester.pumpWidget(app(binding));
      await tester.pumpAndSettle();
      expect(binding.visible, isFalse);
      expect(repo.sent, isEmpty);
      final field = find.widgetWithText(TextField, 'Nombre de la sesión');
      await tester.enterText(field, ' A medio escribir ');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(repo.latest.state['editor']['nameText'], ' A medio escribir ');
      expect(repo.latest.state['editor']['blocks'], raw()['blocks']);
      expect(repo.latest.state['context'], {'showInLibrary': false});
      await tester.pumpWidget(const SizedBox.shrink());
      final recovered = Binding(repo, repo.latest);
      await tester.pumpWidget(app(recovered));
      await tester.pumpAndSettle();
      expect(find.text(' A medio escribir '), findsOneWidget);
      expect(recovered.visible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('un schema ilegible no abre editor vacío ni sobrescribe', (
    tester,
  ) async {
    final repo = Works();
    final bad = WorkoutEditorWork(
      id: 'work',
      origin: const {},
      revision: 1,
      state: {...state(), 'schema': 99},
    );
    await tester.pumpWidget(app(Binding(repo, bad)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se conserva sin sobrescribir'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repo.sent, isEmpty);
  });
  testWidgets('salir guarda trabajo sin exigir receta válida', (tester) async {
    final repo = Works();
    final binding = Binding(repo, repo.latest);
    final exit = WorkflowExitController();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowExitScope(
          controller: exit,
          child: WorkoutEditorPage(
            workBinding: binding,
            loadExercises: () async => [],
            onSave: (_) async => 'legacy',
            onSaved: (_) {},
            title: 'Sesión',
            heading: 'Contenido',
            instructions: 'Prueba',
            saveLabel: 'Guardar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre de la sesión'),
      'Pendiente',
    );
    expect(await exit.onExit!(), isTrue);
    expect(repo.latest.state['editor']['nameText'], 'Pendiente');
  });
}
