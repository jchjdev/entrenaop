import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_program_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

class _Repository extends Fake implements AdminGuidedRepository {
  String draftStatus = 'draft', publicStatus = 'published';
  bool fail = false;
  int reads = 0;
  final changes = <String>[];

  @override
  Future<List<GuidedProgram>> programs() async {
    reads++;
    if (fail) throw StateError('Sin conexión');
    return [
      GuidedProgram(
        id: 'routine',
        name: 'Empuje y tirón',
        mode: GuidedProgramMode.guide,
        status: publicStatus,
        phases: const [
          GuidedPhase(
            name: 'Secuencia',
            sessions: [GuidedSession(templateId: 's', name: 'Empuje')],
          ),
        ],
        categories: const [
          GuidedProgramCategory(id: 'strength', name: 'Fuerza básica'),
        ],
        primaryCategoryId: 'strength',
      ),
      GuidedProgram(
        id: 'phased',
        name: 'Dominadas',
        mode: GuidedProgramMode.phased,
        status: draftStatus,
        version: 2,
        phases: const [],
      ),
    ];
  }

  @override
  Future<void> setStatus(String id, String status) async {
    changes.add('$id:$status');
    if (id == 'phased') draftStatus = status;
    if (id == 'routine') publicStatus = status;
  }
}

Future<_Repository> _mount(WidgetTester tester) async {
  final repo = _Repository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => AdminGuidedCatalogPage(repository: repo),
      ),
      GoRoute(
        path: '/guided-programs/:id/edit',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Editor ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/guided-programs/:id/review',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Revisión ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/guided-programs/new',
        builder: (_, _) => const Scaffold(body: Text('Nuevo programa')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'combina búsqueda sin tildes, modalidad y estado conservando el catálogo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = await _mount(tester);
      expect(find.text('1 sesiones · Secuencia repetible'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar programas'),
        'basica',
      );
      await tester.pumpAndSettle();
      expect(find.text('Empuje y tirón'), findsOneWidget);
      expect(find.text('Dominadas'), findsNothing);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Por fases'));
      expect(
        find.text('No hay programas con esta búsqueda y filtros.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar programas'),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.text('Dominadas'), findsOneWidget);
      await _tap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Publicados').last);
      await tester.pumpAndSettle();
      expect(find.byType(AdminGuidedProgramCard), findsNothing);
      expect(repo.reads, 1);
      expect(repo.changes, isEmpty);
    },
  );

  testWidgets(
    'abre revisión sin publicar, retira desde Más opciones y conserva la versión correcta',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = await _mount(tester);
      await _tap(tester, find.text('Editar borrador'));
      expect(find.text('Editor phased'), findsOneWidget);
      expect(repo.changes, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Revisar y publicar'));
      expect(find.text('Revisión phased'), findsOneWidget);
      expect(repo.changes, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Más opciones de Empuje y tirón'));
      await tester.tap(find.text('Retirar del catálogo'));
      await tester.pumpAndSettle();
      expect(repo.changes.last, 'routine:archived');
      expect(find.text('Retirado'), findsOneWidget);
      final card = find.widgetWithText(
        AdminGuidedProgramCard,
        'Empuje y tirón',
      );
      await _tap(
        tester,
        find.descendant(of: card, matching: find.text('Crear revisión')),
      );
      expect(find.text('Editor routine'), findsOneWidget);
      expect(repo.changes, hasLength(1));
    },
  );

  testWidgets(
    'catálogo a 320 px y texto 2× permite buscar y acceder a las acciones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repository();
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
        find.text('Editar borrador'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Editar borrador').hitTestable(), findsOneWidget);
    },
  );
}
