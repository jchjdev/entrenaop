import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';

abstract class AuthRepository {
  Future<UserEntity> signIn({required String email, required String password});

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut();

  Future<UserEntity?> getCurrentUser();
}
