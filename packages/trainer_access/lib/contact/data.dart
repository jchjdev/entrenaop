import 'package:supabase_flutter/supabase_flutter.dart';

import '../authenticated_rpc.dart';
import '../directory/domain.dart';
import '../trainer_message.dart';
import 'domain.dart';
import 'policy.dart';

class SupabaseContactRepository implements ContactRepository {
  const SupabaseContactRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;

  Future<dynamic> _rpc(String name, Map<String, dynamic> parameters) async {
    try {
      return await authenticatedTrainerRpc(
        client,
        owner,
        name,
        params: parameters,
      );
    } on PostgrestException catch (e) {
      throw DirectoryFailure(switch (e.code) {
        '54000' => 'Has alcanzado el límite de envíos. Espera antes de volver a intentarlo.',
        '22023' => 'La operación no coincide con el envío pendiente. Vuelve a abrir la conversación.',
        '55000' => 'Ya existe un contacto con este preparador. Este mensaje no se ha enviado. Abre Mis contactos y solicitudes.',
        '42501' => 'Esta conversación no admite la operación. Actualiza su estado y comprueba tu acceso.',
        _ => 'No se pudo confirmar el envío. Reintenta conservando el mismo mensaje.',
      });
    }
  }

  ContactConversation _conversation(dynamic value) {
    final j = Map<String, dynamic>.from(value as Map);
    return ContactConversation(
      id: j['id'] as String?,
      profileId: j['profile_id'] as String?,
      relationId: j['relation_id'] as String?,
      requesterId: j['requester_id'] as String?,
      name: j['name'] as String? ?? 'Conversación',
      state: j['state'] == null || j['state'] == 'new'
          ? ContactState.fresh
          : ContactState.values.byName(j['state'] as String),
      isTrainer: j['is_trainer'] == true,
      canSend: j['can_send'] == true,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    );
  }

  @override
  Future<ContactConversation> open(String profileId) async => _conversation(
    await _rpc('open_directory_contact', {'p_profile': profileId}),
  );
  @override
  Future<ContactConversation> context(String id) async =>
      _conversation(await _rpc('get_directory_contact', {'p_id': id}));
  @override
  Future<ContactInbox> inbox({ContactConversation? before}) async {
    final j = Map<String, dynamic>.from(
      await _rpc('list_directory_contacts', {
        'p_before_at': before?.createdAt?.toUtc().toIso8601String(),
        'p_before_id': before?.id,
      }) as Map,
    );
    return ContactInbox(
      (j['items'] as List).map(_conversation).toList(),
      pendingCount: (j['pending_count'] as num).toInt(),
    );
  }

  @override
  Future<ContactConversation> request({
    required String operationId,
    required String profileId,
    required String body,
  }) async => _conversation(
    await _rpc('request_directory_contact', {
      'p_id': operationId,
      'p_profile': profileId,
      'p_body': body,
      'p_notice': contactNoticeVersion,
    }),
  );
  @override
  Future<void> decide(String id, ContactState state) async {
    await _rpc('decide_directory_contact', {
      'p_id': id,
      'p_action': state.name,
    });
  }

  @override
  Future<List<TrainerMessage>> messages(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  }) async =>
      (await _rpc('list_directory_contact_messages', {
            'p_contact': id,
            'p_before_at': beforeAt?.toUtc().toIso8601String(),
            'p_before_id': beforeId,
          }) as List)
          .map(
            (v) => TrainerMessage.fromJson(
              Map<String, dynamic>.from(v as Map),
              owner,
            ),
          )
          .toList();
  @override
  Future<void> send({
    required String operationId,
    required String contactId,
    required String body,
  }) async {
    await _rpc('send_directory_contact_message', {
      'p_id': operationId,
      'p_contact': contactId,
      'p_body': body,
    });
  }

  @override
  Future<void> markRead(String contactId, List<String> ids) async {
    if (ids.isNotEmpty) {
      await _rpc('read_directory_contact_messages', {
        'p_contact': contactId,
        'p_ids': ids,
      });
    }
  }

  @override
  Future<void> report(
    String id,
    DirectoryReportReason reason,
    String details,
  ) async {
    await _rpc('report_directory_contact', {
      'p_id': id,
      'p_reason': reason.name,
      'p_details': details,
    });
  }
}
