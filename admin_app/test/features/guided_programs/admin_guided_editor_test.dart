import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:workout_core/guided_program.dart';

class _Guided extends Fake implements AdminGuidedRepository {
  GuidedProgram? saved;
  @override
  Future<List<GuidedWarmup>> warmups() async => [];
  @override
  Future<String> save(GuidedProgram program, {String? id}) async {
    saved = program;
    return 'new';
  }
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => [
    const AdminWorkoutSummary(
      id: 'official',
      name: 'Empuje publicado',
      status: 'published',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
    ),
    const AdminWorkoutSummary(
      id: 'draft',
      name: 'Sesión no publicada',
      status: 'draft',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
    ),
  ];
}

void main() {
  testWidgets(
    'el creador guarda una guía ejecutable y excluye sesiones borrador',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Guided();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (c) => TextButton(
                  onPressed: () => c.push('/new'),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/new',
            builder: (_, _) => AdminGuidedEditorPage(
              repository: repository,
              workouts: _Workouts(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del programa'),
        'Guía estable',
      );
      await tester.ensureVisible(find.text('Añadir sesión'));
      await tester.tap(find.text('Añadir sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión no publicada'), findsNothing);
      await tester.tap(find.text('Empuje publicado'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar borrador'));
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repository.saved?.mode, GuidedProgramMode.guide);
      expect(
        repository.saved?.phases.single.sessions.single.templateId,
        'official',
      );
      expect(repository.saved?.phases.single.durationWeeks, isNull);
    },
  );
  testWidgets(
    'el mismo creador muestra duración y condiciones al elegir fases',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AdminGuidedEditorPage(
            repository: _Guided(),
            workouts: _Workouts(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Por fases'));
      await tester.tap(find.text('Por fases'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Duración orientativa (semanas)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          TextFormField,
          'Indicaciones y condiciones de avance',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Añadir fase'));
      await tester.tap(find.text('Añadir fase'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Rutina'));
      await tester.tap(find.text('Rutina'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Conserva una sola fase antes de convertirlo en rutina.'),
      );
      expect(
        find.text('Conserva una sola fase antes de convertirlo en rutina.'),
        findsOneWidget,
      );
    },
  );
}
