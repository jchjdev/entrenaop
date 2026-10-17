import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';

import '../domain/guided_program_repository.dart';

class SupabaseGuidedProgramRepository implements GuidedProgramRepository {
  const SupabaseGuidedProgramRepository(this.client);
  final SupabaseClient client;
  @override
  String? get currentUserId => client.auth.currentUser?.id;
  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
  }) async {
    final rows = await client.rpc(
      'get_guided_program_catalog',
      params: {
        'p_query': query,
        'p_mode': mode?.name,
        'p_offset': page * pageSize,
        'p_limit': pageSize + 1,
        'p_followed': followed,
      },
    ) as List;
    return GuidedCatalogPage(
      rows
          .take(pageSize)
          .map(
            (r) => guidedProgramFromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList(),
      hasMore: rows.length > pageSize,
    );
  }

  @override
  Future<GuidedProgramDetail> detail(String id) async {
    final row = await client
        .from('guided_programs')
        .select()
        .eq('id', id)
        .single();
    final follow = await client
        .from('guided_program_follows')
        .select()
        .eq('program_id', id)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final runs = follow == null
        ? <Map<String, dynamic>>[]
        : await client
              .from('guided_program_runs')
              .select(
                'phase_index,session_index,execution_id,workout_executions(status)',
              )
              .eq('follow_id', follow['id'])
              .order('created_at', ascending: false);
    return GuidedProgramDetail(
      guidedProgramFromJson(row),
      follow: follow == null
          ? null
          : GuidedFollow(
              id: follow['id'] as String,
              phaseIndex: follow['phase_index'] as int,
              completed: follow['completed_at'] != null,
            ),
      runs: runs
          .map(
            (r) => GuidedRun(
              phaseIndex: r['phase_index'] as int,
              sessionIndex: r['session_index'] as int,
              executionId: r['execution_id'] as String?,
              status:
                  (r['workout_executions'] as Map?)?['status'] as String? ??
                  'discarded',
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> follow(String id) async {
    await client.rpc('follow_guided_program', params: {'p_program_id': id});
  }

  @override
  Future<void> advance(String followId, int expectedPhase) async {
    await client.rpc(
      'advance_guided_program',
      params: {'p_follow_id': followId, 'p_expected_phase': expectedPhase},
    );
  }

  @override
  Future<String> start({
    required String programId,
    required int phaseIndex,
    required int sessionIndex,
    required String operationId,
    required bool omitWarmup,
    int? restSeconds,
  }) async => await client.rpc(
    'start_guided_program_session',
    params: {
      'p_program_id': programId,
      'p_phase_index': phaseIndex,
      'p_session_index': sessionIndex,
      'p_operation_id': operationId,
      'p_omit_warmup': omitWarmup,
      'p_rest_seconds': restSeconds,
    },
  ) as String;
}
