import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:equatable/equatable.dart';

sealed class SignUpOutcome extends Equatable {
  const SignUpOutcome();
}

class SignUpAuthenticated extends SignUpOutcome {
  final UserEntity user;

  const SignUpAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class SignUpConfirmationRequired extends SignUpOutcome {
  final String email;

  const SignUpConfirmationRequired(this.email);

  @override
  List<Object?> get props => [email];
}
