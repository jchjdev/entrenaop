import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_state.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'carga la semana natural y separa biblioteca de sesiones propias',
    () async {
      final scheduleRepository = _FakeScheduleRepository(items: [_scheduled()]);
      final workoutRepository = _FakeWorkoutRepository();
      final cubit = _cubit(scheduleRepository, workoutRepository);

      await cubit.load();

      expect(scheduleRepository.lastStart, DateTime(2026, 9, 21));
      expect(scheduleRepository.lastEnd, DateTime(2026, 9, 27));
      expect(cubit.state.status, WorkoutScheduleStatus.ready);
      expect(cubit.state.selectedItems, [_scheduled()]);
      expect(cubit.state.publicTemplates.single.id, 'public-1');
      expect(cubit.state.personalTemplates.single.id, 'personal-1');
      await cubit.close();
    },
  );

  test(
    'al programar recarga la agenda sin perder el día seleccionado',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final workoutRepository = _FakeWorkoutRepository();
      final cubit = _cubit(scheduleRepository, workoutRepository);
      await cubit.load();
      cubit.selectDay(DateTime(2026, 9, 24));

      final success = await cubit.schedule(workoutRepository.personal.single);

      expect(success, isTrue);
      expect(scheduleRepository.scheduledTemplateId, 'personal-1');
      expect(scheduleRepository.scheduledDate, DateTime(2026, 9, 24));
      expect(cubit.state.selectedDay, DateTime(2026, 9, 24));
      await cubit.close();
    },
  );

  test('abre la semana y el día solicitados desde Inicio', () {
    final cubit = WorkoutScheduleCubit(
      getSchedule: GetWorkoutScheduleUseCase(_FakeScheduleRepository()),
      scheduleWorkout: ScheduleWorkoutUseCase(_FakeScheduleRepository()),
      rescheduleWorkout: RescheduleWorkoutUseCase(_FakeScheduleRepository()),
      cancelWorkout: CancelScheduledWorkoutUseCase(_FakeScheduleRepository()),
      startWorkout: StartScheduledWorkoutUseCase(_FakeScheduleRepository()),
      getPublicWorkouts: GetPublicWorkoutsUseCase(_FakeWorkoutRepository()),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(_FakeWorkoutRepository()),
      initialDate: DateTime(2026, 10, 4),
      now: () => DateTime(2026, 9, 23),
    );
    addTearDown(cubit.close);

    expect(cubit.state.weekStart, DateTime(2026, 9, 28));
    expect(cubit.state.selectedDay, DateTime(2026, 10, 4));
  });
}

WorkoutScheduleCubit _cubit(
  WorkoutScheduleRepository scheduleRepository,
  WorkoutRepository workoutRepository,
) => WorkoutScheduleCubit(
  getSchedule: GetWorkoutScheduleUseCase(scheduleRepository),
  scheduleWorkout: ScheduleWorkoutUseCase(scheduleRepository),
  rescheduleWorkout: RescheduleWorkoutUseCase(scheduleRepository),
  cancelWorkout: CancelScheduledWorkoutUseCase(scheduleRepository),
  startWorkout: StartScheduledWorkoutUseCase(scheduleRepository),
  getPublicWorkouts: GetPublicWorkoutsUseCase(workoutRepository),
  getPersonalWorkouts: GetPersonalWorkoutsUseCase(workoutRepository),
  now: () => DateTime(2026, 9, 23, 18),
);

ScheduledWorkout _scheduled() => ScheduledWorkout(
  id: 'scheduled-1',
  templateId: 'public-1',
  templateName: 'Fuerza de tren superior',
  templateVersion: 1,
  scheduledDate: DateTime(2026, 9, 23),
  source: ScheduledWorkoutSource.library,
  status: ScheduledWorkoutStatus.planned,
);

class _FakeScheduleRepository implements WorkoutScheduleRepository {
  _FakeScheduleRepository({this.items = const []});

  final List<ScheduledWorkout> items;
  DateTime? lastStart;
  DateTime? lastEnd;
  String? scheduledTemplateId;
  DateTime? scheduledDate;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async {
    lastStart = start;
    lastEnd = end;
    return items;
  }

  @override
  Future<String> schedule(
    String templateId,
    DateTime date, {
    String? time,
  }) async {
    scheduledTemplateId = templateId;
    scheduledDate = date;
    return 'scheduled-2';
  }

  @override
  Future<void> cancel(String scheduledId) async {}

  @override
  Future<void> reschedule(
    String scheduledId,
    DateTime date, {
    String? time,
  }) async {}

  @override
  Future<String> start(String scheduledId) async => 'execution-1';
}

class _FakeWorkoutRepository implements WorkoutRepository {
  final public = const [
    WorkoutTemplateSummary(
      id: 'public-1',
      name: 'Fuerza de tren superior',
      description: null,
      estimatedDurationMinutes: 35,
      origin: WorkoutTemplateOrigin.system,
      version: 1,
    ),
  ];
  final personal = const [
    WorkoutTemplateSummary(
      id: 'personal-1',
      name: 'Mi sesión de dominadas',
      description: null,
      estimatedDurationMinutes: 25,
      origin: WorkoutTemplateOrigin.user,
      version: 2,
    ),
  ];

  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => public;

  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => personal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
