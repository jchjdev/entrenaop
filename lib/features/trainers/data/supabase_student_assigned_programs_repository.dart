import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../domain/student_assigned_programs.dart';

class SupabaseStudentAssignedProgramsRepository
    implements StudentAssignedProgramsRepository {
  const SupabaseStudentAssignedProgramsRepository(this._client, this._owner);

  final SupabaseClient _client;
  final String _owner;

  static StudentAssignedProgram _program(Map row) => StudentAssignedProgram(
    id: row['id'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    name: row['name'] as String,
    trainerName: row['trainer_name'] as String,
    total: row['total'] as int,
    completed: row['completed'] as int,
    description: row['description'] as String?,
    note: row['note'] as String?,
    phases: [
      for (final phase in row['phases'] as List? ?? const [])
        StudentAssignedPhase(
          phase['name'] as String,
          phase['instructions'] as String?,
          [
            for (final session in phase['sessions'] as List)
              StudentAssignedSession(
                session['id'] as String,
                session['name'] as String,
                DateTime.parse(session['date'] as String),
                session['status'] as String,
              ),
          ],
        ),
    ],
  );

  Future<Map> _load(Map<String, dynamic> parameters) async =>
      await authenticatedTrainerRpc(
        _client,
        _owner,
        'list_my_assigned_programs',
        params: {'p_expected_owner': _owner, ...parameters},
      ) as Map;

  @override
  Future<({List<StudentAssignedProgram> items, bool hasMore})> list({
    AssignedProgramCursor? before,
  }) async {
    final data = await _load({
      if (before != null) ...{
        'p_before_at': before.createdAt.toUtc().toIso8601String(),
        'p_before_id': before.id,
      },
    });
    return (
      items: (data['items'] as List).cast<Map>().map(_program).toList(),
      hasMore: data['has_more'] as bool,
    );
  }

  @override
  Future<StudentAssignedProgram?> get(String deliveryId) async {
    final data = await _load({'p_delivery_id': deliveryId});
    final row = (data['items'] as List).cast<Map>().singleOrNull;
    return row == null ? null : _program(row);
  }
}
