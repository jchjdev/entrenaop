// features/auth/data/datasources/auth_remote_datasource.dart
import 'package:entrenaop/features/auth/data/models/user_model.dart';

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
}
