// Formularios actuales; repositorios ficticios, sin cuentas ni Supabase.
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/visual_atlas_capture.dart';
import '../test/helpers/admin_test_app.dart';

void main() {
  atlasSource = 'admin_app/tools/visual_form_accessibility_capture.dart';
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    for (final form in ['programa', 'ejercicio']) {
      atlasTestWidgets('Formulario $form $width $scale', (t) async {
        t.view.physicalSize = Size(width, 1050);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final exercises = _Exercises();
        await atlasPumpWidget(
          t,
          AdminTestApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: form == 'programa'
                ? AdminProgramsPage(
                    repository: _Programs(),
                    workoutRepository: _Workouts(),
                    exerciseRepository: exercises,
                    onSignOut: () {},
                  )
                : AdminExercisesPage(repository: exercises),
          ),
        );
        await atlasSettle(t); // 1: catálogo, fuera de la selección exportada.
        await t.ensureVisible(
          find.text(form == 'programa' ? 'Crear programa' : 'Nuevo ejercicio'),
        );
        await t.pumpAndSettle();
        await t.tap(
          find.text(form == 'programa' ? 'Crear programa' : 'Nuevo ejercicio'),
        );
        await t.pumpAndSettle();
        if (form == 'programa') {
          await t.enterText(find.byType(TextFormField), 'Programa de ejemplo');
          final field = find.byType(DropdownButtonFormField<String>);
          await t.ensureVisible(field);
          await t.pumpAndSettle();
          await t.tap(field);
          await t.pumpAndSettle();
          await t.tap(find.text('Evaluación interna').last);
          await atlasSettle(t); // 2: selección completa.
          await t.ensureVisible(find.text('Crear borrador'));
          await t.pumpAndSettle();
          await t.tap(find.text('Crear borrador'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.textContaining('Tus datos siguen aquí'));
          await atlasSettle(t); // 3: error con borrador conservado.
        } else {
          await t.enterText(
            find.byKey(const ValueKey('admin-exercise-name')),
            'Sentadilla de ejemplo',
          );
          await t.enterText(
            find.byKey(const ValueKey('admin-exercise-muscles')),
            'piernas',
          );
          for (final (label, value) in [
            ('Dificultad', 'Intermedio'),
            ('Medición habitual', 'Repeticiones'),
          ]) {
            final field = find.widgetWithText(
              DropdownButtonFormField<String>,
              label,
            );
            await t.ensureVisible(field);
            await t.pumpAndSettle();
            await t.tap(field);
            await t.pumpAndSettle();
            await t.tap(find.text(value).last);
            await t.pumpAndSettle();
          }
          await atlasSettle(t); // 2: selectores del formulario compartido.
          await t.ensureVisible(find.text('Nuevo ejercicio oficial'));
          await atlasSettle(t); // 3: controles de foto y vista previa.
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}

class _Programs implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<List<AdminProgram>> listPrograms() async => const [];
  @override
  Future<void> createDraft({
    required String name,
    required String kind,
  }) async => throw StateError('Fallo simulado');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exercises implements AdminExerciseRepository {
  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workouts implements AdminWorkoutRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
