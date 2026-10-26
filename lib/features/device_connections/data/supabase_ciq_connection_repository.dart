import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ciq_connection.dart';

class SupabaseCiqConnectionRepository implements CiqConnectionRepository {
  const SupabaseCiqConnectionRepository(this.client, this.ownerId);
  final SupabaseClient client;
  final String ownerId;

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != ownerId) {
      throw const CiqException('account_changed');
    }
    bool unchanged() =>
        client.auth.currentUser?.id == ownerId &&
        client.auth.currentSession?.accessToken == session.accessToken;
    try {
      final result = await client.functions.invoke(
        'garmin-ciq/account',
        body: {'action': action, 'expected_user_id': ownerId, ...input},
      );
      if (!unchanged()) throw const CiqException('account_changed');
      if (result.data is! Map) throw const CiqException('invalid_response');
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (error) {
      if (!unchanged()) throw const CiqException('account_changed');
      final details = error.details;
      throw CiqException(
        details is Map && details['code'] is String
            ? details['code'] as String
            : 'unavailable',
      );
    } on CiqException {
      rethrow;
    } catch (_) {
      throw CiqException(unchanged() ? 'unavailable' : 'account_changed');
    }
  }

  @override
  Future<CiqAccount> load() async => decodeCiqAccount(await _call('account'));
  @override
  Future<CiqPairReview> review(String code) async {
    try {
      final data = await _call('review', {'code': code});
      return CiqPairReview(
        data['id'] as String,
        data['device'] as String,
        DateTime.parse(data['pair_until'] as String),
      );
    } on CiqException {
      rethrow;
    } catch (_) {
      throw const CiqException('invalid_response');
    }
  }

  @override
  Future<void> approve(String code, String id) async {
    final data = await _call('approve', {'code': code, 'id': id});
    if (data['linked'] != true) throw const CiqException('invalid_response');
  }

  @override
  Future<void> revoke(String id) async {
    final data = await _call('revoke', {'id': id});
    if (data['revoked'] != true) throw const CiqException('invalid_response');
  }
}

CiqAccount decodeCiqAccount(Map<String, dynamic> data) {
  try {
    final links = (data['links'] as List)
        .map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return CiqLink(
            row['id'] as String,
            DateTime.parse(row['created_at'] as String),
            DateTime.parse(row['valid_until'] as String),
            row['revoked'] as bool,
            row['last_seen_at'] == null
                ? null
                : DateTime.parse(row['last_seen_at'] as String),
          );
        })
        .toList(growable: false);
    return CiqAccount(data['allowed'] as bool, links);
  } catch (_) {
    throw const CiqException('invalid_response');
  }
}
