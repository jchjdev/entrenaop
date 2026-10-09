// features/auth/data/datasources/auth_remote_datasource_impl.dart
import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:entrenaop/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;
  final SharedPreferences preferences;
  final String redirectUrl;
  static const recoveryOwnerKey = 'auth_recovery_owner_v1';
  static const recoveryUpdatedKey = 'auth_recovery_updated_v1';

  AuthRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.preferences,
    required this.redirectUrl,
  });

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw const ServerException('Usuario no encontrado');

      // Obtenemos el perfil completo desde la tabla 'profiles'
      final profile = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson({...profile, 'email': user.email ?? ''});
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        throw EmailConfirmationException(email);
      }
      throw ServerException(_authMessage(e));
    } on ServerException {
      rethrow;
    } catch (_) {
      throw const ServerException(
        'No se ha podido iniciar sesión. Comprueba tu conexión y reintenta.',
      );
    }
  }

  @override
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: redirectUrl,
      );
      final user = response.user;
      if (user == null) {
        throw const ServerException('No se ha podido crear la cuenta.');
      }

      if (response.session == null) return null;

      final profile = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson({...profile, 'email': user.email ?? email});
    } on AuthException catch (e) {
      throw ServerException(_authMessage(e));
    } on ServerException {
      rethrow;
    } catch (_) {
      throw const ServerException(
        'No se ha podido crear la cuenta. Comprueba tu conexión y reintenta.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabaseClient.auth.signOut();
    } on AuthException catch (e) {
      throw ServerException(_authMessage(e));
    } catch (_) {
      throw const ServerException(
        'No se ha podido cerrar sesión. Comprueba tu conexión y reintenta.',
      );
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) return null;

      final profile = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson({...profile, 'email': user.email ?? ''});
    } on AuthException catch (e) {
      throw ServerException(_authMessage(e));
    } catch (_) {
      throw const ServerException(
        'No se ha podido validar la sesión. Comprueba tu conexión y reintenta.',
      );
    }
  }

  @override
  Stream<AuthSessionChange> watchCurrentUser() {
    return supabaseClient.auth.onAuthStateChange
        .asyncMap((authState) async {
          final user = authState.session?.user;
          // Una consulta antigua no puede restaurar el usuario que ya salió.
          if (user?.id != supabaseClient.auth.currentUser?.id) {
            return const AuthSessionChange(null);
          }
          if (user == null) {
            await _clearRecovery();
            return const AuthSessionChange(null);
          }
          if (authState.event == AuthChangeEvent.passwordRecovery) {
            await preferences.setString(recoveryOwnerKey, user.id);
            await preferences.setBool(recoveryUpdatedKey, false);
          } else if (authState.event == AuthChangeEvent.signedIn) {
            await _clearRecovery();
          }
          // El marcador conserva el recorrido al recargar, nunca concede permisos.
          // Solo se utiliza junto a la sesión vigente que validó Supabase.
          if (preferences.getString(recoveryOwnerKey) == user.id) {
            return AuthSessionChange.recovery(
              userId: user.id,
              email: user.email ?? '',
              passwordUpdated: preferences.getBool(recoveryUpdatedKey) ?? false,
            );
          }
          await _clearRecovery();

          try {
            final profile = await supabaseClient
                .from('profiles')
                .select()
                .eq('id', user.id)
                .single();
            return AuthSessionChange(
              UserModel.fromJson({...profile, 'email': user.email ?? ''}),
            );
          } on AuthException catch (error) {
            throw ServerException(_authMessage(error));
          } catch (_) {
            throw const ServerException(
              'No se ha podido validar la sesión. Comprueba la conexión y reintenta.',
            );
          }
        })
        .where(
          (change) =>
              (change.recoveryUserId ?? change.user?.id) ==
              supabaseClient.auth.currentUser?.id,
        )
        .handleError((Object error) {
          if (error is AuthException && error is! AuthRetryableFetchException) {
            throw const AuthLinkException();
          }
          throw const ServerException(
            'No se ha podido validar la sesión. Comprueba la conexión y reintenta.',
          );
        });
  }

  Future<void> _clearRecovery() async {
    await preferences.remove(recoveryOwnerKey);
    await preferences.remove(recoveryUpdatedKey);
  }

  @override
  Future<void> requestPasswordReset(String email) => _accountAction(
    () => supabaseClient.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectUrl,
    ),
  );

  @override
  Future<void> resendConfirmation(String email) => _accountAction(
    () => supabaseClient.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: redirectUrl,
    ),
  );

  @override
  Future<void> updateRecoveredPassword(String password) async {
    final user = supabaseClient.auth.currentUser;
    if (user == null || preferences.getString(recoveryOwnerKey) != user.id) {
      throw const AuthLinkException();
    }
    await _accountAction(
      () => supabaseClient.auth.updateUser(UserAttributes(password: password)),
    );
    // Una respuesta anterior no confirma la recuperación de otra cuenta.
    if (supabaseClient.auth.currentUser?.id != user.id ||
        preferences.getString(recoveryOwnerKey) != user.id) {
      return;
    }
    await preferences.setBool(recoveryUpdatedKey, true);
  }

  @override
  Future<void> finishPasswordRecovery() async {
    await _accountAction(
      () => supabaseClient.auth.signOut(scope: SignOutScope.local),
    );
    await _clearRecovery();
  }

  Future<void> _accountAction(Future<Object?> Function() action) async {
    try {
      await action();
    } on AuthException catch (error) {
      if (const [
        'session_not_found',
        'refresh_token_not_found',
        'bad_jwt',
        'otp_expired',
      ].contains(error.code)) {
        throw const AuthLinkException();
      }
      throw ServerException(_authMessage(error));
    } catch (_) {
      throw const ServerException(
        'No se ha podido conectar. Comprueba tu conexión y reintenta.',
      );
    }
  }

  String _authMessage(AuthException error) {
    // El código del servidor decide el mensaje. No mostramos textos técnicos
    // ni distinguimos si falló el correo o la contraseña al iniciar sesión.
    final code =
        error.code ??
        (error.message.toLowerCase() == 'invalid login credentials'
            ? 'invalid_credentials'
            : null);
    return switch (code) {
      'invalid_credentials' => 'El correo o la contraseña no son correctos.',
      'email_not_confirmed' => 'Confirma tu correo antes de entrar.',
      'over_email_send_rate_limit' =>
        'Espera un minuto antes de volver a solicitar el correo.',
      'over_request_rate_limit' || 'over_password_rate_limit' => 'Has realizado demasiados intentos. Espera un poco y vuelve a intentarlo.',
      'same_password' => 'Elige una contraseña diferente a la anterior.',
      'weak_password' => 'La contraseña no cumple los requisitos. Utiliza al menos 8 caracteres.',
      'email_address_invalid' =>
        'Revisa el correo e introduce una dirección válida.',
      'email_address_not_authorized' =>
        'No se ha podido enviar el correo. Inténtalo más tarde.',
      'user_already_exists' || 'email_exists' => 'No se ha podido crear la cuenta. Si ya tienes una, inicia sesión o recupera tu contraseña.',
      'signup_disabled' =>
        'El registro de nuevas cuentas no está disponible ahora.',
      _ => 'No se ha podido completar la solicitud. Puedes reintentarlo.',
    };
  }
}
