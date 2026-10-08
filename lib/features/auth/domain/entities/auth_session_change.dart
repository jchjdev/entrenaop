import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';

/// Una recuperación validada por Supabase tiene un recorrido distinto al acceso.
class AuthSessionChange {
  const AuthSessionChange(this.user)
    : recoveryUserId = null,
      recoveryEmail = null,
      passwordUpdated = false;

  const AuthSessionChange.recovery({
    required String userId,
    required String email,
    this.passwordUpdated = false,
  }) : user = null,
       recoveryUserId = userId,
       recoveryEmail = email;

  final UserEntity? user;
  final String? recoveryUserId;
  final String? recoveryEmail;
  final bool passwordUpdated;
}
