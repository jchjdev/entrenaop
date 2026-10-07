// Renderizado de pantallas reales sin fixture previo; no usa cuentas reales.
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_test_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_test_page.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visual_atlas_capture.dart';

void main() {
  // El cliente no realiza llamadas: los repositorios inferiores sustituyen IO.
  final fixtureClient = SupabaseClient(
    'http://127.0.0.1:1',
    'fixture-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  tearDownAll(fixtureClient.dispose);
  atlasSource = 'tools/visual_atlas_supplement.dart';

  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await atlasPumpWidget(
      tester,
      MaterialApp(
        theme: EntrenaTheme.dark,
        debugShowCheckedModeBanner: false,
        home: page,
      ),
    );
    await atlasSettle(tester);
  }

  atlasTestWidgets('Herramientas disponibles', (tester) async {
    await mount(tester, const HomeToolsPage());
  });

  atlasTestWidgets('Formulario de evaluación Tropa y resultado', (
    tester,
  ) async {
    final cubit = PhysicalAssessmentCubit(
      evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
        AssessmentEvaluator(),
      ),
      savePhysicalAssessment: SavePhysicalAssessmentUseCase(
        _PhysicalRepository(),
      ),
    );
    addTearDown(cubit.close);
    await mount(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const InitialAssessmentPage(goalId: 'fixture-goal'),
      ),
    );
    final values = ['9', '40', '11:54', '15,4'];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    cubit.evaluate(const [
      RecordedMark(
        testId: 'upper_body_push_ups_2_min',
        unit: MarkUnit.repetitions,
        value: 9,
      ),
      RecordedMark(
        testId: 'abdominal_plank',
        unit: MarkUnit.milliseconds,
        value: 40000,
      ),
      RecordedMark(
        testId: 'run_2000_m',
        unit: MarkUnit.milliseconds,
        value: 714000,
      ),
      RecordedMark(
        testId: 'agility_speed_circuit',
        unit: MarkUnit.milliseconds,
        value: 15400,
      ),
    ]);
    await atlasSettle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -550));
    await atlasSettle(tester);
  });

  atlasTestWidgets('Historial real de controles de carrera con fixture', (
    tester,
  ) async {
    final client = fixtureClient;
    await mount(
      tester,
      RunningTestPage(
        goalId: 'fixture-goal',
        repository: _RunningRepository(client),
      ),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await atlasSettle(tester);
  });

  atlasTestWidgets('Formulario real de control de 2 km', (tester) async {
    final client = fixtureClient;
    await mount(
      tester,
      RunningTestFormPage(
        goalId: 'fixture-goal',
        repository: _RunningRepository(client),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '10:30');
    await atlasSettle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await atlasSettle(tester);
  });

  atlasTestWidgets('Historial periódico con resultado ficticio', (
    tester,
  ) async {
    final client = fixtureClient;
    final reference = await tester.runAsync(FasPeriodic2027Reference.load);
    await mount(
      tester,
      FasPeriodicHistoryPage(
        repository: _PeriodicRepository(client),
        reference: reference,
      ),
    );
    await tester.tap(find.byType(ExpansionTile).first);
    await atlasSettle(tester);
  });

  atlasTestWidgets('Pantalla antigua de preferencias, sin ruta actual', (
    tester,
  ) async {
    final cubit = TrainingPreferencesCubit(repository: _Preferences());
    cubit.load();
    addTearDown(cubit.close);
    await mount(
      tester,
      BlocProvider.value(value: cubit, child: const TrainingPlanPage()),
    );
  });
}

class _PhysicalRepository implements PhysicalAssessmentRepository {
  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async => [];
  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistoryForGoal(
    String goalId,
  ) async => [];
  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
    String? goalId,
  }) async => 'fixture-assessment';
}

class _Preferences implements TrainingPreferencesRepository {
  @override
  Future<TrainingPreferences?> get() async => null;
  @override
  Future<void> save(TrainingPreferences preferences) async {}
}

class _RunningRepository extends RunningTestRepository {
  _RunningRepository(super.client);
  @override
  Future<List<RunningTestResult>> history(String goalId) async => [
    RunningTestResult(
      id: 'fixture-running-test',
      completedAt: DateTime(2026, 10, 7),
      durationSeconds: 630,
      rpe: 8,
      notes: 'Ejemplo ficticio de un control registrado.',
    ),
  ];
  @override
  Future<void> save(String goalId, RunningTestResult result) async {}
}

class _PeriodicRepository extends FasPeriodicAssessmentRepository {
  _PeriodicRepository(super.client);
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async => [
    FasPeriodicAssessmentEntry(
      id: 'fixture-periodic',
      goalId: 'fixture-goal',
      scoringVersion: FasPeriodic2027Reference.version,
      completedAt: DateTime(2026, 10, 7),
      category: 'men',
      age: 30,
      isPreEffectiveReference: true,
      marks: const [
        FasPeriodicAssessmentMark(
          testId: 'upper_body_push_ups_2_min',
          testName: 'Flexiones',
          unit: 'repetitions',
          value: 35,
          threshold: 15,
          meetsMinimum: true,
        ),
        FasPeriodicAssessmentMark(
          testId: 'run_2000_m',
          testName: 'Carrera 2 km',
          unit: 'milliseconds',
          value: 630000,
          threshold: 780000,
          meetsMinimum: true,
        ),
        FasPeriodicAssessmentMark(
          testId: 'agility_speed_circuit',
          testName: 'Agilidad',
          unit: 'milliseconds',
          value: 15000,
          threshold: 16000,
          meetsMinimum: true,
        ),
      ],
    ),
  ];
}
