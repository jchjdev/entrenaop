import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';

class WatchCurrentUserUseCase {
  const WatchCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Stream<UserEntity?> call() => _repository.watchCurrentUser();
}
