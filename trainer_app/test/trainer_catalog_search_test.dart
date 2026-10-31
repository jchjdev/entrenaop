import '../../test/helpers/performance_visual_review.dart';

import 'dart:async';

import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_filters.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_program_repository.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program_codec.dart';

import 'trainer_workout_flow_test.dart' show WorkoutFixture;
import 'trainer_program_flow_test.dart' show ProgramFixture, privateProgram;
import 'trainer_groups_flow_test.dart' show access;

class SearchWorkouts extends WorkoutFixture {
  final queries = <String>[];
  final pending = Completer<List<TrainerWorkout>>();
  final rows = List.generate(
    121,
    (i) => TrainerWorkout.fromJson({
      'id': 'workout-$i',
      'name': i == 120 ? 'Última sesión ágil' : 'Sesión $i',
      'version': 1,
      'is_running': false,
      'formats': ['amrap'],
      'search_content': [if (i == 120) 'Dominadas únicas'],
      'created_at': '2026-10-31T08:00:00Z',
    }),
  );
  @override
  Future<List<TrainerWorkout>> workouts({
    TrainerWorkout? before,
    String query = '',
    bool? running,
    String? format,
  }) async {
    queries.add(query);
    if (query == 'lenta') return pending.future;
    final filtered = rows
        .where(
          (row) => matchesTrainerWorkout(
            row,
            query: query,
            running: running,
            format: format,
          ),
        )
        .toList();
    final offset = before == null
        ? 0
        : filtered.indexWhere((row) => row.id == before.id) + 1;
    return filtered.skip(offset).take(50).toList();
  }
}

class SearchPrograms extends ProgramFixture {
  final queries = <String>[];
  final rows = List.generate(
    121,
    (i) => TrainerProgram.fromJson({
      'id': 'program-$i',
      'family_id': 'family-$i',
      'version': 2,
      'status': 'published',
      'content': {
        ...guidedProgramToJson(privateProgram),
        'name': i == 120 ? 'Programa límite' : 'Programa $i',
      },
      'created_at': '2026-10-31T08:00:00Z',
    }),
  );
  @override
  Future<List<TrainerProgram>> programs({
    TrainerProgram? before,
    String query = '',
  }) async {
    queries.add(query);
    final filtered = rows
        .where(
          (row) => row.program.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final offset = before == null
        ? 0
        : filtered.indexWhere((row) => row.program.id == before.program.id) + 1;
    return filtered.skip(offset).take(50).toList();
  }
}

Widget app(Widget child) => MaterialApp(
  theme: EntrenaTheme.dark,
  home: RepaintBoundary(key: const ValueKey('review-boundary'), child: child),
);
Finder input(String label) => find.widgetWithText(TextField, label);
void main() {
  setUpAll(loadReviewFont);
  testWidgets(
    'las coincidencias continúan al desplazarse sin pulsar cargar más',
    (t) async {
      final repo = SearchWorkouts();
      await t.pumpWidget(
        app(
          TrainerWorkoutLibraryPage(
            repository: repo,
            accessRepository: access(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = input('Buscar en todas mis sesiones, bloques y ejercicios');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'sesion');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Sesión 119'),
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await t.pumpAndSettle();
      expect(find.text('Sesión 119'), findsOneWidget);
      expect(
        repo.queries.where((q) => q == 'sesion').length,
        greaterThanOrEqualTo(3),
      );
      expect(find.text('Cargar más sesiones'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'sesiones: encuentra por contenido fuera de 50 filas y agrupa pulsaciones',
    (t) async {
      final repo = SearchWorkouts();
      await t.pumpWidget(
        app(
          TrainerWorkoutLibraryPage(
            repository: repo,
            accessRepository: access(),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Última sesión ágil'), findsNothing);
      final field = input('Buscar en todas mis sesiones, bloques y ejercicios');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'ULTIMA');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(field, 'ULTIMA DOMINADAS');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      expect(repo.queries, ['', 'ULTIMA DOMINADAS']);
      await capturePerformanceWidget(t, 'trainer-library-global-search');
      expect(find.text('Última sesión ágil'), findsOneWidget);
      expect(find.text('Cargar más sesiones'), findsNothing);
      expect(repo.assigned, isEmpty);
    },
  );
  testWidgets(
    'una respuesta antigua no sustituye la búsqueda actual y salir cancela el temporizador',
    (t) async {
      final repo = SearchWorkouts();
      await t.pumpWidget(
        app(
          TrainerWorkoutLibraryPage(
            repository: repo,
            accessRepository: access(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = input('Buscar en todas mis sesiones, bloques y ejercicios');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'lenta');
      await t.pump(const Duration(milliseconds: 310));
      await t.enterText(field, 'ULTIMA');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      repo.pending.complete([repo.rows.first]);
      await t.pumpAndSettle();
      expect(find.text('Última sesión ágil'), findsOneWidget);
      expect(find.text('Sesión 0'), findsNothing);
      await t.enterText(field, 'descartada');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(repo.queries, isNot(contains('descartada')));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'programas: encuentra el 121 sin cargar las páginas anteriores y distingue vacío de sin coincidencias',
    (t) async {
      final repo = SearchPrograms();
      await t.pumpWidget(
        app(TrainerProgramLibraryPage(repository: repo, access: access())),
      );
      await t.pumpAndSettle();
      expect(find.text('Programa límite'), findsNothing);
      final field = input('Buscar en todos mis programas');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'límite');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      expect(repo.queries, ['', 'límite']);
      expect(find.text('Programa límite'), findsOneWidget);
      await t.enterText(field, 'ausente');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      expect(
        find.text('No hay programas que coincidan con la búsqueda.'),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no has creado programas privados.'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'selector de sesión consulta toda la biblioteca antes de confirmar',
    (t) async {
      final repo = SearchWorkouts();
      await t.pumpWidget(
        app(TrainerAssignmentDialog(repository: repo, relationId: 'relation')),
      );
      await t.pumpAndSettle();
      final field = input('Buscar en el contenido de las sesiones');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'ULTIMA');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      expect(repo.queries, ['', 'ULTIMA']);
      expect(find.text('Última sesión ágil'), findsOneWidget);
      expect(repo.assigned, isEmpty);
    },
  );
  testWidgets(
    'selector de programas encuentra versiones no cargadas sin modificar la pauta',
    (t) async {
      final repo = SearchPrograms();
      await t.pumpWidget(
        app(
          TrainerProgramAssignmentDialog(
            repository: repo,
            relationId: 'relation',
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = input('Buscar en todos mis programas');
      await t.ensureVisible(field);
      await t.pumpAndSettle();
      await t.enterText(field, 'límite');
      await t.pump(const Duration(milliseconds: 310));
      await t.pumpAndSettle();
      expect(repo.queries, ['', 'límite']);
      expect(find.text('Programa límite'), findsOneWidget);
      expect(repo.assigned, isEmpty);
    },
  );
  testWidgets(
    'el panel remoto conserva resultados por contenido y permite seguir escribiendo mientras consulta',
    (t) async {
      var query = '';
      final seen = <String>[];
      await t.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: ProfessionalLibraryPane<String>(
                title: 'Biblioteca',
                items: const ['Sesión de fuerza'],
                nameOf: (s) => s,
                subtitleOf: (s) => 'Privada',
                onSelected: (_) {},
                enabled: false,
                searchQuery: query,
                searching: true,
                onSearchChanged: (value) {
                  seen.add(value);
                  setState(() => query = value);
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(input('Buscar en la biblioteca'), 'dominadas');
      await t.pumpAndSettle();
      expect(seen, ['dominadas']);
      expect(find.text('Sesión de fuerza'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
