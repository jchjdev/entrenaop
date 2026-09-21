import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource_impl.dart';
import 'package:entrenaop/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource_impl.dart';
import 'package:entrenaop/features/exercises/data/repositories/exercise_repository_impl.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/delete_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_by_muscle_group_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercises_cubit.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/data/datasources/physical_assessment_remote_datasource.dart';
import 'package:entrenaop/features/physical_assessment/data/datasources/physical_assessment_remote_datasource_impl.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/physical_assessment_repository_impl.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/preparation_goal/data/datasources/preparation_goal_remote_datasource.dart';
import 'package:entrenaop/features/preparation_goal/data/datasources/preparation_goal_remote_datasource_impl.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/preparation_goal_repository_impl.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/training_plan/data/datasources/training_preferences_remote_datasource.dart';
import 'package:entrenaop/features/training_plan/data/datasources/training_preferences_remote_datasource_impl.dart';
import 'package:entrenaop/features/training_plan/data/repositories/training_preferences_repository_impl.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource_impl.dart';
import 'package:entrenaop/features/workout_schedule/data/repositories/workout_schedule_repository_impl.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource_impl.dart';
import 'package:entrenaop/features/workouts/data/repositories/workout_repository_impl.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_timer_store.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_mutation_queue.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_mutation_queue.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  sl.registerLazySingleton(() => Supabase.instance.client);
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<WorkoutTimerStore>(
    () => SharedPreferencesWorkoutTimerStore(sharedPreferences),
  );
  sl.registerLazySingleton<WorkoutCueService>(
    () => SharedPreferencesWorkoutCueService(sharedPreferences),
  );
  sl.registerLazySingleton<WorkoutMutationQueue>(
    () => SharedPreferencesWorkoutMutationQueue(sharedPreferences),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(supabaseClient: sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => WatchCurrentUserUseCase(sl()));

  sl.registerFactory(
    () => AuthCubit(
      signInUseCase: sl(),
      signUpUseCase: sl(),
      signOutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      watchCurrentUserUseCase: sl(),
    )..watchAuthState(),
  );

  // --- Exercises ---

  // El datasource habla con Supabase — recibe el cliente ya registrado
  sl.registerLazySingleton<ExerciseRemoteDataSource>(
    () => ExerciseRemoteDataSourceImpl(supabaseClient: sl()),
  );

  // El repositorio recibe el datasource
  sl.registerLazySingleton<ExerciseRepository>(
    () => ExerciseRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases — cada uno recibe el repositorio
  sl.registerLazySingleton(() => GetExercisesUseCase(sl()));
  sl.registerLazySingleton(() => GetExercisesByMuscleGroupUseCase(sl()));
  sl.registerLazySingleton(() => GetExerciseByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateExerciseUseCase(sl()));
  sl.registerLazySingleton(() => UpdateExerciseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteExerciseUseCase(sl()));

  // El cubit se registra como Factory — nueva instancia cada vez que se necesita
  sl.registerFactory(
    () => ExercisesCubit(
      getExercisesUseCase: sl(),
      getExercisesByMuscleGroupUseCase: sl(),
    ),
  );

  // --- Physical assessment ---

  sl.registerLazySingleton(() => const AssessmentEvaluator());
  sl.registerLazySingleton(() => const AssessmentProgressCalculator());
  sl.registerLazySingleton(() => EvaluateInitialAssessmentUseCase(sl()));
  sl.registerLazySingleton<PhysicalAssessmentRemoteDataSource>(
    () => PhysicalAssessmentRemoteDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<PhysicalAssessmentRepository>(
    () => PhysicalAssessmentRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => SavePhysicalAssessmentUseCase(sl()));
  sl.registerLazySingleton(() => GetPhysicalAssessmentHistoryUseCase(sl()));
  sl.registerFactory(
    () => PhysicalAssessmentCubit(
      evaluateInitialAssessment: sl(),
      savePhysicalAssessment: sl(),
    ),
  );
  sl.registerFactory(
    () => PhysicalAssessmentHistoryCubit(
      getHistory: sl(),
      progressCalculator: sl(),
    )..load(),
  );

  // --- Training preferences ---

  sl.registerLazySingleton<TrainingPreferencesRemoteDataSource>(
    () => TrainingPreferencesRemoteDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<TrainingPreferencesRepository>(
    () => TrainingPreferencesRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerFactory(() => TrainingPreferencesCubit(repository: sl())..load());

  // --- Preparation goal ---

  sl.registerLazySingleton<PreparationGoalRemoteDataSource>(
    () => PreparationGoalRemoteDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<PreparationGoalRepository>(
    () => PreparationGoalRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerFactory(() => PreparationGoalCubit(repository: sl())..load());

  // --- Workout templates ---

  sl.registerLazySingleton<WorkoutRemoteDataSource>(
    () => WorkoutRemoteDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<WorkoutRepository>(
    () => WorkoutRepositoryImpl(remoteDataSource: sl(), mutationQueue: sl()),
  );
  sl.registerLazySingleton(() => GetWorkoutTemplateUseCase(sl()));
  sl.registerLazySingleton(() => GetPublicWorkoutsUseCase(sl()));
  sl.registerLazySingleton(() => GetPersonalWorkoutsUseCase(sl()));
  sl.registerLazySingleton(() => CreatePersonalWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => RevisePersonalWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => DuplicatePersonalWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => ArchivePersonalWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => StartWorkoutExecutionUseCase(sl()));
  sl.registerLazySingleton(() => GetWorkoutExecutionUseCase(sl()));
  sl.registerLazySingleton(() => GetWorkoutHistoryUseCase(sl()));
  sl.registerLazySingleton(() => CompleteWorkoutSetUseCase(sl()));
  sl.registerLazySingleton(() => CompleteAmrapBlockUseCase(sl()));
  sl.registerLazySingleton(() => CorrectWorkoutSetUseCase(sl()));
  sl.registerLazySingleton(() => SkipWorkoutSetUseCase(sl()));
  sl.registerLazySingleton(() => FinishWorkoutExecutionUseCase(sl()));
  sl.registerLazySingleton(() => AbandonWorkoutExecutionUseCase(sl()));
  sl.registerLazySingleton(() => GetPendingWorkoutMutationCountUseCase(sl()));
  sl.registerFactoryParam<WorkoutPreviewCubit, String, void>(
    (templateId, _) => WorkoutPreviewCubit(
      templateId: templateId,
      getWorkoutTemplate: sl(),
      startExecution: sl(),
    )..load(),
  );
  sl.registerFactory(
    () => WorkoutLibraryCubit(
      getPublicWorkouts: sl(),
      getPersonalWorkouts: sl(),
      duplicatePersonalWorkout: sl(),
      archivePersonalWorkout: sl(),
    )..load(),
  );
  sl.registerFactoryParam<WorkoutEditorCubit, String, void>(
    (templateId, _) => WorkoutEditorCubit(
      getExercises: sl(),
      createExercise: sl(),
      createWorkout: sl(),
      getWorkoutTemplate: sl(),
      reviseWorkout: sl(),
      templateId: templateId.isEmpty ? null : templateId,
    )..load(),
  );
  sl.registerFactoryParam<ActiveWorkoutCubit, String, void>(
    (executionId, _) => ActiveWorkoutCubit(
      executionId: executionId,
      getExecution: sl(),
      completeSet: sl(),
      completeAmrap: sl(),
      skipSet: sl(),
      finishExecution: sl(),
      abandonExecution: sl(),
      getPendingMutationCount: sl(),
      timerStore: sl(),
      cueService: sl(),
    )..load(),
  );
  sl.registerFactory(() => WorkoutHistoryCubit(getHistory: sl())..load());
  sl.registerFactoryParam<WorkoutHistoryDetailCubit, String, void>(
    (executionId, _) => WorkoutHistoryDetailCubit(
      executionId: executionId,
      getExecution: sl(),
      correctSet: sl(),
    )..load(),
  );

  // --- Weekly workout schedule ---

  sl.registerLazySingleton<WorkoutScheduleRemoteDataSource>(
    () => WorkoutScheduleRemoteDataSourceImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<WorkoutScheduleRepository>(
    () => WorkoutScheduleRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetWorkoutScheduleUseCase(sl()));
  sl.registerLazySingleton(() => ScheduleWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => RescheduleWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => CancelScheduledWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => StartScheduledWorkoutUseCase(sl()));
  sl.registerFactory(
    () => WorkoutScheduleCubit(
      getSchedule: sl(),
      scheduleWorkout: sl(),
      rescheduleWorkout: sl(),
      cancelWorkout: sl(),
      startWorkout: sl(),
      getPublicWorkouts: sl(),
      getPersonalWorkouts: sl(),
    )..load(),
  );

  // --- Dashboard ---

  sl.registerLazySingleton(
    () => GetPreparationOverviewUseCase(
      assessmentRepository: sl(),
      preferencesRepository: sl(),
      goalRepository: sl(),
    ),
  );
  sl.registerFactory(() => DashboardCubit(getOverview: sl())..load());
}
