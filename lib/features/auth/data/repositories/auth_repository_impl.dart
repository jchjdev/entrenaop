import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
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
  Stream<UserEntity?> watchCurrentUser() {
    return remoteDataSource.watchCurrentUser();
  }
}
