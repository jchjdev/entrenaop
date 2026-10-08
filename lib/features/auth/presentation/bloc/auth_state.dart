import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:equatable/equatable.dart';

class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  AuthAuthenticated({required this.user});
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthEmailConfirmationRequired extends AuthState {
  final String email;
  final bool isSending;
  final String? message;
  final bool hasError;
  final DateTime? retryAt;

  AuthEmailConfirmationRequired({
    required this.email,
    this.isSending = false,
    this.message,
    this.hasError = false,
    this.retryAt,
  });

  @override
  List<Object?> get props => [email, isSending, message, hasError, retryAt];
}

class AuthPasswordResetRequest extends AuthState {
  AuthPasswordResetRequest({
    required this.email,
    this.isSending = false,
    this.sent = false,
    this.message,
    this.retryAt,
  });
  final String email;
  final bool isSending;
  final bool sent;
  final String? message;
  final DateTime? retryAt;
  @override
  List<Object?> get props => [email, isSending, sent, message, retryAt];
}

class AuthPasswordRecovery extends AuthState {
  AuthPasswordRecovery({
    required this.userId,
    required this.email,
    this.isSaving = false,
    this.passwordUpdated = false,
    this.message,
  });
  final String userId;
  final String email;
  final bool isSaving;
  final bool passwordUpdated;
  final String? message;
  @override
  List<Object?> get props => [
    userId,
    email,
    isSaving,
    passwordUpdated,
    message,
  ];
}

class AuthLinkError extends AuthState {
  AuthLinkError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
