import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../domain/student_notice_repository.dart';

class SupabaseStudentNoticeRepository implements StudentNoticeRepository {
  const SupabaseStudentNoticeRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  Future<dynamic> _rpc(String name, [Map<String, dynamic>? parameters]) =>
      authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: {'p_expected_owner': userId, ...?parameters},
      );

  static Map<String, dynamic> _row(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static StudentNoticeKind _kind(String value) =>
      StudentNoticeKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => throw const FormatException('Tipo de aviso desconocido.'),
      );

  static String _title(StudentNoticeKind kind, int revision) => switch (kind) {
    StudentNoticeKind.message => 'Mensaje de tu preparador',
    StudentNoticeKind.form => 'Formulario de tu preparador',
    StudentNoticeKind.assessment => 'Pruebas de tu preparador',
    StudentNoticeKind.techniqueFeedback => 'Revisión de tu técnica',
    StudentNoticeKind.assignment =>
      revision == 0
          ? 'Nueva pauta de tu preparador'
          : 'Tu preparador ha cambiado una pauta',
  };

  @override
  Future<StudentNoticeSnapshot> snapshot({
    StudentNotice? before,
    StudentNoticeKind? kind,
  }) async {
    final data = _row(
      await _rpc('get_my_trainer_notices', {
        'p_before_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_kind': kind?.name,
      }),
    );
    final resources = _row(data['resources']);
    return StudentNoticeSnapshot(
      items: (data['items'] as List)
          .map((value) {
            final row = _row(value);
            final kind = _kind(row['kind'] as String);
            return StudentNotice(
              id: row['id'] as String,
              kind: kind,
              title: _title(kind, row['source_revision'] as int),
              createdAt: DateTime.parse(row['created_at'] as String),
              readAt: row['read_at'] == null
                  ? null
                  : DateTime.parse(row['read_at'] as String),
            );
          })
          .toList(growable: false),
      hasMore: data['has_more'] as bool,
      unreadCount: data['unread_count'] as int,
      resources: StudentNoticeResources(
        hasForms: resources['has_forms'] as bool,
        hasAssessments: resources['has_assessments'] as bool,
        hasConversations: resources['has_conversations'] as bool,
        hasTechnique: resources['has_technique'] as bool,
        hasAssignedWorkouts: resources['has_assigned_workouts'] as bool,
        conversationRelationId:
            resources['conversation_relation_id'] as String?,
        conversations: ((resources['conversations'] as List?) ?? const [])
            .map(
              (value) => StudentConversationLink(
                (value as Map)['relation_id'] as String,
                value['trainer_name'] as String,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> ack(String noticeId) async {
    await _rpc('ack_my_trainer_notice', {'p_notice_id': noticeId});
  }

  @override
  Future<StudentNoticeTarget?> resolve(String noticeId) async {
    final value = await _rpc('resolve_my_trainer_notice', {
      'p_notice_id': noticeId,
    });
    if (value == null) return null;
    final row = _row(value);
    final kind = StudentNoticeTargetKind.values.firstWhere(
      (kind) => kind.name == row['kind'],
      orElse: () =>
          throw const FormatException('Destino de aviso desconocido.'),
    );
    final date = row['scheduled_date'] as String?;
    if (kind == StudentNoticeTargetKind.workout && date == null) {
      throw const FormatException('La pauta no tiene fecha de agenda.');
    }
    return StudentNoticeTarget(
      kind: kind,
      targetId: row['target_id'] as String,
      scheduledDate: date == null ? null : DateTime.parse(date),
    );
  }

  @override
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before}) async {
    final data = _row(
      await _rpc('list_my_trainer_technique', {
        'p_before_at': before?.startedAt.toUtc().toIso8601String(),
        'p_before_id': before?.executionId,
      }),
    );
    return TechniqueTargetPage(
      items: (data['items'] as List)
          .map((value) {
            final row = _row(value);
            return TechniqueTarget(
              executionId: row['execution_id'] as String,
              sessionName: row['session_name'] as String,
              startedAt: DateTime.parse(row['started_at'] as String),
            );
          })
          .toList(growable: false),
      hasMore: data['has_more'] as bool,
    );
  }
}
