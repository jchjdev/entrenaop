import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/guided_session_picker.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_preview_page.dart';
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
  bool listed = true;
  bool failVisibility = false;
  Completer<void>? visibilityGate;
  final visibilityWrites = <({String id, bool value, bool expected})>[];

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => WorkoutTemplate(
    id: id,
    name: 'Empuje publicado',
    description: null,
    estimatedDurationMinutes: null,
    version: 1,
    blocks: const [],
  );

  @override
  Future<void> setLibraryVisibility(
    String templateId,
    bool value, {
    required bool expected,
  }) async {
    visibilityWrites.add((id: templateId, value: value, expected: expected));
    await visibilityGate?.future;
    if (failVisibility) throw StateError('Sin conexión');
    expect(listed, expected);
    listed = value;
  }

  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => [
    AdminWorkoutSummary(
      id: 'official',
      name: 'Empuje publicado',
      status: 'published',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
      showInLibrary: listed,
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

Future<void> _mountVisibilityProgram(
  WidgetTester tester,
  _Guided guided,
  _Workouts workouts,
) async {
  await tester.binding.setSurfaceSize(const Size(1100, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: AdminGuidedEditorPage(
        repository: guided,
        workouts: workouts,
        original: const GuidedProgram(
          id: 'program',
          name: 'Programa de prueba',
          mode: GuidedProgramMode.guide,
          phases: [
            GuidedPhase(
              name: 'Trabajo',
              sessions: [
                GuidedSession(templateId: 'official', name: 'Empuje publicado'),
                GuidedSession(templateId: 'official', name: 'Empuje repetido'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Mostrar en Sesiones de EntrenaOP').first,
    250,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets('el switch guarda sin salir y sincroniza las referencias', (
    tester,
  ) async {
    final workouts = _Workouts();
    final guided = _Guided();
    await _mountVisibilityProgram(tester, guided, workouts);
    final switches = find.widgetWithText(
      SwitchListTile,
      'Mostrar en Sesiones de EntrenaOP',
    );
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
    expect(workouts.visibilityWrites.single, (
      id: 'official',
      value: false,
      expected: true,
    ));
    expect(find.text('Oculta como sesión suelta'), findsNWidgets(2));
    expect(
      tester.widgetList<SwitchListTile>(switches).every((s) => !s.value),
      isTrue,
    );
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
    expect(workouts.visibilityWrites.last, (
      id: 'official',
      value: true,
      expected: false,
    ));
    expect(find.text('Visible como sesión suelta'), findsNWidgets(2));
    expect(guided.saved, isNull);
    expect(find.byType(AdminGuidedEditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guardado pendiente bloquea cambios y el error permite reintentar',
    (tester) async {
      final workouts = _Workouts()
        ..failVisibility = true
        ..visibilityGate = Completer<void>();
      final guided = _Guided();
      await _mountVisibilityProgram(tester, guided, workouts);
      final switches = find.widgetWithText(
        SwitchListTile,
        'Mostrar en Sesiones de EntrenaOP',
      );
      await tester.tap(switches.first);
      await tester.pump();
      expect(workouts.visibilityWrites, hasLength(1));
      expect(find.text('Guardando visibilidad…'), findsNWidgets(2));
      expect(
        tester
            .widgetList<SwitchListTile>(switches)
            .every((s) => s.onChanged == null && s.value),
        isTrue,
      );
      workouts.visibilityGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo guardar la visibilidad'),
        findsNWidgets(2),
      );
      expect(workouts.listed, isTrue);
      expect(find.text('Visible como sesión suelta'), findsNWidgets(2));
      workouts.failVisibility = false;
      await tester.tap(switches.first);
      await tester.pumpAndSettle();
      expect(workouts.visibilityWrites, hasLength(2));
      expect(workouts.listed, isFalse);
      expect(
        find.textContaining('No se pudo guardar la visibilidad'),
        findsNothing,
      );
      expect(guided.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el programa muestra la visibilidad y la refresca tras revisar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workouts = _Workouts();
    final guided = _Guided();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => AdminGuidedEditorPage(
            repository: guided,
            workouts: workouts,
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
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Visible como sesión suelta'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Visible como sesión suelta'), findsOneWidget);
    await tester.ensureVisible(find.text('Revisar sesión'));
    await tester.tap(find.text('Revisar sesión'));
    await tester.pumpAndSettle();
    final toggle = find.descendant(
      of: find.byType(AdminWorkoutPreviewPage),
      matching: find.widgetWithText(
        SwitchListTile,
        'Mostrar en Sesiones de EntrenaOP',
      ),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver al programa'));
    await tester.pumpAndSettle();
    expect(find.text('Oculta como sesión suelta'), findsOneWidget);
    expect(find.text('Visible como sesión suelta'), findsNothing);
    expect(find.text('1. Empuje publicado'), findsOneWidget);
    expect(guided.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el selector distingue borradores y permite reutilizar ocultas', (
    tester,
  ) async {
    final workouts = _Workouts()..listed = false;
    final sessions = await workouts.listGeneral();
    AdminWorkoutSummary? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showDialog<AdminWorkoutSummary>(
                  context: context,
                  builder: (_) => GuidedSessionPicker(sessions: sessions),
                );
              },
              child: const Text('Elegir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();
    expect(find.text('Oculta como sesión suelta'), findsOneWidget);
    await tester.tap(find.text('Borradores'));
    await tester.pumpAndSettle();
    expect(
      find.text('Se mostrará como sesión suelta al publicar'),
      findsOneWidget,
    );
    expect(find.text('Visible como sesión suelta'), findsNothing);
    await tester.tap(find.text('Publicadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empuje publicado'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'official');
    expect(selected?.showInLibrary, isFalse);
    expect(tester.takeException(), isNull);
  });

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
        find.descendant(
          of: find.byKey(const ValueKey('program-label-Categoría principal')),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('program-label-Categoría principal')),
          matching: find.byType(DropdownButtonFormField<String>),
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
    'el selector comienza por publicadas y guarda una guía ejecutable',
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
        find.byKey(const ValueKey('program-field-Nombre del programa')),
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
        find.byKey(
          const ValueKey('program-field-Duración orientativa (semanas)'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('program-field-Indicaciones y condiciones de avance'),
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
