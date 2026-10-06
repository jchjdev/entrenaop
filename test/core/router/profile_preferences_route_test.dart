import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_context_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final route in ['/profile/preferences', '/plan/preferences']) {
    testWidgets('$route conserva datos y selecciona Perfil', (tester) async {
      final preferences = _Preferences();
      sl.registerSingleton<PreparationGoalRepository>(_Goals());
      sl.registerSingleton<ProfileBirthDateRepository>(_BirthDate());
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
            theme: EntrenaTheme.dark,
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
      expect(tester.takeException(), isNull);
    });
  }
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
