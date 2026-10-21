import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_trash.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_work.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_trash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../../../../test/helpers/performance_visual_review.dart';

final _deleted = GuidedTrashEntry(
  id: 'family',
  name: 'Glúteos · cuatro sesiones',
  isWork: false,
  trashedAt: DateTime.utc(2026, 10, 21),
  versions: 2,
  workCount: 1,
);

class _Trash extends Fake implements AdminGuidedTrashRepository {
  List<GuidedTrashEntry> entries = [];
  final removed = <String>[];
  final restored = <GuidedTrashEntry>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<List<GuidedTrashEntry>> list() async => entries;
  @override
  Future<void> trashProgram(String programId) async {
    if (fail) throw StateError('Sin conexión');
    removed.add(programId);
    entries = [_deleted];
  }

  @override
  Future<void> restore(GuidedTrashEntry entry) async {
    restored.add(entry);
    await gate?.future;
    if (fail) throw StateError('Sin conexión');
    entries = [];
  }
}

class _Catalog extends Fake implements AdminGuidedRepository {
  _Catalog(this.trash);
  final _Trash trash;
  @override
  Future<List<GuidedProgram>> programs() async => [
    if (trash.removed.isEmpty)
      const GuidedProgram(
        id: 'published',
        name: 'Glúteos · cuatro sesiones',
        mode: GuidedProgramMode.guide,
        status: 'published',
        phases: [],
      ),
    const GuidedProgram(
      id: 'draft',
      name: 'Torso en borrador',
      mode: GuidedProgramMode.guide,
      phases: [],
    ),
  ];
}

class _Work extends Fake implements AdminGuidedWorkRepository {
  bool discarded = false;
  @override
  Future<List<GuidedWork>> list() async => discarded
      ? []
      : [
          const GuidedWork(
            id: 'work',
            state: {'name': 'Trabajo incompleto'},
            revision: 4,
          ),
        ];
  @override
  Future<void> discard(GuidedWork work) async {
    discarded = true;
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  testWidgets(
    'cancelar conserva el programa; mover permite abrir su papelera sin otro editor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final trash = _Trash();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => AdminGuidedCatalogPage(
              repository: _Catalog(trash),
              trashRepository: trash,
            ),
          ),
          GoRoute(
            path: '/guided-programs/trash',
            builder: (_, _) => AdminGuidedTrashPage(repository: trash),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (_, child) => RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byTooltip('Más opciones de Glúteos · cuatro sesiones'),
      );
      await _tap(tester, find.text('Mover a papelera'));
      expect(find.textContaining('todas las versiones'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect(trash.removed, isEmpty);
      await _tap(
        tester,
        find.byTooltip('Más opciones de Glúteos · cuatro sesiones'),
      );
      await _tap(tester, find.text('Mover a papelera'));
      await _tap(tester, find.text('Mover a papelera').last);
      expect(trash.removed, ['published']);
      expect(find.text('Glúteos · cuatro sesiones'), findsNothing);
      expect(find.text('Torso en borrador'), findsOneWidget);
      await _tap(tester, find.text('Ver papelera'));
      expect(find.byType(AdminGuidedTrashPage), findsOneWidget);
      expect(find.text('2 versiones · 1 trabajo vinculado'), findsOneWidget);
      await capturePerformanceWidget(tester, 'admin-trash-desktop');
    },
  );

  testWidgets(
    'borrador y trabajo incompleto ofrecen papelera sin exigir publicación',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final trash = _Trash();
      final work = _Work();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminGuidedCatalogPage(
            repository: _Catalog(trash),
            trashRepository: trash,
            workRepository: work,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Más opciones de Torso en borrador'));
      expect(find.text('Mover a papelera'), findsNWidgets(2));
      expect(find.text('Retirar del catálogo'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Mover a papelera'));
      expect(
        find.textContaining('programa de origen se conservan'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Mover a papelera').last);
      expect(work.discarded, isTrue);
      expect(trash.removed, isEmpty);
    },
  );

  testWidgets(
    'recuperar confirma el estado retirado, evita doble envío y conserva la identidad',
    (tester) async {
      final trash = _Trash()
        ..entries = [_deleted]
        ..gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminGuidedTrashPage(repository: trash),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Recuperar programa'));
      expect(find.textContaining('quedará retirado'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect(trash.restored, isEmpty);
      await _tap(tester, find.text('Recuperar programa'));
      await _tap(tester, find.text('Recuperar', skipOffstage: false).last);
      expect(trash.restored, [_deleted]);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Recuperar programa'),
            )
            .onPressed,
        isNull,
      );
      trash.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('La papelera está vacía.'), findsOneWidget);
    },
  );

  testWidgets(
    'fallo incierto conserva la entrada y permite comprobar de nuevo antes de recuperar',
    (tester) async {
      final trash = _Trash()
        ..entries = [_deleted]
        ..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminGuidedTrashPage(repository: trash),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Recuperar programa'));
      await _tap(tester, find.text('Recuperar').last);
      expect(find.textContaining('No se pudo confirmar'), findsOneWidget);
      expect(find.text(_deleted.name), findsOneWidget);
      trash.fail = false;
      await _tap(tester, find.text('Actualizar papelera'));
      expect(find.textContaining('No se pudo confirmar'), findsNothing);
    },
  );

  testWidgets('papelera y confirmación son utilizables a 320 px con texto 2×', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final trash = _Trash()..entries = [_deleted];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: child!,
          ),
        ),
        home: AdminGuidedTrashPage(repository: trash),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recuperar programa'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, find.text('Recuperar programa'));
    await capturePerformanceWidget(tester, 'admin-trash-confirm-320-2x');
    await _tap(tester, find.text('Cancelar'));
    expect(tester.takeException(), isNull);
    expect(trash.restored, isEmpty);
  });
}
