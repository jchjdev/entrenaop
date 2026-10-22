import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/garmin_connection.dart';

class SupabaseGarminConnectionRepository implements GarminConnectionRepository {
  const SupabaseGarminConnectionRepository(this.client, this.ownerId);
  final SupabaseClient client;
  final String ownerId;

  String _sessionId() {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != ownerId) {
      throw const GarminConnectionException(
        GarminConnectionProblem.accountChanged,
      );
    }
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(session.accessToken.split('.')[1]),
          ),
        ),
      ) as Map;
      return payload['session_id'] as String;
    } catch (_) {
      throw const GarminConnectionException(
        GarminConnectionProblem.accountChanged,
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final session = _sessionId();
    try {
      final response = await client.functions.invoke(
        'garmin-connection',
        body: {'action': action, 'expected_user_id': ownerId, ...fields},
      );
      if (_sessionId() != session) {
        throw const GarminConnectionException(
          GarminConnectionProblem.accountChanged,
        );
      }
      if (response.status != 200 || response.data is! Map) {
        throw const GarminConnectionException(
          GarminConnectionProblem.invalidResponse,
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on GarminConnectionException {
      rethrow;
    } on FunctionException catch (error) {
      if (_sessionId() != session) {
        throw const GarminConnectionException(
          GarminConnectionProblem.accountChanged,
        );
      }
      final code = error.details is Map ? (error.details as Map)['code'] : null;
      throw GarminConnectionException(switch (code) {
        'account_changed' ||
        'unauthorized' => GarminConnectionProblem.accountChanged,
        'access_required' => GarminConnectionProblem.accessRequired,
        'rate_limited' => GarminConnectionProblem.rateLimited,
        'stale_attempt' ||
        'connection_busy' => GarminConnectionProblem.conflict,
        _ => GarminConnectionProblem.unavailable,
      });
    } catch (_) {
      if (_sessionId() != session) {
        throw const GarminConnectionException(
          GarminConnectionProblem.accountChanged,
        );
      }
      throw const GarminConnectionException(
        GarminConnectionProblem.unavailable,
      );
    }
  }

  @override
  Future<GarminConnectionSnapshot> load() async =>
      decodeGarminSnapshot(await _call('status'));

  @override
  Future<GarminAuthorization> begin() async {
    final json = await _call('begin');
    final snapshot = decodeGarminSnapshot(json);
    final uri = Uri.tryParse(
      json['authorization_url'] is String
          ? json['authorization_url'] as String
          : '',
    );
    if (snapshot.status != GarminConnectionStatus.authorizing ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'connect.garmin.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path != '/oauth2Confirm' ||
        uri.fragment.isNotEmpty) {
      throw const GarminConnectionException(
        GarminConnectionProblem.invalidResponse,
      );
    }
    return GarminAuthorization(snapshot, uri);
  }

  @override
  Future<GarminConnectionSnapshot> disconnect(int generation) async =>
      decodeGarminSnapshot(
        await _call('disconnect', {'generation': generation}),
      );
}

GarminConnectionSnapshot decodeGarminSnapshot(Map<String, dynamic> json) {
  try {
    final status = switch (json['status']) {
      'disconnected' => GarminConnectionStatus.disconnected,
      'authorizing' => GarminConnectionStatus.authorizing,
      'connected' => GarminConnectionStatus.connected,
      'authorization_failed' => GarminConnectionStatus.authorizationFailed,
      'disconnecting' => GarminConnectionStatus.disconnecting,
      'revocation_pending' => GarminConnectionStatus.revocationPending,
      _ => throw const FormatException(),
    };
    final generation = json['generation'] as int;
    if (generation < 0) throw const FormatException();
    final expires = json['authorization_expires_at'];
    return GarminConnectionSnapshot(
      status: status,
      allowed: json['allowed'] as bool,
      generation: generation,
      canRead: json['can_read'] as bool,
      canSend: json['can_send'] as bool,
      authorizationExpiresAt: expires == null
          ? null
          : DateTime.parse(expires as String),
    );
  } catch (_) {
    throw const GarminConnectionException(
      GarminConnectionProblem.invalidResponse,
    );
  }
}
