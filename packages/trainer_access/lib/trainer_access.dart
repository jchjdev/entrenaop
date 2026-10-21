import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_rpc.dart';

typedef Json = Map<String, dynamic>;
DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

class TrainerAccess {
  TrainerAccess.fromJson(Json json)
    : trainerId = json['trainer_id'] as String,
      enabled = json['enabled'] == true,
      effective = json['effective'] == true,
      limit = (json['client_limit'] as num).toInt(),
      activeClients = (json['active_clients'] as num).toInt(),
      revision = (json['revision'] as num).toInt(),
      validUntil = _date(json['valid_until']);
  final String trainerId;
  final bool enabled, effective;
  final int limit, activeClients, revision;
  final DateTime? validUntil;
  bool get full => activeClients >= limit;
  String get status => effective
      ? (full ? 'Cupo completo' : 'Acceso activo')
      : enabled
      ? 'Acceso caducado'
      : 'Acceso profesional inactivo';
}

class TrainerRelation {
  TrainerRelation.fromJson(Json json)
    : id = json['id'] as String,
      personId = json['person_id'] as String,
      name = json['person_name'] as String,
      acceptedAt = DateTime.parse(json['accepted_at'] as String),
      endedAt = _date(json['ended_at']);
  final String id, personId, name;
  final DateTime acceptedAt;
  final DateTime? endedAt;
}

enum TrainerClientState { active, inactive, archived }

class TrainerClient {
  TrainerClient.fromJson(Json json)
    : personId = json['person_id'] as String,
      name = json['person_name'] as String,
      createdAt = DateTime.parse(json['created_at'] as String),
      updatedAt = DateTime.parse(json['updated_at'] as String),
      acceptedAt = DateTime.parse(json['accepted_at'] as String),
      endedAt = _date(json['ended_at']),
      archivedAt = _date(json['archived_at']),
      activeRelationId = json['active_relation_id'] as String?,
      episodeCount = (json['episode_count'] as num).toInt();
  final String personId, name;
  final String? activeRelationId;
  final DateTime createdAt, updatedAt, acceptedAt;
  final DateTime? endedAt, archivedAt;
  final int episodeCount;
  bool get active => activeRelationId != null;
}

class TrainerInvitation {
  TrainerInvitation.fromJson(Json json)
    : id = json['id'] as String,
      createdAt = DateTime.parse(json['created_at'] as String),
      expiresAt = DateTime.parse(json['expires_at'] as String),
      revokedAt = _date(json['revoked_at']),
      acceptedAt = _date(json['accepted_at']);
  final String id;
  final DateTime createdAt, expiresAt;
  final DateTime? revokedAt, acceptedAt;
  String get status => acceptedAt != null
      ? 'Aceptada'
      : revokedAt != null
      ? 'Cancelada'
      : expiresAt.isBefore(DateTime.now())
      ? 'Caducada'
      : 'Pendiente';
  bool get canCancel => acceptedAt == null && revokedAt == null;
}

class TrainerInvitationPreview {
  TrainerInvitationPreview.fromJson(Json json)
    : trainerId = json['trainer_id'] as String,
      name = (json['trainer_name'] as String?)?.trim() ?? 'Tu preparador',
      expiresAt = DateTime.parse(json['expires_at'] as String);
  final String trainerId, name;
  final DateTime expiresAt;
}

class TrainerManagement {
  TrainerManagement.fromJson(Json json)
    : access = TrainerAccess.fromJson(Json.from(json['access'] as Map)),
      enabled = json['manual_access_enabled'] == true;
  final TrainerAccess access;
  final bool enabled;
}

// Identidad y secreto se conservan juntos en memoria al reintentar una creación
// incierta. Ni el código ni su huella deben aparecer en URLs o registros.
class TrainerInvitationDraft {
  const TrainerInvitationDraft(this.id, this.secret);
  factory TrainerInvitationDraft.secure() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    String hex(List<int> values) =>
        values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final uuid = hex(bytes);
    return TrainerInvitationDraft(
      '${uuid.substring(0, 8)}-${uuid.substring(8, 12)}-${uuid.substring(12, 16)}-${uuid.substring(16, 20)}-${uuid.substring(20)}',
      hex(List.generate(32, (_) => random.nextInt(256))),
    );
  }
  final String id, secret;
}

class TrainerAccessChange {
  const TrainerAccessChange({
    required this.trainerId,
    required this.limit,
    required this.enabled,
    required this.revision,
    required this.reason,
    this.validUntil,
  });
  final String trainerId, reason;
  final int limit, revision;
  final bool enabled;
  final DateTime? validUntil;
}

class ManagedTrainer {
  ManagedTrainer.fromJson(Json json)
    : id = json['trainer_id'] as String,
      name = json['name'] as String? ?? 'Usuario de EntrenaOP',
      email = json['email'] as String? ?? '',
      enabled = json['enabled'] == true,
      limit = (json['client_limit'] as num).toInt(),
      activeClients = (json['active_clients'] as num).toInt(),
      validUntil = _date(json['valid_until']);
  final String id, name, email;
  final bool enabled;
  final int limit, activeClients;
  final DateTime? validUntil;
  String get status => !enabled
      ? 'Inactivo'
      : validUntil != null && !validUntil!.isAfter(DateTime.now())
      ? 'Caducado'
      : 'Habilitado';
}

abstract class TrainerRepository {
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  });
  Future<void> archiveClient(String clientId, {required bool archived});
  Future<List<TrainerRelation>> clientRelations(
    String clientId, {
    TrainerRelation? before,
  });
  Future<List<ManagedTrainer>> managedTrainers({String? afterId});
  Future<TrainerAccess> access();
  Future<List<TrainerRelation>> relations({
    required bool asTrainer,
    bool ended = false,
    TrainerRelation? before,
  });
  Future<List<TrainerInvitation>> invitations({TrainerInvitation? before});
  Future<void> createInvitation(TrainerInvitationDraft draft);
  Future<TrainerInvitationPreview> preview(String secret);
  Future<void> accept(String secret);
  Future<void> cancelInvitation(String id);
  Future<void> endRelation(String id);
  Future<TrainerManagement> management(String trainerId);
  Future<TrainerAccess> changeAccess(TrainerAccessChange change);
}

class SupabaseTrainerRepository implements TrainerRepository {
  SupabaseTrainerRepository(this.client, {required this.userId});
  final SupabaseClient client;
  final String userId;

  void _checkIdentity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, [Json? params]) async {
    _checkIdentity();
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: params,
    );
    _checkIdentity();
    return result;
  }

  Json _json(dynamic data) => Json.from(data as Map);
  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) async => (await _rpc('list_trainer_clients', {
    'p_state': state.name,
    'p_before_at': before?.updatedAt.toUtc().toIso8601String(),
    'p_before_client_id': before?.personId,
  }) as List).map((v) => TrainerClient.fromJson(_json(v))).toList();
  @override
  Future<void> archiveClient(String clientId, {required bool archived}) async {
    await _rpc('archive_trainer_client', {
      'p_client_id': clientId,
      'p_archived': archived,
    });
  }

  @override
  Future<List<TrainerRelation>> clientRelations(
    String clientId, {
    TrainerRelation? before,
  }) async => (await _rpc('get_trainer_client_relations', {
    'p_client_id': clientId,
    'p_before_at': before?.acceptedAt.toUtc().toIso8601String(),
    'p_before_id': before?.id,
  }) as List).map((v) => TrainerRelation.fromJson(_json(v))).toList();
  @override
  Future<List<ManagedTrainer>> managedTrainers({String? afterId}) async =>
      (await _rpc('list_managed_trainers', {'p_after_id': afterId}) as List)
          .map((v) => ManagedTrainer.fromJson(_json(v)))
          .toList();
  @override
  Future<TrainerAccess> access() async =>
      TrainerAccess.fromJson(_json(await _rpc('get_trainer_access')));
  @override
  Future<List<TrainerRelation>> relations({
    required bool asTrainer,
    bool ended = false,
    TrainerRelation? before,
  }) async => (await _rpc('list_my_trainer_relations', {
    'p_as_trainer': asTrainer,
    'p_ended': ended,
    'p_before_at': before?.acceptedAt.toUtc().toIso8601String(),
    'p_before_id': before?.id,
  }) as List).map((v) => TrainerRelation.fromJson(_json(v))).toList();
  @override
  Future<List<TrainerInvitation>> invitations({
    TrainerInvitation? before,
  }) async {
    _checkIdentity();
    var query = client
        .from('trainer_invitations')
        .select('id,created_at,expires_at,revoked_at,accepted_at')
        .eq('trainer_id', userId);
    // Cursor compuesto para no omitir invitaciones con la misma fecha.
    if (before != null) {
      query = query.or(
        'created_at.lt.${before.createdAt.toUtc().toIso8601String()},and(created_at.eq.${before.createdAt.toUtc().toIso8601String()},id.lt.${before.id})',
      );
    }
    final result = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50);
    _checkIdentity();
    return result.map((v) => TrainerInvitation.fromJson(v)).toList();
  }

  @override
  Future<void> createInvitation(TrainerInvitationDraft draft) async {
    await _rpc('create_trainer_invitation', {
      'p_id': draft.id,
      'p_secret': draft.secret,
    });
  }

  @override
  Future<TrainerInvitationPreview> preview(String secret) async =>
      TrainerInvitationPreview.fromJson(
        _json(await _rpc('preview_trainer_invitation', {'p_secret': secret})),
      );
  @override
  Future<void> accept(String secret) async {
    await _rpc('accept_trainer_invitation', {'p_secret': secret});
  }

  @override
  Future<void> cancelInvitation(String id) async {
    await _rpc('cancel_trainer_invitation', {'p_id': id});
  }

  @override
  Future<void> endRelation(String id) async {
    await _rpc('end_trainer_relation', {'p_id': id});
  }

  @override
  Future<TrainerManagement> management(String trainerId) async =>
      TrainerManagement.fromJson(
        _json(
          await _rpc('get_trainer_management_status', {
            'p_trainer_id': trainerId,
          }),
        ),
      );
  @override
  Future<TrainerAccess> changeAccess(TrainerAccessChange change) async =>
      TrainerAccess.fromJson(
        _json(
          await _rpc('admin_set_trainer_access', {
            'p_trainer_id': change.trainerId,
            'p_client_limit': change.limit,
            'p_enabled': change.enabled,
            'p_expected_revision': change.revision,
            'p_reason': change.reason,
            'p_valid_until': change.validUntil?.toUtc().toIso8601String(),
          }),
        ),
      );
}

String trainerError(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '23505' =>
        'El alumno ya tiene un preparador activo. Actualiza el vínculo.',
      '23514' => 'El cupo no permite esta operación. Actualiza los clientes y el acceso.',
      '40001' => 'Los datos han cambiado. Actualiza antes de volver a guardar.',
      '42501' =>
        'Esta cuenta no tiene acceso a esta operación o el acceso ha caducado.',
      '22023' =>
        'La invitación o los datos ya no son válidos. Revísalos y actualiza.',
      _ => 'No se ha podido confirmar la operación. Puedes reintentarlo.',
    };
  }
  return 'No se ha podido confirmar la operación. Comprueba la conexión y reintenta.';
}

String trainerDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
