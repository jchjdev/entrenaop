import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdminOperationsRepository {
  Future<List<Map<String, dynamic>>> history({String? kind, int? beforeId});
  Future<Map<String, dynamic>?> event(int id);
  Future<String> restore(int id, String requestId, {required bool useBefore});
  Future<List<Map<String, dynamic>>> quality();
  Future<Map<String, dynamic>> status();
  Future<Map<String, dynamic>> support(String userId);
  Future<Map<String, dynamic>?> deployment();
}

class SupabaseAdminOperationsRepository implements AdminOperationsRepository {
  const SupabaseAdminOperationsRepository(this.client);
  final SupabaseClient client;

  List<Map<String, dynamic>> _rows(dynamic data) => [
    for (final row in data as List) Map<String, dynamic>.from(row as Map),
  ];
  @override
  Future<List<Map<String, dynamic>>> history({
    String? kind,
    int? beforeId,
  }) async => _rows(
    await client.rpc(
      'admin_editorial_history',
      params: {'p_kind': kind, 'p_before_id': beforeId},
    ),
  );
  @override
  Future<Map<String, dynamic>?> event(int id) async {
    final data = await client.rpc(
      'admin_editorial_event',
      params: {'p_event_id': id},
    );
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<String> restore(
    int id,
    String requestId, {
    required bool useBefore,
  }) async => await client.rpc(
    'restore_admin_editorial_event',
    params: {
      'p_event_id': id,
      'p_request_id': requestId,
      'p_use_before': useBefore,
    },
  ) as String;
  @override
  Future<List<Map<String, dynamic>>> quality() async =>
      _rows(await client.rpc('admin_catalog_quality'));
  @override
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    await client.rpc('admin_operations_status') as Map,
  );
  @override
  Future<Map<String, dynamic>> support(String userId) async =>
      Map<String, dynamic>.from(
        await client.rpc('admin_account_support', params: {'p_user_id': userId})
            as Map,
      );
  @override
  Future<Map<String, dynamic>?> deployment() async {
    final transport = http.Client();
    try {
      final response = await transport
          .get(
            Uri.base
                .resolve('/build-info.json')
                .replace(
                  queryParameters: {
                    'check': DateTime.now().millisecondsSinceEpoch.toString(),
                  },
                ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404 &&
          ['localhost', '127.0.0.1'].contains(Uri.base.host)) {
        return null;
      }
      if (response.statusCode != 200) {
        throw StateError('Manifiesto no disponible');
      }
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (!['development', 'production'].contains(data['environment']) ||
          data['supabaseProject'] is! String ||
          data['builtAtUtc'] is! String ||
          data['revision'] is! String ||
          !RegExp(r'^[a-f0-9]{40}$').hasMatch(data['revision'] as String)) {
        throw const FormatException('Manifiesto inválido');
      }
      return data;
    } finally {
      transport.close();
    }
  }
}
