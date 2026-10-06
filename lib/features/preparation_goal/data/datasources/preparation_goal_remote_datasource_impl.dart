import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/preparation_goal/data/datasources/preparation_goal_remote_datasource.dart';
import 'package:entrenaop/features/preparation_goal/data/models/preparation_goal_model.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreparationGoalRemoteDataSourceImpl
    implements PreparationGoalRemoteDataSource {
  const PreparationGoalRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;
  String _coverUrl(String path) =>
      supabaseClient.storage.from('program-covers-public').getPublicUrl(path);

  @override
  Future<List<PreparationGoal>> getActiveGoals() async {
    try {
      final response = await supabaseClient
          .from('preparation_goals')
          .select('''
            *,
            preparation_programs!inner(
              id,
              name,
              kind,
              preparation_program_catalogs(catalog_version, is_current),
              preparation_program_covers(card_image_path, header_image_path, focal_x, focal_y, header_focal_x, header_focal_y)
            )
          ''')
          .eq('status', 'active')
          .order('created_at');
      return response
          .map(
            (json) =>
                PreparationGoalModel.fromJson(json, resolveCoverUrl: _coverUrl),
          )
          .toList(growable: false);
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async {
    try {
      final response = await supabaseClient
          .from('preparation_programs')
          .select('''
            id,
            name,
            kind,
            preparation_program_catalogs(catalog_version, is_current),
            preparation_program_covers(card_image_path, header_image_path, focal_x, focal_y, header_focal_x, header_focal_y)
          ''')
          .eq('enabled', true)
          .order('name');
      return response
          .map(
            (json) => PreparationProgramModel.fromJson(
              json,
              resolveCoverUrl: _coverUrl,
            ),
          )
          .toList(growable: false);
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
                .select('''
                  *,
                  preparation_programs!inner(
                    id,
                    name,
                    kind,
                    preparation_program_catalogs(catalog_version, is_current),
                    preparation_program_covers(card_image_path, header_image_path, focal_x, focal_y, header_focal_x, header_focal_y)
                  )
                ''')
                .single()
          : await supabaseClient
                .from('preparation_goals')
                .update(values)
                .eq('id', goal.id!)
                .select('''
                  *,
                  preparation_programs!inner(
                    id,
                    name,
                    kind,
                    preparation_program_catalogs(catalog_version, is_current),
                    preparation_program_covers(card_image_path, header_image_path, focal_x, focal_y, header_focal_x, header_focal_y)
                  )
                ''')
                .single();
      return PreparationGoalModel.fromJson(
        response,
        resolveCoverUrl: _coverUrl,
      );
    } catch (error) {
      if (error is ServerException) rethrow;
      throw ServerException(error.toString());
    }
  }

  @override
  Future<void> archive(String goalId) async {
    try {
      await supabaseClient
          .from('preparation_goals')
          .update({
            'status': 'archived',
            'archived_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', goalId);
    } catch (error) {
      throw ServerException(error.toString());
    }
  }
}
