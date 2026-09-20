import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/training_plan/data/datasources/training_preferences_remote_datasource.dart';
import 'package:entrenaop/features/training_plan/data/models/training_preferences_model.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainingPreferencesRemoteDataSourceImpl
    implements TrainingPreferencesRemoteDataSource {
  const TrainingPreferencesRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<TrainingPreferences?> get() async {
    try {
      final response = await supabaseClient
          .from('training_preferences')
          .select()
          .maybeSingle();
      return response == null
          ? null
          : TrainingPreferencesModel.fromJson(response);
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<void> save(TrainingPreferences preferences) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw const ServerException('No hay una sesión autenticada.');
      }
      await supabaseClient
          .from('training_preferences')
          .upsert(
            TrainingPreferencesModel.toJson(preferences, userId: userId),
            onConflict: 'user_id',
          );
    } catch (error) {
      if (error is ServerException) rethrow;
      throw ServerException(error.toString());
    }
  }
}
