import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

import 'trainer_video_repository.dart';

typedef TrainerMediaRow = Map<String, dynamic>;

abstract class TrainerMediaRepository {
  Future<List<TrainerMediaRow>> usage();
  Future<List<TrainerMediaRow>> list({TrainerMediaRow? before});
  ExerciseVideoSource source({TrainerMediaRow? resume});
  Future<List<TrainerMediaRow>> technique(String assignmentId);
  Future<void> feedback(
    String operation,
    String assetId,
    double second,
    String body,
  );
}

class SupabaseTrainerMediaRepository implements TrainerMediaRepository {
  const SupabaseTrainerMediaRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  Future<dynamic> _rpc(String name, Map<String, Object?> params) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: params,
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    return result;
  }

  List<TrainerMediaRow> _rows(dynamic result) =>
      (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  @override
  Future<List<TrainerMediaRow>> usage() async =>
      _rows(await _rpc('get_trainer_video_usage', {}));
  @override
  Future<List<TrainerMediaRow>> list({TrainerMediaRow? before}) async => _rows(
    await _rpc('list_trainer_exercise_videos', {
      'p_before_at': before?['created_at'],
      'p_before_id': before?['id'],
    }),
  );
  @override
  ExerciseVideoSource source({TrainerMediaRow? resume}) {
    final original = SupabaseTrainerVideoRepository(client, userId);
    return resume == null
        ? original
        : original.resumeAsset(
            resume['id'] as String,
            resume['source_bytes'] as int,
          );
  }

  @override
  Future<List<TrainerMediaRow>> technique(String assignmentId) async => _rows(
    await _rpc('list_client_technique_videos', {
      'p_assignment_id': assignmentId,
    }),
  );
  @override
  Future<void> feedback(
    String operation,
    String assetId,
    double second,
    String body,
  ) async {
    await _rpc('add_trainer_video_feedback', {
      'p_operation_id': operation,
      'p_id': assetId,
      'p_second': second,
      'p_body': body,
    });
  }
}
