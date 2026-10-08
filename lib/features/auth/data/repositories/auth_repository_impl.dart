import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.signIn(email: email, password: password);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final user = await remoteDataSource.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    return user == null
        ? SignUpConfirmationRequired(email)
        : SignUpAuthenticated(user);
  }

  @override
  Future<void> signOut() async {
    return await remoteDataSource.signOut();
  }

  @override
  Stream<AuthSessionChange> watchCurrentUser() {
    return remoteDataSource.watchCurrentUser();
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      remoteDataSource.requestPasswordReset(email);

  @override
  Future<void> resendConfirmation(String email) =>
      remoteDataSource.resendConfirmation(email);

  @override
  Future<void> updateRecoveredPassword(String password) =>
      remoteDataSource.updateRecoveredPassword(password);

  @override
  Future<void> finishPasswordRecovery() =>
      remoteDataSource.finishPasswordRecovery();
}
