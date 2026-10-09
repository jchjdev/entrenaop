import 'dart:async';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/repositories/auth_repository.dart';

class AuthCubit extends Cubit<AuthState> {
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final WatchCurrentUserUseCase watchCurrentUserUseCase;
  StreamSubscription<AuthSessionChange>? _sessionSubscription;
  final AuthRepository? accountRepository;
  DateTime? _emailRetryAt;
  int _emailRequest = 0;
  int _sessionGeneration = 0;

  AuthCubit({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.watchCurrentUserUseCase,
    this.accountRepository,
  }) : super(AuthInitial());

  void watchAuthState() {
    _sessionSubscription ??= watchCurrentUserUseCase().listen(
      (change) {
        if (isClosed) return;
        _sessionGeneration++;
        if (change.recoveryUserId case final userId?) {
          final current = state;
          // Una renovación no reemplaza el guardado ni su confirmación visible.
          if (current is AuthPasswordRecovery && current.userId == userId) {
            return;
          }
          _emailRequest++;
          emit(
            AuthPasswordRecovery(
              userId: userId,
              email: change.recoveryEmail ?? '',
              passwordUpdated: change.passwordUpdated,
            ),
          );
          return;
        }
        final user = change.user;
        _emailRequest++;
        emit(
          user == null ? AuthUnauthenticated() : AuthAuthenticated(user: user),
        );
      },
      onError: (Object error) {
        if (isClosed) return;
        if (state is AuthAuthenticated) return;
        if (error is AuthLinkException) {
          emit(AuthLinkError(message: error.message));
          return;
        }
        emit(
          AuthError(
            message: error is ServerException
                ? error.message
                : _accountError(error),
          ),
        );
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state is AuthLoading || state is AuthPasswordRecovery) return;
    emit(AuthLoading());
    final generation = ++_sessionGeneration;
    try {
      final user = await signInUseCase(email: email, password: password);
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      if (e is EmailConfirmationException) {
        emit(AuthEmailConfirmationRequired(email: e.email));
        return;
      }
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: _accountError(e)));
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (state is AuthLoading || state is AuthPasswordRecovery) return;
    emit(AuthLoading());
    final generation = ++_sessionGeneration;
    try {
      final outcome = await signUpUseCase(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      switch (outcome) {
        case SignUpAuthenticated(:final user):
          emit(AuthAuthenticated(user: user));
        case SignUpConfirmationRequired(:final email):
          emit(AuthEmailConfirmationRequired(email: email));
      }
    } catch (e) {
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: _accountError(e)));
      }
    }
  }

  Future<void> signOut() async {
    if (state is AuthPasswordRecovery) return finishPasswordRecovery();
    emit(AuthLoading());
    final generation = ++_sessionGeneration;
    try {
      await signOutUseCase();
      if (isClosed || generation != _sessionGeneration) return;
      emit(AuthUnauthenticated());
    } catch (e) {
      if (isClosed || generation != _sessionGeneration) return;
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: _accountError(e)));
      }
    }
  }

  Future<void> checkCurrentUser() async {
    if (state is AuthPasswordRecovery) return;
    emit(AuthLoading());
    final generation = ++_sessionGeneration;
    try {
      final user = await getCurrentUserUseCase();
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (isClosed ||
          generation != _sessionGeneration ||
          state is AuthPasswordRecovery) {
        return;
      }
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: _accountError(e)));
      }
    }
  }

  void dismissAccountNotice() {
    _emailRequest++;
    if (state is AuthEmailConfirmationRequired ||
        state is AuthPasswordResetRequest ||
        state is AuthLinkError ||
        state is AuthError) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> requestPasswordReset(String email) async {
    if (state is AuthPasswordResetRequest &&
        (state as AuthPasswordResetRequest).isSending) {
      return;
    }
    if (_emailRetryAt != null && DateTime.now().isBefore(_emailRetryAt!)) {
      emit(
        AuthPasswordResetRequest(
          email: email,
          retryAt: _emailRetryAt,
          message: 'Espera antes de solicitar otro correo.',
        ),
      );
      return;
    }
    final request = ++_emailRequest;
    emit(AuthPasswordResetRequest(email: email, isSending: true));
    try {
      await accountRepository!.requestPasswordReset(email);
      if (isClosed ||
          request != _emailRequest ||
          state is! AuthPasswordResetRequest) {
        return;
      }
      _emailRetryAt = DateTime.now().add(const Duration(minutes: 1));
      emit(
        AuthPasswordResetRequest(
          email: email,
          sent: true,
          retryAt: _emailRetryAt,
        ),
      );
    } catch (error) {
      if (isClosed ||
          request != _emailRequest ||
          state is! AuthPasswordResetRequest) {
        return;
      }
      emit(
        AuthPasswordResetRequest(email: email, message: _accountError(error)),
      );
    }
  }

  Future<void> resendConfirmation(String email) async {
    if (state is AuthEmailConfirmationRequired &&
        (state as AuthEmailConfirmationRequired).isSending) {
      return;
    }
    if (_emailRetryAt != null && DateTime.now().isBefore(_emailRetryAt!)) {
      emit(
        AuthEmailConfirmationRequired(
          email: email,
          retryAt: _emailRetryAt,
          message: 'Espera antes de solicitar otro correo.',
        ),
      );
      return;
    }
    final request = ++_emailRequest;
    emit(AuthEmailConfirmationRequired(email: email, isSending: true));
    try {
      await accountRepository!.resendConfirmation(email);
      if (isClosed ||
          request != _emailRequest ||
          state is! AuthEmailConfirmationRequired) {
        return;
      }
      _emailRetryAt = DateTime.now().add(const Duration(minutes: 1));
      emit(
        AuthEmailConfirmationRequired(
          email: email,
          retryAt: _emailRetryAt,
          message: 'Si la cuenta está pendiente de confirmación, recibirás un nuevo correo.',
        ),
      );
    } catch (error) {
      if (isClosed ||
          request != _emailRequest ||
          state is! AuthEmailConfirmationRequired) {
        return;
      }
      emit(
        AuthEmailConfirmationRequired(
          email: email,
          hasError: true,
          message: _accountError(error),
        ),
      );
    }
  }

  Future<void> updateRecoveredPassword(String password) async {
    final recovery = state;
    if (recovery is! AuthPasswordRecovery ||
        recovery.isSaving ||
        recovery.passwordUpdated) {
      return;
    }
    if (password.length < 8) {
      emit(
        AuthPasswordRecovery(
          userId: recovery.userId,
          email: recovery.email,
          message: 'Utiliza al menos 8 caracteres.',
        ),
      );
      return;
    }
    emit(
      AuthPasswordRecovery(
        userId: recovery.userId,
        email: recovery.email,
        isSaving: true,
      ),
    );
    try {
      await accountRepository!.updateRecoveredPassword(password);
      if (isClosed ||
          state is! AuthPasswordRecovery ||
          (state as AuthPasswordRecovery).userId != recovery.userId) {
        return;
      }
      emit(
        AuthPasswordRecovery(
          userId: recovery.userId,
          email: recovery.email,
          passwordUpdated: true,
        ),
      );
    } catch (error) {
      if (isClosed ||
          state is! AuthPasswordRecovery ||
          (state as AuthPasswordRecovery).userId != recovery.userId) {
        return;
      }
      if (error is AuthLinkException) {
        emit(AuthLinkError(message: error.message));
        return;
      }
      emit(
        AuthPasswordRecovery(
          userId: recovery.userId,
          email: recovery.email,
          message: _accountError(error),
        ),
      );
    }
  }

  Future<void> finishPasswordRecovery() async {
    final recovery = state;
    if (recovery is! AuthPasswordRecovery || recovery.isSaving) return;
    emit(
      AuthPasswordRecovery(
        userId: recovery.userId,
        email: recovery.email,
        passwordUpdated: recovery.passwordUpdated,
        isSaving: true,
      ),
    );
    try {
      await accountRepository!.finishPasswordRecovery();
      if (!isClosed &&
          (state is AuthPasswordRecovery || state is AuthUnauthenticated)) {
        emit(AuthUnauthenticated());
      }
    } catch (error) {
      if (isClosed || state is! AuthPasswordRecovery) return;
      emit(
        AuthPasswordRecovery(
          userId: recovery.userId,
          email: recovery.email,
          passwordUpdated: recovery.passwordUpdated,
          message: _accountError(error),
        ),
      );
    }
  }

  String _accountError(Object error) => error is ServerException
      ? error.message
      : 'No se ha podido completar la solicitud. Puedes reintentarlo.';

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
