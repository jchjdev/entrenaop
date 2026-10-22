import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/training_delivery.dart';

class SupabaseTrainingDeliveryRepository implements TrainingDeliveryRepository {
  const SupabaseTrainingDeliveryRepository(this.client, this.ownerId);
  final SupabaseClient client;
  final String ownerId;
  String _session() {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != ownerId) {
      throw const TrainingDeliveryException('account_changed');
    }
    try {
      return (jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(session.accessToken.split('.')[1]),
              ),
            ),
          ) as Map)['session_id']
          as String;
    } catch (_) {
      throw const TrainingDeliveryException('account_changed');
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, Object?> fields = const {},
  ]) async {
    final session = _session();
    try {
      final response = await client.functions.invoke(
        'garmin-training',
        body: {'action': action, 'expected_user_id': ownerId, ...fields},
      );
      if (_session() != session) {
        throw const TrainingDeliveryException('account_changed');
      }
      if (response.status != 200 || response.data is! Map) {
        throw const TrainingDeliveryException('garmin_unavailable');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      if (_session() != session) {
        throw const TrainingDeliveryException('account_changed');
      }
      final code = error.details is Map ? (error.details as Map)['code'] : null;
      throw TrainingDeliveryException(
        code is String ? code : 'garmin_unavailable',
      );
    } catch (_) {
      if (_session() != session) {
        throw const TrainingDeliveryException('account_changed');
      }
      rethrow;
    }
  }

  @override
  Future<TrainingCatalog> load() async {
    final json = await _call('list');
    return TrainingCatalog(
      (json['candidates'] as List)
          .map(
            (v) => TrainingCandidate(
              v['id'] as String,
              v['name'] as String,
              v['date'] as String,
              v['source'] as String,
            ),
          )
          .toList(growable: false),
      (json['deliveries'] as List)
          .map(
            (v) => decodeTrainingReceipt(Map<String, dynamic>.from(v as Map)),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<TrainingPreview> preview(String scheduledId) async {
    final json = await _call('preview', {'scheduled_id': scheduledId});
    return decodeTrainingPreview(json);
  }

  @override
  Future<TrainingReceipt> send(String scheduledId, String revision) async =>
      decodeTrainingReceipt(
        await _call('send', {
          'scheduled_id': scheduledId,
          'revision': revision,
        }),
      );
}

TrainingPreview decodeTrainingPreview(Map<String, dynamic> json) {
  final p = json['prescription'] as Map;
  final revision = json['revision'] as String;
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(revision)) {
    throw const FormatException('Revisión inválida');
  }
  final steps = (p['steps'] as List)
      .map((v) {
        final value = (v['value'] as num).toDouble();
        if (!value.isFinite ||
            value <= 0 ||
            !['seconds', 'meters'].contains(v['measure']) ||
            ![
              'run',
              'warmup',
              'cooldown',
              'rest',
              'walk',
              'jog',
            ].contains(v['kind'])) {
          throw const FormatException('Paso incompatible');
        }
        final pace = v['pace'] as Map?;
        final fast = (pace?['fast'] as num?)?.toDouble(),
            slow = (pace?['slow'] as num?)?.toDouble();
        if (pace != null &&
            (fast == null ||
                slow == null ||
                !fast.isFinite ||
                !slow.isFinite ||
                fast <= 0 ||
                slow < fast)) {
          throw const FormatException('Ritmo inválido');
        }
        return TrainingStep(
          v['kind'] as String,
          v['measure'] as String,
          value,
          v['description'] as String,
          fast,
          slow,
        );
      })
      .toList(growable: false);
  if (steps.isEmpty || steps.length > 100) {
    throw const FormatException('Número de pasos inválido');
  }
  return TrainingPreview(
    revision,
    p['name'] as String,
    p['date'] as String,
    steps,
    description: p['description'] as String? ?? '',
  );
}

TrainingReceipt decodeTrainingReceipt(Map<String, dynamic> json) {
  final status = json['status'] as String;
  if (![
    'prepared',
    'refreshing',
    'creating',
    'workout_created',
    'scheduling',
    'sent',
    'failed',
    'uncertain',
  ].contains(status)) {
    throw const FormatException('Estado desconocido');
  }
  return TrainingReceipt(
    json['id'] as String,
    json['scheduled_id'] as String,
    status,
    json['name'] as String,
    json['date'] as String,
    json['error_code'] as String?,
  );
}
