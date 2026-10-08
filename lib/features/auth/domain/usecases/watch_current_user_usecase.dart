import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';

class WatchCurrentUserUseCase {
  const WatchCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Stream<AuthSessionChange> call() => _repository.watchCurrentUser();
}
