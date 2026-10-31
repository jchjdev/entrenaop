// Planificaciones ficticias para mostrar los formatos reales de EntrenaOP.
// No son recomendaciones de entrenamiento ni un programa comercial.
import 'package:workout_core/workout_template.dart';

final demoRecipes = <WorkoutTemplate>[
  WorkoutTemplate(
    id: 'upper',
    name: 'Fuerza · Tren superior',
    description: 'Control, técnica y fuerza. Trabajo de tren superior con superseries y core.',
    estimatedDurationMinutes: 45,
    version: 2,
    blocks: [
      _block(
        'activation',
        'Activación y movilidad',
        WorkoutBlockFormat.warmUp,
        [
          _exercise(
            'mobility',
            'Movilidad de hombros y activación',
            seconds: 300,
          ),
        ],
      ),
      _block(
        'upper',
        'Tirón + empuje',
        WorkoutBlockFormat.superset,
        [
          _exercise('pull', 'Dominadas', reps: 8, rir: 2),
          _exercise('push', 'Flexiones', reps: 12, rir: 2),
        ],
        rounds: 3,
        rest: 90,
      ),
      _block('core', 'Core y estabilidad', WorkoutBlockFormat.straightSets, [
        _exercise('plank', 'Plancha isométrica', seconds: 45, sets: 3),
      ]),
      _block('cool', 'Vuelta a la calma', WorkoutBlockFormat.coolDown, [
        _exercise('stretch', 'Movilidad suave', seconds: 180),
      ]),
    ],
  ),
  WorkoutTemplate(
    id: 'intervals',
    name: 'Carrera · Series 6 × 400',
    description: 'Calentamiento, series con ritmo objetivo y recuperación entre esfuerzos.',
    estimatedDurationMinutes: 38,
    version: 3,
    blocks: [
      _block(
        'warm-run',
        'Calentamiento · 10 minutos',
        WorkoutBlockFormat.warmUp,
        [
          _run(
            'warm-run',
            seconds: 600,
            pace: 330,
            kind: RunningStepKind.warmup,
          ),
        ],
      ),
      _block(
        'intervals',
        'Bloque principal · 6 × 400 m',
        WorkoutBlockFormat.running,
        [_run('intervals', meters: 400, sets: 6, pace: 245, recovery: 90)],
      ),
      _block(
        'cool-run',
        'Vuelta a la calma · 5 minutos',
        WorkoutBlockFormat.coolDown,
        [
          _run(
            'cool-run',
            seconds: 300,
            pace: 350,
            kind: RunningStepKind.cooldown,
          ),
        ],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'circuit',
    name: 'Fuerza · Circuito completo',
    description: 'Una sesión completa de fuerza y rendimiento. Calidad de movimiento en cada ronda.',
    estimatedDurationMinutes: 40,
    version: 2,
    blocks: [
      _block(
        'warm-circuit',
        'Preparación del movimiento',
        WorkoutBlockFormat.warmUp,
        [_exercise('mobility', 'Movilidad y activación', seconds: 300)],
      ),
      _block(
        'circuit',
        'Circuito de fuerza · 3 rondas',
        WorkoutBlockFormat.circuit,
        [
          _exercise('pull', 'Dominadas', reps: 6, rir: 2),
          _exercise('lunge', 'Zancadas', reps: 12, rir: 2),
          _exercise('push', 'Flexiones', reps: 12, rir: 2),
        ],
        rounds: 3,
        rest: 90,
      ),
      _block(
        'isometric',
        'Estabilidad del core',
        WorkoutBlockFormat.straightSets,
        [_exercise('plank', 'Plancha isométrica', seconds: 45, sets: 3)],
      ),
    ],
  ),
  WorkoutTemplate(
    id: 'progressive',
    name: 'Carrera · Rodaje progresivo',
    description:
        'Encuentra tu ritmo. Tres tramos progresivos con un objetivo claro.',
    estimatedDurationMinutes: 35,
    version: 1,
    blocks: [
      _block('warm-progressive', 'Entrada suave', WorkoutBlockFormat.warmUp, [
        _run(
          'warm-progressive',
          seconds: 300,
          pace: 350,
          kind: RunningStepKind.warmup,
        ),
      ]),
      _block(
        'progressive',
        'Progresivo · 3 kilómetros',
        WorkoutBlockFormat.running,
        [
          for (var i = 0; i < 3; i++)
            _run('progressive-$i', meters: 1000, pace: 320 - i * 15),
        ],
      ),
      _block(
        'cool-progressive',
        'Soltar y recuperar',
        WorkoutBlockFormat.coolDown,
        [
          _run(
            'cool-progressive',
            seconds: 300,
            pace: 360,
            kind: RunningStepKind.cooldown,
          ),
        ],
      ),
    ],
  ),
];

WorkoutBlock _block(
  String id,
  String name,
  WorkoutBlockFormat format,
  List<WorkoutItem> items, {
  int rounds = 1,
  int rest = 0,
}) => WorkoutBlock(
  id: id,
  name: name,
  format: format,
  rounds: rounds,
  restAfterSeconds: rest,
  items: items,
);
WorkoutItem _exercise(
  String id,
  String name, {
  int? reps,
  int? seconds,
  int sets = 1,
  double? rir,
}) => WorkoutItem(
  id: id,
  exerciseId: id,
  exerciseName: name,
  sets: [
    for (var i = 0; i < sets; i++)
      WorkoutSet(
        id: '$id-$i',
        order: i,
        targetReps: reps,
        targetDurationSeconds: seconds,
        targetRir: rir,
        restAfterSeconds: 60,
      ),
  ],
);
WorkoutItem _run(
  String id, {
  double? meters,
  int? seconds,
  int sets = 1,
  required int pace,
  int recovery = 0,
  RunningStepKind kind = RunningStepKind.run,
}) => WorkoutItem(
  id: id,
  exerciseId: runningExerciseId,
  exerciseName: 'Carrera',
  sets: [
    for (var i = 0; i < sets; i++)
      WorkoutSet(
        id: '$id-$i',
        order: i,
        targetDistanceMeters: meters,
        targetDurationSeconds: seconds,
        runningStep: RunningStepMetadata(
          kind: kind,
          completion: meters == null
              ? RunningStepCompletion.time
              : RunningStepCompletion.distance,
        ),
        targetPaceMinSecondsPerKm: pace - 5,
        targetPaceMaxSecondsPerKm: pace + 5,
        recoveryType: recovery > 0 ? RunningRecoveryType.walking : null,
        recoveryDurationSeconds: recovery > 0 ? recovery : null,
        restAfterSeconds: recovery,
      ),
  ],
);
