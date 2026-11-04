import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_setup_progress_store.dart';

import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/core/theme/entrena_theme.dart';

import '../../../helpers/performance_visual_review.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/training_scope.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_training_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

class _Repository implements PreparationTrainingRepository {
  @override
  Future<String?> getInProgressExecutionId() async {
    lookups++;
    if (lookupFails) {
      throw const PreparationTrainingException(
        'No se ha podido consultar la sesión abierta. Vuelve a intentarlo.',
      );
    }
    return inProgressExecution;
  }

  String? inProgressExecution;
  bool lookupFails = false;
  int lookups = 0;

  bool paused = false;
  bool complete = false;
  bool hasTargetDate = true;
  bool confirmedContext = true;
  String? programName;
  int pauses = 0;
  bool? calculatedActivation;
  TrainingScope savedScope = TrainingScope.full;
  TrainingScope activeScope = TrainingScope.full;
  DateTime? oldPublishedWeek;
  List<Map<String, dynamic>>? programsToPause;
  Map<String, dynamic>? strengthAlternative;
  int calculations = 0;
  @override
  Future<void> pause(String goalId) async {
    pauses++;
    paused = true;
  }

  @override
  Future<List<AdaptiveProgramProgress>> refreshPrograms() async => [];
  int savedContexts = 0, publications = 0;
  Map<String, dynamic>? reviewed;
  bool blocked = false, hasRunning = false;
  List<Map<String, dynamic>>? pendingOverride;
  int advances = 0;
  @override
  Future<void> skipSession(String id) async {}
  bool includeSession = false, published = false;
  DateTime? calculatedWeek;
  int revisions = 0;
  bool canReplacePending = false, canResetTrial = false;
  int resets = 0;
  DateTime? savedTargetDate;
  List<Map<String, dynamic>> objectives = const [];
  List<Map<String, dynamic>> references = const [];
  final initialTargetDate = DateTime.now().add(const Duration(days: 90));
  DateTime get _nextMonday {
    final today = DateUtils.dateOnly(DateTime.now());
    return today.add(
      Duration(days: today.weekday == 1 ? 0 : 8 - today.weekday),
    );
  }

  @override
  Future<void> resetTrial(String goalId, String confirmation) async {
    expect(confirmation, 'REINICIAR');
    resets++;
    published = false;
  }

  PreparationTrainingData get data => PreparationTrainingData(
    programName: programName,
    availableRunning: hasRunning,
    trainingScope: savedScope,
    canResetTrial: canResetTrial,
    updateOptions: {
      'can_replace_pending': published && canReplacePending,
      'week_start': _nextMonday.toIso8601String().split('T').first,
      'reason': 'Esta semana ya tiene sesiones realizadas. Conservamos sus registros.',
    },
    programState: complete
        ? {'auto_advance': false, 'status': 'complete'}
        : paused
        ? {
            'auto_advance': false,
            'status': 'paused',
            'training_scope': activeScope.value,
            'message': 'Tu progreso está guardado.',
          }
        : published
        ? {
            'auto_advance': true,
            'status': 'training',
            'training_scope': activeScope.value,
            'message': 'Tu próxima semana se preparará con tus resultados.',
          }
        : {},
    hasRunning: hasRunning && savedScope.includesRunning,
    targetDate: hasTargetDate ? savedTargetDate ?? initialTargetDate : null,
    catalog: StrengthExerciseCatalogCodec.decode(
      jsonDecode(
        File('supabase/catalogs/strength_exercises_v1.json').readAsStringSync(),
      ),
    ).exercises,
    context: {
      'availability': {'1': 60, '4': 60},
      'equipment': [],
      'reports_pain': false,
      'capacity_confirmed': confirmedContext,
    },
    runningContext: null,
    references: references,
    objectives: objectives,
    relations: const [],
    publishedWeeks: published
        ? [
            oldPublishedWeek ??
                DateTime.now()
                    .add(
                      Duration(
                        days: DateTime.now().weekday == 1
                            ? 0
                            : 8 - DateTime.now().weekday,
                      ),
                    )
                    .copyWith(
                      hour: 0,
                      minute: 0,
                      second: 0,
                      millisecond: 0,
                      microsecond: 0,
                    ),
          ]
        : const [],
  );
  @override
  Future<void> saveProgram(
    String goalId,
    DateTime targetDate,
    Map<String, dynamic> targets, {
    TrainingScope scope = TrainingScope.full,
  }) async {
    savedTargetDate = targetDate;
    savedScope = scope;
  }

  @override
  Future<void> advance(String goalId) async {
    advances++;
  }

  @override
  Future<Map<String, dynamic>> activate(
    String goalId,
    DateTime week,
    Map<String, dynamic> reviewed,
  ) {
    paused = false;
    activeScope = savedScope;
    return publish(goalId, week, reviewed);
  }

  @override
  Future<PreparationTrainingData> load(String goalId) async => data;
  @override
  Future<void> saveContext(
    Map<String, int> availability,
    Set<String> equipment, {
    required bool reportsPain,
    required bool capacityConfirmed,
  }) async {
    savedContexts++;
  }

  @override
  Future<void> saveReference(
    String goalId,
    Map<String, dynamic> reference, {
    String? testId,
  }) async {}
  @override
  Future<void> deactivateReference(String id) async {}
  @override
  Future<Map<String, dynamic>> calculate(
    String goalId,
    DateTime week, {
    bool revise = false,
    bool activation = false,
  }) async {
    calculations++;
    if (revise) revisions++;
    calculatedActivation = activation;
    calculatedWeek = week;
    return {
      'status': blocked ? 'needs_attention' : 'ready',
      'reason': 'Referencia y contexto comprobados.',
      'sessions': [],
      if (strengthAlternative != null)
        'strength_schedule_alternative': strengthAlternative,
      if (activation && programsToPause != null)
        'activation': {'pauses': programsToPause},
      if (includeSession)
        'running': {
          'sessions': [
            {
              'date': week.toIso8601String().split('T').first,
              'minutes': 30,
              'name': 'Carrera fácil',
            },
          ],
        },
      if (published && !revise && !activation) 'decision_id': 'original',
      if (revise) 'revision': {'preparation_decision_id': 'original'},
      'pending':
          pendingOverride ??
          (blocked
              ? [
                  {'name': 'Plancha', 'reason': 'Falta una referencia actual.'},
                ]
              : []),
    };
  }

  @override
  Future<Map<String, dynamic>> publish(
    String goalId,
    DateTime week,
    Map<String, dynamic> proposal,
  ) async {
    publications++;
    reviewed = proposal;
    return {...proposal, 'decision_id': 'published'};
  }
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label));
  await t.pumpAndSettle();
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

Future<void> _prepare(WidgetTester t) async {
  await _tap(t, 'Continuar con mi disponibilidad');
  await _tap(t, 'Continuar con los movimientos');
  await _tap(t, 'Revisar mi plan');
  await _tap(t, 'Ver mis primeros entrenamientos');
}

void main() {
  setUpAll(loadReviewFont);

  testWidgets('la alternativa muestra la semana y deja reprogramar o conservar', (t) async {
    final repo = _Repository()
      ..strengthAlternative = {
        'name': 'Fuerza de piernas',
        'scheduled_id': 'legs-tuesday',
        'from_date': '2026-11-10',
        'to_date': '2026-11-11',
        'agenda': [
          {'date': '2026-11-11', 'name': 'Fuerza de piernas', 'minutes': 35},
        ],
        'running': [
          {'date': '2026-11-09', 'name': 'Intervalos sostenidos', 'minutes': 30},
        ],
        'performance': [],
      };
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
        GoRoute(
          path: '/plan/week',
          builder: (_, state) => Scaffold(
            body: Text('Agenda ${state.uri.queryParameters['session']}'),
          ),
        ),
        GoRoute(
          path: '/plan/goal/goal/plan',
          builder: (_, _) => const Scaffold(body: Text('Plan activado')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await _prepare(t);

    expect(find.textContaining('martes 10/11 al miércoles 11/11'), findsOneWidget);
    expect(find.text('lunes 9/11 · Intervalos sostenidos · 30 min'), findsOneWidget);
    expect(find.text('miércoles 11/11 · Fuerza de piernas · 35 min'), findsOneWidget);
    final initialCalculations = repo.calculations;
    await _tap(t, 'Abrir sesión en mi agenda');
    expect(find.text('Agenda legs-tuesday'), findsOneWidget);
    expect(repo.publications, 0);
    router.pop();
    await t.pumpAndSettle();
    expect(repo.calculations, initialCalculations + 1);
    await _tap(t, 'Activar mi plan');
    expect(repo.publications, 1);
    expect(repo.reviewed!.containsKey('strength_schedule_alternative'), isFalse);
  });

  for (final anotherRoute in [false, true]) {
    testWidgets(
      'el cambio de propietario retira solo su referencia abierta: encima=$anotherRoute',
      (t) async {
        final owner = ValueNotifier('A');
        addTearDown(owner.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final repositories = {
          'A': _Repository()..programName = 'Preparación A',
          'B': _Repository()..programName = 'Preparación B',
        };
        await t.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: ValueListenableBuilder<String>(
              valueListenable: owner,
              builder: (_, id, _) => PreparationTrainingPage(
                key: ValueKey(id),
                goalId: 'goal-$id',
                repository: repositories[id]!,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await _tap(t, 'Continuar con mi disponibilidad');
        await _tap(t, 'Continuar con los movimientos');
        await _tap(t, 'Añadir objetivo de mejora');
        expect(find.byType(PerformanceReferenceDialog), findsOneWidget);
        if (anotherRoute) {
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Pantalla nueva')),
            ),
          );
          await t.pumpAndSettle();
        }
        owner.value = 'B';
        await t.pumpAndSettle();
        expect(
          find.byType(PerformanceReferenceDialog, skipOffstage: false),
          findsNothing,
        );
        if (anotherRoute) {
          expect(find.text('Pantalla nueva'), findsOneWidget);
          navigator.currentState!.pop();
          await t.pumpAndSettle();
        }
        expect(find.text('Preparación B'), findsOneWidget);
        expect(find.text('Preparación A'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final screen in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'configuración reanudada accesible a ${screen.$1} px y texto ${screen.$2}',
      (t) async {
        t.view.physicalSize = Size(screen.$1, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final repo = _Repository()
          ..programName = 'Evaluación periódica FAS · 2027 (PAFAS/PAEF)'
          ..objectives = const [
            {
              'objective_key': 'test',
              'name': 'Plancha abdominal',
              'measurement': 'DURATION',
            },
          ];
        final store = _SetupProgress()
          ..steps['goal'] = PreparationSetupStep.movements;
        await t.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(screen.$2)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: PreparationTrainingPage(
                goalId: 'goal',
                repository: repo,
                progressStore: store,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Paso 3 de 4 · Movimientos'), findsOneWidget);
        expect(t.takeException(), isNull);
        await capturePerformanceWidget(
          t,
          'configuracion-continuar-${screen.$1.toInt()}',
        );
        await _tap(t, 'Atrás');
        expect(find.text('Paso 2 de 4 · Disponibilidad'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('reanudar no salta datos requeridos que ya no están guardados', (
    t,
  ) async {
    final store = _SetupProgress()
      ..steps['goal'] = PreparationSetupStep.proposal;
    final repo = _Repository()..hasTargetDate = false;
    Widget page() => MaterialApp(
      home: PreparationTrainingPage(
        goalId: 'goal',
        repository: repo,
        progressStore: store,
      ),
    );
    await t.pumpWidget(page());
    await t.pumpAndSettle();
    expect(find.textContaining('Paso 1 de'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    repo.hasTargetDate = true;
    repo.confirmedContext = false;
    await t.pumpWidget(page());
    await t.pumpAndSettle();
    expect(find.text('Paso 2 de 4 · Disponibilidad'), findsOneWidget);
    expect(repo.calculatedWeek, isNull);
    expect(repo.publications, 0);
  });

  testWidgets(
    'la consulta finalizada conserva resultados sin prometer otra semana',
    (t) async {
      final repo = _Repository()..complete = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Preparación finalizada'), findsOneWidget);
      expect(
        find.textContaining('Al terminar las sesiones previstas'),
        findsNothing,
      );
      expect(find.text('Revisar configuración'), findsOneWidget);
      expect(repo.publications, 0);
      expect(repo.calculatedWeek, isNull);
    },
  );

  testWidgets(
    'continúa el paso guardado sin activar ni calcular otra preparación',
    (t) async {
      final repo = _Repository();
      final store = _SetupProgress();
      Widget page() => MaterialApp(
        theme: EntrenaTheme.dark,
        home: PreparationTrainingPage(
          goalId: 'goal',
          repository: repo,
          progressStore: store,
        ),
      );
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con los movimientos');
      expect(await store.read('goal'), PreparationSetupStep.movements);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('Paso 3 de 4 · Movimientos'), findsOneWidget);
      expect(
        find.textContaining('Continuamos desde tus datos guardados'),
        findsOneWidget,
      );
      expect(repo.calculatedWeek, isNull);
      expect(repo.publications, 0);
      expect(repo.advances, 2);
    },
  );

  testWidgets(
    'la posición recordada se adapta al alcance y no desplaza un plan activo',
    (t) async {
      final store = _SetupProgress()
        ..steps['goal'] = PreparationSetupStep.running;
      final repo = _Repository();
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(
            goalId: 'goal',
            repository: repo,
            progressStore: store,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Paso 2 de 4 · Disponibilidad'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      repo.published = true;
      store.steps['goal'] = PreparationSetupStep.proposal;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(
            goalId: 'goal',
            repository: repo,
            progressStore: store,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Paso 4 de'), findsNothing);
      expect(find.text('Mi plan adaptativo'), findsOneWidget);
    },
  );

  testWidgets(
    'cambiar configuración abre el asistente del plan activo directamente',
    (t) async {
      final repo = _Repository()..published = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(
            goalId: 'goal',
            repository: repo,
            editOnOpen: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Cambiar configuración'), findsOneWidget);
      expect(find.textContaining('Paso 1 de'), findsOneWidget);
      expect(repo.publications, 0);
    },
  );

  testWidgets(
    'la flecha de disponibilidad vuelve al paso previo y conserva el objetivo',
    (t) async {
      final repo = _Repository();
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'Continuar con mi disponibilidad');
      await t.tap(find.byTooltip('Volver'));
      await t.pumpAndSettle();
      expect(find.textContaining('Paso 1 de'), findsOneWidget);
      expect(repo.savedTargetDate, repo.initialTargetDate);
      expect(repo.publications, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'una meta cero se corrige en Movimientos y dejarla vacía permite continuar',
    (t) async {
      final repo = _Repository()
        ..objectives = const [
          {
            'objective_key': 'test',
            'name': 'Movimiento',
            'measurement': 'REPS',
          },
        ];
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con los movimientos');
      final target = find.byKey(const ValueKey('target-test'));
      await t.enterText(target, '0');
      await _tap(t, 'Revisar mi plan');
      expect(find.text('Paso 3 de 4 · Movimientos'), findsOneWidget);
      expect(find.textContaining('mayor que cero'), findsOneWidget);
      expect(repo.calculatedWeek, isNull);
      await t.enterText(target, 'NaN');
      await _tap(t, 'Revisar mi plan');
      expect(find.text('Paso 3 de 4 · Movimientos'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.enterText(target, '');
      await _tap(t, 'Revisar mi plan');
      expect(find.text('Paso 4 de 4 · Propuesta'), findsOneWidget);
    },
  );

  testWidgets('las referencias usan la fecha visible común', (t) async {
    final repo = _Repository()
      ..references = const [
        {
          'id': 'r',
          'reference': {
            'observed_on': '2026-11-03',
            'reference_kind': 'work_set',
            'targets': [{}],
          },
        },
      ];
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(goalId: 'goal', repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'Continuar con mi disponibilidad');
    await _tap(t, 'Continuar con los movimientos');
    expect(find.text('Referencia: 03-11-2026 · 1 serie'), findsOneWidget);
    expect(find.textContaining('2026-11-03'), findsNothing);
  });

  testWidgets(
    'activar termina en la consulta canónica y limpia la posición guardada',
    (t) async {
      final repo = _Repository();
      final store = _SetupProgress();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Origen')),
          ),
          GoRoute(
            path: '/setup',
            builder: (_, _) => PreparationTrainingPage(
              goalId: 'goal',
              repository: repo,
              progressStore: store,
            ),
          ),
          GoRoute(
            path: '/plan/goal/goal/plan',
            builder: (_, _) => const Scaffold(body: Text('Consulta canónica')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/setup');
      await t.pumpAndSettle();
      await _prepare(t);
      await _tap(t, 'Activar mi plan');
      expect(find.text('Consulta canónica'), findsOneWidget);
      expect(repo.publications, 1);
      expect(await store.read('goal'), isNull);
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('Origen'), findsOneWidget);
    },
  );
  for (final scope in [TrainingScope.running, TrainingScope.performance]) {
    testWidgets('selección $scope solo pregunta por lo elegido', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = _Repository()..hasRunning = true;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: PreparationTrainingPage(
              goalId: 'goal',
              repository: repo,
              runningStepBuilder: (_, next, back) => Column(
                children: [
                  const Text('Datos específicos de carrera'),
                  FilledButton(
                    onPressed: next,
                    child: const Text('Continuar con el programa'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await capturePerformanceWidget(t, 'eleccion-de-entrenamiento');
      await _tap(
        t,
        scope == TrainingScope.running
            ? 'Solo carrera'
            : 'Fuerza y otras pruebas',
      );
      await _tap(t, 'Continuar con mi disponibilidad');
      expect(repo.savedScope, scope);
      if (scope == TrainingScope.running) {
        await _tap(t, 'Continuar con carrera');
        await _tap(t, 'Continuar con el programa');
        expect(find.text('Revisar mi plan'), findsNothing);
      } else {
        await _tap(t, 'Continuar con los movimientos');
        expect(find.text('Datos específicos de carrera'), findsNothing);
        await _tap(t, 'Revisar mi plan');
      }
      expect(find.text('Paso 4 de 4 · Propuesta'), findsOneWidget);
      await _tap(t, 'Ver mis primeros entrenamientos');
      expect(repo.calculatedActivation, isTrue);
      expect(repo.publications, 0);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('pausar requiere confirmar y muestra un programa reanudable', (
    t,
  ) async {
    final repo = _Repository()..published = true;
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(goalId: 'goal', repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'Pausar mi plan');
    expect(repo.pauses, 0);
    await _tap(t, 'Cancelar');
    expect(repo.pauses, 0);
    await _tap(t, 'Pausar mi plan');
    await _tap(t, 'Pausar plan');
    expect(repo.pauses, 1);
    expect(find.text('Tu plan está pausado'), findsOneWidget);
    expect(find.text('Retomar mi plan'), findsOneWidget);
    expect(find.text('Revisar mi punto de partida'), findsOneWidget);
    expect(find.text('Tu plan está en marcha'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'retomar revisa datos y propone una semana actual, no la antigua',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = _Repository()
        ..published = true
        ..paused = true
        ..oldPublishedWeek = DateTime(2026, 1, 5)
        ..programsToPause = [
          {'goal_id': 'other', 'name': 'Tropa'},
        ];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: PreparationTrainingPage(goalId: 'goal', repository: repo),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.calculatedWeek, isNull);
      await capturePerformanceWidget(t, 'programa-pausado');
      await _tap(t, 'Retomar mi plan');
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con los movimientos');
      await _tap(t, 'Revisar mi plan');
      await _tap(t, 'Revisar mis próximos entrenamientos');
      expect(repo.calculatedWeek, repo._nextMonday);
      expect(repo.calculatedActivation, isTrue);
      expect(find.textContaining('se pausará: Tropa'), findsOneWidget);
      expect(repo.publications, 0);
      await capturePerformanceWidget(t, 'aceptacion-de-cambio');
      await _tap(t, 'Retomar mi plan');
      expect(repo.publications, 1);
      expect(find.text('Tu plan está en marcha'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('cambiar selección necesita aceptar la propuesta nueva', (
    t,
  ) async {
    final repo = _Repository()
      ..published = true
      ..hasRunning = true
      ..oldPublishedWeek = DateTime(2026, 1, 5);
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(
          goalId: 'goal',
          repository: repo,
          runningStepBuilder: (_, next, back) => Column(
            children: [
              const Text('Cuestionario de carrera'),
              FilledButton(
                onPressed: next,
                child: const Text('Continuar con el programa'),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'Cambiar configuración');
    await _tap(t, 'Solo carrera');
    await _tap(t, 'Continuar con mi disponibilidad');
    await _tap(t, 'Continuar con carrera');
    await _tap(t, 'Continuar con el programa');
    await _tap(t, 'Guardar cambios');
    expect(repo.activeScope, TrainingScope.full);
    expect(repo.savedScope, TrainingScope.running);
    expect(repo.calculatedActivation, isTrue);
    expect(repo.calculatedWeek, repo._nextMonday);
    expect(repo.publications, 0);
    await _tap(t, 'Aplicar selección de entrenamiento');
    expect(repo.activeScope, TrainingScope.running);
    expect(repo.publications, 1);
    expect(find.text('Tu plan está en marcha'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('un borrador de selección no sustituye el panel activo', (
    t,
  ) async {
    final repo = _Repository()
      ..published = true
      ..hasRunning = true
      ..savedScope = TrainingScope.running
      ..activeScope = TrainingScope.full;
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(goalId: 'goal', repository: repo),
      ),
    );
    await t.pumpAndSettle();
    expect(repo.calculatedActivation, isFalse);
    expect(find.text('Preparación completa'), findsOneWidget);
    expect(find.text('Tu plan está en marcha'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'carrera es un bloque del programa y la propuesta requiere revisión',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = _Repository()..hasRunning = true;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: PreparationTrainingPage(
              goalId: 'goal',
              repository: repo,
              runningStepBuilder: (_, next, back) => Column(
                children: [
                  const Text('Datos específicos de carrera'),
                  FilledButton(
                    onPressed: next,
                    child: const Text('Continuar con el programa'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Paso 1 de 5 · Tu preparación'), findsOneWidget);
      await capturePerformanceWidget(t, 'programa-inicio');
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con carrera');
      expect(find.text('Paso 3 de 5 · Carrera'), findsOneWidget);
      expect(find.text('Datos específicos de carrera'), findsOneWidget);
      await _tap(t, 'Continuar con el programa');
      await _tap(t, 'Revisar mi plan');
      expect(find.text('Ver mis primeros entrenamientos'), findsOneWidget);
      expect(repo.calculatedWeek, isNull);
      expect(repo.publications, 0);
      await capturePerformanceWidget(t, 'programa-resumen');
      await _tap(t, 'Ver mis primeros entrenamientos');
      expect(repo.calculatedWeek, isNotNull);
      expect(repo.publications, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'una propuesta con sesiones muestra el día sin inicializar locales',
    (t) async {
      final repo = _Repository()..includeSession = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _prepare(t);
      expect(find.textContaining('30 min en total'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'un programa activo no devuelve al cuestionario ni al calculador',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = _Repository()..published = true;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: PreparationTrainingPage(
              goalId: 'goal',
              repository: repo,
              initialWeek: repo.data.publishedWeeks.single.add(
                const Duration(days: 21),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tu plan está en marcha'), findsOneWidget);
      expect(find.textContaining('Paso 1 de'), findsNothing);
      expect(find.text('Activar continuidad automática'), findsNothing);
      expect(find.text('Recalcular con mis datos actuales'), findsNothing);
      expect(repo.calculatedWeek, repo.data.publishedWeeks.single);
      expect(repo.advances, 1);
      expect(repo.revisions, 0);
      expect(repo.publications, 0);
      expect(t.takeException(), isNull);
      await capturePerformanceWidget(t, 'programa-en-marcha');
    },
  );
  testWidgets(
    'volver al programa muestra la semana real, sin inventar futuras',
    (t) async {
      final repo = _Repository()..published = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();

      expect(repo.calculatedWeek, repo.data.publishedWeeks.single);
      expect(repo.publications, 0);
    },
  );
  testWidgets(
    'la semana pedida desde la agenda se respeta y no se publica sola',
    (t) async {
      final repo = _Repository();
      final week = DateTime(2026, 10, 12);
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(
            goalId: 'goal',
            repository: repo,
            initialWeek: week.add(const Duration(days: 2)),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _prepare(t);
      expect(repo.calculatedWeek, week);
      expect(repo.publications, 0);
    },
  );
  for (final blocked in [false, true]) {
    testWidgets(
      'recorrido móvil: publicación ${blocked ? 'bloqueada' : 'revisada'}',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final repo = _Repository()..blocked = blocked;
        await t.pumpWidget(
          MaterialApp(
            home: PreparationTrainingPage(goalId: 'goal', repository: repo),
          ),
        );
        await t.pumpAndSettle();
        await _prepare(t);
        expect(repo.savedContexts, 1);
        expect(repo.publications, 0);
        if (blocked) {
          expect(find.text('Falta una referencia actual.'), findsOneWidget);
          expect(
            t
                .widget<FilledButton>(
                  find.ancestor(
                    of: find.text('Activar mi plan'),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );
        } else {
          await _tap(t, 'Activar mi plan');
          expect(repo.publications, 1);
          expect(repo.reviewed?['status'], 'ready');
        }
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('solo fuerza no muestra cuestionario de carrera', (t) async {
    final repo = _Repository()..hasRunning = false;
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(goalId: 'goal', repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'Continuar con mi disponibilidad');
    await _tap(t, 'Continuar con los movimientos');
    expect(find.text('Revisar datos de carrera'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'avisos de hueco y frecuencia abren disponibilidad, no calibración',
    (t) async {
      final repo = _Repository()
        ..blocked = true
        ..pendingOverride = [
          {
            'reference_id': 'reference',
            'scheduled': 0,
            'requested': 2,
            'name': 'Plancha sin hueco',
            'reason': 'Revisa el tiempo total.',
          },
          {
            'status': 'needs_running_frequency',
            'name': 'Cobertura de carrera',
            'reason': 'Revisa los días disponibles.',
          },
        ];
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _prepare(t);
      expect(find.text('Antes de activar tu programa'), findsOneWidget);
      await _tap(t, 'Plancha sin hueco');
      expect(find.text('Tiempo para la sesión completa'), findsOneWidget);
      await _tap(t, 'Continuar con los movimientos');
      await _tap(t, 'Revisar mi plan');
      await _tap(t, 'Ver mis primeros entrenamientos');
      await _tap(t, 'Cobertura de carrera');
      expect(find.text('Tiempo para la sesión completa'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('el aviso de contexto de carrera abre su bloque específico', (
    t,
  ) async {
    final repo = _Repository()
      ..blocked = true
      ..hasRunning = true
      ..pendingOverride = [
        {
          'status': 'running_pending',
          'name': 'Carrera pendiente',
          'reason': 'Actualiza el cuestionario.',
        },
      ];
    await t.pumpWidget(
      MaterialApp(
        home: PreparationTrainingPage(
          goalId: 'goal',
          repository: repo,
          runningStepBuilder: (_, next, back) => Column(
            children: [
              const Text('Cuestionario de carrera'),
              TextButton(
                onPressed: next,
                child: const Text('Continuar con el programa'),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'Continuar con mi disponibilidad');
    await _tap(t, 'Continuar con carrera');
    await _tap(t, 'Continuar con el programa');
    await _tap(t, 'Revisar mi plan');
    await _tap(t, 'Ver mis primeros entrenamientos');
    await _tap(t, 'Carrera pendiente');
    expect(find.text('Cuestionario de carrera'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'guardar datos revisa una semana no empezada antes de sustituirla',
    (t) async {
      final repo = _Repository()
        ..published = true
        ..canReplacePending = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'Cambiar configuración');
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con los movimientos');
      await _tap(t, 'Revisar mi plan');
      await _tap(t, 'Guardar cambios');
      expect(repo.revisions, 1);
      expect(repo.publications, 0);
      expect(find.text('Sustituir las sesiones pendientes'), findsOneWidget);
      await _tap(t, 'Sustituir las sesiones pendientes');
      expect(repo.publications, 1);
      expect(repo.reviewed?['revision'], isNotNull);
      expect(find.text('Tu plan está en marcha'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'cambiar datos conserva una semana realizada y explica cuándo se aplican',
    (t) async {
      final repo = _Repository()..published = true;
      await t.pumpWidget(
        MaterialApp(
          home: PreparationTrainingPage(goalId: 'goal', repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'Cambiar configuración');
      await _tap(t, 'Continuar con mi disponibilidad');
      await _tap(t, 'Continuar con los movimientos');
      await _tap(t, 'Revisar mi plan');
      await _tap(t, 'Guardar cambios');
      expect(repo.savedTargetDate, isNotNull);
      expect(repo.revisions, 0);
      expect(repo.publications, 0);
      expect(
        find.textContaining('Datos guardados. Se aplicarán'),
        findsOneWidget,
      );
      expect(find.text('Reiniciar ensayos de este programa'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'reiniciar ensayos exige confirmación y conserva los datos para una propuesta nueva',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = _Repository()
        ..published = true
        ..canResetTrial = true;
      final originalDate = repo.data.targetDate;
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            home: PreparationTrainingPage(goalId: 'goal', repository: repo),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'Reiniciar ensayos de este programa');
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'REI');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(repo.resets, 0);
      await t.showKeyboard(find.byType(TextField));
      await _tap(t, 'Cancelar');
      expect(repo.resets, 0);
      expect(t.testTextInput.isVisible, isFalse);
      await _tap(t, 'Reiniciar ensayos de este programa');
      final button = find.widgetWithText(
        OutlinedButton,
        'Borrar ensayos y reiniciar',
      );
      expect(t.widget<OutlinedButton>(button).onPressed, isNull);
      await capturePerformanceWidget(t, 'programa-reiniciar-ensayos');
      await t.enterText(find.byType(TextField), 'REINICIAR');
      expect(t.testTextInput.isVisible, isTrue);
      t.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(TextField));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final fieldBottom = t.getBottomRight(find.byType(TextField)).dy;
      final cancelTop = t
          .getTopLeft(find.widgetWithText(FilledButton, 'Cancelar'))
          .dy;
      expect(fieldBottom, lessThan(cancelTop));
      await capturePerformanceWidget(t, 'programa-reiniciar-con-teclado');
      await _tap(t, 'Borrar ensayos y reiniciar');
      expect(t.testTextInput.isVisible, isFalse);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      expect(repo.resets, 1);
      expect(repo.publications, 0);
      expect(repo.data.context?['availability'], {'1': 60, '4': 60});
      expect(repo.data.targetDate!.difference(originalDate!).inSeconds, 0);
      expect(find.text('Activar mi plan'), findsOneWidget);
      expect(find.textContaining('Ensayos reiniciados.'), findsOneWidget);
      await _tap(t, 'Volver a los movimientos');
      expect(find.text('Lo que necesitas preparar'), findsOneWidget);
      expect(t.testTextInput.isVisible, isFalse);
      await capturePerformanceWidget(t, 'programa-movimientos-sin-teclado');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('plancha no pide RIR ni rellena una capacidad ficticia', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final data = _Repository().data;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformanceReferenceDialog(
            data: data,
            objective: const {
              'objective_key': 'legacy:abdominal_plank',
              'program_objective_key': 'legacy:abdominal_plank',
              'name': 'Plancha',
              'profile_code': 'front_plank_forearms',
              'profile_version': 1,
              'measurement': 'DURATION',
              'protocol_key': 'def_15_2026_plank',
              'protocol_version': 1,
              'parameters': {},
              'instructions': 'Cuerpo alineado; detener al perder la postura.',
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Repeticiones que te quedaban'), findsNothing);
    final fields = t.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.every((f) => f.controller?.text.isEmpty ?? true), isTrue);
    expect(t.takeException(), isNull);
  });
  for (final situation in ['open', 'closed', 'offline', 'still-open']) {
    testWidgets(
      'aviso de sesión $situation conserva la propuesta y vuelve al lugar correcto',
      (t) async {
        final repo = _Repository()
          ..blocked = true
          ..inProgressExecution = situation == 'closed'
              ? null
              : 'execution-other-goal'
          ..lookupFails = situation == 'offline'
          ..pendingOverride = [
            {
              'status': 'session_in_progress',
              'name': 'Entrenamiento en curso',
              'reason': 'Finaliza o abandona la sesión en curso antes de cambiar el programa.',
            },
          ];
        final router = GoRouter(
          initialLocation: '/plan/goal/goal/training',
          routes: [
            GoRoute(
              path: '/plan',
              builder: (_, _) => const Scaffold(body: Text('Mi plan')),
              routes: [
                GoRoute(
                  path: 'goal/:goal',
                  builder: (_, _) => const Scaffold(body: Text('Preparación')),
                  routes: [
                    GoRoute(
                      path: 'training',
                      builder: (_, _) => PreparationTrainingPage(
                        goalId: 'goal',
                        repository: repo,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'week',
                  builder: (_, _) => const Scaffold(body: Text('Mi semana')),
                  routes: [
                    GoRoute(
                      path: 'active/:execution',
                      builder: (context, state) => Scaffold(
                        body: Column(
                          children: [
                            Text(
                              'Ejecución: ${state.pathParameters['execution']}',
                            ),
                            TextButton(
                              onPressed: () {
                                if (situation != 'still-open') {
                                  repo.blocked = false;
                                  repo.pendingOverride = [];
                                  repo.inProgressExecution = null;
                                }
                                context.pop();
                              },
                              child: const Text('Resolver sesión y volver'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await t.pumpWidget(
          MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
        );
        await t.pumpAndSettle();
        await _prepare(t);
        if (situation == 'closed') {
          repo.blocked = false;
          repo.pendingOverride = [];
        }
        await _tap(t, 'Entrenamiento en curso');
        expect(repo.lookups, 1);
        if (situation == 'open' || situation == 'still-open') {
          expect(
            router.state.uri.path,
            '/plan/week/active/execution-other-goal',
          );
          expect(find.text('Ejecución: execution-other-goal'), findsOneWidget);
          await _tap(t, 'Resolver sesión y volver');
        } else if (situation == 'offline') {
          expect(router.state.uri.path, '/plan/goal/goal/training');
          expect(
            find.textContaining('No se ha podido consultar la sesión abierta'),
            findsOneWidget,
          );
          repo.lookupFails = false;
          await _tap(t, 'Entrenamiento en curso');
          await _tap(t, 'Resolver sesión y volver');
        }
        expect(router.state.uri.path, '/plan/goal/goal/training');
        expect(find.text('Paso 4 de 4 · Propuesta'), findsOneWidget);
        expect(
          find.text('Entrenamiento en curso'),
          situation == 'still-open' ? findsOneWidget : findsNothing,
        );
        expect(repo.publications, 0);
        expect(repo.savedContexts, 1);
        expect(repo.savedTargetDate, repo.initialTargetDate);
        final activate = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Activar mi plan'),
        );
        expect(
          activate.onPressed,
          situation == 'still-open' ? isNull : isNotNull,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}

class _SetupProgress implements PreparationSetupProgressStore {
  final steps = <String, PreparationSetupStep>{};
  @override
  Future<PreparationSetupStep?> read(String goalId) async => steps[goalId];
  @override
  Future<void> write(String goalId, PreparationSetupStep step) async =>
      steps[goalId] = step;
  @override
  Future<void> clear(String goalId) async => steps.remove(goalId);
}
