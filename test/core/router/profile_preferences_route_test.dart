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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, GoTrueClient, User;
import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_forms_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_assessments_page.dart';

void main() {
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
    testWidgets('$route conserva datos y regresa a Perfil sin barra', (
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
      // Perfil y su tarea permanecen en el navegador raíz, sin pestaña propia.
      await tester.dragFrom(const Offset(2, 300), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsNothing);
      expect(preferences.saves, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Mi preparador abre desde Perfil como tarea y vuelve sin datos de otra identidad',
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
      await tester.scrollUntilVisible(find.text('Mi preparador'), 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mi preparador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi preparador'));
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
  @override
  Future<TrainingContextSettings> load() async {
    reads++;
    return TrainingContextSettings(
      context: TrainingContext(
        availability: {'1': 45, '3': 60},
        equipment: {'cones'},
        reportsPain: false,
        capacityConfirmed: true,
      ),
      equipmentOptions: {'cones', 'pull_up_bar'},
    );
  }

  @override
  Future<void> save(TrainingContext value) async {
    saves++;
  }
}
