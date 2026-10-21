import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_editor_ui/exercise_video_client.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

typedef ClientTechniqueClip = Map<String, dynamic>;

class ClientTechniqueContext {
  ClientTechniqueContext.fromJson(Map<String, dynamic> row)
    : assignmentId = row['assignment_id'] as String,
      executionId = row['execution_id'] as String,
      canUpload = row['can_upload'] as bool,
      sourceLimit = row['source_limit'] as int,
      durationLimit = row['duration_limit'] as int;
  final String assignmentId, executionId;
  final bool canUpload;
  final int sourceLimit, durationLimit;
}

abstract class ClientTechniqueRepository {
  Future<ClientTechniqueContext?> context(String executionId);
  Future<List<ClientTechniqueClip>> clips(String assignmentId);
  ExerciseVideoSource uploader(
    ClientTechniqueContext context, {
    String? executionSetId,
    ClientTechniqueClip? resume,
  });
  Future<void> setShared(String operation, String clipId, bool shared);
  Future<void> check(String clipId);
}

class SupabaseClientTechniqueRepository implements ClientTechniqueRepository {
  const SupabaseClientTechniqueRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, Object?> params) async {
    _identity();
    final result = await client.rpc(name, params: params);
    _identity();
    return result;
  }

  Future<Map<String, dynamic>> _edge(Map<String, Object?> body) async {
    _identity();
    try {
      final result = await client.functions.invoke(
        'exercise-video',
        body: {...body, 'expected_user_id': userId},
      );
      _identity();
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      _identity();
      rethrow;
    }
  }

  @override
  Future<ClientTechniqueContext?> context(String executionId) async {
    _identity();
    // Solo una cita coach propia habilita la sección: sin ella no se abre
    // ningún panel profesional ni se consulta la RPC de adjuntos.
    final schedule = await client
        .from('scheduled_workouts')
        .select('id')
        .eq('user_id', userId)
        .eq('execution_id', executionId)
        .eq('source', 'coach')
        .maybeSingle();
    _identity();
    if (schedule == null) return null;
    final result = await _rpc('get_client_technique_context', {
      'p_execution_id': executionId,
    });
    return result == null
        ? null
        : ClientTechniqueContext.fromJson(
            Map<String, dynamic>.from(result as Map),
          );
  }

  @override
  Future<List<ClientTechniqueClip>> clips(String assignmentId) async =>
      (await _rpc('list_client_technique_videos', {
        'p_assignment_id': assignmentId,
      }) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  @override
  ExerciseVideoSource uploader(
    ClientTechniqueContext context, {
    String? executionSetId,
    ClientTechniqueClip? resume,
  }) {
    if (resume != null &&
        (resume['scope'] != 'client_technique' ||
            resume['assignment_id'] != context.assignmentId ||
            resume['execution_id'] != context.executionId)) {
      throw const FormatException('La reserva no pertenece a esta ejecución.');
    }
    final source = ExerciseVideoClient(
      call: _edge,
      checkIdentity: _identity,
      operationId: const Uuid().v4,
      scope: 'client_technique',
      context: {
        'assignment_id': context.assignmentId,
        'execution_id': context.executionId,
        'execution_set_id': executionSetId,
      },
    );
    return resume == null
        ? source
        : source.resumeAsset(
            resume['id'] as String,
            resume['source_bytes'] as int,
          );
  }

  @override
  Future<void> setShared(String operation, String clipId, bool shared) async {
    await _rpc('set_client_technique_shared', {
      'p_operation_id': operation,
      'p_id': clipId,
      'p_shared': shared,
    });
  }

  @override
  Future<void> check(String clipId) async {
    await _edge({'action': 'status', 'id': clipId});
  }
}
