import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/operations/data/admin_operations_repository.dart';
import 'package:entrenaop_admin/features/operations/presentation/admin_dashboard_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_work.dart';

import '../../../../test/helpers/performance_visual_review.dart';

class Operations extends Fake implements AdminOperationsRepository {
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> quality() async {
    if (fail) throw StateError('Sin conexión');
    return [
      {
        'name': 'Sesión de prueba',
        'severity': 'pending',
        'message': 'Pendiente de revisión',
        'resource_type': 'session',
        'resource_id': 's',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> diagnostics() async => {
    'checked_at': '2026-10-21T12:00:00Z',
    'backups': [],
    'errors': [],
    'collection': null,
  };
}

class SessionWorks extends Fake implements WorkoutEditorWorkRepository {
  @override
  Future<List<WorkoutEditorWork>> list() async => [
    const WorkoutEditorWork(
      id: 'session-work',
      origin: {'programId': null},
      revision: 1,
      state: {
        'editor': {'nameText': 'Sesión de glúteos · por terminar'},
      },
    ),
  ];
}

class ProgramWorks extends Fake implements AdminGuidedWorkRepository {
  @override
  Future<List<GuidedWork>> list() async => [
    const GuidedWork(
      id: 'program-work',
      revision: 1,
      state: {'name': 'Programa de glúteos'},
    ),
  ];
}

void main() {
  setUpAll(loadReviewFont);
  for (final (width, scale) in [(1200.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'portada cabe a $width/$scale y no confunde copia ausente con verificada',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: EntrenaTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: AdminDashboardPage(
                operations: Operations(),
                sessions: SessionWorks(),
                programs: ProgramWorks(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pendientes del admin'), findsOneWidget);
        await capturePerformanceWidget(
          tester,
          'admin-pendientes-${width.toInt()}-${scale.toInt()}',
        );
        await tester.scrollUntilVisible(
          find.text('Sin copia registrada'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Sin copia registrada'), findsOneWidget);
        expect(find.textContaining('Copia cifrada verificada'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'un fallo de calidad permite reintentar sin esconder las copias',
    (tester) async {
      final repo = Operations()..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: AdminDashboardPage(operations: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Su estado es desconocido'), findsOneWidget);
      expect(find.text('Sin copia registrada'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Reintentar sección'));
      await tester.pumpAndSettle();
      expect(
        find.text('0 errores · 0 avisos por completar · 1 pendiente editorial'),
        findsOneWidget,
      );
      expect(find.textContaining('Su estado es desconocido'), findsNothing);
    },
  );
}
