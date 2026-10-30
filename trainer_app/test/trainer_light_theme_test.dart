import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_client_planning_page.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../../test/helpers/performance_visual_review.dart';
import 'trainer_client_planning_test.dart'
    show SelfWorkspace, PlanningFixture, FutureCoachCalendar;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;
import 'trainer_program_flow_test.dart' show ProgramFixture;
import 'trainer_operations_flow_test.dart' show OperationsFixture;

void main() {
  setUpAll(() => loadReviewFont());
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'el modo claro es accesible desde Más a $width y texto $scale',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final controller = ProfessionalThemeController(
          read: () => 'dark',
          write: (_) {},
        );
        addTearDown(controller.dispose);
        await t.pumpWidget(
          ProfessionalThemeScope(
            controller: controller,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: EntrenaTheme.light,
                darkTheme: EntrenaTheme.dark,
                themeMode: ProfessionalThemeScope.maybeOf(context)!.value,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const TrainerShell(
                  location: '/home',
                  child: Scaffold(body: Text('Contenido')),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Más'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Cambiar a modo claro'));
        await t.pumpAndSettle();
        expect(controller.value, ThemeMode.light);
        expect(find.text('Calculadora de ritmos'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'el selector junto a herramientas conserva planificación y calculadora',
    (t) async {
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final controller = ProfessionalThemeController(
        read: () => 'dark',
        write: (_) {},
      );
      addTearDown(controller.dispose);
      final page = TrainerClientPlanningPage(
        clientId: 'self',
        workspace: SelfWorkspace(),
        access: FakeTrainerRepository(),
        planning: PlanningFixture(),
        sharedCalendar: FutureCoachCalendar(),
        workouts: WorkoutFixture(),
        programs: ProgramFixture(),
        operations: OperationsFixture(),
        initialDate: DateTime(2026, 11, 3),
      );
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: ProfessionalThemeScope(
            controller: controller,
            child: Builder(
              builder: (context) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: EntrenaTheme.light,
                darkTheme: EntrenaTheme.dark,
                themeMode: ProfessionalThemeScope.maybeOf(context)!.value,
                home: TrainerShell(location: '/self', child: page),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> readyLogo() async {
        final logo = find.byType(EntrenaWordmark).first;
        final image = t
            .widget<Image>(
              find.descendant(of: logo, matching: find.byType(Image)),
            )
            .image;
        await t.runAsync(() => precacheImage(image, t.element(logo)));
        await t.pumpAndSettle();
      }

      await readyLogo();
      await capturePerformanceWidget(t, 'trainer-para-mi-dark');
      await t.tap(find.byTooltip('Cambiar a modo claro'));
      await t.pumpAndSettle();
      await readyLogo();
      expect(
        Theme.of(t.element(find.byType(TrainerClientPlanningPage))).brightness,
        Brightness.light,
      );
      expect(find.text('Carrera pautada por Ervigio'), findsOneWidget);
      final switchRect = t.getRect(
        find.byKey(const ValueKey('professional-theme-toggle')),
      );
      final toolRect = t.getRect(find.byTooltip('Herramientas').first);
      expect((switchRect.center.dy - toolRect.center.dy).abs(), lessThan(2));
      await capturePerformanceWidget(t, 'trainer-para-mi-light');
      await t.tap(find.byTooltip('Herramientas').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Calculadora de ritmos'));
      await t.pumpAndSettle();
      final pace = find.byKey(const ValueKey('running-pace-input'));
      await t.enterText(pace, '5:15');
      await t.pumpAndSettle();
      final editable = find.descendant(
        of: pace,
        matching: find.byType(EditableText),
      );
      final before = t.widget<EditableText>(editable).controller.text;
      expect(before, '05:15');
      await capturePerformanceWidget(t, 'trainer-calculator-light');
      await t.tap(find.byTooltip('Cambiar a modo oscuro'));
      await t.pumpAndSettle();
      expect(t.widget<EditableText>(editable).controller.text, before);
      expect(find.text('Carrera pautada por Ervigio'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
