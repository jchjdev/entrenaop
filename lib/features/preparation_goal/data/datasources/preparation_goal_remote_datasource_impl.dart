import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/preparation_goal/data/datasources/preparation_goal_remote_datasource.dart';
import 'package:entrenaop/features/preparation_goal/data/models/preparation_goal_model.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreparationGoalRemoteDataSourceImpl
    implements PreparationGoalRemoteDataSource {
  const PreparationGoalRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<PreparationGoal?> getActive() async {
    try {
      final response = await supabaseClient
          .from('preparation_goals')
          .select()
          .eq('status', 'active')
          .maybeSingle();
      return response == null ? null : PreparationGoalModel.fromJson(response);
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<PreparationGoal> save(PreparationGoal goal) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw const ServerException('No hay una sesión autenticada.');
      }
      final values = PreparationGoalModel.toJson(goal, userId: userId);
      final response = goal.id == null
          ? await supabaseClient
                .from('preparation_goals')
                .insert(values)
                .select()
                .single()
          : await supabaseClient
                .from('preparation_goals')
                .update(values)
                .eq('id', goal.id!)
                .select()
                .single();
      return PreparationGoalModel.fromJson(response);
    } catch (error) {
      if (error is ServerException) rethrow;
      throw ServerException(error.toString());
    }
  }
}
