import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/training_plan/presentation/widgets/training_context_fields.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_result_fields.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_test_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_test_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_step_fields.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/workout_format_field.dart';
import 'package:workout_editor_ui/workout_effort_field.dart';

import '../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final section in [
        'acceso',
        'carrera',
        'resultados',
        'disponibilidad',
        'formatos',
        'tropa',
        'marca-carrera',
      ]) {
        testWidgets(
          '$section a $width px y texto $scale con salida de teclado',
          (t) async {
            t.view.physicalSize = Size(width, 844);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final controllers = [
              for (final value in ['20:00', '05:00', '05:20', '01:30'])
                TextEditingController(text: value),
            ];
            addTearDown(() {
              for (final c in controllers) {
                c.dispose();
              }
            });
            final content = switch (section) {
              'tropa' => _tropa(t),
              'marca-carrera' => RunningTestFormPage(
                goalId: 'audit',
                repository: _RunningTests(),
              ),
              'acceso' => await _access(),
              'carrera' => _page(
                RunningStepFields(
                  targetType: WorkoutTargetType.duration,
                  targetController: controllers[0],
                  paceMinController: controllers[1],
                  paceMaxController: controllers[2],
                  recoveryController: controllers[3],
                  recoveryType: RunningRecoveryType.walking,
                  recoveryByDistance: false,
                  onTargetTypeChanged: (_) {},
                  onRecoveryTypeChanged: (_) {},
                  onRecoveryMeasureChanged: (_) {},
                  onEdited: () {},
                ),
              ),
              'resultados' => _page(
                Column(
                  children: [
                    WorkoutDurationResultField(
                      controller: controllers[0],
                      label: 'Tiempo realizado',
                    ),
                    WorkoutNumberResultField(
                      controller: controllers[1],
                      label: 'Carga externa (kg)',
                    ),
                    StrengthSetFields(
                      targetType: WorkoutTargetType.repetitions,
                      targetText: '10',
                      restText: '90',
                      loadText: '20',
                      rirText: '2',
                      onTargetChanged: (_) {},
                      onRestChanged: (_) {},
                      onLoadChanged: (_) {},
                      onRirChanged: (_) {},
                    ),
                    WorkoutEffortField(
                      label: 'Repeticiones que te quedaban · 0 a 10',
                      minimum: 0,
                      value: null,
                      enabled: true,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              'disponibilidad' => _page(
                TrainingContextFields(
                  availability: const {'1': 45, '3': 60},
                  equipment: const {'pull_up_bar'},
                  equipmentOptions: const {'pull_up_bar', 'dumbbells'},
                  reportsPain: false,
                  confirmed: true,
                  onAvailability: (_, _) {},
                  onEquipment: (_, _) {},
                  onPain: (_) {},
                  onConfirmed: (_) {},
                ),
              ),
              _ => _page(
                Column(
                  children: [
                    for (final format in WorkoutBlockFormat.values.where(
                      (f) => ![
                        WorkoutBlockFormat.running,
                        WorkoutBlockFormat.warmUp,
                        WorkoutBlockFormat.coolDown,
                      ].contains(f),
                    )) ...[
                      WorkoutFormatField(
                        format: format,
                        exerciseCount: 1,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            };
            await t.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('review-boundary'),
                child: MaterialApp(
                  theme: EntrenaTheme.dark,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: EntrenaInputPolicy(child: child!),
                  ),
                  home: content,
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            for (final label in {
              'Correo electrónico',
              'Contraseña',
              'Recuperación',
              'Tiempo realizado',
              'Días disponibles',
              'Evaluación física · Tropa',
              'Repeticiones que te quedaban · 0 a 10',
              for (final decorator in t.widgetList<InputDecorator>(
                find.byType(InputDecorator),
              ))
                ?decorator.decoration.labelText,
            }) {
              for (final e in find.text(label).evaluate()) {
                final paragraph = t.renderObject<RenderParagraph>(
                  find.byWidget(e.widget),
                );
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: '$label completo en $section a $width/$scale',
                );
              }
            }
            await capturePerformanceWidget(
              t,
              'pulido-$section-${width.toInt()}-$scale',
            );
            final inputs = find.byType(EditableText);
            if (inputs.evaluate().isNotEmpty) {
              final field = inputs.first;
              await t.ensureVisible(field);
              await t.pumpAndSettle();
              await t.tap(field);
              await t.pump();
              expect(t.testTextInput.isVisible, isTrue);
              t.view.viewInsets = const FakeViewPadding(bottom: 300);
              await t.pumpAndSettle();
              await t.ensureVisible(field);
              await t.pumpAndSettle();
              expect(t.getRect(field).bottom, lessThanOrEqualTo(544));
              expect(t.takeException(), isNull);
              if (width == 390 && scale == 1) {
                await capturePerformanceWidget(
                  t,
                  'pulido-$section-con-teclado',
                );
              }
              await t.tapAt(Offset(width - 5, 30));
              await t.pumpAndSettle();
              expect(t.testTextInput.isVisible, isFalse);
            }
          },
        );
      }
    }
  }
}

Widget _page(Widget child) => Scaffold(
  appBar: AppBar(title: const Text('Formulario')),
  body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
);

Widget _tropa(WidgetTester t) {
  final cubit = PhysicalAssessmentCubit(
    evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
      AssessmentEvaluator(),
    ),
    savePhysicalAssessment: SavePhysicalAssessmentUseCase(_Assessments()),
  );
  addTearDown(cubit.close);
  return BlocProvider.value(value: cubit, child: const InitialAssessmentPage());
}

class _Assessments implements PhysicalAssessmentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RunningTests implements RunningTestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Widget> _access() async {
  final repository = _Auth();
  final cubit = AuthCubit(
    signInUseCase: SignInUseCase(repository),
    signUpUseCase: SignUpUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    watchCurrentUserUseCase: WatchCurrentUserUseCase(repository),
  );
  addTearDown(cubit.close);
  await cubit.checkCurrentUser();
  return BlocProvider.value(value: cubit, child: const LoginPage());
}

class _Auth implements AuthRepository {
  @override
  Future<UserEntity?> getCurrentUser() async => null;
  @override
  Stream<AuthSessionChange> watchCurrentUser() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
