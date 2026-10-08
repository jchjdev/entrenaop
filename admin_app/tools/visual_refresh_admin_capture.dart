// Widgets actuales y repositorios ficticios; no consulta ni modifica Supabase.
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_detail_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/visual_atlas_capture.dart';
import '../test/helpers/admin_test_app.dart';

const _tests = [
  AdminProgramTest(
    id: 'strength',
    code: 'strength',
    name: 'Dominadas',
    unit: 'repetitions',
    betterDirection: 'higher',
    protocolNotes:
        'Ejemplo ficticio de protocolo: registrar repeticiones válidas.',
    definitionVersion: 1,
  ),
  AdminProgramTest(
    id: 'running',
    code: 'running',
    name: 'Carrera 2.000 m',
    unit: 'seconds',
    betterDirection: 'lower',
    protocolNotes: 'Ejemplo ficticio: carrera continua cronometrada en pista.',
    definitionVersion: 1,
    distanceMeters: 2000,
    measurementProtocol: 'run_2000m_v1',
  ),
];

class _Programs implements AdminProgramRepository {
  @override
  Future<List<AdminProgramTest>> listTests(String programId) async => _tests;
  @override
  Future<AdminProgramScoringRule?> getScoringRule(String programId) async =>
      const AdminProgramScoringRule(
        version: 'ejemplo-v1',
        sourceUrl: 'https://example.org/fuente',
        sourceLabel: 'Fuente de ejemplo; sin validez oficial',
        aggregation: 'average',
        maxPoints: 10,
        minEachPoints: 1,
        minAggregatePoints: 5,
      );
  @override
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String programId,
  ) async => const [
    AdminProgramTrainingModule(
      testId: 'running',
      moduleKey: 'running_2000m_v1',
    ),
  ];
  @override
  Future<AdminPerformanceSetup> loadPerformanceSetup(String programId) async =>
      const AdminPerformanceSetup([], []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workouts implements AdminWorkoutRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Covers implements ProgramCoverRepository {
  @override
  Future<ProgramCover> load(String programId) async =>
      ProgramCover(programId: programId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  atlasSource = 'admin_app/tools/visual_refresh_admin_capture.dart';
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    for (final published in [false, true]) {
      atlasTestWidgets('Admin $width $scale $published', (tester) async {
        tester.view.physicalSize = Size(width, width > 900 ? 900 : 1050);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await atlasPumpWidget(
          tester,
          AdminTestApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AdminProgramDetailPage(
              program: AdminProgram(
                id: 'example',
                name: 'Acceso · pruebas físicas',
                kind: 'access',
                enabled: published,
              ),
              repository: _Programs(),
              workoutRepository: _Workouts(),
              coverRepository: _Covers(),
            ),
          ),
        );
        await atlasSettle(tester);
        await tester.tap(
          find.byKey(const ValueKey('program-section-assessment')),
        );
        await atlasSettle(tester);
        final tile = find.widgetWithText(ExpansionTile, 'Dominadas');
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: tile, matching: find.text('Dominadas')),
        );
        await atlasSettle(tester);
        await tester.tap(
          find.byKey(const ValueKey('program-section-training')),
        );
        await atlasSettle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
