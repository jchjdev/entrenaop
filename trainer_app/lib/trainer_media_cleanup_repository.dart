import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class TrainerMediaCleanupRepository {
  Object get ownerKey;
  Future<Map<String, dynamic>> inspect();
  Future<Map<String, dynamic>> sweep(String operationId);
  Future<Map<String, dynamic>> deleteVideo(String operationId, String assetId);
  Future<Map<String, dynamic>> run();
}

class SupabaseTrainerMediaCleanupRepository
    implements TrainerMediaCleanupRepository {
  const SupabaseTrainerMediaCleanupRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  @override
  Object get ownerKey => userId;

  Session _identity() {
    final session = client.auth.currentSession;
    if (session == null ||
        session.user.id != userId ||
        session.user.isAnonymous ||
        session.accessToken.isEmpty) {
      throw StateError(
        'La cuenta ha cambiado o ya no tiene una sesión válida.',
      );
    }
    return session;
  }

  Future<Map<String, dynamic>> _call(
    String action, {
    String? operationId,
    String? kind,
    String? target,
  }) async {
    var session = _identity();
    if (session.isExpired) {
      await client.auth.getSession();
      session = _identity();
      if (session.isExpired) throw StateError('Inicia sesión de nuevo.');
    }
    final bearer = 'Bearer ${session.accessToken}';
    try {
      final response = await client.functions.invoke(
        'trainer-media-cleanup',
        headers: {
          for (final key in client.functions.headers.keys.where(
            (key) => key.toLowerCase() == 'authorization',
          ))
            key: bearer,
          'Authorization': bearer,
        },
        body: {
          'expected_user_id': userId,
          'scope': 'trainer',
          'action': action,
          'operation_id': ?operationId,
          'kind': ?kind,
          'target': ?target,
        },
      );
      _identity();
      final data = response.data;
      if (data is! Map || data['items'] is! List || data['summary'] is! Map) {
        throw StateError('No se recibió un informe de limpieza válido.');
      }
      final summary = data['summary'] as Map;
      if ([
            'pending',
            'deleted',
            'protected',
            'freed_images',
            'freed_bytes',
          ].any((key) => summary[key] is! num || (summary[key] as num) < 0) ||
          (data['items'] as List).any(
            (item) =>
                item is! Map ||
                !['image', 'video'].contains(item['kind']) ||
                item['scope'] != 'trainer' ||
                item['state'] is! String,
          )) {
        throw StateError('No se recibió un informe de limpieza válido.');
      }
      if (operationId != null) {
        final receipt = data['receipt'];
        if (receipt is! Map ||
            receipt['operation_id'] != operationId ||
            receipt['expected_user_id'] != userId ||
            receipt['action'] != action ||
            receipt['scope'] != 'trainer' ||
            receipt['kind'] != kind ||
            receipt['target'] != target) {
          throw StateError('No se pudo confirmar la solicitud de limpieza.');
        }
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      _identity();
      if ([400, 401, 403, 409].contains(error.status)) {
        throw const FormatException(
          'No se autorizó la solicitud. Comprueba tu cuenta, el doble factor y si el archivo sigue disponible.',
        );
      }
      rethrow;
    } finally {
      _identity();
    }
  }

  @override
  Future<Map<String, dynamic>> inspect() => _call('inspect');
  @override
  Future<Map<String, dynamic>> sweep(String operationId) =>
      _call('sweep', operationId: operationId);
  @override
  Future<Map<String, dynamic>> deleteVideo(
    String operationId,
    String assetId,
  ) =>
      _call('delete', operationId: operationId, kind: 'video', target: assetId);
  @override
  Future<Map<String, dynamic>> run() => _call('run');
}
