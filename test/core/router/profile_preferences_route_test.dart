import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/navigation/app_back_gesture.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_context_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/profile_photo/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, GoTrueClient, User;
import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_forms_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_assessments_page.dart';
import 'package:entrenaop/features/device_connections/presentation/device_connections_page.dart';
import 'package:entrenaop/features/device_connections/presentation/garmin_connection_page.dart';

import '../../support/pro_access_fixture.dart';

void main() {
  setUp(() => sl.registerSingleton<ProfilePhotoRepository>(_PhotoFixture()));
  testWidgets(
    'Disponibilidad conserva borrador, guarda y vuelve a Entrenar con fecha y cara',
    (tester) async {
      final preferences = _Preferences();
      sl.registerSingleton<TrainingContextRepository>(preferences);
      sl.registerSingleton<ProfileBirthDateRepository>(_BirthDate());
      sl.registerSingleton<ProfileNameRepository>(
        ProfileNameRepository(_ClientWithoutSession()),
      );
      sl.registerSingleton<ProAccessRepository>(ProAccessFixture(isPro: true));
      sl.registerFactory<DashboardCubit>(
        () => DashboardCubit(getOverview: _Overview(preferences))..load(),
      );
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/plan?tab=availability&date=2026-11-05');
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router.config,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(TrainingHubPage));
      await tester.ensureVisible(find.text('Editar disponibilidad y material'));
      await tester.tap(find.text('Editar disponibilidad y material'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/preferences');
      expect(find.byType(NavigationBar), findsNothing);
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Martes'));
      await tester.tap(find.widgetWithText(FilterChip, 'Martes'));
      await tester.pumpAndSettle();
      router.config.pop();
      await tester.pumpAndSettle();
      expect(find.text('Continuar'), findsOneWidget);
      expect(preferences.saves, 0);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/preferences');
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Martes'))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(
        find.text('Guardar disponibilidad y material'),
      );
      await tester.tap(find.text('Guardar disponibilidad y material'));
      await tester.pumpAndSettle();
      expect(preferences.saves, 1);
      expect(preferences.saved.availability['2'], 45);
      router.config.pop();
      await tester.pumpAndSettle();
      expect(
        router.config.state.uri.toString(),
        '/plan?tab=availability&date=2026-11-05',
      );
      expect(tester.state(find.byType(TrainingHubPage)), same(original));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.text('Editar disponibilidad y material'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Perfil agrupa conexiones y volver de Garmin conserva la pantalla común',
    (tester) async {
      sl.registerSingleton<SupabaseClient>(_ClientWithoutSession());
      sl.registerSingleton<PreparationGoalRepository>(_Goals());
      sl.registerSingleton<ProfileBirthDateRepository>(_BirthDate());
      sl.registerSingleton<ProfileNameRepository>(
        ProfileNameRepository(_ClientWithoutSession()),
      );
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/profile');
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router.config,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Carreras de Salud'), findsNothing);
      expect(find.text('Conexión con Garmin'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Dispositivos y conexiones'),
        300,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dispositivos y conexiones'));
      await tester.tap(find.text('Dispositivos y conexiones'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/connections');
      expect(find.byType(DeviceConnectionsPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.ensureVisible(find.text('Gestionar Garmin'));
      await tester.tap(find.text('Gestionar Garmin'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/garmin');
      expect(find.byType(GarminConnectionPage), findsOneWidget);
      router.config.pop();
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/connections');
      router.config.pop();
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile');
      expect(tester.takeException(), isNull);
    },
  );
  for (final route in [
    '/my-trainer/forms',
    '/my-trainer/forms/assignment',
    '/my-trainer/assessments',
    '/my-trainer/assessments/delivery',
  ]) {
    testWidgets(
      '$route exige coincidencia de identidad y no muestra datos de otra cuenta',
      (tester) async {
        sl.registerSingleton<SupabaseClient>(_ClientWithoutSession());
        addTearDown(sl.reset);
        final auth = _Auth();
        final router = AppRouter(auth);
        addTearDown(router.dispose);
        router.config.go(route);
        await tester.pumpWidget(
          BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp.router(
              theme: EntrenaTheme.dark,
              routerConfig: router.config,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(router.config.state.uri.path, route);
        expect(
          find.textContaining('No se ha podido confirmar'),
          findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsNothing);
        expect(
          find.byType(
            route.contains('/assessments')
                ? (route.endsWith('delivery')
                      ? TrainerStudentAssessmentPage
                      : TrainerStudentAssessmentsPage)
                : (route.endsWith('assignment')
                      ? TrainerStudentFormPage
                      : TrainerStudentFormsPage),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final route in ['/profile/preferences', '/plan/preferences']) {
    testWidgets('$route conserva datos y regresa a la pestaña Perfil', (
      tester,
    ) async {
      final preferences = _Preferences();
      sl.registerSingleton<PreparationGoalRepository>(_Goals());
      sl.registerSingleton<ProfileBirthDateRepository>(_BirthDate());
      sl.registerSingleton<ProfileNameRepository>(
        ProfileNameRepository(_ClientWithoutSession()),
      );
      sl.registerSingleton<TrainingContextRepository>(preferences);
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go(route);
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp.router(
            theme: withAppBackGesture(
              EntrenaTheme.dark.copyWith(platform: TargetPlatform.iOS),
            ),
            routerConfig: router.config,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.config.routeInformationProvider.value.uri.path,
        '/profile/preferences',
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Disponibilidad y material'), findsOneWidget);
      expect(find.text('El mismo contexto para tu programa'), findsOneWidget);
      expect(preferences.saves, 0);
      expect(preferences.reads, 1);
      // El editor sigue siendo una tarea raíz; volver recupera la pestaña Perfil.
      await tester.dragFrom(const Offset(2, 300), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(preferences.saves, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'el enlace heredado al vínculo conserva la tarea y vuelve a Perfil',
    (tester) async {
      final client = _ClientWithoutSession();
      sl.registerSingleton<SupabaseClient>(client);
      sl.registerSingleton<PreparationGoalRepository>(_Goals());
      sl.registerSingleton<ProfileBirthDateRepository>(_BirthDate());
      sl.registerSingleton<ProfileNameRepository>(
        ProfileNameRepository(_ClientWithoutSession()),
      );
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/profile/trainer');
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router.config,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile/trainer');
      expect(find.byType(MyTrainerPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // El cliente simulado carece de la sesión de route-user: falla cerrado.
      expect(find.textContaining('No se ha podido confirmar'), findsOneWidget);
      router.config.pop();
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile');
    },
  );
}

class _PhotoFixture implements ProfilePhotoRepository {
  @override
  String get ownerId => 'route-user';
  @override
  Future<ProfilePhotoState> own() async =>
      const ProfilePhotoState(path: null, revision: 0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ClientWithoutSession extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => _EmptyAuth();
}

class _EmptyAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

class _Auth implements AuthCubit {
  @override
  AuthState get state => AuthAuthenticated(
    user: UserEntity(
      id: 'route-user',
      email: 'route@example.test',
      role: 'free',
      createdAt: DateTime(2026),
    ),
  );
  @override
  Stream<AuthState> get stream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Goals implements PreparationGoalRepository {
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BirthDate implements ProfileBirthDateRepository {
  @override
  Future<DateTime?> get() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements TrainingContextRepository {
  int saves = 0;
  int reads = 0;
  TrainingContext saved = TrainingContext(
    availability: {'1': 45, '3': 60},
    equipment: {'cones'},
    reportsPain: false,
    capacityConfirmed: true,
  );
  @override
  Future<TrainingContextSettings> load() async {
    reads++;
    return TrainingContextSettings(
      context: saved,
      equipmentOptions: {'cones', 'pull_up_bar'},
    );
  }

  @override
  Future<void> save(TrainingContext value) async {
    saves++;
    saved = value;
  }
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.preferences);
  final _Preferences preferences;
  @override
  Future<PreparationOverview> call() async => PreparationOverview(
    assessments: const [],
    preferences: null,
    goals: const [],
    weekStart: DateTime(2026, 11, 2),
    weeklyWorkouts: const [],
    trainingContext: preferences.saved,
  );
}
