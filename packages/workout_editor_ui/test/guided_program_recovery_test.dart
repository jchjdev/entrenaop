import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/guided_program_editor_adapter.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/guided_program_work.dart';
import 'package:workout_editor_ui/program_session_catalog.dart';

const firstPosition = '10000000-0000-4000-8000-000000000001';
const secondPosition = '10000000-0000-4000-8000-000000000002';

Map<String, dynamic> _session({
  String? position,
  String id = 'S',
  String? warmup,
  String minimum = '60',
}) => {
  'id': id,
  'name': id == 'S' ? 'Original' : 'Posterior',
  'positionId': ?position,
  'warmup': warmup,
  'adjustable': true,
  'minimum': minimum,
  'maximum': '240',
};

Map<String, dynamic> _snapshot({
  required List<Map<String, dynamic>> sessions,
  bool pending = false,
  Map<String, String> positions = const {},
}) => {
  'schema': 1,
  'name': 'Programa de prueba',
  'description': '',
  'audience': '',
  'equipment': '',
  'mode': 'guide',
  'categories': <String>[],
  'primary': null,
  'phases': [
    {
      'name': 'Entrenamiento',
      'weeks': '2',
      'instructions': '',
      'sessions': sessions,
      'pending': [if (pending) 'T'],
      'replacements': {if (pending) 'T': 'S'},
      if (positions.isNotEmpty) 'replacementPositions': positions,
    },
  ],
};

class _Works implements GuidedWorkRepository {
  _Works(Map<String, dynamic> state)
    : latest = GuidedWork(id: 'work', revision: 1, state: state);
  GuidedWork latest;
  final writes = <Map<String, dynamic>>[];
  bool loseLinkedResponse = false;
  final _receipts = <String, GuidedWork>{};
  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    final copy = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(state)) as Map,
    );
    writes.add(copy);
    final key = '${work.revision}:${jsonEncode(copy)}';
    if (_receipts[key] case final receipt?) return receipt;
    latest = GuidedWork(id: work.id, revision: work.revision + 1, state: copy);
    _receipts[key] = latest;
    final phase = (copy['phases'] as List).single as Map;
    if (loseLinkedResponse &&
        (phase['pending'] as List).isEmpty &&
        (phase['sessions'] as List).any((s) => s['id'] == 'T')) {
      loseLinkedResponse = false;
      throw StateError('linked snapshot committed but response lost');
    }
    return latest;
  }

  @override
  Future<GuidedWork?> load(String id) async => latest;
  @override
  Future<List<GuidedWork>> list() async => [latest];
  @override
  Future<void> discard(GuidedWork work) async {}
  @override
  Future<String> finalize(GuidedWork work, GuidedProgram program) async =>
      'program';
}

class _Composition extends Fake implements GuidedProgramCompositionRepository {
  @override
  Future<List<GuidedWarmup>> warmups() async => [
    for (final id in ['wa', 'wb'])
      GuidedWarmup(
        id: id,
        templateId: id,
        name: id,
        version: 1,
        status: 'published',
      ),
  ];
  @override
  Future<List<GuidedProgramCategory>> categories() async => [];
}

class _Catalog extends Fake implements ProgramSessionCatalog {
  bool fail = false;
  @override
  Future<List<ProgramSessionSummary>> listGeneral() async {
    if (fail) throw StateError('catalog unavailable after session saved');
    return [
      for (final id in ['S', 'T', 'U'])
        ProgramSessionSummary(
          id: id,
          name: id == 'S' ? 'Original' : 'Revisada $id',
          status: 'published',
          version: id == 'S' ? 1 : 2,
          isRunning: false,
          catalogScope: 'general',
        ),
    ];
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => WorkoutTemplate(
    id: id,
    name: id,
    description: null,
    estimatedDurationMinutes: null,
    version: 1,
    blocks: const [],
  );
}

class _Adapter extends GuidedProgramEditorAdapter {
  _Adapter(this.catalog, {this.isProfessional = false, this.beforeSession});
  final _Catalog catalog;
  final bool isProfessional;
  final VoidCallback? beforeSession;
  int edits = 0;
  Object? linkingError;
  @override
  bool get professional => isProfessional;
  @override
  Future<void> openSession(
    BuildContext context, {
    required String programName,
    String? sessionId,
    required bool duplicate,
    required Future<void> Function(String) onSaved,
  }) async {
    edits++;
    beforeSession?.call();
    catalog.fail = true;
    try {
      await onSaved('T');
    } catch (error) {
      linkingError = error;
    }
  }

  @override
  Widget sessionStatus(ProgramSessionSummary? session) =>
      const SizedBox.shrink();
  @override
  Future<String?> createWarmup(BuildContext context) async => null;
  @override
  Future<GuidedProgramCategory?> createCategory(BuildContext context) async =>
      null;
  @override
  Future<void> manageCategories(BuildContext context) async {}
  @override
  void finish(BuildContext context, String id, bool review) {}
  @override
  Future<void> openLibrary(BuildContext context) async {}
  @override
  void openPrograms(BuildContext context) {}
}

class _RetryAdapter extends _Adapter {
  _RetryAdapter(super.catalog);
  Object? retryError;
  @override
  Future<void> openSession(
    BuildContext context, {
    required String programName,
    String? sessionId,
    required bool duplicate,
    required Future<void> Function(String) onSaved,
  }) async {
    edits++;
    try {
      await onSaved('T');
    } catch (error) {
      linkingError = error;
    }
    // Interrupción de catálogo antes de poder limpiar un pendiente reintroducido.
    // Confirmar el enlace ya aplicado no necesita otra lectura del catálogo.
    catalog.fail = true;
    try {
      await onSaved('T');
    } catch (error) {
      retryError = error;
    }
  }
}

Widget _app(
  _Works works,
  _Catalog catalog,
  _Adapter adapter, {
  String key = 'editor',
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  home: GuidedProgramEditorPage(
    key: ValueKey(key),
    repository: _Composition(),
    workouts: catalog,
    adapter: adapter,
    workRepository: works,
    work: works.latest,
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _phase(_Works works) => Map<String, dynamic>.from(
  (works.latest.state['phases'] as List).single as Map,
);
List<Map<String, dynamic>> _sessions(_Works works) =>
    (_phase(works)['sessions'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

void main() {
  for (final editing in [false, true]) {
    testWidgets(
      'retry de onSaved tras respuesta perdida confirma enlace sin reintroducir pendiente, edición=$editing',
      (tester) async {
        final works = _Works(
          _snapshot(sessions: [if (editing) _session(position: firstPosition)]),
        )..loseLinkedResponse = true;
        final catalog = _Catalog();
        final adapter = _RetryAdapter(catalog);
        await tester.pumpWidget(_app(works, catalog, adapter));
        await tester.pumpAndSettle();
        await _tap(
          tester,
          find.text(editing ? 'Editar sesión' : 'Crear nueva sesión'),
        );
        expect(adapter.linkingError, isNotNull);
        expect(adapter.retryError, isNull);
        expect(adapter.edits, 1);
        for (final payload in works.writes) {
          final phase = (payload['phases'] as List).single as Map;
          final applied = (phase['sessions'] as List).any(
            (s) => s['id'] == 'T',
          );
          expect(applied && (phase['pending'] as List).contains('T'), isFalse);
        }
        expect(_sessions(works).map((s) => s['id']), ['T']);
        expect(_phase(works)['pending'], isEmpty);
        expect(_phase(works)['replacements'], isEmpty);
        expect(_phase(works)['replacementPositions'], isEmpty);
        // El último envío es el mismo snapshot/revisión que perdió la respuesta.
        expect(works.writes[works.writes.length - 2], works.writes.last);
        catalog.fail = false;
        await tester.pumpWidget(
          _app(works, catalog, adapter, key: 'reloaded-retry'),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Guardar trabajo ahora'));
        expect(_sessions(works).map((s) => s['id']), ['T']);
        expect(_phase(works)['pending'], isEmpty);
        expect(find.text('Retomar sesión'), findsNothing);
      },
    );
  }
  testWidgets(
    'trabajo actual con orden JSONB distinto no necesita otra escritura',
    (tester) async {
      Object? reverseMaps(Object? value) {
        if (value is Map) {
          return {
            for (final key in value.keys.toList().reversed)
              key: reverseMaps(value[key]),
          };
        }
        if (value is List) return value.map(reverseMaps).toList();
        return value;
      }

      final raw = _snapshot(sessions: [_session(position: firstPosition)]);
      (raw['phases'] as List).single['replacementPositions'] =
          <String, String>{};
      final works = _Works(Map<String, dynamic>.from(reverseMaps(raw) as Map));
      final catalog = _Catalog();
      await tester.pumpWidget(_app(works, catalog, _Adapter(catalog)));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Trabajo guardado · puedes continuar más tarde desde Programas',
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text('Guardar trabajo ahora'));
      expect(works.writes, isEmpty);
    },
  );

  testWidgets(
    'restaurar legado persiste IDs distintos antes de abrir la sesión hija',
    (tester) async {
      final works = _Works(_snapshot(sessions: [_session(), _session()]));
      final catalog = _Catalog();
      List<Object?>? savedPositionsAtOpen;
      final adapter = _Adapter(
        catalog,
        beforeSession: () {
          expect(works.writes, hasLength(1));
          savedPositionsAtOpen = _sessions(works)
              .map((s) => s['positionId'])
              .toList();
          expect(savedPositionsAtOpen!.toSet(), hasLength(2));
          expect(savedPositionsAtOpen!.contains(null), isFalse);
        },
      );
      await tester.pumpWidget(_app(works, catalog, adapter));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2. Original'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Editar sesión').at(1));
      expect(adapter.edits, 1);
      expect(_phase(works)['replacementPositions'], {
        'T': savedPositionsAtOpen![1],
      });
    },
  );

  for (final professional in [false, true]) {
    testWidgets(
      '[S,S] revisión de segunda sobrevive fallo y recarga como [S,T], professional=$professional',
      (tester) async {
        final works = _Works(
          _snapshot(
            sessions: [
              _session(position: firstPosition, warmup: 'wa', minimum: '45'),
              _session(position: secondPosition, warmup: 'wb', minimum: '70'),
            ],
          ),
        );
        final catalog = _Catalog();
        final adapter = _Adapter(catalog, isProfessional: professional);
        await tester.pumpWidget(_app(works, catalog, adapter));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('2. Original'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Editar sesión').at(1));
        expect(adapter.linkingError, isNotNull);
        expect(_phase(works)['replacements'], {'T': 'S'});
        expect(_phase(works)['replacementPositions'], {'T': secondPosition});
        expect(_sessions(works).map((s) => s['id']), ['S', 'S']);
        catalog.fail = false;
        await tester.pumpWidget(_app(works, catalog, adapter, key: 'reloaded'));
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Retomar sesión'));
        expect(find.byType(SimpleDialog), findsNothing);
        expect(_sessions(works).map((s) => s['id']), ['S', 'T']);
        expect(_sessions(works).map((s) => s['positionId']), [
          firstPosition,
          secondPosition,
        ]);
        expect(_sessions(works).map((s) => s['warmup']), ['wa', 'wb']);
        expect(_sessions(works).map((s) => s['minimum']), ['45', '70']);
        expect(_phase(works)['pending'], isEmpty);
        expect(_phase(works)['replacements'], isEmpty);
        expect(_phase(works)['replacementPositions'], isEmpty);
        expect(adapter.edits, 1);
      },
    );
  }

  testWidgets(
    'legado duplicado conserva pendiente y permite elegir exactamente la segunda posición',
    (tester) async {
      final works = _Works(
        _snapshot(
          sessions: [
            _session(minimum: '45'),
            _session(minimum: '70'),
          ],
          pending: true,
        ),
      );
      final catalog = _Catalog();
      final adapter = _Adapter(catalog);
      await tester.pumpWidget(_app(works, catalog, adapter));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Retomar sesión'));
      expect(
        find.text('Elige la posición que quieres sustituir'),
        findsOneWidget,
      );
      expect(_phase(works)['pending'], ['T']);
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(_sessions(works).map((s) => s['id']), ['S', 'S']);
      await _tap(tester, find.text('Retomar sesión'));
      await tester.tap(find.widgetWithText(SimpleDialogOption, '2. Original'));
      await tester.pumpAndSettle();
      expect(_sessions(works).map((s) => s['id']), ['S', 'T']);
      expect(_sessions(works).map((s) => s['minimum']), ['45', '70']);
      final ids = _sessions(works).map((s) => s['positionId']).toSet();
      expect(ids, hasLength(2));
      expect(ids.contains(null), isFalse);
    },
  );

  testWidgets(
    'legado inequívoco sustituye sin duplicar y persiste su posición nueva',
    (tester) async {
      final works = _Works(_snapshot(sessions: [_session()], pending: true));
      final catalog = _Catalog();
      await tester.pumpWidget(_app(works, catalog, _Adapter(catalog)));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Retomar sesión'));
      expect(find.byType(SimpleDialog), findsNothing);
      expect(_sessions(works).map((s) => s['id']), ['T']);
      expect(_sessions(works).single['positionId'], isNotEmpty);
    },
  );

  testWidgets(
    'posición desaparecida no sustituye por receta ni añade otra al cancelar',
    (tester) async {
      final works = _Works(
        _snapshot(
          sessions: [_session(position: firstPosition)],
          pending: true,
          positions: {'T': secondPosition},
        ),
      );
      final catalog = _Catalog();
      await tester.pumpWidget(_app(works, catalog, _Adapter(catalog)));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Retomar sesión'));
      expect(find.byType(SimpleDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(_sessions(works).map((s) => s['id']), ['S']);
      expect(_phase(works)['pending'], ['T']);
      expect(_phase(works)['replacementPositions'], {'T': secondPosition});
    },
  );

  testWidgets(
    'reordenar conserva identidad y sustituye la posición original movida',
    (tester) async {
      final works = _Works(
        _snapshot(
          sessions: [
            _session(position: secondPosition),
            _session(position: firstPosition),
          ],
          pending: true,
          positions: {'T': secondPosition},
        ),
      );
      final catalog = _Catalog();
      await tester.pumpWidget(_app(works, catalog, _Adapter(catalog)));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Retomar sesión'));
      expect(_sessions(works).map((s) => s['id']), ['T', 'S']);
      expect(_sessions(works).map((s) => s['positionId']), [
        secondPosition,
        firstPosition,
      ]);
    },
  );

  testWidgets(
    'otra revisión en la posición exige elección, no sobrescribe automáticamente',
    (tester) async {
      final works = _Works(
        _snapshot(
          sessions: [_session(position: secondPosition, id: 'U')],
          pending: true,
          positions: {'T': secondPosition},
        ),
      );
      final catalog = _Catalog();
      await tester.pumpWidget(_app(works, catalog, _Adapter(catalog)));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Retomar sesión'));
      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(_sessions(works).single['id'], 'U');
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(_phase(works)['pending'], ['T']);
    },
  );
}
