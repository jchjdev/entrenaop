import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';

import '../domain/guided_program_repository.dart';

class SupabaseGuidedProgramRepository implements GuidedProgramRepository {
  const SupabaseGuidedProgramRepository(this.client);
  final SupabaseClient client;
  @override
  String? get currentUserId => client.auth.currentUser?.id;
  Future<List<GuidedProgram>> _withEditorial(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final families = rows.map((r) => r['family_id'] as String).toSet().toList();
    final results = await Future.wait([
      client
          .from('guided_program_covers')
          .select()
          .inFilter('program_id', families),
      client
          .from('guided_program_category_links')
          .select('program_id,is_primary,guided_program_categories(*)')
          .inFilter('program_id', rows.map((r) => r['id'] as String).toList()),
    ]);
    final covers = results[0], links = results[1];
    final byFamily = {
      for (final cover in covers) cover['program_id'] as String: cover,
    };
    return [
      for (final row in rows)
        guidedProgramFromJson(
          {
            ...row,
            'cover': byFamily[row['family_id']],
            'category_links': links
                .where((l) => l['program_id'] == row['id'])
                .toList(),
          },
          resolveCoverUrl: (path) =>
              client.storage.from('program-covers-public').getPublicUrl(path),
        ),
    ];
  }

  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async {
    final owner = currentUserId;
    if (owner == null) return const [];
    final rows = await client
        .from('guided_program_follows')
        .select('phase_index,guided_programs!inner(*)')
        .eq('user_id', owner)
        .isFilter('completed_at', null)
        .isFilter('abandoned_at', null)
        .order('started_at', ascending: false)
        .order('id', ascending: false)
        .limit(3);
    if (owner != currentUserId) return const [];
    final programs = await _withEditorial([
      for (final row in rows)
        Map<String, dynamic>.from(row['guided_programs'] as Map),
    ]);
    if (owner != currentUserId) return const [];
    return [
      for (final (index, row) in rows.indexed)
        StartedGuidedProgram(
          program: programs[index],
          phaseIndex: row['phase_index'] as int,
        ),
    ];
  }

  @override
  Future<List<GuidedProgramCategory>> categories() async =>
      (await client
              .from('guided_program_categories')
              .select()
              .eq('is_active', true)
              .order('name'))
          .map(guidedCategoryFromJson)
          .toList();

  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) async {
    final rows = await client.rpc(
      'get_guided_program_catalog',
      params: {
        'p_query': query,
        'p_mode': mode?.name,
        'p_offset': page * pageSize,
        'p_limit': pageSize + 1,
        'p_followed': followed,
        'p_category_id': categoryId,
      },
    ) as List;
    return GuidedCatalogPage(
      await _withEditorial([
        for (final r in rows.take(pageSize))
          Map<String, dynamic>.from(r as Map),
      ]),
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
      (await _withEditorial([row])).single,
      follow: follow == null
          ? null
          : GuidedFollow(
              id: follow['id'] as String,
              phaseIndex: follow['phase_index'] as int,
              completed: follow['completed_at'] != null,
              abandoned: follow['abandoned_at'] != null,
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
  Future<void> abandon(String followId) async {
    await client.rpc(
      'abandon_guided_program',
      params: {'p_follow_id': followId},
    );
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
