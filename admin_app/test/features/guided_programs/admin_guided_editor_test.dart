import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:workout_core/guided_program.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/editorial_covers/domain/program_cover.dart';
import 'package:entrenaop_admin/features/editorial_covers/presentation/program_cover_editor.dart';

class _Guided extends Fake implements AdminGuidedRepository {
  GuidedProgram? saved;
  List<GuidedProgramCategory> categoryItems = [];
  bool failCategory = false;
  @override
  Future<List<GuidedProgramCategory>> categories() async => categoryItems;
  @override
  Future<GuidedProgramCategory> saveCategory(
    String name, {
    GuidedProgramCategory? original,
    bool active = true,
  }) async {
    if (failCategory) throw StateError('Sin conexión');
    final result = GuidedProgramCategory(
      id: original?.id ?? 'new-category',
      name: name,
      active: active,
      revision: (original?.revision ?? 0) + 1,
    );
    categoryItems = [...categoryItems.where((c) => c.id != result.id), result];
    return result;
  }

  @override
  Future<List<GuidedProgram>> programs() async => [
    const GuidedProgram(
      id: 'program',
      name: 'Hipertrofia',
      mode: GuidedProgramMode.guide,
      phases: [],
    ),
  ];
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
  testWidgets('el gestor y la creación admiten texto 2× en móvil estrecho', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Guided()
      ..categoryItems = [
        const GuidedProgramCategory(
          id: 'strength',
          name: 'Fuerza e iniciación',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AdminGuidedCatalogPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Categorías'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear categoría'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Nombre de la categoría'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'selecciona varias categorías, cambia principal y crea desde el borrador',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Guided()
        ..categoryItems = [
          const GuidedProgramCategory(id: 'strength', name: 'Fuerza'),
          const GuidedProgramCategory(id: 'beginner', name: 'Iniciación'),
        ];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.push('/editor'),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/editor',
            builder: (_, _) => AdminGuidedEditorPage(
              repository: repo,
              workouts: _Workouts(),
              original: const GuidedProgram(
                id: 'program',
                name: 'Programa de prueba',
                mode: GuidedProgramMode.guide,
                phases: [
                  GuidedPhase(
                    name: 'Trabajo',
                    sessions: [
                      GuidedSession(
                        templateId: 'official',
                        name: 'Empuje publicado',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Fuerza'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Fuerza'));
      await tester.tap(find.text('Iniciación'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Categoría principal',
        ),
      );
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Categoría principal',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciación').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear categoría'));
      await tester.tap(find.text('Crear categoría'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la categoría'),
        'Rehabilitación',
      );
      repo.failCategory = true;
      await tester.tap(find.text('Guardar categoría'));
      await tester.pumpAndSettle();
      expect(find.text('Rehabilitación'), findsOneWidget);
      expect(
        find.textContaining('No se pudo guardar la categoría'),
        findsOneWidget,
      );
      repo.failCategory = false;
      await tester.tap(find.text('Guardar categoría'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Rehabilitación'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guardar borrador'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.saved!.categories.map((c) => c.id), [
        'strength',
        'beginner',
        'new-category',
      ]);
      expect(repo.saved!.primaryCategoryId, 'beginner');
      expect(repo.saved!.phases.single.sessions.single.templateId, 'official');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gestiona nombres y desactiva categorías conservando su identidad',
    (tester) async {
      final repo = _Guided()
        ..categoryItems = [
          const GuidedProgramCategory(id: 'strength', name: 'Fuerza'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminGuidedCatalogPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categorías'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fuerza'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la categoría'),
        'Fuerza inicial',
      );
      await tester.tap(find.text('Disponible para nuevos programas'));
      await tester.tap(find.text('Guardar categoría'));
      await tester.pumpAndSettle();
      expect(find.text('Fuerza inicial'), findsOneWidget);
      expect(find.text('Desactivada'), findsOneWidget);
      expect(repo.categoryItems.single.id, 'strength');
      expect(repo.categoryItems.single.revision, 2);
      expect(repo.categoryItems.single.active, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'el catálogo abre el mismo editor de portada con la tarjeta compartida',
    (tester) async {
      final repo = _Guided();
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminGuidedCatalogPage(repository: repo, covers: _Covers()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portada'));
      await tester.pumpAndSettle();
      expect(find.byType(ProgramCoverEditor), findsOneWidget);
      expect(find.text('Imagen del programa'), findsOneWidget);
      final card = find.byType(EntrenaProgramCard);
      final preview = tester.widget<EntrenaProgramCard>(card);
      expect(
        tester
                .getTopLeft(
                  find.descendant(
                    of: card,
                    matching: find.text(preview.detail),
                  ),
                )
                .dy -
            tester
                .getBottomLeft(
                  find.descendant(of: card, matching: find.text(preview.title)),
                )
                .dy,
        closeTo(6, 0.01),
      );
      expect(repo.saved, isNull);
    },
  );
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
      await tester.ensureVisible(find.text('Elegir del catálogo'));
      await tester.tap(find.text('Elegir del catálogo'));
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

class _Covers extends Fake implements ProgramCoverRepository {
  @override
  Future<ProgramCover> load(String id) async =>
      const ProgramCover(programId: 'family');
}
