import 'dart:async';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';

class AccountAuthFixture implements AuthRepository {
  final changes = StreamController<AuthSessionChange>.broadcast();
  final user = UserEntity(
    id: 'account-fixture',
    email: 'persona@example.com',
    role: 'user',
    createdAt: DateTime.utc(2026, 10, 8),
  );
  int resetCalls = 0, resendCalls = 0, updateCalls = 0, finishCalls = 0;
  String? lastEmail, lastPassword;
  bool failEmail = false, failUpdate = false, emailNotConfirmed = false;
  Completer<void>? pendingEmail, pendingUpdate;
  Completer<void>? pendingSignIn;
  AuthCubit cubit() => AuthCubit(
    signInUseCase: SignInUseCase(this),
    signUpUseCase: SignUpUseCase(this),
    signOutUseCase: SignOutUseCase(this),
    getCurrentUserUseCase: GetCurrentUserUseCase(this),
    watchCurrentUserUseCase: WatchCurrentUserUseCase(this),
    accountRepository: this,
  );
  @override
  Future<UserEntity?> getCurrentUser() async => user;
  @override
  Stream<AuthSessionChange> watchCurrentUser() => changes.stream;
  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    if (pendingSignIn != null) await pendingSignIn!.future;
    if (emailNotConfirmed) throw EmailConfirmationException(email);
    return user;
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async => SignUpConfirmationRequired(email);
  @override
  Future<void> signOut() async => changes.add(const AuthSessionChange(null));
  @override
  Future<void> requestPasswordReset(String email) async {
    resetCalls++;
    lastEmail = email;
    if (pendingEmail != null) await pendingEmail!.future;
    if (failEmail) {
      throw const ServerException('Sin conexión. Puedes reintentarlo.');
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    resendCalls++;
    await requestPasswordReset(email);
  }

  @override
  Future<void> updateRecoveredPassword(String password) async {
    updateCalls++;
    lastPassword = password;
    if (pendingUpdate != null) await pendingUpdate!.future;
    if (failUpdate) {
      throw const ServerException(
        'No se ha podido guardar. Puedes reintentarlo.',
      );
    }
  }

  @override
  Future<void> finishPasswordRecovery() async {
    finishCalls++;
    changes.add(const AuthSessionChange(null));
  }

  void recover({String id = 'account-fixture', bool updated = false}) =>
      changes.add(
        AuthSessionChange.recovery(
          userId: id,
          email: user.email,
          passwordUpdated: updated,
        ),
      );
}
