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
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  sl.registerLazySingleton(() => Supabase.instance.client);

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
