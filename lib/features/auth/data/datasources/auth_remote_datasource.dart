// features/auth/data/datasources/auth_remote_datasource.dart
import 'package:entrenaop/features/auth/data/models/user_model.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';

abstract class AuthRemoteDataSource {
  /// Inicia sesión con email y contraseña.
  /// Lanza [ServerException] si las credenciales son incorrectas.
  Future<UserModel> signIn({required String email, required String password});

  /// Crea una cuenta. Devuelve null cuando Supabase exige confirmar el correo
  /// antes de crear una sesión autenticada.
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  /// Cierra la sesión del usuario actual.
  Future<void> signOut();

  /// Devuelve el [UserModel] del usuario autenticado, o null si no hay sesión activa.
  Future<UserModel?> getCurrentUser();

  /// Emite el usuario vigente cuando Supabase crea, renueva o elimina la
  /// sesión, distinguiendo una recuperación de contraseña. Un usuario null
  /// sin identidad de recuperación significa que la sesión ha terminado.
  Stream<AuthSessionChange> watchCurrentUser();

  Future<void> requestPasswordReset(String email);
  Future<void> resendConfirmation(String email);
  Future<void> updateRecoveredPassword(String password);
  Future<void> finishPasswordRecovery();
}
