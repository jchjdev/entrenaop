import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final user = UserEntity(
    id: 'user-id',
    email: 'opositor@example.com',
    role: 'free',
    createdAt: DateTime.utc(2026, 9, 19),
  );

  group('AuthCubit.checkCurrentUser', () {
    test('restaura un usuario existente', () async {
      final repository = _FakeAuthRepository(currentUser: user);
      final cubit = _createCubit(repository);
      final statesExpectation = expectLater(
        cubit.stream,
        emitsInOrder([AuthLoading(), AuthAuthenticated(user: user)]),
      );

      await cubit.checkCurrentUser();
      await statesExpectation;

      await cubit.close();
    });

    test('queda sin autenticar cuando no existe una sesión', () async {
      final repository = _FakeAuthRepository();
      final cubit = _createCubit(repository);
      final statesExpectation = expectLater(
        cubit.stream,
        emitsInOrder([AuthLoading(), AuthUnauthenticated()]),
      );

      await cubit.checkCurrentUser();
      await statesExpectation;

      await cubit.close();
    });
  });

  group('AuthCubit.signUp', () {
    test('autentica cuando Supabase crea una sesión', () async {
      final repository = _FakeAuthRepository(
        signUpOutcome: SignUpAuthenticated(user),
      );
      final cubit = _createCubit(repository);
      final statesExpectation = expectLater(
        cubit.stream,
        emitsInOrder([AuthLoading(), AuthAuthenticated(user: user)]),
      );

      await cubit.signUp(
        email: user.email,
        password: 'una-clave-segura',
        fullName: 'Opositor',
      );
      await statesExpectation;

      await cubit.close();
    });

    test('pide confirmar el correo cuando todavía no hay sesión', () async {
      final repository = _FakeAuthRepository(
        signUpOutcome: SignUpConfirmationRequired(user.email),
      );
      final cubit = _createCubit(repository);
      final statesExpectation = expectLater(
        cubit.stream,
        emitsInOrder([
          AuthLoading(),
          AuthEmailConfirmationRequired(email: user.email),
        ]),
      );

      await cubit.signUp(
        email: user.email,
        password: 'una-clave-segura',
        fullName: 'Opositor',
      );
      await statesExpectation;

      await cubit.close();
    });
  });
}

AuthCubit _createCubit(AuthRepository repository) {
  return AuthCubit(
    signInUseCase: SignInUseCase(repository),
    signUpUseCase: SignUpUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
  );
}

class _FakeAuthRepository implements AuthRepository {
  final UserEntity? currentUser;
  final SignUpOutcome? signUpOutcome;

  _FakeAuthRepository({this.currentUser, this.signUpOutcome});

  @override
  Future<UserEntity?> getCurrentUser() async => currentUser;

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return signUpOutcome ?? (throw UnimplementedError());
  }

  @override
  Future<void> signOut() async {}
}
