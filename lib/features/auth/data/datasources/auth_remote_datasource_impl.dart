// features/auth/data/datasources/auth_remote_datasource_impl.dart
import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:entrenaop/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl({required this.supabaseClient});

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

      try {
        final model = UserModel.fromJson({
          ...profile,
          'email': user.email ?? '',
        });
        return model;
      } catch (e) {
        throw ServerException(e.toString());
      }
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
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
      throw ServerException(e.message);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabaseClient.auth.signOut();
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
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
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
