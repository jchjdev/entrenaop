import 'dart:async';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:entrenaop/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:entrenaop/features/auth/domain/usecases/watch_current_user_usecase.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final WatchCurrentUserUseCase watchCurrentUserUseCase;
  StreamSubscription<UserEntity?>? _sessionSubscription;

  AuthCubit({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.watchCurrentUserUseCase,
  }) : super(AuthInitial());

  void watchAuthState() {
    _sessionSubscription ??= watchCurrentUserUseCase().listen(
      (user) {
        if (isClosed) return;
        emit(
          user == null ? AuthUnauthenticated() : AuthAuthenticated(user: user),
        );
      },
      onError: (Object error) {
        if (isClosed) return;
        emit(
          AuthError(
            message: error is ServerException
                ? error.message
                : error.toString(),
          ),
        );
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(AuthLoading());
    try {
      final user = await signInUseCase(email: email, password: password);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: e.toString()));
      }
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    try {
      final outcome = await signUpUseCase(
        email: email,
        password: password,
        fullName: fullName,
      );
      switch (outcome) {
        case SignUpAuthenticated(:final user):
          emit(AuthAuthenticated(user: user));
        case SignUpConfirmationRequired(:final email):
          emit(AuthEmailConfirmationRequired(email: email));
      }
    } catch (e) {
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: e.toString()));
      }
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await signOutUseCase();
      emit(AuthUnauthenticated());
    } catch (e) {
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: e.toString()));
      }
    }
  }

  Future<void> checkCurrentUser() async {
    emit(AuthLoading());
    try {
      final user = await getCurrentUserUseCase();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (e is ServerException) {
        emit(AuthError(message: e.message));
      } else {
        emit(AuthError(message: e.toString()));
      }
    }
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
