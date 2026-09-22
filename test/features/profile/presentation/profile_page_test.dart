import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'muestra identidad y preparaciones reales sin plan comercial ficticio',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authRepository = _AuthRepository();
      final authCubit = AuthCubit(
        signInUseCase: SignInUseCase(authRepository),
        signUpUseCase: SignUpUseCase(authRepository),
        signOutUseCase: SignOutUseCase(authRepository),
        getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
        watchCurrentUserUseCase: WatchCurrentUserUseCase(authRepository),
      );
      await authCubit.checkCurrentUser();
      addTearDown(authCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BlocProvider.value(
            value: authCubit,
            child: ProfilePage(preparations: _PreparationRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Javier'), findsOneWidget);
      expect(find.text('javier@example.com'), findsOneWidget);
      expect(find.text('Ingreso · Tropa y marinería'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _AuthRepository implements AuthRepository {
  @override
  Future<UserEntity?> getCurrentUser() async => UserEntity(
    id: 'user-1',
    fullName: 'Javier',
    email: 'javier@example.com',
    role: 'user',
    createdAt: DateTime(2026, 9),
  );

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Stream<UserEntity?> watchCurrentUser() => const Stream.empty();
}

class _PreparationRepository implements PreparationGoalRepository {
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [
    const PreparationGoal(
      id: 'goal-1',
      program: PreparationProgram(
        id: PreparationProgramIds.armedForcesTroopEntry,
        name: 'Ingreso · Tropa y marinería',
        kind: PreparationProgramKind.access,
      ),
    ),
  ];

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() =>
      throw UnimplementedError();

  @override
  Future<PreparationGoal> save(PreparationGoal goal) =>
      throw UnimplementedError();

  @override
  Future<void> archive(String goalId) => throw UnimplementedError();
}
