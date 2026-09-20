import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  Future<SignUpOutcome> call({
    required String email,
    required String password,
    required String fullName,
  }) {
    return repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
  }
}
